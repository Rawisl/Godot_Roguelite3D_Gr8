#!/usr/bin/env python3
"""Turns balance/balance.xlsx into the .tres balance files of the game.

Run from anywhere:  python tools/balance/generate.py
Check only:         python tools/balance/generate.py --check   (exit 1 when a file would change)

The whole table is checked first. Any empty cell or negative number is reported as sheet!cell
and nothing is written. Needs Python 3.13+ and openpyxl; Godot is not needed.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[2]
XLSX = ROOT / "balance" / "balance.xlsx"
HEADER_COMMENT = "; AUTO-GENERATED from balance/balance.xlsx by tools/balance/generate.py. Edit the table, not this file."
SHEETS = ["character", "skills", "towers", "weapons", "enemies", "waves", "wave_rewards"]

# Sheet id -> id used by the game.
WEAPON_IDS = {"sword": "sword_base"}
# Sheet key -> key the code reads, per skill.
SKILL_KEYS = {"firebomb": {"dps": "damage"}}
# Weapon columns that are fields of WeaponData and not effect parameters.
WEAPON_FIELDS = {"range_mult", "effect_id"}


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
    book = openpyxl.load_workbook(XLSX, data_only=True)
    tables: dict[str, Table] = {}
    for name in SHEETS:
        if name not in book.sheetnames:
            errors.append(f"{name}: sheet is missing")
            continue
        sheet = book[name]
        rows = list(sheet.iter_rows())
        if not rows:
            errors.append(f"{name}: sheet is empty")
            continue
        header: list[str] = []
        for cell in rows[0]:
            if cell.value is None or str(cell.value).strip() == "":
                break
            header.append(str(cell.value).strip())
        table = Table(name, header)
        for row in rows[1:]:
            if all(c.value is None or str(c.value).strip() == "" for c in row):
                continue
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


EXPORT_RE = re.compile(r"^@export(?:_range\(.*?\))?\s+var\s+(\w+)\s*:\s*([^=\n]+?)\s*(?:=\s*(.*))?$")
ENUM_RE = re.compile(r"^enum\s+(\w+)\s*\{(.*?)\}", re.M | re.S)


def parse_script(path: Path) -> dict[str, str]:
    """Exported fields of a script in declaration order: name -> declared type."""
    fields: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = EXPORT_RE.match(line.strip())
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def parse_enums() -> dict[str, dict[str, int]]:
    text = (ROOT / "common" / "enums.gd").read_text(encoding="utf-8")
    enums: dict[str, dict[str, int]] = {}
    for name, body in ENUM_RE.findall(text):
        members: dict[str, int] = {}
        for index, item in enumerate(p.strip() for p in body.split(",") if p.strip()):
            key, _, number = item.partition("=")
            members[key.strip()] = int(number) if number.strip() else index
        enums[name] = members
    return enums


ENUMS = parse_enums()


def format_number(value: float) -> str:
    """Whole numbers print without .0, others with up to 10 significant digits."""
    if float(value).is_integer():
        return str(int(value))
    return format(float(value), ".10g")


def format_value(value, declared_type: str, where: str):
    """Formats a table value as the text of a .tres field of the declared GDScript type."""
    if declared_type.startswith("Enums."):
        members = ENUMS[declared_type.split(".", 1)[1]]
        if isinstance(value, str):
            if value.strip().upper() not in members:
                raise BalanceError(f"{where}: '{value}' is not a member of {declared_type}")
            return str(members[value.strip().upper()])
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
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise BalanceError(f"{where}: expected a number, got {value!r}")
        return format_number(value)
    if declared_type == "StringName":
        return f'&"{value}"'
    if declared_type == "String":
        return f'"{value}"'
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
    script = ROOT / "common" / "skill_data.gd"
    grouped: dict[str, dict[str, dict[int, float]]] = {}
    skipped = 0
    for row, coords in zip(table.rows, table.cells):
        if str(row["kind"]).upper() != "ACTIVE":
            skipped += 1
            continue
        skill = str(row["skill_id"])
        key = SKILL_KEYS.get(skill, {}).get(str(row["key"]), str(row["key"]))
        level = row["level"]
        if isinstance(level, bool) or not isinstance(level, (int, float)) or not float(level).is_integer() or level < 1:
            raise BalanceError(f"skills!{coords['level']}: level must be a whole number from 1")
        grouped.setdefault(skill, {}).setdefault(key, {})[int(level)] = row["value"]
    plan.warnings.append(f"skills: {skipped} passive and stat rows are not generated (only ACTIVE skills are)")
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
                raise BalanceError(f"skills: {skill}.{key} has gaps in its levels {sorted(levels)}")
            lines.append(f'&"{key}": PackedFloat32Array({", ".join(format_number(levels[n]) for n in sorted(levels))})')
        counts = {len(v) for v in keys.values()}
        if len(counts) != 1:
            raise BalanceError(f"skills: {skill} has a different number of levels per key")
        values = "Dictionary[StringName, PackedFloat32Array]({\n" + ",\n".join(lines) + "\n})"
        plan.add(path, render(script, "SkillData", old, {"values": values}))


def gen_towers(table: Table, plan: Plan) -> None:
    data_script = ROOT / "common" / "tower_data.gd"
    level_script = ROOT / "common" / "tower_level_data.gd"
    level_fields = parse_script(level_script)
    grouped: dict[str, dict[int, tuple[dict, dict]]] = {}
    for row, coords in zip(table.rows, table.cells):
        level = row["level"]
        if isinstance(level, bool) or not isinstance(level, (int, float)) or not float(level).is_integer() or level < 1:
            raise BalanceError(f"towers!{coords['level']}: level must be a whole number from 1")
        grouped.setdefault(str(row["tower_id"]), {})[int(level)] = (row, coords)
    for tower, levels in grouped.items():
        if sorted(levels) != list(range(1, len(levels) + 1)):
            raise BalanceError(f"towers: {tower} has gaps in its levels")
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
                if column not in row:
                    raise BalanceError(f"towers: column '{column}' of TowerLevelData is missing in the sheet")
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
    script = ROOT / "common" / "weapon_data.gd"
    if not script.exists():
        plan.warnings.append("weapons: common/weapon_data.gd does not exist yet, the weapons sheet is skipped")
        return
    declared = parse_script(script)
    grouped: dict[str, dict] = {}
    for row, coords in zip(table.rows, table.cells):
        weapon = WEAPON_IDS.get(str(row["weapon_id"]), str(row["weapon_id"]))
        entry = grouped.setdefault(weapon, {"effect": str(row["effect_id"]), "fields": {}, "params": {}})
        if str(row["effect_id"]) != entry["effect"]:
            raise BalanceError(f"weapons!{coords['effect_id']}: {weapon} has more than one effect_id")
        key = str(row["key"])
        if key in WEAPON_FIELDS:
            entry["fields"][key] = format_value(row["value"], declared[key], f"weapons!{coords['value']}")
        else:
            entry["params"][key] = format_value(row["value"], "float", f"weapons!{coords['value']}")
    for weapon, entry in grouped.items():
        path = ROOT / "data" / "weapons" / f"{weapon}.tres"
        managed = {"id": f'&"{weapon}"', "effect_id": f'&"{entry["effect"]}"'}
        managed.update(entry["fields"])
        if entry["params"]:
            items = ",\n".join(f'&"{k}": {v}' for k, v in entry["params"].items())
            managed["params"] = "Dictionary[StringName, float]({\n" + items + "\n})"
        else:
            old_file = parse_tres(path)
            if old_file is not None and "params" in old_file.fields:
                managed["params"] = "Dictionary[StringName, float]({})"
        plan.add(path, render(script, "WeaponData", parse_tres(path), managed, defaults={"name_key": f'&"weapon.{weapon}.name"'}))


def check_unused(tables: dict[str, Table], plan: Plan) -> None:
    for name in ("waves", "wave_rewards"):
        plan.warnings.append(f"{name}: checked, but nothing is generated from it yet")


# --------------------------------------------------------------------------- main


def build_plan(tables: dict[str, Table]) -> Plan:
    plan = Plan()
    gen_character(tables["character"], plan)
    gen_skills(tables["skills"], plan)
    gen_towers(tables["towers"], plan)
    gen_enemies(tables["enemies"], plan)
    gen_weapons(tables["weapons"], plan)
    check_unused(tables, plan)
    return plan


def main(argv: list[str]) -> int:
    check_only = "--check" in argv
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
    for path in changed:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(plan.files[path])
    print(f"{len(changed)} files written, {same} unchanged")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
