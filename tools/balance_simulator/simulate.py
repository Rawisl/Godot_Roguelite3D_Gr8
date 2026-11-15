#!/usr/bin/env python3
"""Compares the cumulative tower prices in balance/balance.xlsx with the gold a run is expected to earn.

Run from anywhere:  python -I tools/balance_simulator/simulate.py
Self check only:    python -I tools/balance_simulator/simulate.py --self-test   (does not read the table)

The script only reads balance/balance.xlsx and autoload/game_config.gd. It never writes the table:
it prints a summary and writes one self-contained interactive HTML page (report_template.html filled with a JSON
payload): knobs, charts, targets and the blocks to paste into the `towers` sheet. The page recomputes in JS with the
same formulas as compute() below. Needs Python 3.13+ and openpyxl; Godot is not needed.
Exit codes: 0 done, 1 bad table or game config, 2 bad arguments.
"""

from __future__ import annotations

import argparse
import copy
import datetime
import hashlib
import html
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import openpyxl

TEMPLATE = Path(__file__).with_name("report_template.html")
ROOT = Path(__file__).resolve().parents[2]
XLSX = ROOT / "balance" / "balance.xlsx"
GAME_CONFIG = ROOT / "autoload" / "game_config.gd"
DEFAULT_OUT = Path(tempfile.gettempdir()) / "endless_war_balance_report.html"

# Defaults of the command line knobs (the price curve shape and the income scenarios).
DEFAULT_GROWTH = 1.2  # price growth per level of the proposed curve
DEFAULT_GROWTH_FROM = ["14:1.1", "24:1.05"]  # used when no --growth-from is given
# Per type knobs of the proposed curve (TYPE.KEY=VALUE); a --set of the same TYPE.KEY replaces that default.
DEFAULT_SET = ("arrow.base=20 cannon.base=50 cannon.growth=1.12 cannon.growth_from=14:1.075 cannon.growth_from=18:1.1 "
               "cannon.growth_from=25:1.05 barricade.base=80 barricade.growth=1.04 barricade.growth_from=13:1.06 "
               "barricade.growth_from=25:1.1 heal_station.base=120 heal_station.growth=1.05 heal_station.growth_from=13:1.07").split()
DEFAULT_ROUND_TO = 5
DEFAULT_LAYOUT = "arrow=3,cannon=1,barricade=1,heal_station=1"  # the six buildings of a full defence
DEFAULT_STARTERS = "arrow=1,cannon=1"  # level 1 towers the run starts with, free of charge
DEFAULT_AVG_CMD_RATIO = 0.4  # share of kills made while a commander flag is up, average player
DEFAULT_STRONG_CMD_RATIO = 0.6  # same, strong player
# Total gold bonus of the strong scenario: the gold meta upgrade at its top, 4 levels of 4 percent.
DEFAULT_STRONG_GOLD_PCT = 0.16
DEFAULT_BOSS_IDS = "bulwark"

# Design targets, only shown as PASS or FAIL next to the numbers.
# M1..M4: (tower type, count, level, wave). The average run's cumulative gold up to and including that wave (the
# starting gold included) must pay count towers of that type, each bought level 1..level (the rebuild price).
AFFORD_TARGETS = [("arrow", 1, 14, 9), ("cannon", 2, 13, 14), ("arrow", 1, 25, 19), ("heal_station", 1, 1, 4)]
M5_MIN_RATIO = 1.0  # cost of the whole layout at tier 3 (starters deducted) compared with the gold of a strong run
# M6: (tower type, count, level, wave, min ratio): average gold up to that wave compared with count towers to that level.
M6_TARGET = ("arrow", 3, 25, 30, 0.8)

SCENARIOS = ["raw", "average", "strong"]
STAT_KEYS = ["max_hp", "damage", "attack_range", "fire_rate"]  # tower stats the page can scale
INT_STATS = {"max_hp": 5, "damage": 2}  # int fields of TowerLevelData and the step a scaled value is rounded to
SHEET_STAT_KEYS = STAT_KEYS + ["splash_radius"]
DEFAULT_TRAVEL_TIME = 15  # seconds a wave needs to walk into range, added to its spawn window
DEFAULT_SPLASH_TARGETS = 2.0  # enemies a splash shot is assumed to hit
DEFAULT_TOWER_SHARE = 1.0  # share of the wave hp the towers have to kill on their own
PAYLOAD_MARK = "/*__PAYLOAD__*/"
NOSCRIPT_MARK = "<!--__NOSCRIPT__-->"

GC_KEYS = [
    "victory_wave",
    "starting_gold",
    "tower_max_level",
    "tower_tier2_level",
    "tower_tier3_level",
    "frontline_gold_mult",
    "boss_gold_base",
    "clear_mult_normal",
    "clear_mult_fast",
    "hazard_enemy_count",
    "hazard_boss_escorts",
]
MAX_GROWTH_FROM_LEVEL = 999  # parser bound of a growth_from level; the real bound is tower_max_level
GC_LINE = re.compile(r"^@export var (\w+)\s*:\s*(int|float)\s*=\s*(-?\d+(?:\.\d+)?)\s*(#.*)?$")


class BalanceSimError(Exception):
    pass


# --------------------------------------------------------------------------- pure calculations


def round_half_up(x: float, step: int) -> int:
    return int(math.floor(x / step + 0.5)) * step


def proposed_costs(base, growth: float, round_to: int, max_level: int, growth_from=None) -> list:
    """Price of each level 1..max_level. Level 1 is the base as it stands in the table.

    growth_from is a list of (level, factor): from that level on the price grows by factor per level instead of
    growth, until the next segment starts. The price before rounding is chained (p(n) = p(n-1) * g(n)), so the
    curve has no gap. Powers are never used, so the JS copy of this function gives the same doubles."""
    costs = [base]
    segments = sorted(growth_from or [])
    chained = float(base)
    for n in range(2, max_level + 1):
        factor = growth
        for start, seg_factor in segments:
            if start <= n:
                factor = seg_factor
        chained *= factor
        cost = round_half_up(chained, round_to)
        costs.append(max(cost, round_to))
    return costs


def cumulative(costs: list) -> list:
    """cum[L] is the price of levels 1..L, cum[0] is 0."""
    cum = [0]
    for cost in costs:
        cum.append(cum[-1] + cost)
    return cum


def wave_income(entry: dict, gc: dict, clear_mult: float, cmd_ratio: float, hazard: bool, gold_pct: float) -> int:
    """Gold of one wave. entry holds normal_gold, normal_count, boss_count and gm (the wave gold multiplier)."""
    gm = entry["gm"]
    f = gc["frontline_gold_mult"]
    base = entry["normal_gold"] * gm * (1 + cmd_ratio * (f - 1))
    total = math.floor(base * (1 + gold_pct) * clear_mult)
    if entry["boss_count"] > 0:
        total += math.floor(gc["boss_gold_base"] * gm * entry["boss_count"] * (1 + gold_pct))
    if hazard:
        avg = entry["normal_gold"] / entry["normal_count"]
        if entry["boss_count"] > 0:
            hz_units = gc["hazard_boss_escorts"] * avg * gm * f
            hz_boss = gc["boss_gold_base"] * gm
        else:
            hz_units = gc["hazard_enemy_count"] * avg * gm * f
            hz_boss = 0
        total += math.floor(hz_units * (1 + gold_pct)) + math.floor(hz_boss * (1 + gold_pct))
    return total


def income_curve(wave_data: dict, gc: dict, params: dict) -> list:
    """Gold in the wallet after the summary of each wave 0..victory_wave."""
    curve = [gc["starting_gold"]]
    for w in range(1, gc["victory_wave"] + 1):
        curve.append(curve[-1] + wave_income(wave_data[w], gc, params["clear_mult"], params["cmd_ratio"],
                                             params["hazard"], params["gold_pct"]))
    return curve


def scenario_params(name: str, scenarios: dict, gc: dict) -> dict:
    """scenarios[name] holds clear (normal or fast), cmd_ratio, hazard and gold_pct."""
    sc = scenarios[name]
    clear_mult = gc["clear_mult_normal"] if sc["clear"] == "normal" else gc["clear_mult_fast"]
    return {"clear_mult": clear_mult, "cmd_ratio": sc["cmd_ratio"], "hazard": sc["hazard"], "gold_pct": sc["gold_pct"]}


