"""Summary of wave bot runs (tests/wave_bot.gd), one JSON line per run.

Usage: python tests/wave_bot_report.py results.jsonl

Prints one line per run and the checks:
- every wave of every run ended (no hung wave), and none ended before its spawn duration
- culls (stuck and hard cap) under 0.1% of the units spawned, over all soak runs
- AFK against Frontline on the same seed: commander level at wave 12 at most 0.65 x Frontline,
  and fewer AFK runs reach wave 15
- how many runs built a Heal station and how many times its store ran dry
- commander level at waves 4 and 8 of the Frontline runs (target 4 +-1 and 8 +-1)
Exit code 1 when a hard check fails (hung wave, short wave, cull rate).
"""
import json
import sys
from collections import defaultdict


def load(path):
    runs = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                runs.append(json.loads(line))
    return runs


def level_at(run, wave):
    levels = run.get("commander_level", {})
    return levels.get(str(wave))


def main(path):
    runs = load(path)
    if not runs:
        print("no runs in", path)
        return 1
    ok = True
    print(f"{'seed':>5} {'mode':<10} {'soak':<5} {'result':<20} {'waves':>5} {'spawned':>7} {'culls':>5} {'cull%':>6} {'skills':>6} {'heal':>5} {'dry':>4}")
    for r in runs:
        culls = r["stuck_culls"] + r["hard_cap_culls"]
        print(f"{r['seed']:>5} {r['mode']:<10} {str(r['soak']):<5} {r['result']:<20} {r['waves_cleared']:>5} {r['spawned']:>7} {culls:>5} {r['cull_pct']:>6.3f} {r.get('skill_casts', 0):>6} {str(r['heal_station_built']):<5} {r['heal_depleted']:>4}")

    hung = [r for r in runs if r.get("hung")]
    short = [(r["seed"], r["mode"], r["short_waves"]) for r in runs if r.get("short_waves")]
    soak = [r for r in runs if r["soak"]]
    spawned = sum(r["spawned"] for r in soak)
    culls = sum(r["stuck_culls"] + r["hard_cap_culls"] for r in soak)
    cull_pct = 100.0 * culls / max(1, spawned)
    print()
    print(f"hung waves: {len(hung)}" + (f"  {[(r['seed'], r['mode']) for r in hung]}" if hung else ""))
    print(f"waves shorter than their spawn duration: {short or 'none'}")
    print(f"soak culls: {culls} of {spawned} units = {cull_pct:.3f}% (limit 0.1%)")
    if hung or short or (soak and cull_pct >= 0.1):
        ok = False

    by_seed = defaultdict(dict)
    for r in runs:
        if not r["soak"]:
            by_seed[r["seed"]][r["mode"]] = r
    pairs = [(s, m["afk"], m["frontline"]) for s, m in sorted(by_seed.items()) if "afk" in m and "frontline" in m]
    if pairs:
        print()
        print("AFK against Frontline, same seed:")
        afk15 = front15 = 0
        for seed, afk, front in pairs:
            la, lf = level_at(afk, 12), level_at(front, 12)
            ratio = (la / lf) if (la is not None and lf) else None
            afk15 += afk["waves_cleared"] >= 15
            front15 += front["waves_cleared"] >= 15
            print(f"  seed {seed}: level at wave 12 AFK {la} / Frontline {lf}"
                  + (f" = {ratio:.2f} (limit 0.65)" if ratio is not None else " (a run ended before wave 12)")
                  + f"; waves cleared AFK {afk['waves_cleared']}, Frontline {front['waves_cleared']}")
        print(f"  reached wave 15: AFK {afk15}/{len(pairs)}, Frontline {front15}/{len(pairs)}")

    front = [r for r in runs if r["mode"] == "frontline"]
    if front:
        print()
        print("Commander level of the Frontline runs (target 4 +-1 at wave 4, 8 +-1 at wave 8):")
        for r in front:
            print(f"  seed {r['seed']}: wave 4 -> {level_at(r, 4)}, wave 8 -> {level_at(r, 8)}, wave 12 -> {level_at(r, 12)}")

    built = [r for r in runs if r["heal_station_built"]]
    print()
    print(f"Heal station: built in {len(built)} of {len(runs)} runs, store ran dry {sum(r['heal_depleted'] for r in runs)} times in total")
    print()
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
