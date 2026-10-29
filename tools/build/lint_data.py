#!/usr/bin/env python3
"""Lint data/*.json: valid JSON, known tags, referenced ids exist, dialogue labels resolve."""
import json, re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
tags_src = (ROOT / "scripts/combat/combat_tags.gd").read_text()
m = re.search(r"const ALL: Array\[StringName\] = \[(.*?)\]\n", tags_src, re.S)
KNOWN = set(re.findall(r'&"([A-Z_]+)"', m.group(1)))
errors = []
def load(p):
    try:
        return json.loads(p.read_text())
    except Exception as e:
        errors.append(f"{p}: {e}")
        return None
techs, enemies, chars, flags, dialogue, encounters = {}, {}, {}, {}, {}, {}
for p in sorted((ROOT/"data/techs").rglob("*.json")):
    d = load(p)
    if not d: continue
    for t in d.get("techs", []):
        tid = t.get("id")
        if tid in techs: errors.append(f"duplicate tech {tid}")
        techs[tid] = t
        for tg in t.get("tags", []):
            if tg not in KNOWN: errors.append(f"tech {tid}: unknown tag {tg}")
for p in sorted((ROOT/"data/enemies").rglob("*.json")):
    d = load(p)
    if not d: continue
    for e in d.get("enemies", []):
        k = e.get("key")
        if k in enemies: errors.append(f"duplicate enemy {k}")
        enemies[k] = e
        for group in ("tags","weak","resist","nullify","immune","absorb"):
            for tg in e.get(group, []):
                if tg not in KNOWN: errors.append(f"enemy {k}: unknown tag {tg} in {group}")
        for a in e.get("actions", []):
            for tg in a.get("tags", []):
                if tg not in KNOWN: errors.append(f"enemy {k} action {a.get('id')}: unknown tag {tg}")
for p in sorted((ROOT/"data/characters").rglob("*.json")):
    d = load(p)
    if not d: continue
    chars[d.get("id")] = d
    for t in d.get("techs", []):
        tid = t["id"] if isinstance(t, dict) else t
        if tid not in techs: errors.append(f"character {d.get('id')}: unknown tech {tid}")
for p in sorted((ROOT/"data/flags").rglob("*.json")):
    d = load(p)
    if not d: continue
    for f in d.get("flags", []):
        if f["id"] in flags: errors.append(f"duplicate flag {f['id']}")
        flags[f["id"]] = f
for p in sorted((ROOT/"data/encounters").rglob("*.json")):
    d = load(p)
    if not d: continue
    for enc in d.get("encounters", []):
        encounters[enc["id"]] = enc
        for ek in enc.get("enemies", []):
            key = ek if isinstance(ek, str) else ek.get("key")
            if key not in enemies: errors.append(f"encounter {enc['id']}: unknown enemy {key}")
for p in sorted((ROOT/"data/dialogue").rglob("*.json")):
    d = load(p)
    if not d: continue
    for sid, cmds in d.items():
        dialogue[sid] = cmds
        labels = {c["label"] for c in cmds if isinstance(c, dict) and "label" in c}
        for c in cmds:
            if not isinstance(c, dict): errors.append(f"{sid}: command is not an object"); continue
            for key in ("goto","then","else"):
                if key in c and c[key] and c[key] not in labels: errors.append(f"{sid}: missing label {c[key]}")
            for o in c.get("choice", []):
                if "goto" in o and o["goto"] not in labels: errors.append(f"{sid}: missing label {o['goto']}")
            if "battle" in c and c["battle"] not in encounters: errors.append(f"{sid}: unknown encounter {c['battle']}")
            if "learn" in c and c["learn"] not in techs: errors.append(f"{sid}: unknown tech {c['learn']}")
print(f"data lint: {len(techs)} techs, {len(enemies)} enemies, {len(chars)} characters, {len(flags)} flags, {len(encounters)} encounters, {len(dialogue)} scripts")
for e in errors: print("  ERROR:", e)
sys.exit(1 if errors else 0)