def layout_cost(level: int, cum: dict, layout: dict, starters: dict):
    total = sum(count * cum[t][level] for t, count in layout.items())
    total -= sum(count * cum[t][1] for t, count in starters.items())
    return total


def uniform_level(gold, cum: dict, layout: dict, starters: dict, max_level: int) -> int:
    best = 0
    for level in range(1, max_level + 1):
        if layout_cost(level, cum, layout, starters) <= gold:
            best = level
    return best


def first_wave(cost, income: list):
    for w, gold in enumerate(income):
        if gold >= cost:
            return w
    return None


def parse_game_config(text: str, source: str = "game_config.gd") -> dict:
    values = {}
    for line in text.splitlines():
        m = GC_LINE.match(line.strip())
        if m is None:
            continue
        name, kind, raw = m.group(1), m.group(2), m.group(3)
        values[name] = int(raw) if kind == "int" else float(raw)
    missing = [k for k in GC_KEYS if k not in values]
    if missing:
        raise BalanceSimError("\n".join(f"{source}: missing {k}" for k in missing))
    return values


def check_towers(rows: list, max_level: int) -> list:
    """rows: dicts with tower_id, level, cost, coord. Returns the list of problems (empty when fine)."""
    errors = []
    seen = {}
    for r in rows:
        cost = r["cost"]
        if isinstance(cost, bool) or not isinstance(cost, (int, float)) or cost <= 0:
            errors.append(f"towers!{r['coord']}: build_cost must be a number above 0")
        level = r["level"]
        if isinstance(level, bool) or not isinstance(level, (int, float)) or int(level) != level:
            errors.append(f"towers!{r['level_coord']}: level must be a whole number")
            continue
        key = (r["tower_id"], int(level))
        if key in seen:
            errors.append(f"towers!{r['level_coord']}: duplicate level {int(level)} of {r['tower_id']}")
        seen[key] = True
    for tid in unique_in_order(r["tower_id"] for r in rows):
        have = {lvl for (t, lvl) in seen if t == tid}
        missing = [n for n in range(1, max_level + 1) if n not in have]
        extra = sorted(n for n in have if n < 1 or n > max_level)
        if missing or extra:
            errors.append(f"towers: {tid} has {len(have)} levels, expected 1..{max_level}"
                          + (f", missing {missing[:5]}" if missing else "") + (f", extra {extra[:5]}" if extra else ""))
    return errors


def unique_in_order(items) -> list:
    out = []
    for item in items:
        if item not in out:
            out.append(item)
    return out


def build_wave_data(wave_rows: list, enemy_gold: dict, boss_ids: set, gold_mult: dict, victory_wave: int) -> dict:
    """wave_rows: (wave, enemy_id, count) tuples. Returns {wave: entry} for 1..victory_wave."""
    data = {w: {"normal_gold": 0.0, "normal_count": 0, "boss_count": 0, "gm": gold_mult[w]}
            for w in range(1, victory_wave + 1)}
    for wave, enemy_id, count in wave_rows:
        if wave not in data:
            continue
        if enemy_id in boss_ids:
            data[wave]["boss_count"] += count
        else:
            data[wave]["normal_gold"] += count * enemy_gold[enemy_id]
            data[wave]["normal_count"] += count
    return data


def default_thresholds(order: list | None = None) -> dict:
    """Shape shared with the page. A type missing from the sheet falls back to the first type of the sheet."""
    def pick(t):
        return t if not order or t in order else order[0]
    afford = [{"type": pick(t), "count": c, "level": lvl, "wave": w} for t, c, lvl, w in AFFORD_TARGETS]
    t, c, lvl, w, ratio = M6_TARGET
    return {"afford": afford, "tier3_ratio": M5_MIN_RATIO,
            "late": {"type": pick(t), "count": c, "level": lvl, "wave": w, "min_ratio": ratio}}


def evaluate_targets(cum: dict, gc: dict, layout: dict, starters: dict, avg_income: list, strong_income: list,
                     thresholds: dict | None = None) -> list:
    """Returns the M1..M6 rows: (code, raw value, passed). M1..M4 value is the first wave an average run affords the
    target (None when never up to the victory wave), M5 value a ratio (None when infinite), M6 value a ratio.
    Income is cumulative gold after the summary of a wave, starting gold included (income[0])."""
    thr = thresholds or default_thresholds()
    n, t3, v = gc["tower_max_level"], gc["tower_tier3_level"], gc["victory_wave"]
    results = []
    for i, spec in enumerate(thr["afford"]):
        cost = spec["count"] * cum[spec["type"]][min(spec["level"], n)]
        results.append((f"M{i + 1}", first_wave(cost, avg_income), avg_income[min(spec["wave"], v)] >= cost))
    ratio = layout_cost(t3, cum, layout, starters) / strong_income[v] if strong_income[v] > 0 else math.inf
    results.append(("M5", None if math.isinf(ratio) else ratio, ratio >= thr["tier3_ratio"]))
    late = thr["late"]
    late_ratio = avg_income[min(late["wave"], v)] / (late["count"] * cum[late["type"]][min(late["level"], n)])
    results.append(("M6", late_ratio, late_ratio >= late["min_ratio"]))
    return results


def target_labels(thr: dict, gc: dict) -> dict:
    """Description of each measure, built from the thresholds. The page has the same text in targetLabels()."""
    labels = {}
    for i, a in enumerate(thr["afford"]):
        labels[f"M{i + 1}"] = f"{a['count']} x {a['type']} at level {a['level']} affordable by wave {a['wave']} (average)"
    labels["M5"] = (f"layout cost at level {gc['tower_tier3_level']} / gold of a strong run at wave {gc['victory_wave']}"
                    f" (target >= {thr['tier3_ratio']})")
    late = thr["late"]
    labels["M6"] = (f"average gold at wave {late['wave']} / cost of {late['count']} x {late['type']} to level "
                    f"{late['level']} (target >= {late['min_ratio']})")
    return labels


def fmt_target(code: str, value, victory_wave: int) -> str:
    if code in ("M5", "M6"):
        return "inf" if value is None else f"{value:.2f}"
    return f"w{value}" if value is not None else f"never (> w{victory_wave})"


# --------------------------------------------------------------------------- knobs and compute


def default_knobs(args, tables: dict, gc: dict) -> dict:
    """The knobs of one run from the command line. Keys and shapes are the contract with the page (payload schema 1)."""
    order, costs_cur = tables["tower_order"], tables["current"]
    price = {}
    for t in order:
        ov = args.override_map.get(t, {})
        base = ov.get("base", costs_cur[t][0])
        if isinstance(base, float) and base.is_integer():
            base = int(base)
        price[t] = {"mode": "curve", "base": base, "growth": ov.get("growth", args.growth),
                    "growth_from": [list(x) for x in ov.get("growth_from", args.growth_from_list)]}
    return {
        "round_to": args.round_to,
        "price": price,
        "scenarios": {
            "raw": {"clear": "normal", "cmd_ratio": 0.0, "hazard": False, "gold_pct": 0.0},
            "average": {"clear": "normal", "cmd_ratio": args.avg_cmd_ratio, "hazard": True, "gold_pct": 0.0},
            "strong": {"clear": "fast", "cmd_ratio": args.strong_cmd_ratio, "hazard": True,
                       "gold_pct": args.strong_gold_pct}},
        "layout": {t: args.layout_map.get(t, 0) for t in order},
        "starters": {t: args.starters_map.get(t, 0) for t in order},
        "target_gold": args.target_gold,
        "target_scenario": "average",
        "thresholds": default_thresholds(order),
        "stats": {t: {k: [] for k in STAT_KEYS} for t in order},  # per stat: [[from level, scale], ...]
        "dps": {"travel_time": DEFAULT_TRAVEL_TIME, "splash_targets": DEFAULT_SPLASH_TARGETS,
                "tower_share": DEFAULT_TOWER_SHARE},
    }


def sheet_knobs(knobs: dict) -> dict:
    """Same knobs with every type priced as in the sheet."""
    out = copy.deepcopy(knobs)
    for p in out["price"].values():
        p["mode"] = "sheet"
    return out


