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
            if "battle" in c and c["battle"] != "" and c["battle"] not in encounters: errors.append(f"{sid}: unknown encounter {c['battle']}")
            if "learn" in c and c["learn"] not in techs: errors.append(f"{sid}: unknown tech {c['learn']}")
# The text layer (data/text/*.json, contract in docs/JOB_CHATGPT.md): a key that names nothing in the game is an
# error; a game id without prose is a gap (warned, counted), so content can land before its text does.
bosses = {}
for p in sorted((ROOT/"data/bosses").rglob("*.json")):
    d = load(p)
    if d and d.get("id"): bosses[d["id"]] = d
items = {}
for p in sorted((ROOT/"data/items").rglob("*.json")):
    d = load(p)
    if d:
        for it in d.get("items", []): items[it["id"]] = it
granted = set()
for cmds in dialogue.values():
    for c in cmds:
        if not isinstance(c, dict): continue
        for node in [c] + [o for o in c.get("choice", []) if isinstance(o, dict)]:
            for key in ("give_item", "key_item", "relic"):
                if key in node: granted.add(node[key])
text = {}
for p in sorted((ROOT/"data/text").glob("*.json")) if (ROOT/"data/text").exists() else []:
    d = load(p)
    if d is None: continue
    text[p.stem] = d
    raw = p.read_text(encoding="utf-8")
    bad = sorted({ch for ch in raw if ord(ch) > 127})
    if bad: errors.append(f"text/{p.stem}: non-ASCII characters {''.join(bad)!r} (the text layer is plain ASCII)")
gaps = []
if text:
    best = text.get("bestiary", {})
    for k in best:
        if k not in enemies and k not in bosses: errors.append(f"text/bestiary: unknown enemy or boss {k}")
    gaps += [f"bestiary:{k}" for k in list(enemies) + list(bosses) if k not in best]
    tt = text.get("techs", {})
    for k in tt:
        if k not in techs: errors.append(f"text/techs: unknown tech {k}")
    gaps += [f"techs:{k}" for k in techs if k not in tt]
    it = text.get("items", {})
    for k in it:
        if k not in items and k not in granted: errors.append(f"text/items: {k} is neither a catalogue item nor granted by dialogue")
    gaps += [f"items:{k}" for k in sorted(set(items) | granted) if k not in it]
    cx = text.get("codex", {})
    for k, page in cx.items():
        if k not in flags: errors.append(f"text/codex: unknown flag {k}"); continue
        states = [s["id"] for s in flags[k].get("states", [])]
        for s in page.get("pages", {}):
            if s not in states: errors.append(f"text/codex: flag {k} has no state {s}")
        gaps += [f"codex:{k}:{s}" for s in states if s not in page.get("pages", {})]
    gaps += [f"codex:{k}" for k in flags if k not in cx]
    for k, lines in text.get("ambient", {}).items():
        if not isinstance(lines, list) or not lines: errors.append(f"text/ambient: {k} has no lines")
print(f"data lint: {len(techs)} techs, {len(enemies)} enemies, {len(bosses)} bosses, {len(chars)} characters, {len(flags)} flags, "
      f"{len(encounters)} encounters, {len(dialogue)} scripts, {len(items)} items, text layer: {len(text)} files, {len(gaps)} ids without text")
for g in gaps[:20]: print("  WARN: no text for", g)
if len(gaps) > 20: print(f"  WARN: ... and {len(gaps) - 20} more")
for e in errors: print("  ERROR:", e)
sys.exit(1 if errors else 0)
