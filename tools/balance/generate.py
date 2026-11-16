#!/usr/bin/env python3
"""Turns balance/balance.xlsx into the .tres balance files of the game.

Run from anywhere:  python tools/balance/generate.py
Check only:         python tools/balance/generate.py --check   (exit 1 when a file would change)

The whole table is checked first. Any empty cell or negative number is reported as sheet!cell
and nothing is written. Needs Python 3.13+ and openpyxl; Godot is not needed.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import sys
import tempfile
from contextlib import closing
from dataclasses import dataclass, field
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[2]
XLSX = ROOT / "balance" / "balance.xlsx"
HEADER_COMMENT = "; AUTO-GENERATED from balance/balance.xlsx by tools/balance/generate.py. Edit the table, not this file."
SHEETS = ["character", "skills", "towers", "weapons", "enemies", "waves", "wave_rewards"]

# Weapon keys that are fields of WeaponData and not effect parameters (`effect_id` has its own column).
WEAPON_FIELDS = {"range_mult"}


class BalanceError(Exception):
    pass


# --------------------------------------------------------------------------- table


@dataclass
class Table:
    name: str
    header: list[str]
    rows: list[dict] = field(default_factory=list)  # column -> value
    cells: list[dict] = field(default_factory=list)  # column -> coordinate, same order as rows


def read_tables() -> tuple[dict[str, Table], list[str]]:
    """Reads every sheet and returns the tables with the list of table errors."""
    errors: list[str] = []
    tables: dict[str, Table] = {}
    with closing(openpyxl.load_workbook(XLSX, data_only=True)) as book:
        for name in SHEETS:
            if name not in book.sheetnames:
                errors.append(f"{name}: sheet is missing")
                continue
            sheet = book[name]
            rows = list(sheet.iter_rows())
            if not rows:
                errors.append(f"{name}!A1: sheet is empty")
                continue
            if len(rows) == 1:
                errors.append(f"{name}!A2: sheet has no data rows")
            header: list[str] = []
            width = max((cell.column for row in rows for cell in row if cell.value is not None), default=1)
            for cell in rows[0][:width]:
                column = str(cell.value).strip() if cell.value is not None else ""
                if not column:
                    errors.append(f"{name}!{cell.coordinate}: empty header")
                    column = f"column_{cell.column}"
                if column in header:
                    errors.append(f"{name}!{cell.coordinate}: duplicate header ({column})")
                header.append(column)
            table = Table(name, header)
            for row in rows[1:]:
                values, coords = {}, {}
                for index, column in enumerate(header):
                    cell = row[index] if index < len(row) else None
                    coordinate = cell.coordinate if cell is not None else f"{openpyxl.utils.get_column_letter(index + 1)}{row[0].row}"
                    value = cell.value if cell is not None else None
                    if value is None or (isinstance(value, str) and value.strip() == ""):
                        errors.append(f"{name}!{coordinate}: empty cell ({column})")
                    elif isinstance(value, (int, float)) and not isinstance(value, bool) and value < 0:
                        errors.append(f"{name}!{coordinate}: negative number {value} ({column})")
                    values[column] = value
                    coords[column] = coordinate
                table.rows.append(values)
                table.cells.append(coords)
            tables[name] = table
    return tables, errors


# --------------------------------------------------------------------------- GDScript


EXPORT_RE = re.compile(r"^@export(?:_\w+(?:\(.*?\))?)?(?:\s+|$)")
ENUM_RE = re.compile(r"^enum\s+(\w+)\s*\{(.*?)\}", re.M | re.S)


def strip_gd_comment(line: str) -> str:
    quote = ""
    escaped = False
    for index, character in enumerate(line):
        if escaped:
            escaped = False
        elif quote and character == "\\":
            escaped = True
        elif character == quote:
            quote = ""
        elif not quote and character in ("'", '"'):
            quote = character
        elif not quote and character == "#":
            return line[:index].rstrip()
    return line.rstrip()


def infer_literal_type(value: str, where: str) -> str:
    if value in ("true", "false"):
        return "bool"
    if re.fullmatch(r"[-+]?\d+", value):
        return "int"
    if re.fullmatch(r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?", value):
        return "float"
    if value.startswith(('&"', "&'")):
        return "StringName"
    if value.startswith(('"', "'")):
        return "String"
    constructor = re.match(r"((?:Array|Dictionary)\[.*\]|Packed\w+Array|int|float|bool|StringName)\(", value)
    if constructor:
        return constructor[1]
    enum = re.fullmatch(r"(Enums\.\w+)\.\w+", value)
    if enum:
        return enum[1]
    raise BalanceError(f"{where}: cannot infer an exported type; declare the type explicitly")


def parse_exports(path: Path) -> dict[str, tuple[str, str]]:
    fields = {}
    pending = False
    for number, source in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = strip_gd_comment(source).strip()
        if not line:
            continue
        if re.match(r"^@export_(?:group|category|subgroup)\(", line):
            continue
        annotation = EXPORT_RE.match(line)
        if annotation:
            pending = True
            line = line[annotation.end():].strip()
            if not line:
                continue
        if not pending:
            continue
        where = f"{path}:{number}"
        inferred = re.fullmatch(r"var\s+(\w+)\s*:=\s*(.+)", line)
        typed = re.fullmatch(r"var\s+(\w+)\s*:\s*([^=]+?)(?:\s*=\s*(.*))?", line)
        if inferred:
            fields[inferred[1]] = (infer_literal_type(inferred[2], where), inferred[2])
        elif typed:
            fields[typed[1]] = (typed[2].strip(), typed[3] or "")
        else:
            raise BalanceError(f"{where}: unsupported export declaration; use a typed variable or literal inference")
        pending = False
    if pending:
        raise BalanceError(f"{path}: export annotation has no variable declaration")
    return fields


def parse_script(path: Path) -> dict[str, str]:
    return {name: kind for name, (kind, _) in parse_exports(path).items()}


def parse_enums() -> dict[str, dict[str, int]]:
    path = ROOT / "common" / "enums.gd"
    source = "\n".join(strip_gd_comment(line) for line in path.read_text(encoding="utf-8").splitlines())
    enums = {}
    for name, body in ENUM_RE.findall(source):
        members = {}
        next_value = 0
        for item in (part.strip() for part in body.split(",") if part.strip()):
            key, separator, number = item.partition("=")
            try:
                value = int(number.strip(), 0) if separator else next_value
            except ValueError as error:
                raise BalanceError(f"{path}: {name}.{key.strip()} must use an integer literal") from error
            members[key.strip()] = value
            next_value = value + 1
        enums[name] = members
    return enums


def format_number(value: float) -> str:
    """Whole numbers print without .0, others with up to 10 significant digits."""
    if float(value).is_integer():
        return str(int(value))
    return format(float(value), ".10g")


def format_value(value, declared_type: str, where: str):
    """Formats a table value as the text of a .tres field of the declared GDScript type."""
    if declared_type.startswith("Enums."):
        members = parse_enums().get(declared_type.split(".", 1)[1])
        if members is None:
            raise BalanceError(f"{where}: unknown enum {declared_type}")
        if isinstance(value, str):
            if value.strip().upper() not in members:
                raise BalanceError(f"{where}: '{value}' is not a member of {declared_type}")
            return str(members[value.strip().upper()])
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not float(value).is_integer():
            raise BalanceError(f"{where}: expected a whole enum value, got {value!r}")
        if int(value) not in members.values():
            raise BalanceError(f"{where}: {value!r} is not a member of {declared_type}")
        return str(int(value))
    if declared_type == "bool":
        if not isinstance(value, bool):
            raise BalanceError(f"{where}: expected TRUE or FALSE, got {value!r}")
        return "true" if value else "false"
    if declared_type == "int":
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not float(value).is_integer():
            raise BalanceError(f"{where}: expected a whole number, got {value!r}")
        return str(int(value))
    if declared_type == "float":
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise BalanceError(f"{where}: expected a finite number, got {value!r}")
        return format_number(value)
    if declared_type == "StringName":
        return "&" + json.dumps(str(value), ensure_ascii=False)
    if declared_type == "String":
        return json.dumps(str(value), ensure_ascii=False)
    raise BalanceError(f"{where}: field type {declared_type} is not supported")


# --------------------------------------------------------------------------- .tres


EXT_RE = re.compile(r'^\[ext_resource type="([^"]*)"(?: uid="([^"]*)")? path="([^"]*)" id="([^"]*)"\]$')
HEAD_RE = re.compile(r'^\[gd_resource type="([^"]*)" script_class="([^"]*)" format=3(?: uid="([^"]*)")?\]$')


@dataclass
class Ext:
    kind: str
    uid: str
    path: str
    id: str

    def line(self) -> str:
        uid = f' uid="{self.uid}"' if self.uid else ""
        return f'[ext_resource type="{self.kind}"{uid} path="{self.path}" id="{self.id}"]'


@dataclass
class Tres:
    script_class: str
    uid: str = ""
    exts: list[Ext] = field(default_factory=list)
    fields: dict[str, str] = field(default_factory=dict)  # name -> raw value text, in file order


def parse_tres(path: Path) -> Tres | None:
    """Reads an existing .tres of the simple shape the generator writes. None when there is none."""
    if not path.exists():
        return None
    result: Tres | None = None
    in_resource = False
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.rstrip("\r")
        if not line.strip() or line.startswith(";"):
            continue
        head = HEAD_RE.match(line)
        if head:
            result = Tres(head.group(2), head.group(3) or "")
            continue
        if result is None:
            raise BalanceError(f"{path}: no [gd_resource] header")
        ext = EXT_RE.match(line)
        if ext:
            result.exts.append(Ext(ext.group(1), ext.group(2) or "", ext.group(3), ext.group(4)))
        elif line == "[resource]":
            in_resource = True
        elif line.startswith("["):
            raise BalanceError(f"{path}: section {line} is not supported by the generator")
        elif in_resource and " = " in line:
            key, _, raw = line.partition(" = ")
            result.fields[key.strip()] = raw
    if result is None:
        raise BalanceError(f"{path}: no [gd_resource] header")
    return result


def script_uid(script: Path) -> str:
    uid_file = script.with_name(script.name + ".uid")
    return uid_file.read_text(encoding="utf-8").strip() if uid_file.exists() else ""


def render(script: Path, script_class: str, old: Tres | None, managed: dict[str, str],
           ext_first: list[Ext] | None = None, ext_last: list[Ext] | None = None,
           defaults: dict[str, str] | None = None) -> str:
    """Builds the text of a .tres.

    managed: field -> new text. Other fields keep their old text, in the order the script declares them.
    ext_first / ext_last: ext_resources that must be listed (the old ones that the body still uses stay).
    defaults: field -> text used only when the file is new and the field is not managed.
    """
    script_res = "res://" + script.relative_to(ROOT).as_posix()
    declared = list(parse_script(script))
    old = old or Tres(script_class)
    script_ext = next((e for e in old.exts if e.path == script_res), None)
    if script_ext is None:
        script_ext = Ext("Script", script_uid(script), script_res, "1_script")
    body = [f'script = ExtResource("{script_ext.id}")']
    seen = set()
    for name in declared:
        if name in managed:
            body.append(f"{name} = {managed[name]}")
        elif name in old.fields:
            body.append(f"{name} = {old.fields[name]}")
        elif defaults and name in defaults:
            body.append(f"{name} = {defaults[name]}")
        else:
            continue
        seen.add(name)
    for name, raw in old.fields.items():  # fields the script does not declare, such as metadata/...
        if name not in seen and name != "script":
            body.append(f"{name} = {raw}")
    body_text = "\n".join(body)

    exts: list[Ext] = [script_ext]
    for ext in list(old.exts) + (ext_first or []):
        if ext.id != script_ext.id and ext.path not in {e.path for e in exts}:
            exts.append(ext)
    for ext in ext_last or []:
        if ext.path not in {e.path for e in exts}:
            exts.append(ext)
    used = [e for e in exts if e.id == script_ext.id or f'ExtResource("{e.id}")' in body_text]

    uid = f' uid="{old.uid}"' if old.uid else ""
    lines = [f'[gd_resource type="Resource" script_class="{script_class}" format=3{uid}]', HEADER_COMMENT, ""]
    lines += [e.line() for e in used]
    lines += ["", "[resource]", body_text]
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- generators


class Plan:
    """Everything the run will write, kept in memory until the whole table has passed."""

    def __init__(self) -> None:
        self.files: dict[Path, str] = {}
        self.warnings: list[str] = []

    def add(self, path: Path, text: str) -> None:
        self.files[path] = text


def res(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def gen_character(table: Table, plan: Plan) -> None:
    validate_table_identity(table, ("key", "value"), ("key",))
    script = ROOT / "common" / "character_stats.gd"
    declared = parse_script(script)
    managed: dict[str, str] = {}
    for row, coords in zip(table.rows, table.cells):
        key = str(row["key"])
        if key not in declared:
            raise BalanceError(f"character!{coords['key']}: CharacterStats has no field '{key}'")
        managed[key] = format_value(row["value"], declared[key], f"character!{coords['value']}")
    path = ROOT / "data" / "config" / "commander_stats.tres"
    plan.add(path, render(script, "CharacterStats", parse_tres(path), managed))


def gen_skills(table: Table, plan: Plan) -> None:
    validate_table_identity(table, ("skill_id", "key", "level", "value"), ("skill_id", "key", "level"))
    script = ROOT / "common" / "skill_data.gd"
    aliases = balance_aliases()["skill_keys"]
    grouped: dict[str, dict[str, dict[int, str]]] = {}
    skill_cells: dict[str, str] = {}
    for row, coords in zip(table.rows, table.cells):
        skill = str(row["skill_id"])
        skill_cells.setdefault(skill, coords["level"])
        key = str(row["key"])
        key = aliases.get(skill, {}).get(key, key)
        level = row["level"]
        if isinstance(level, bool) or not isinstance(level, (int, float)) or not float(level).is_integer() or level < 1:
            raise BalanceError(f"skills!{coords['level']}: level must be a whole number from 1")
        value = format_value(row["value"], "float", f"skills!{coords['value']}")
        levels = grouped.setdefault(skill, {}).setdefault(key, {})
        if int(level) in levels:
            raise BalanceError(f"skills!{coords['key']}: duplicate normalized skill key and level")
        levels[int(level)] = value
    for skill, keys in grouped.items():
        path = ROOT / "data" / "skills" / f"{skill}.tres"
        old = parse_tres(path)
        if old is None:
            plan.warnings.append(f"skills: {res(path)} does not exist, {skill} skipped (it needs the icon and name keys of its file)")
            continue
        lines = []
        for key in sorted(keys):
            levels = keys[key]
            if sorted(levels) != list(range(1, len(levels) + 1)):
                raise BalanceError(f"skills!{skill_cells[skill]}: {skill}.{key} has gaps in its levels {sorted(levels)}")
            ordered_values = ", ".join(levels[n] for n in sorted(levels))
            lines.append(f'{format_value(key, "StringName", "skills")}: PackedFloat32Array({ordered_values})')
        counts = {len(v) for v in keys.values()}
        if len(counts) != 1:
            raise BalanceError(f"skills!{skill_cells[skill]}: {skill} has a different number of levels per key")
        values = "Dictionary[StringName, PackedFloat32Array]({\n" + ",\n".join(lines) + "\n})"
        plan.add(path, render(script, "SkillData", old, {"values": values}))


def gen_towers(table: Table, plan: Plan) -> None:
    data_script = ROOT / "common" / "tower_data.gd"
    level_script = ROOT / "common" / "tower_level_data.gd"
    level_fields = parse_script(level_script)
    validate_table_identity(table, ("tower_id", "level", *level_fields), ("tower_id", "level"))
    maximum = config_number("tower_max_level", "int")
    grouped: dict[str, dict[int, tuple[dict, dict]]] = {}
    for row, coords in zip(table.rows, table.cells):
        level = row["level"]
        if isinstance(level, bool) or not isinstance(level, (int, float)) or not float(level).is_integer() or level < 1:
            raise BalanceError(f"towers!{coords['level']}: level must be a whole number from 1")
        grouped.setdefault(str(row["tower_id"]), {})[int(level)] = (row, coords)
    for tower, levels in grouped.items():
        if sorted(levels) != list(range(1, maximum + 1)):
            coordinate = next(iter(levels.values()))[1]["level"]
            raise BalanceError(f"towers!{coordinate}: {tower} must have every level in 1..{maximum}")
        data_path = ROOT / "data" / "towers" / f"{tower}.tres"
        old = parse_tres(data_path)
        if old is None:
            plan.warnings.append(f"towers: {res(data_path)} does not exist, {tower} skipped")
            continue
        level_exts: list[Ext] = []
        taken = {e.id for e in old.exts}
        for number in sorted(levels):
            row, coords = levels[number]
            managed = {}
            for column, declared in level_fields.items():
                managed[column] = format_value(row[column], declared, f"towers!{coords[column]}")
            level_path = ROOT / "data" / "towers" / f"{tower}_l{number}.tres"
            plan.add(level_path, render(level_script, "TowerLevelData", parse_tres(level_path), managed))
            path_text = res(level_path)
            known = next((e for e in old.exts if e.path == path_text), None)
            if known is None:
                new_id = f"l{number}"
                while new_id in taken:
                    new_id += "_"
                taken.add(new_id)
                known = Ext("Resource", "", path_text, new_id)
            level_exts.append(known)
        level_type = next((e for e in old.exts if e.path == res(level_script)), None)
        type_id = level_type.id if level_type else "1_lvl"
        refs = ", ".join(f'ExtResource("{e.id}")' for e in level_exts)
        script_ext = Ext("Script", script_uid(level_script), res(level_script), type_id)
        old_level_paths = {e.path for e in old.exts if re.search(rf"/{re.escape(tower)}_l\d+\.tres$", e.path)}
        old_other = Tres(old.script_class, old.uid, [e for e in old.exts if e.path not in old_level_paths], dict(old.fields))
        managed = {"levels": f"Array[ExtResource(\"{type_id}\")]([{refs}])"}
        plan.add(data_path, render(data_script, "TowerData", old_other, managed, ext_first=[script_ext], ext_last=level_exts))


def gen_enemies(table: Table, plan: Plan) -> None:
    validate_table_identity(table, ("enemy_id",), ("enemy_id",))
    script = ROOT / "common" / "enemy_data.gd"
    declared = parse_script(script)
    extra = [c for c in table.header if c != "enemy_id" and c not in declared]
    if extra:
        plan.warnings.append(f"enemies: {len(extra)} columns are not fields of EnemyData and are skipped: {', '.join(extra)}")
    for row, coords in zip(table.rows, table.cells):
        enemy = str(row["enemy_id"])
        path = ROOT / "data" / "enemies" / f"{enemy}.tres"
        old = parse_tres(path)
        if old is None:
            plan.warnings.append(f"enemies: {res(path)} does not exist, {enemy} skipped")
            continue
        managed = {c: format_value(row[c], declared[c], f"enemies!{coords[c]}") for c in table.header if c in declared}
        plan.add(path, render(script, "EnemyData", old, managed))


def gen_weapons(table: Table, plan: Plan) -> None:
    validate_table_identity(table, ("weapon_id", "key", "value", "effect_id"), ("weapon_id", "key"))
    script = ROOT / "common" / "weapon_data.gd"
    if not script.exists():
        plan.warnings.append("weapons: common/weapon_data.gd does not exist yet, the weapons sheet is skipped")
        return
    declared = parse_script(script)
    aliases = balance_aliases()["weapon_ids"]
    seen = set()
    grouped: dict[str, dict] = {}
    for row, coords in zip(table.rows, table.cells):
        weapon = aliases.get(str(row["weapon_id"]), str(row["weapon_id"]))
        entry = grouped.setdefault(weapon, {"effect": str(row["effect_id"]), "fields": {}, "params": {}})
        if str(row["effect_id"]) != entry["effect"]:
            raise BalanceError(f"weapons!{coords['effect_id']}: {weapon} has more than one effect_id")
        key = str(row["key"])
        if (weapon, key) in seen:
            raise BalanceError(f"weapons!{coords['key']}: duplicate normalized weapon key")
        seen.add((weapon, key))
        if key == "effect_id":
            raise BalanceError(f"weapons!{coords['key']}: use the effect_id column instead of key 'effect_id'")
        if key in WEAPON_FIELDS:
            entry["fields"][key] = format_value(row["value"], declared[key], f"weapons!{coords['value']}")
        else:
            entry["params"][key] = format_value(row["value"], "float", f"weapons!{coords['value']}")
    for weapon, entry in grouped.items():
        path = ROOT / "data" / "weapons" / f"{weapon}.tres"
        managed = {"id": format_value(weapon, "StringName", "weapons"),
                   "effect_id": format_value(entry["effect"], "StringName", "weapons")}
        managed.update(entry["fields"])
        if entry["params"]:
            items = ",\n".join(f'{format_value(k, "StringName", "weapons")}: {v}' for k, v in entry["params"].items())
            managed["params"] = "Dictionary[StringName, float]({\n" + items + "\n})"
        else:
            old_file = parse_tres(path)
            if old_file is not None and "params" in old_file.fields:
                managed["params"] = "Dictionary[StringName, float]({})"
        plan.add(path, render(script, "WeaponData", parse_tres(path), managed, defaults={"name_key": format_value(f"weapon.{weapon}.name", "StringName", "weapons")}))


WAVE_FIELDS = ("spawn_duration", "hp_mult", "dmg_mult", "speed_mult")


@dataclass(frozen=True)
class WaveConfig:
    victory_wave: int
    boss_wave_interval: int
    wave_max_enemy_types: int
    lbd_min_seconds_per_wave: float


def config_number(name: str, kind: str):
    path = ROOT / "autoload" / "game_config.gd"
    fields = parse_exports(path)
    if name not in fields or fields[name][0] != kind:
        raise BalanceError(f"{path}: {name} must declare type {kind}")
    try:
        value = float(fields[name][1])
    except ValueError as error:
        raise BalanceError(f"{path}: {name} must use a numeric literal") from error
    format_value(value, kind, f"{path}: {name}")
    if value <= 0:
        raise BalanceError(f"{path}: {name} must be positive")
    return int(value) if kind == "int" else value


def wave_config() -> WaveConfig:
    return WaveConfig(**{name: config_number(name, kind) for name, kind in (
        ("victory_wave", "int"), ("boss_wave_interval", "int"),
        ("wave_max_enemy_types", "int"), ("lbd_min_seconds_per_wave", "float"),
    )})


def require_columns(table: Table, columns) -> None:
    missing = set(columns) - set(table.header)
    if missing:
        raise BalanceError(f"{table.name}!A1: missing columns: {', '.join(sorted(missing))}")


def validate_table_identity(table: Table, required, keys) -> None:
    require_columns(table, required)
    seen = {}
    for row, coords in zip(table.rows, table.cells):
        identity = tuple(row[key] if key == "level" else str(row[key]) for key in keys)
        if identity in seen:
            coordinate = coords[keys[0]]
            raise BalanceError(f"{table.name}!{coordinate}: duplicate row key {identity!r}; first at {table.name}!{seen[identity]}")
        seen[identity] = coords[keys[0]]


def balance_aliases() -> dict:
    path = Path(__file__).with_name("aliases.json")
    try:
        aliases = json.loads(path.read_text(encoding="utf-8"))
        weapons = aliases["weapon_ids"]
        skills = aliases["skill_keys"]
        valid = isinstance(weapons, dict) and isinstance(skills, dict)
        valid = valid and all(isinstance(key, str) and isinstance(value, str) for key, value in weapons.items())
        valid = valid and all(isinstance(skill, str) and isinstance(keys, dict)
                              and all(isinstance(key, str) and isinstance(value, str) for key, value in keys.items())
                              for skill, keys in skills.items())
        if not valid:
            raise ValueError("expected string aliases grouped by weapon ID and skill ID")
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise BalanceError(f"{path}: invalid balance aliases: {error}") from error
    return aliases


def numeric_cell(table: Table, row: dict, coords: dict, column: str, kind: str):
    where = f"{table.name}!{coords[column]}"
    format_value(row[column], kind, where)
    if row[column] < 0:
        raise BalanceError(f"{where}: negative number {row[column]} ({column})")
    return row[column]


def group_wave_rows(table: Table, config: WaveConfig, errors: list[str]) -> dict:
    grouped = {}
    for row, coords in zip(table.rows, table.cells):
        try:
            wave = int(numeric_cell(table, row, coords, "wave", "int"))
            if not 1 <= wave <= config.victory_wave:
                raise BalanceError(f"{table.name}!{coords['wave']}: wave must be in 1..{config.victory_wave}")
            grouped.setdefault(wave, []).append((row, coords))
        except BalanceError as error:
            errors.append(str(error))
    missing = sorted(set(range(1, config.victory_wave + 1)) - grouped.keys())
    if missing:
        anchor = table.cells[0]["wave"] if table.cells else "A1"
        errors.append(f"{table.name}!{anchor}: missing waves {missing}")
    return grouped


def boss_ids() -> set[str]:
    result: set[str] = set()
    for path in sorted((ROOT / "data" / "bosses").glob("*.tres")):
        resource = parse_tres(path)
        if resource is None or resource.script_class != "BossData":
            continue
        raw = resource.fields.get("id", "")
        try:
            identifier = json.loads(raw.removeprefix("&"))
        except (ValueError, TypeError) as error:
            raise BalanceError(f"{path}: BossData must declare a string id") from error
        if not isinstance(identifier, str) or not identifier or identifier in result:
            raise BalanceError(f"{path}: BossData id must be nonempty and unique")
        result.add(identifier)
    if not result:
        raise BalanceError("data/bosses: no BossData resources found")
    return result


def validate_wave_entry(table: Table, row: dict, coords: dict, references: dict,
                        enemies: set[str], config: WaveConfig, errors: list[str]) -> set[str]:
    valid_fields: set[str] = set()
    try:
        count = numeric_cell(table, row, coords, "count", "int")
        if count < 1:
            raise BalanceError(f"waves!{coords['count']}: count must be at least 1")
        valid_fields.add("count")
    except BalanceError as error:
        errors.append(str(error))
    try:
        format_value(row["is_escort"], "bool", f"waves!{coords['is_escort']}")
        valid_fields.add("is_escort")
    except BalanceError as error:
        errors.append(str(error))
    if row["enemy_id"] not in enemies:
        errors.append(f"waves!{coords['enemy_id']}: unknown enemy_id {row['enemy_id']!r}")
    for column in WAVE_FIELDS:
        try:
            value = numeric_cell(table, row, coords, column, "float")
        except BalanceError as error:
            errors.append(str(error))
            continue
        reference = references.setdefault(column, value)
        if not math.isclose(value, reference, rel_tol=1e-9, abs_tol=1e-9):
            errors.append(f"waves!{coords[column]}: {column} differs within wave {row['wave']}")
        if column == "spawn_duration" and value < config.lbd_min_seconds_per_wave:
            minimum = format_number(config.lbd_min_seconds_per_wave)
            errors.append(f"waves!{coords[column]}: spawn_duration must be at least {minimum} seconds")
    return valid_fields


def validate_boss_entries(wave: int, entries: list, valid_fields: list[set[str]],
                          bosses: set[str], errors: list[str]) -> None:
    anchor = f"waves!{entries[0][1]['enemy_id']}"
    boss_entries = [(row, coords, valid) for (row, coords), valid in zip(entries, valid_fields)
                    if row["enemy_id"] in bosses]
    if all("count" in valid for _, _, valid in boss_entries):
        count = sum(row["count"] for row, _, _ in boss_entries)
        if count != 1:
            cell = f"waves!{boss_entries[0][1]['count']}" if boss_entries else anchor
            errors.append(f"{cell}: boss wave {wave} must contain exactly one boss")
    escort_entries = [(row, valid) for (row, _), valid in zip(entries, valid_fields)
                      if row["enemy_id"] not in bosses]
    escort_fields = {"count", "is_escort"}
    has_escort = any(escort_fields <= valid and row["is_escort"] for row, valid in escort_entries)
    if not has_escort and all(escort_fields <= valid for _, valid in escort_entries):
        errors.append(f"{anchor}: boss wave {wave} must have an escort")


def validate_wave_groups(table: Table, grouped: dict, enemies: set[str],
                         bosses: set[str], config: WaveConfig, errors: list[str]) -> None:
    for wave, entries in grouped.items():
        references: dict[str, float] = {}
        valid_fields = [validate_wave_entry(table, row, coords, references, enemies, config, errors)
                        for row, coords in entries]
        anchor = f"waves!{entries[0][1]['enemy_id']}"
        if len({row["enemy_id"] for row, _ in entries}) > config.wave_max_enemy_types:
            errors.append(f"{anchor}: wave {wave} has more than {config.wave_max_enemy_types} enemy types")
        if wave % config.boss_wave_interval == 0:
            validate_boss_entries(wave, entries, valid_fields, bosses, errors)


def validate_reward_groups(table: Table, grouped: dict, errors: list[str]) -> None:
    for wave, entries in grouped.items():
        for index, (row, coords) in enumerate(entries):
            if index > 0:
                errors.append(f"wave_rewards!{coords['wave']}: duplicate reward for wave {wave}")
            try:
                for column in ("gold_mult", "xp_mult", "mithril_reward"):
                    numeric_cell(table, row, coords, column, "int" if column == "mithril_reward" else "float")
            except BalanceError as error:
                errors.append(str(error))


def validate_waves(tables: dict[str, Table]) -> None:
    config = wave_config()
    require_columns(tables["enemies"], ("enemy_id",))
    require_columns(tables["waves"], ("wave", "enemy_id", "count", "is_escort", *WAVE_FIELDS))
    require_columns(tables["wave_rewards"], ("wave", "gold_mult", "xp_mult", "mithril_reward"))
    enemies = {str(row["enemy_id"]) for row in tables["enemies"].rows}
    errors: list[str] = []
    grouped = group_wave_rows(tables["waves"], config, errors)
    validate_wave_groups(tables["waves"], grouped, enemies, boss_ids(), config, errors)
    grouped = group_wave_rows(tables["wave_rewards"], config, errors)
    validate_reward_groups(tables["wave_rewards"], grouped, errors)
    if errors:
        raise BalanceError("\n".join(errors))


def packed(values, kind: str) -> str:
    return f"{kind}({', '.join(format_number(value) for value in values)})"


def gen_waves(table: Table, plan: Plan) -> None:
    script = ROOT / "common" / "wave_script.gd"
    path = ROOT / "data" / "waves" / "wave_script.tres"
    rows = sorted(table.rows, key=lambda row: row["wave"])
    per_wave = {row["wave"]: row for row in rows}
    managed = {
        "wave_of_entry": packed((row["wave"] for row in rows), "PackedInt32Array"),
        "enemy_ids": "Array[StringName]([" + ", ".join(format_value(row["enemy_id"], "StringName", "waves") for row in rows) + "])",
        "counts": packed((row["count"] for row in rows), "PackedInt32Array"),
        "escorts": packed((int(row["is_escort"]) for row in rows), "PackedByteArray"),
    }
    for column in WAVE_FIELDS:
        managed[column] = packed((per_wave[wave][column] for wave in sorted(per_wave)), "PackedFloat32Array")
    plan.add(path, render(script, "WaveScript", parse_tres(path), managed))


def gen_wave_rewards(table: Table, plan: Plan) -> None:
    script = ROOT / "common" / "wave_reward_table.gd"
    path = ROOT / "data" / "waves" / "wave_rewards.tres"
    rows = sorted(table.rows, key=lambda row: row["wave"])
    managed = {column: packed((row[column] for row in rows), kind) for column, kind in (
        ("gold_mult", "PackedFloat32Array"), ("xp_mult", "PackedFloat32Array"),
        ("mithril_reward", "PackedInt32Array"),
    )}
    plan.add(path, render(script, "WaveRewardTable", parse_tres(path), managed))


def write_plan(plan: Plan, changed: list[Path]) -> None:
    staged: dict[Path, Path] = {}
    backups: dict[Path, Path | None] = {}
    installed: list[Path] = []
    retained: set[Path] = set()
    try:
        for path in changed:
            path.parent.mkdir(parents=True, exist_ok=True)
            for content, destination in ((plan.files[path].encode("utf-8"), staged),
                                         (path.read_bytes() if path.exists() else None, backups)):
                if content is None:
                    destination[path] = None
                    continue
                with tempfile.NamedTemporaryFile(dir=path.parent, prefix=path.name + ".", suffix=".tmp", delete=False) as handle:
                    destination[path] = Path(handle.name)
                    handle.write(content)
                    handle.flush()
                    os.fsync(handle.fileno())
        for path in changed:
            os.replace(staged[path], path)
            installed.append(path)
    except OSError as error:
        recovery_errors = []
        for path in reversed(installed):
            backup = backups[path]
            try:
                if backup is None:
                    path.unlink()
                else:
                    os.replace(backup, path)
            except OSError as recovery_error:
                if backup is not None:
                    retained.add(backup)
                recovery_errors.append(f"{path}: {recovery_error}; original backup: {backup}")
        if recovery_errors:
            raise OSError(f"{error}; rollback incomplete: {'; '.join(recovery_errors)}") from error
        raise
    finally:
        for temporary in [*staged.values(), *backups.values()]:
            if temporary is not None and temporary not in retained:
                temporary.unlink(missing_ok=True)


# --------------------------------------------------------------------------- main


def build_plan(tables: dict[str, Table]) -> Plan:
    plan = Plan()
    errors: list[str] = []
    waves_valid = False
    try:
        validate_waves(tables)
        waves_valid = True
    except BalanceError as error:
        errors.append(str(error))
    for generator, sheet in (
        (gen_character, "character"),
        (gen_skills, "skills"),
        (gen_towers, "towers"),
        (gen_enemies, "enemies"),
        (gen_weapons, "weapons"),
    ):
        try:
            generator(tables[sheet], plan)
        except BalanceError as error:
            errors.append(str(error))
    if waves_valid:
        gen_waves(tables["waves"], plan)
        gen_wave_rewards(tables["wave_rewards"], plan)
    if errors:
        unique_lines = list(dict.fromkeys(line for message in errors for line in message.splitlines()))
        raise BalanceError("\n".join(unique_lines))
    return plan


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--check", action="store_true", help="report changes without writing files")
    try:
        options = parser.parse_args(argv)
    except SystemExit as error:
        return int(error.code)
    check_only = options.check
    tables, errors = read_tables()
    if errors:
        print("The table has errors, nothing was written:", file=sys.stderr)
        for message in errors:
            print(f"  {message}", file=sys.stderr)
        return 1
    try:
        plan = build_plan(tables)
    except BalanceError as error:
        print(f"Nothing was written: {error}", file=sys.stderr)
        return 1

    changed, same = [], 0
    for path, text in sorted(plan.files.items()):
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == text:
            same += 1
        else:
            changed.append(path)
    for message in plan.warnings:
        print(f"warning: {message}")
    if check_only:
        for path in changed:
            print(f"would change: {path.relative_to(ROOT).as_posix()}")
        print(f"{len(changed)} files would change, {same} are up to date")
        return 1 if changed else 0
    try:
        write_plan(plan, changed)
    except OSError as error:
        print(f"Could not write balance files: {error}", file=sys.stderr)
        return 1
    print(f"{len(changed)} files written, {same} unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