def scaled_stats(sheet_stats: dict, order: list, stats_knobs: dict) -> dict:
    """Stats of each level from [from, mult] segments, chained like the price curve: level 1 keeps the sheet value and
    level n = level n-1 x mult of the segment with the largest from <= n (1 below every segment). Only the sheet value
    of level 1 is used; a stat without segments keeps the sheet column as it is."""
    out = {}
    for t in order:
        out[t] = {}
        for stat in STAT_KEYS:
            segments = sorted(stats_knobs[t][stat])
            if len({start for start, _ in segments}) != len(segments):
                raise BalanceSimError(f"stats.{t}.{stat}: two segments start at the same level")
            sheet = sheet_stats[t][stat]
            values, chained = [sheet[0]], sheet[0]
            for level in range(2, len(sheet) + 1) if segments else ():
                chained *= next((factor for start, factor in reversed(segments) if start <= level), 1)
                if stat in INT_STATS:
                    values.append(max(round_half_up(chained, INT_STATS[stat]), INT_STATS[stat]))
                else:
                    values.append(math.floor(chained * 100 + 0.5) / 100)
            out[t][stat] = values if segments else list(sheet)
    return out


def dps_curves(static: dict, stats: dict, layout: dict, uniform: dict, dps_knobs: dict) -> dict:
    """demand[w-1]: hp the towers must kill per second of wave w. supply[s][w-1]: tower dps at the uniform level
    that the wallet after wave w-1 buys."""
    v = static["gc"]["victory_wave"]
    sheet = static["sheet_stats"]
    demand = [e["hp"] * dps_knobs["tower_share"] / (e["spawn_window"] + dps_knobs["travel_time"])
              for e in static["wave_hp"]]
    supply = {}
    for s, levels in uniform.items():
        curve = []
        for w in range(1, v + 1):
            level = levels[w - 1]
            total = 0
            for t in static["order"]:
                if t not in layout or level < 1:
                    continue
                i = level - 1
                mult = dps_knobs["splash_targets"] if sheet[t]["splash_radius"][i] > 0 else 1
                total += layout[t] * stats[t]["damage"][i] * stats[t]["fire_rate"][i] * mult
            curve.append(total)
        supply[s] = curve
    return {"demand": demand, "supply": supply}


def compute(static: dict, knobs: dict) -> dict:
    """The whole simulation for one set of knobs. static: gc, order, sheet_costs, sheet_stats, wave_data, wave_hp.
    The JS compute() of report_template.html does the same steps in the same order."""
    gc, order = static["gc"], static["order"]
    n, v = gc["tower_max_level"], gc["victory_wave"]
    costs = {}
    for t in order:
        p = knobs["price"][t]
        if p["mode"] == "sheet":
            costs[t] = list(static["sheet_costs"][t])
        else:
            costs[t] = proposed_costs(p["base"], p["growth"], knobs["round_to"], n, p["growth_from"])
    cum = {t: cumulative(costs[t]) for t in order}
    income = {s: income_curve(static["wave_data"], gc, scenario_params(s, knobs["scenarios"], gc))
              for s in SCENARIOS}
    layout = {t: knobs["layout"][t] for t in order if knobs["layout"].get(t, 0) > 0}
    starters = {t: knobs["starters"][t] for t in order if knobs["starters"].get(t, 0) > 0}
    uniform = {s: [uniform_level(income[s][w], cum, layout, starters, n) for w in range(v + 1)] for s in SCENARIOS}
    targets = evaluate_targets(cum, gc, layout, starters, income["average"], income["strong"], knobs["thresholds"])
    gap = None
    if knobs["target_gold"]:
        gold = income[knobs["target_scenario"]][v]
        gap = {"gold": gold, "ratio": gold / knobs["target_gold"]}
    stats = dps = None
    if static["sheet_stats"] is not None:
        stats = scaled_stats(static["sheet_stats"], order, knobs["stats"])
        if static["wave_hp"] is not None:
            dps = dps_curves(static, stats, layout, uniform, knobs["dps"])
    return {"costs": costs, "cum": cum, "income": income, "uniform": uniform, "targets": targets,
            "target_gap": gap, "stats": stats, "dps": dps}


def reference_knobs(defaults: dict, order: list, max_level: int, with_stats: bool = True) -> list:
    """The fixed knob sets the page replays to prove that its JS matches this file: (name, knobs) pairs."""
    cases = [("defaults", copy.deepcopy(defaults)), ("sheet", sheet_knobs(defaults))]
    seg = copy.deepcopy(defaults)
    seg["round_to"] = 10
    for t in order:
        seg["price"][t].update({"mode": "curve", "growth": 1.09, "growth_from": []})
    if "arrow" in order:
        seg["price"]["arrow"]["growth_from"] = [[min(20, max_level - 1), 1.12], [min(30, max_level), 1.05]]
    if "cannon" in order:
        seg["price"]["cannon"]["base"] += 7
    cases.append(("segments", seg))
    sc = copy.deepcopy(defaults)
    sc["scenarios"]["average"].update({"cmd_ratio": 0.7, "hazard": False})
    sc["scenarios"]["strong"].update({"gold_pct": 0.3, "clear": "normal"})
    sc["layout"] = {t: {"arrow": 2, "cannon": 2, "barricade": 1, "heal_station": 1}.get(t, 0) for t in order}
    sc["starters"] = {t: {"arrow": 1}.get(t, 0) for t in order}
    pick = [order[i % len(order)] for i in range(5)]  # the sheet may hold other types than the default four
    sc["thresholds"] = {"afford": [{"type": pick[0], "count": 3, "level": 10, "wave": 12},
                                   {"type": pick[1], "count": 2, "level": min(20, max_level), "wave": 25},
                                   {"type": pick[2], "count": 1, "level": max_level, "wave": 30},
                                   {"type": pick[3], "count": 4, "level": 5, "wave": 3}],
                        "tier3_ratio": 1.2,
                        "late": {"type": pick[4], "count": 2, "level": min(30, max_level), "wave": 20, "min_ratio": 0.5}}
    sc["target_gold"] = 10000
    cases.append(("scenarios", sc))
    if with_stats:
        st = copy.deepcopy(defaults)
        for t, stat, segments in (("arrow", "damage", [[13, 1.2], [25, 1.5]]), ("cannon", "fire_rate", [[1, 0.9]]),
                                  ("barricade", "max_hp", [[min(25, max_level), 1.5]]),
                                  ("arrow", "attack_range", [[10, 1.1], [20, 1], [30, 0.9]])):
            if t in order:
                st["stats"][t][stat] = [list(x) for x in segments]
        st["dps"] = {"travel_time": 20, "splash_targets": 3, "tower_share": 0.7}
        cases.append(("stats", st))
    return cases


# --------------------------------------------------------------------------- reading the files


def read_sheet(wb, name: str, columns: list) -> list:
    """Rows of a sheet as dicts column -> (value, coordinate), plus 'row'. Columns are found by header name."""
    if name not in wb.sheetnames:
        raise BalanceSimError(f"{name}: sheet not found")
    ws = wb[name]
    header = {}
    for cell in ws[1]:
        if cell.value is not None:
            header[str(cell.value).strip()] = cell.column - 1
    missing = [c for c in columns if c not in header]
    if missing:
        raise BalanceSimError("\n".join(f"{name}: missing column {c}" for c in missing))
    rows = []
    for row in ws.iter_rows(min_row=2):
        if all(c.value is None for c in row):
            continue
        item = {"row": row[0].row}
        for c in columns:
            cell = row[header[c]]
            item[c] = (cell.value, cell.coordinate)
        rows.append(item)
    return rows


def is_number(x) -> bool:
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def read_tower_stats(wb, tower_rows: list, max_level: int):
    """Optional stat columns of the towers sheet: ({type: {stat: [per level]}}, {stat: column letter})."""
    rows = read_sheet(wb, "towers", SHEET_STAT_KEYS)
    stats = {r["tower_id"]: {k: [0] * max_level for k in SHEET_STAT_KEYS} for r in tower_rows}
    for row, r in zip(rows, tower_rows):
        for k in SHEET_STAT_KEYS:
            value, coord = row[k]
            if not is_number(value) or value < 0:
                raise BalanceSimError(f"towers!{coord}: {k} must be a number of 0 or more")
            stats[r["tower_id"]][k][int(r["level"]) - 1] = value
    letters = {k: re.match(r"[A-Z]+", rows[0][k][1]).group(0) for k in SHEET_STAT_KEYS} if rows else {}
    return stats, letters


def read_wave_hp(wb, victory_wave: int) -> list:
    """Optional: total enemy hp of each wave 1..victory_wave and its longest spawn window."""
    base_hp = {}
    for r in read_sheet(wb, "enemies", ["enemy_id", "base_hp"]):
        if not is_number(r["base_hp"][0]) or r["base_hp"][0] < 0:
            raise BalanceSimError(f"enemies!{r['base_hp'][1]}: base_hp must be a number of 0 or more")
        base_hp[r["enemy_id"][0]] = r["base_hp"][0]
    hp = {w: 0.0 for w in range(1, victory_wave + 1)}
    window = {w: 0 for w in range(1, victory_wave + 1)}
    for r in read_sheet(wb, "waves", ["wave", "enemy_id", "count", "spawn_duration", "hp_mult"]):
        w = r["wave"][0]
        if w not in hp:
            continue
        if r["enemy_id"][0] not in base_hp:
            raise BalanceSimError(f"waves!{r['enemy_id'][1]}: no base_hp for {r['enemy_id'][0]}")
        for col in ("spawn_duration", "hp_mult"):
            if not is_number(r[col][0]) or r[col][0] < 0:
                raise BalanceSimError(f"waves!{r[col][1]}: {col} must be a number of 0 or more")
        hp[w] += r["count"][0] * base_hp[r["enemy_id"][0]] * r["hp_mult"][0]
        window[w] = max(window[w], r["spawn_duration"][0])
    return [{"wave": w, "hp": hp[w], "spawn_window": window[w]} for w in range(1, victory_wave + 1)]


def load_tables(xlsx: Path, gc: dict, boss_ids: set) -> dict:
    """Reads and checks the four sheets. Raises BalanceSimError with every problem found."""
    if not xlsx.is_file():
        raise BalanceSimError(f"{xlsx}: file not found")
    try:
        wb = openpyxl.load_workbook(xlsx, data_only=True, read_only=False)
    except Exception as exc:  # unreadable or locked file
        raise BalanceSimError(f"{xlsx}: cannot open ({exc})") from exc
    errors = []
    v, n = gc["victory_wave"], gc["tower_max_level"]
    result = {}

    tower_rows = []
    cost_col_letter = "C"
    try:
        rows = read_sheet(wb, "towers", ["tower_id", "level", "build_cost"])
        for r in rows:
            tower_rows.append({"tower_id": r["tower_id"][0], "level": r["level"][0], "level_coord": r["level"][1],
                               "cost": r["build_cost"][0], "coord": r["build_cost"][1], "row": r["row"]})
        if rows:
            cost_col_letter = re.match(r"[A-Z]+", rows[0]["build_cost"][1]).group(0)
        errors += check_towers(tower_rows, n)
    except BalanceSimError as exc:
        errors.append(str(exc))

    enemy_gold = {}
    try:
        for r in read_sheet(wb, "enemies", ["enemy_id", "gold_reward"]):
            gold = r["gold_reward"][0]
            if isinstance(gold, bool) or not isinstance(gold, (int, float)) or gold < 0:
                errors.append(f"enemies!{r['gold_reward'][1]}: gold_reward must be a number of 0 or more")
                continue
            enemy_gold[r["enemy_id"][0]] = gold
    except BalanceSimError as exc:
        errors.append(str(exc))

    gold_mult = {}
    try:
        for r in read_sheet(wb, "wave_rewards", ["wave", "gold_mult"]):
            gm = r["gold_mult"][0]
            if isinstance(gm, bool) or not isinstance(gm, (int, float)) or gm < 0:
                errors.append(f"wave_rewards!{r['gold_mult'][1]}: gold_mult must be a number of 0 or more")
                continue
            gold_mult[r["wave"][0]] = gm
        for w in range(1, v + 1):
            if w not in gold_mult:
                errors.append(f"wave_rewards: no row for wave {w}")
    except BalanceSimError as exc:
        errors.append(str(exc))

    wave_rows = []
    try:
        for r in read_sheet(wb, "waves", ["wave", "enemy_id", "count"]):
            count = r["count"][0]
            if isinstance(count, bool) or not isinstance(count, (int, float)) or count < 0 or int(count) != count:
                errors.append(f"waves!{r['count'][1]}: count must be a whole number of 0 or more")
                continue
            if r["enemy_id"][0] not in enemy_gold and r["enemy_id"][0] not in boss_ids:
                errors.append(f"waves!{r['enemy_id'][1]}: unknown enemy_id {r['enemy_id'][0]}")
                continue
            wave_rows.append((r["wave"][0], r["enemy_id"][0], int(count)))
        for w in range(1, v + 1):
            mine = [x for x in wave_rows if x[0] == w]
            if not mine:
                errors.append(f"waves: no row for wave {w}")
            elif sum(c for _, e, c in mine if e not in boss_ids) <= 0:
                errors.append(f"waves: wave {w} has no regular enemy")
    except BalanceSimError as exc:
        errors.append(str(exc))

    if errors:
        raise BalanceSimError("\n".join(errors))

    order = unique_in_order(r["tower_id"] for r in tower_rows)
    result["tower_rows"] = tower_rows
    result["cost_column"] = cost_col_letter
    result["tower_order"] = order
    result["current"] = {t: [0] * n for t in order}
    for r in tower_rows:
        result["current"][r["tower_id"]][int(r["level"]) - 1] = r["cost"]
    result["wave_data"] = build_wave_data(wave_rows, enemy_gold, boss_ids, gold_mult, v)
    result["columns"] = {"build_cost": cost_col_letter}
    result["sheet_stats"] = result["wave_hp"] = None
    try:
        result["sheet_stats"], letters = read_tower_stats(wb, tower_rows, n)
        result["columns"].update(letters)
    except BalanceSimError as exc:
        print(f"warning: tower stats are off ({exc})", file=sys.stderr)
    try:
        result["wave_hp"] = read_wave_hp(wb, v)
    except BalanceSimError as exc:
        print(f"warning: the dps chart is off ({exc})", file=sys.stderr)
    return result


# --------------------------------------------------------------------------- arguments


def parse_pairs(spec: str, parser, flag: str) -> dict:
    out = {}
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        name, sep, raw = part.partition("=")
        if not sep or not name.strip():
            parser.error(f"{flag}: expected TYPE=COUNT pairs, got '{part}'")
        try:
            count = int(raw)
        except ValueError:
            parser.error(f"{flag}: count of {name} is not a whole number")
        if count < 0:
            parser.error(f"{flag}: count of {name} must be 0 or more")
        out[name.strip()] = count
    return out


def parse_growth_from(spec: str, parser, flag: str) -> tuple:
    """One LEVEL:FACTOR text to (level, factor). The upper bound of LEVEL is checked once GameConfig is read."""
    level_text, sep, factor_text = spec.strip().partition(":")
    if not sep:
        parser.error(f"{flag}: expected LEVEL:FACTOR, got '{spec}'")
    try:
        level = int(level_text)
    except ValueError:
        parser.error(f"{flag}: level of '{spec}' is not a whole number")
    try:
        factor = float(factor_text)
    except ValueError:
        parser.error(f"{flag}: factor of '{spec}' is not a number")
    if not math.isfinite(factor) or factor <= 0:
        parser.error(f"{flag}: factor of '{spec}' must be above 0")
    if level < 2 or level > MAX_GROWTH_FROM_LEVEL:
        parser.error(f"{flag}: level of '{spec}' must be a whole number from 2 to {MAX_GROWTH_FROM_LEVEL}")
    return level, factor


def check_growth_from_list(segments: list, parser, flag: str, max_level=None) -> list:
    """Rejects a duplicate level (and a level above max_level when given). Returns the list sorted by level."""
    seen = set()
    for level, _ in segments:
        if level in seen:
            parser.error(f"{flag}: level {level} appears more than once")
        seen.add(level)
        if max_level is not None and level > max_level:
            parser.error(f"{flag}: level {level} is above the max tower level {max_level}")
    return sorted(segments)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Compare cumulative tower prices with the expected income.")
    p.add_argument("--xlsx", type=Path, default=XLSX, help="balance table")
    p.add_argument("--game-config", type=Path, default=GAME_CONFIG, help="source of the GameConfig constants")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT, help="HTML report path")
    p.add_argument("--growth", type=float, default=DEFAULT_GROWTH, help="price growth per level")
    p.add_argument("--growth-from", dest="growth_from", action="append", default=None, metavar="LEVEL:FACTOR",
                   help="growth per level from LEVEL on, repeatable (replaces --growth from that level)")
    p.add_argument("--round-to", type=int, default=DEFAULT_ROUND_TO, help="round prices to a multiple of this")
    p.add_argument("--set", dest="overrides", action="append", default=None, metavar="TYPE.KEY=VALUE",
                   help="per type override, KEY is base, growth or growth_from (LEVEL:FACTOR, repeatable)")
    p.add_argument("--layout", default=DEFAULT_LAYOUT, help="buildings of a full defence, TYPE=COUNT list")
    p.add_argument("--starters", default=DEFAULT_STARTERS, help="free level 1 towers, TYPE=COUNT list")
    p.add_argument("--avg-cmd-ratio", type=float, default=DEFAULT_AVG_CMD_RATIO)
    p.add_argument("--strong-cmd-ratio", type=float, default=DEFAULT_STRONG_CMD_RATIO)
    p.add_argument("--strong-gold-pct", type=float, default=DEFAULT_STRONG_GOLD_PCT)
    p.add_argument("--target-gold", type=int, default=None, help="gold wanted at the victory wave (reference only)")
    p.add_argument("--boss-ids", default=DEFAULT_BOSS_IDS, help="comma list of enemy ids treated as bosses")
    p.add_argument("--tsv", type=Path, default=None, help="also write the proposed build_cost column to this file")
    p.add_argument("--check-js", action="store_true",
                   help="open the page in headless Edge or Chrome and check that its JS matches this script")
    p.add_argument("--self-test", action="store_true", help="run the built-in checks and exit")
    return p


def validate_args(args, parser) -> None:
    if args.growth <= 0:
        parser.error("--growth must be above 0")
    if args.round_to < 1:
        parser.error("--round-to must be 1 or more")
    for flag, value in (("--avg-cmd-ratio", args.avg_cmd_ratio), ("--strong-cmd-ratio", args.strong_cmd_ratio)):
        if not 0 <= value <= 1:
            parser.error(f"{flag} must be between 0 and 1")
    if args.strong_gold_pct < 0:
        parser.error("--strong-gold-pct must be 0 or more")
    if args.target_gold is not None and args.target_gold <= 0:
        parser.error("--target-gold must be above 0")
    args.layout_map = parse_pairs(args.layout, parser, "--layout")
    args.starters_map = parse_pairs(args.starters, parser, "--starters")
    args.boss_set = {b.strip() for b in args.boss_ids.split(",") if b.strip()}
    args.growth_from_list = check_growth_from_list(
        [parse_growth_from(x, parser, "--growth-from") for x in args.growth_from or DEFAULT_GROWTH_FROM], parser,
        "--growth-from")
    args.override_map = parse_overrides(DEFAULT_SET, parser)
    for tid, ov in parse_overrides(args.overrides or [], parser).items():
        args.override_map.setdefault(tid, {}).update(ov)


def parse_overrides(items: list, parser) -> dict:
    result = {}
    for item in items:
        left, sep, raw = item.partition("=")
        tid, dot, key = left.partition(".")
        if not sep or not dot or key not in ("base", "growth", "growth_from"):
            parser.error(f"--set: expected TYPE.KEY=VALUE with KEY base, growth or growth_from, got '{item}'")
        if key == "growth_from":
            segments = result.setdefault(tid, {}).setdefault("growth_from", [])
            segments.append(parse_growth_from(raw, parser, f"--set {left}"))
            continue
        try:
            value = float(raw)
        except ValueError:
            parser.error(f"--set: value of {left} is not a number")
        if value <= 0:
            parser.error(f"--set: {left} must be above 0")
        result.setdefault(tid, {})[key] = value
    for tid, ov in result.items():
        if "growth_from" in ov:
            ov["growth_from"] = check_growth_from_list(ov["growth_from"], parser, f"--set {tid}.growth_from")
    return result


# --------------------------------------------------------------------------- report


def fmt_num(x) -> str:
    if isinstance(x, float) and x.is_integer():
        x = int(x)
    return f"{x:,}".replace(",", " ") if isinstance(x, int) else f"{x:g}"


def tsv_ranges(tower_rows: list, col: str) -> str:
    runs = []
    for r in tower_rows:
        if runs and r["row"] == runs[-1][1] + 1:
            runs[-1][1] = r["row"]
        else:
            runs.append([r["row"], r["row"]])
    return ", ".join(f"towers!{col}{a}:{col}{b}" for a, b in runs)


def build_static(gc: dict, tables: dict) -> dict:
    """The numbers that do not depend on the knobs."""
    return {"gc": gc, "order": tables["tower_order"], "sheet_costs": tables["current"],
            "sheet_stats": tables["sheet_stats"], "wave_data": tables["wave_data"], "wave_hp": tables["wave_hp"]}


def static_json(static: dict, tables: dict) -> dict:
    """The static part of the payload, as plain JSON types (wave_data becomes a list, tower_rows are added)."""
    return {"gc": static["gc"], "order": static["order"], "sheet_costs": static["sheet_costs"],
            "sheet_stats": static["sheet_stats"], "columns": tables["columns"],
            "tower_rows": [[r["tower_id"], int(r["level"]), r["row"]] for r in tables["tower_rows"]],
            "wave_data": [dict(entry, wave=w) for w, entry in sorted(static["wave_data"].items())],
            "wave_hp": static["wave_hp"]}


def py_static(static: dict) -> dict:
    """The static_json() dict with wave_data keyed by wave, as compute() reads it."""
    return dict(static, wave_data={e["wave"]: e for e in static["wave_data"]})


def build_payload(static: dict, defaults: dict, meta: dict) -> dict:
    """static: the dict of static_json(). meta: generated, xlsx, game_config. Schema 1 of report_template.html."""
    fingerprint = hashlib.sha256(json.dumps(static, sort_keys=True).encode("utf-8")).hexdigest()[:12]
    n = static["gc"]["tower_max_level"]
    reference = [{"name": name, "knobs": knobs, "result": compute(py_static(static), knobs)}
                 for name, knobs in reference_knobs(defaults, static["order"], n, static["sheet_stats"] is not None)]
    payload = {"schema": 1, "fingerprint": fingerprint, "defaults": defaults, "reference": reference}
    payload.update(static)
    payload.update(meta)
    return payload


def render_html(payload: dict, noscript_html: str) -> str:
    """Fills report_template.html. Each placeholder must be in the template exactly once."""
    try:
        template = TEMPLATE.read_text(encoding="utf-8")
    except OSError as exc:
        raise BalanceSimError(f"{TEMPLATE}: cannot read ({exc})") from exc
    for mark in (PAYLOAD_MARK, NOSCRIPT_MARK):
        if template.count(mark) != 1:
            raise BalanceSimError(f"{TEMPLATE}: placeholder {mark} must appear exactly once")
    data = json.dumps(payload, ensure_ascii=False, sort_keys=True).replace("</", "<\\/")
    before, rest = template.split(PAYLOAD_MARK)
    return (before + data + rest).replace(NOSCRIPT_MARK, noscript_html)


def build_noscript(gc: dict, thresholds: dict, result: dict, sheet_result: dict, tsv: str, tsv_range: str) -> str:
    """Targets and the build_cost block for a browser with JS off, from the command line knobs."""
    v = gc["victory_wave"]

    def cell(row):
        return f"<td>{html.escape(fmt_target(row[0], row[1], v))}</td><td>{'PASS' if row[2] else 'FAIL'}</td>"

    labels = target_labels(thresholds, gc)
    rows = "".join(f"<tr><td>{a[0]}</td><td>{html.escape(labels[a[0]])}</td>{cell(a)}{cell(b)}</tr>"
                   for a, b in zip(sheet_result["targets"], result["targets"]))
    return (f"<noscript><p>Turn on JavaScript to use the knobs and charts. Values for the command line knobs:</p>"
            f"<table><tr><th>Code</th><th>Measure</th><th>Sheet</th><th></th><th>Proposed</th><th></th></tr>{rows}</table>"
            f"<p>Paste into {html.escape(tsv_range)}:</p><pre>{html.escape(tsv)}</pre></noscript>")


def find_browser():
    """Edge or Chrome of this machine, or None."""
    for env, rel in (("ProgramFiles(x86)", r"Microsoft\Edge\Application\msedge.exe"),
                     ("ProgramFiles", r"Microsoft\Edge\Application\msedge.exe"),
                     ("ProgramFiles", r"Google\Chrome\Application\chrome.exe"),
                     ("LocalAppData", r"Google\Chrome\Application\chrome.exe")):
        if os.environ.get(env) and (Path(os.environ[env]) / rel).is_file():
            return str(Path(os.environ[env]) / rel)
    return shutil.which("msedge") or shutil.which("chrome")


def check_js(page: Path) -> int:
    """Loads the page in a headless browser and reads the engine check result the page puts on <body>."""
    browser = find_browser()
    if browser is None:
        print("engine check: skipped (no Edge or Chrome found)")
        return 0
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as profile:
        cmd = [browser, "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--dump-dom",
               page.resolve().as_uri()]
        try:
            done = subprocess.run(cmd, capture_output=True, timeout=60)
        except (OSError, subprocess.TimeoutExpired) as exc:
            print(f"engine check: failed (browser did not finish: {exc})")
            return 1
    dom = done.stdout.decode("utf-8", errors="replace")
    state = re.search(r'data-engine-check="(\w+)"', dom)
    detail = re.search(r'data-engine-detail="([^"]*)"', dom)
    if state is None:
        print("engine check: failed (the page did not report a result)")
        return 1
    if state.group(1) == "pass":
        print("engine check: pass")
        return 0
    print("engine check: failed " + (html.unescape(detail.group(1)) if detail else ""))
    return 1


# --------------------------------------------------------------------------- run


def run(args, parser) -> int:
    try:
        gc = parse_game_config(args.game_config.read_text(encoding="utf-8"), args.game_config.name)
    except OSError as exc:
        raise BalanceSimError(f"{args.game_config}: cannot read ({exc})") from exc
    tables = load_tables(args.xlsx, gc, args.boss_set)
    order, n = tables["tower_order"], gc["tower_max_level"]
    for flag, pairs in (("--layout", args.layout_map), ("--starters", args.starters_map)):
        for t in pairs:
            if t not in order:
                parser.error(f"{flag}: unknown tower type {t}")
    for t, count in args.starters_map.items():
        if count > args.layout_map.get(t, 0):
            parser.error(f"--starters: {t} has more starters than the layout holds")
    for t in args.override_map:
        if t not in order:
            parser.error(f"--set: unknown tower type {t}")
    check_growth_from_list(args.growth_from_list, parser, "--growth-from", n)
    for t, ov in args.override_map.items():
        check_growth_from_list(ov.get("growth_from", []), parser, f"--set {t}.growth_from", n)

    static = build_static(gc, tables)
    knobs = default_knobs(args, tables, gc)
    result = compute(static, knobs)
    sheet_result = compute(static, sheet_knobs(knobs))

    lines = []
    for r in tables["tower_rows"]:
        lines.append(str(result["costs"][r["tower_id"]][int(r["level"]) - 1]))
    tsv = "\n".join(lines) + "\n"
    tsv_range = tsv_ranges(tables["tower_rows"], tables["cost_column"])

    v = gc["victory_wave"]
    print("Income at waves 10 / 20 / 30 (cumulative gold):")
    for s in SCENARIOS:
        marks = [min(w, v) for w in (10, 20, 30)]
        print(f"  {s:8s} " + "  ".join(f"w{w}={fmt_num(result['income'][s][w])}" for w in marks))
    print("Targets (sheet vs proposed):")
    labels = target_labels(knobs["thresholds"], gc)
    for a, b in zip(sheet_result["targets"], result["targets"]):
        print(f"  {a[0]}  {fmt_target(*a[:2], v):>14s} {'PASS' if a[2] else 'FAIL'}   "
              f"{fmt_target(*b[:2], v):>14s} {'PASS' if b[2] else 'FAIL'}   {labels[a[0]]}")
    gap = result["target_gap"]
    if gap is not None:
        print(f"Target gold {fmt_num(knobs['target_gold'])} at wave {v}: {knobs['target_scenario']} run has "
              f"{fmt_num(gap['gold'])} ({gap['ratio'] * 100:.1f} %)")

    meta = {"generated": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), "xlsx": str(args.xlsx.resolve()),
            "game_config": str(args.game_config.resolve())}
    payload = build_payload(static_json(static, tables), knobs, meta)
    noscript = build_noscript(gc, knobs["thresholds"], result, sheet_result, tsv, tsv_range)
    page = render_html(payload, noscript)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(page, encoding="utf-8")
    if args.tsv is not None:
        args.tsv.parent.mkdir(parents=True, exist_ok=True)
        args.tsv.write_text(tsv, encoding="utf-8")
        print(f"TSV: {args.tsv.resolve()}")
    print(f"Paste the proposed build_cost column into {tsv_range}")
    print(f"Report: {args.out.resolve()}")
    if args.check_js:
        return check_js(args.out)
    return 0


# --------------------------------------------------------------------------- self test


def self_test() -> int:
    results = []

    def case(name, fn):
        try:
            ok = bool(fn())
        except Exception as exc:  # a crash is a failed case
            print(f"FAIL {name} ({exc})")
            results.append(False)
            return
        print(("PASS " if ok else "FAIL ") + name)
        results.append(ok)

    gc = {"victory_wave": 2, "starting_gold": 10, "frontline_gold_mult": 1.25, "boss_gold_base": 100,
          "clear_mult_normal": 1.0, "clear_mult_fast": 1.25, "hazard_enemy_count": 5, "hazard_boss_escorts": 4,
          "tower_max_level": 36, "tower_tier2_level": 13, "tower_tier3_level": 25}
    enemy_gold = {"grunt": 4, "brute": 20, "bulwark": 100}
    wave_rows = [(1, "grunt", 10), (2, "grunt", 6), (2, "brute", 1), (2, "bulwark", 1)]
    wd = build_wave_data(wave_rows, enemy_gold, {"bulwark"}, {1: 1.0, 2: 1.5}, 2)

    def toy(order, with_stats=True):
        """Static numbers (JSON shape of the payload) and default knobs for a tiny two wave game."""
        levels = range(36)
        sheet_stats = {t: {"max_hp": [100 + i for i in levels], "damage": [10 + i for i in levels],
                           "attack_range": [14.0 + i for i in levels], "fire_rate": [1.0 + 0.1 * i for i in levels],
                           "splash_radius": [0] * 36} for t in order} if with_stats else None
        sj = {"gc": gc, "order": order, "sheet_costs": {t: [10 + 5 * i for i in levels] for t in order},
              "sheet_stats": sheet_stats, "columns": {"build_cost": "C"},
              "tower_rows": [[t, i + 1, 2 + i] for t in order for i in levels],
              "wave_data": [dict(e, wave=w) for w, e in sorted(wd.items())],
              "wave_hp": [{"wave": 1, "hp": 300.0, "spawn_window": 15}, {"wave": 2, "hp": 600.0, "spawn_window": 5}]
              if with_stats else None}
        tables = {"tower_order": order, "current": sj["sheet_costs"]}
        args = build_parser().parse_args([])
        validate_args(args, build_parser())
        kn = default_knobs(args, tables, gc)
        kn["layout"] = {t: (2 if i == 0 else 0) for i, t in enumerate(order)}
        kn["starters"] = {t: 0 for t in order}
        return sj, kn

    sj0, kn0 = toy(["arrow", "wall"])
    st0 = py_static(sj0)

    def inc(s, knobs=kn0):
        return compute(st0, knobs)["income"][s]

    case("round_half_up", lambda: (round_half_up(52.5, 5), round_half_up(47.4, 5), round_half_up(47.5, 5)) == (55, 45, 50))
    pc = proposed_costs(50, 1.085, 5, 36)
    case("proposed_costs", lambda: pc[:5] == [50, 55, 60, 65, 70] and pc[11] == 125 and pc[12] == 135
         and pc[13] == 145 and pc[24] == 355 and pc[35] == 870 and len(pc) == 36)
    case("level 1 is not rounded", lambda: proposed_costs(52, 1.085, 5, 36)[0] == 52)
    case("cumulative", lambda: cumulative([50, 55, 60]) == [0, 50, 105, 165])
    case("income raw", lambda: inc("raw") == [10, 50, 266])
    case("income average", lambda: inc("average") == [10, 79, 498])
    case("income strong", lambda: inc("strong") == [10, 104, 616])
    cum = {"t": cumulative([10, 20, 30])}
    lay = {"t": 1}
    case("uniform_level", lambda: [uniform_level(g, cum, lay, {}, 3) for g in (29, 30, 1000, 5)] == [1, 2, 3, 0])
    case("first_wave", lambda: first_wave(60, [10, 50, 266]) == 2 and first_wave(9999, [10, 50, 266]) is None)

    sample = ("@export_group(\"x\")\n@export var a: int = 3\n@export var b: float = 1.25  # note\n"
              "@export var c: StringName = &\"W2\"\n")

    def parse_case():
        keys_text = "".join(f"@export var {k}: int = 1\n" for k in GC_KEYS)
        got = parse_game_config(sample + keys_text)
        if got.get("a") != 3 or not isinstance(got["a"], int):
            return False
        if got.get("b") != 1.25 or not isinstance(got["b"], float) or "c" in got:
            return False
        try:
            parse_game_config(sample)
        except BalanceSimError as exc:
            return "victory_wave" in str(exc)
        return False

    case("parse game config", parse_case)

    def towers_case():
        rows = [{"tower_id": "arrow", "level": L, "level_coord": f"B{L + 1}", "cost": 10, "coord": f"C{L + 1}"}
                for L in range(1, 36)]
        errors = check_towers(rows, 36)
        return bool(errors) and "towers" in "\n".join(errors)

    case("towers check", towers_case)

    class _Rejected(Exception):
        pass

    class _Parser:
        def error(self, message):
            raise _Rejected(message)

    def rejects(fn):
        try:
            fn()
        except _Rejected:
            return True
        return False

    pr = _Parser()
    plain = [50] + [max(round_half_up(50 * 1.085 ** (n - 1), 5), 5) for n in range(2, 37)]
    case("no growth_from equals base x growth^(n-1), no spike at levels 13 and 25",
         lambda: pc == plain and proposed_costs(50, 1.085, 5, 36, []) == plain)
    one = proposed_costs(50, 1.085, 5, 36, [(25, 1.10)])
    p24 = 50 * 1.085 ** 23
    case("growth_from 25 changes only levels 25 and up",
         lambda: one[:24] == plain[:24] and all(one[i] != plain[i] for i in range(24, 36)))
    case("growth_from level 25 is p(24) x factor, level 26 chains on it",
         lambda: one[24] == round_half_up(p24 * 1.10, 5) and one[25] == round_half_up(p24 * 1.10 * 1.10, 5))
    two = proposed_costs(50, 1.085, 5, 36, [(30, 1.05), (20, 1.12)])
    p19 = 50 * 1.085 ** 18
    p29 = p19 * 1.12 ** 10
    case("growth_from two segments chain without a gap",
         lambda: two[:19] == plain[:19] and two[19] == round_half_up(p19 * 1.12, 5)
         and two[28] == round_half_up(p29, 5) and two[29] == round_half_up(p29 * 1.05, 5)
         and two[35] == round_half_up(p29 * 1.05 ** 7, 5))

    def override_case():
        args = build_parser().parse_args(["--growth-from", "25:1.10", "--set", "arrow.growth_from=20:1.05",
                                          "--set", "arrow.growth_from=30:1.02"])
        validate_args(args, pr)
        return args.growth_from_list == [(25, 1.10)] and args.override_map["arrow"]["growth_from"] == [
            (20, 1.05), (30, 1.02)]

    case("growth_from per type list overrides the global list", override_case)

    def bad_arg(*argv):
        return rejects(lambda: validate_args(build_parser().parse_args(list(argv)), pr))

    case("growth_from invalid input is rejected",
         lambda: bad_arg("--growth-from", "1:1.1") and bad_arg("--growth-from", "1000:1.1")
         and bad_arg("--growth-from", "25:0") and bad_arg("--growth-from", "25:-1.2")
         and bad_arg("--growth-from", "25") and bad_arg("--growth-from", "x:1.1")
         and bad_arg("--growth-from", "25.5:1.1") and bad_arg("--growth-from", "25:abc")
         and bad_arg("--growth-from", "25:1.1", "--growth-from", "25:1.2")
         and bad_arg("--set", "arrow.growth_from=25:1.1", "--set", "arrow.growth_from=25:1.2")
         and bad_arg("--set", "arrow.growth_from=1:1.1"))
    case("growth_from above the max level is rejected",
         lambda: rejects(lambda: check_growth_from_list([(37, 1.1)], pr, "--growth-from", 36))
         and not rejects(lambda: check_growth_from_list([(36, 1.1)], pr, "--growth-from", 36)))
    case("tier_mult is no longer a knob", lambda: bad_arg("--set", "arrow.tier_mult=1.4"))

    case("chained growth matches pow on a sweep", lambda: all(
        proposed_costs(b, g, 5, 36) == [b] + [max(round_half_up(b * g ** (n - 1), 5), 5) for n in range(2, 37)]
        for b in (30, 40, 50, 60, 90, 120, 200) for g in [round(1.05 + 0.0025 * k, 4) for k in range(41)]))

    def with_knobs(mutate):
        kn = copy.deepcopy(kn0)
        mutate(kn)
        return compute(st0, kn)
    case("compute defaults equals the old pipeline", lambda: (inc("raw"), inc("average"), inc("strong")) == (
        [10, 50, 266], [10, 79, 498], [10, 104, 616])
        and compute(st0, kn0)["uniform"]["average"][2] == uniform_level(
            498, compute(st0, kn0)["cum"], {"arrow": 2}, {}, 36))

    def fast_case():
        kn = copy.deepcopy(kn0)
        kn["scenarios"]["raw"].update(clear="fast")
        return inc("raw", kn) == [10, 60, 292]
    case("scenario dict covers clear fast and hazard off", fast_case)

    def afford(spec):
        kn = copy.deepcopy(kn0)
        kn["price"]["arrow"]["mode"] = "sheet"
        kn["thresholds"]["afford"][0] = dict(spec)
        return compute(st0, kn)["targets"][0]

    def afford_case():
        # sheet arrow costs 10, 15, 20, ...: cumulative 70 at level 4, 100 at level 5; average income is [10, 79, 498]
        ok = afford({"type": "arrow", "count": 1, "level": 4, "wave": 1}) == ("M1", 1, True)
        ok = ok and afford({"type": "arrow", "count": 1, "level": 5, "wave": 1}) == ("M1", 2, False)
        ok = ok and afford({"type": "arrow", "count": 1, "level": 5, "wave": 2}) == ("M1", 2, True)
        ok = ok and afford({"type": "arrow", "count": 2, "level": 4, "wave": 1}) == ("M1", 2, False)
        ok = ok and afford({"type": "arrow", "count": 1, "level": 1, "wave": 0}) == ("M1", 0, True)
        return ok and afford({"type": "arrow", "count": 1, "level": 36, "wave": 2}) == ("M1", None, False)
    case("afford target: pass or fail by the wave, first affordable wave, never", afford_case)

    def afford_wave_clamp_case():
        return afford({"type": "arrow", "count": 1, "level": 4, "wave": 99})[2]
    case("afford target: a wave beyond the victory wave counts as the victory wave", afford_wave_clamp_case)

    def late_case():
        def late(ratio):
            kn = copy.deepcopy(kn0)
            kn["price"]["arrow"]["mode"] = "sheet"
            kn["thresholds"]["late"] = {"type": "arrow", "count": 2, "level": 4, "wave": 2, "min_ratio": ratio}
            return compute(st0, kn)["targets"][5]
        row, low = late(3.5), late(3.6)
        return row[0] == "M6" and abs(row[1] - 498 / 140) < 1e-12 and row[2] and not low[2] and low[1] == row[1]
    case("late ratio target: average gold at the wave over count x cumulative cost", late_case)

    def tier3_case():
        kn = copy.deepcopy(kn0)
        res = compute(st0, kn)
        expect = layout_cost(gc["tower_tier3_level"], res["cum"], {"arrow": 2}, {}) / 616
        kn["thresholds"]["tier3_ratio"] = expect + 0.01
        low = compute(st0, kn)["targets"][4]
        kn["thresholds"]["tier3_ratio"] = expect
        return abs(res["targets"][4][1] - expect) < 1e-12 and not low[2] and compute(st0, kn)["targets"][4][2]
    case("layout ratio target: tier 3 layout cost over strong gold at the victory wave", tier3_case)

    def thresholds_case():
        base = compute(st0, kn0)["targets"]
        res = with_knobs(lambda kn: kn["thresholds"].update({"tier3_ratio": 1000}))
        return [r[:2] for r in res["targets"]] == [r[:2] for r in base] and len(base) == 6             and [r[0] for r in base] == ["M1", "M2", "M3", "M4", "M5", "M6"] and not res["targets"][4][2]
    case("thresholds change pass flags only", thresholds_case)

    def default_thr_case():
        thr = default_thresholds(["arrow", "cannon", "heal_station"])
        return [(a["type"], a["count"], a["level"], a["wave"]) for a in thr["afford"]] == [
            ("arrow", 1, 14, 9), ("cannon", 2, 13, 14), ("arrow", 1, 25, 19), ("heal_station", 1, 1, 4)]             and thr["tier3_ratio"] == 1.0 and thr["late"] == {"type": "arrow", "count": 3, "level": 25, "wave": 30,
                                                              "min_ratio": 0.8}             and default_thresholds(["wall"])["afford"][1]["type"] == "wall"
    case("default targets and a fallback type missing from the sheet", default_thr_case)

    def sheet_case():
        res = with_knobs(lambda kn: kn["price"]["arrow"].update({"mode": "sheet"}))
        return res["costs"]["arrow"] == sj0["sheet_costs"]["arrow"] and res["costs"]["wall"] != sj0["sheet_costs"]["wall"] \
            and res["cum"]["arrow"] == cumulative(sj0["sheet_costs"]["arrow"])
    case("sheet mode uses the sheet prices", sheet_case)

    meta = {"generated": "x", "xlsx": "x", "game_config": "x"}
    payload = build_payload(sj0, kn0, meta)
    keys = {"schema", "fingerprint", "generated", "xlsx", "game_config", "gc", "order", "sheet_costs", "sheet_stats",
            "columns", "tower_rows", "wave_data", "wave_hp", "defaults", "reference"}
    case("payload round-trips as JSON and has every key of schema 1",
         lambda: set(payload) == keys and payload["schema"] == 1 and len(payload["fingerprint"]) == 12
         and json.loads(json.dumps(payload, sort_keys=True)) == json.loads(json.dumps(payload)))

    def escape_case():
        sj, kn = toy(["x</script>"])
        page = render_html(build_payload(sj, kn, meta), "")
        return "x</script>" not in page and "x<\\/script>" in page
    case("payload escapes </script>", escape_case)

    def template_case():
        text = TEMPLATE.read_text(encoding="utf-8")
        page = render_html(payload, "<noscript>marker</noscript>")
        return text.count(PAYLOAD_MARK) == 1 and text.count(NOSCRIPT_MARK) == 1 and PAYLOAD_MARK not in page \
            and NOSCRIPT_MARK not in page and "<noscript>marker</noscript>" in page
    case("template has each placeholder once and none is left after render", template_case)

    def reference_case():
        sj, kn = toy(["arrow", "wall"], with_stats=False)
        again = [{"name": n, "knobs": k, "result": compute(st0, k)} for n, k in reference_knobs(kn0, ["arrow", "wall"], 36)]
        return len(payload["reference"]) == 5 and len(build_payload(sj, kn, meta)["reference"]) == 4             and json.loads(json.dumps(payload["reference"])) == json.loads(json.dumps(again))
    case("reference has 5 cases (4 without stats) and each result equals compute()", reference_case)

    def gap_case():
        res = with_knobs(lambda kn: kn.update({"target_gold": 1000, "target_scenario": "strong"}))
        return compute(st0, kn0)["target_gap"] is None and res["target_gap"] == {"gold": 616, "ratio": 0.616}
    case("target gap ratio and null when unset", gap_case)

    def stats_case():
        sheet = {"arrow": {"max_hp": [100] * 36, "damage": list(range(10, 46)), "attack_range": [14.0] * 36,
                           "fire_rate": [1.25] * 36}}
        kn = {"arrow": {k: [] for k in STAT_KEYS}}
        kn["arrow"].update(damage=[[13, 1.25]], attack_range=[[1, 1.234]], fire_rate=[[36, 0.8]], max_hp=[[30, 1.234]])
        out = scaled_stats(sheet, ["arrow"], kn)["arrow"]
        return out["damage"][:12] == [10] * 12 and out["damage"][12:14] == [12, 16]             and out["attack_range"][:2] == [14.0, 17.28] and out["fire_rate"][34:] == [1.25, 1.0]             and out["max_hp"] == [100] * 29 + [125, 150, 190, 230, 285, 355, 435]
    case("chained stats start from the sheet level 1 value and round int and float fields", stats_case)

    def stat_segments_case():
        sheet = {"arrow": {k: [100] * 36 for k in STAT_KEYS}}
        kn = {"arrow": {k: [] for k in STAT_KEYS}}
        kn["arrow"]["damage"] = [[25, 1.5], [10, 1.2]]  # unsorted on purpose
        kn["arrow"]["max_hp"] = [[10, 2], [20, 1]]  # a mult of 1 holds the previous level
        sheet["arrow"]["fire_rate"] = list(range(1, 37))
        out = scaled_stats(sheet, ["arrow"], kn)["arrow"]
        return out["damage"][:9] == [100] * 9 and out["damage"][9:11] == [120, 144] and out["max_hp"][9] == 200             and out["damage"][24] == round_half_up(100 * 1.2 ** 15 * 1.5, 2) and out["max_hp"][18:] == [102400] * 18             and isinstance(out["damage"][12], int) and out["fire_rate"] == list(range(1, 37))
    case("stat segments: the latest segment replaces earlier ones, no segment keeps the sheet", stat_segments_case)

    def stat_dup_case():
        kn = {"arrow": {k: [] for k in STAT_KEYS}}
        kn["arrow"]["damage"] = [[10, 1.2], [10, 1.5]]
        try:
            scaled_stats({"arrow": {k: [100] * 36 for k in STAT_KEYS}}, ["arrow"], kn)
        except BalanceSimError:
            return True
        return False
    case("a repeated stat segment level is rejected", stat_dup_case)

    def dps_case():
        st = dict(st0, order=["arrow"])
        stats = scaled_stats(st["sheet_stats"], ["arrow"], kn0["stats"])
        uniform = {"raw": [0, 1, 1]}
        a = dps_curves(st, stats, {"arrow": 2}, uniform, kn0["dps"])
        st["sheet_stats"] = copy.deepcopy(st["sheet_stats"])
        st["sheet_stats"]["arrow"]["splash_radius"][0] = 2
        b = dps_curves(st, stats, {"arrow": 2}, uniform, kn0["dps"])
        return a["demand"] == [10.0, 30.0] and a["supply"]["raw"] == [0, 20.0] and b["supply"]["raw"] == [0, 40.0]
    case("dps supply and demand on toy data", dps_case)
    total = len(results)
    passed = sum(results)
    print(f"self-test: {passed}/{total}")
    return 0 if passed == total else 1


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    validate_args(args, parser)
    try:
        return run(args, parser)
    except BalanceSimError as exc:
        for line in str(exc).splitlines():
            print(f"error: {line}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
