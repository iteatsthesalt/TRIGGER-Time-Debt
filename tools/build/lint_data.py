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
# Ambient keys are location ids: Location reads Data.ambient_lines(location_id), so a key must be a Router id
# (scripts/autoload/scene_router.gd) or a Location.location_id. A key for a location that is not built yet is a
# warning (the lines wait for the scene); the lead checks it against the planned scene list.
warnings = []
# Bosses (BossDef, BossController): every phase gate is one the controller or a director opens, a director-only gate
# without scripts/battle/bosses/<id>.gd stalls (warned: the chapter that builds the boss writes it), a phase script
# exists, a boss phase script nobody names is a warning, and a drop the dialogue also hands out is a warning.
GENERIC_GATES = {"break", "adds_defeated", "arm_broken", "branch"}
DIRECTOR_GATES = {"scripted", "threads_cut", "honest_lines", "sera_voluntary_phase_out", "stand_still_12s", "ending"}
named_scripts = set()
for bid, b in bosses.items():
    has_director = (ROOT / "scripts/battle/bosses" / f"{bid}.gd").exists()
    for i, ph in enumerate(b.get("phases", [])):
        gate = ph.get("advance_on", "")
        if gate and gate not in GENERIC_GATES | DIRECTOR_GATES: errors.append(f"boss {bid} phase {i}: unknown advance_on {gate}")
        elif gate in DIRECTOR_GATES and not has_director: warnings.append(f"boss {bid} phase {i}: advance_on {gate} needs scripts/battle/bosses/{bid}.gd (it stalls without one)")
        if ph.get("script"):
            named_scripts.add(ph["script"])
            if ph["script"] not in dialogue: errors.append(f"boss {bid} phase {i}: unknown script {ph['script']}")
    for d in b.get("drops", []):
        if d in granted: warnings.append(f"boss {bid}: drop {d} is also handed out by dialogue (it would be given twice)")
for sid in dialogue:
    if re.search(r"_(phase\d+|p\d+|mid)$", sid) and sid not in named_scripts:
        warnings.append(f"dialogue {sid} looks like a boss phase script but no boss phase names it")
router_src = (ROOT / "scripts/autoload/scene_router.gd").read_text()
location_ids = set(re.findall(r'locations\[&"([a-z0-9_]+)"\]', router_src))
for p in sorted((ROOT / "scripts/locations").glob("*.gd")):
    location_ids |= set(re.findall(r'location_id\s*=\s*&"([a-z0-9_]+)"', p.read_text()))
for k in text.get("ambient", {}):
    if k not in location_ids:
        warnings.append(f"text/ambient: {k} matches no Router or Location id (unreachable until a scene registers it)")
# Music and ambience ids: Audio.play_music loads res://audio/music/<id>.ogg or <id>__<stem>.ogg and play_ambience
# res://audio/ambience/<id>.ogg, and both drop a missing file silently. Every id named by data/ (dialogue cues,
# encounters, bosses, universes) or by a location script is checked; a missing track is a warning, counted, unless
# the Prologue or Chapter 1 (prologue.json, chapter1.json, the built location scripts) asks for it: then an error.
AUDIO_SHIPPED = {"data/dialogue/prologue.json", "data/dialogue/chapter1.json"}
def _audio_refs():
    refs = {}  # (kind, id) -> set of files
    def add(kind, ident, src):
        refs.setdefault((kind, ident), set()).add(src)
    for p in sorted((ROOT / "data").rglob("*.json")):
        rel = p.relative_to(ROOT).as_posix()
        raw = p.read_text(encoding="utf-8")
        for ident in re.findall(r'"(mus_[a-z0-9_]+)"', raw): add("music", ident, rel)
        for ident in re.findall(r'"(amb_[a-z0-9_]+)"', raw): add("ambience", ident, rel)
    for p in sorted((ROOT / "scripts/locations").glob("*.gd")):
        rel = p.relative_to(ROOT).as_posix()
        raw = p.read_text(encoding="utf-8")
        for ident in re.findall(r'field_music\s*=\s*&"(mus_[a-z0-9_]+)"', raw): add("music", ident, rel)
        for ident in re.findall(r'ambience\s*=\s*&"(amb_[a-z0-9_]+)"', raw): add("ambience", ident, rel)
        for ident in re.findall(r'play_music\(&"(mus_[a-z0-9_]+)"', raw): add("music", ident, rel)
    return refs
music_dir, amb_dir = ROOT / "audio/music", ROOT / "audio/ambience"
def _has_track(kind, ident):
    d = music_dir if kind == "music" else amb_dir
    return (d / f"{ident}.ogg").exists() or (kind == "music" and any(d.glob(f"{ident}__*.ogg")))
missing_audio = []
for (kind, ident), srcs in sorted(_audio_refs().items()):
    if _has_track(kind, ident): continue
    shipped = sorted(s for s in srcs if s in AUDIO_SHIPPED or s.startswith("scripts/locations/"))
    if shipped: errors.append(f"audio: {kind} id {ident} has no file under audio/{kind}/ but the Prologue/Chapter 1 plays it ({', '.join(shipped)})")
    else: missing_audio.append(f"{ident} ({', '.join(sorted(srcs))})")
if missing_audio:
    warnings.append(f"audio: {len(missing_audio)} music/ambience id(s) referenced by data have no track yet (AudioDirector plays silence for them):")
    warnings += [f"    {m}" for m in missing_audio]
# Sound effects: Audio.play_sfx(id) loads res://audio/sfx/<id>.wav|.ogg or a random <id>_01..05.wav and drops a
# missing id silently, so every literal id a script plays and every dialogue `sfx` is checked here; ids built at
# run time ("magic/%s_contact", "time/gate_open_u%d") are not. A warning, counted, until the file is delivered.
sfx_dir = ROOT / "audio/sfx"
def _has_sfx(ident):
    return any((sfx_dir / f"{ident}{ext}").exists() for ext in (".wav", ".ogg", "_01.wav"))
sfx_refs = {}
for p in sorted((ROOT / "scripts").rglob("*.gd")):
    for ident in re.findall(r'play_sfx\("([a-z0-9_/]+)"', p.read_text(encoding="utf-8")):
        sfx_refs.setdefault(ident, set()).add(p.relative_to(ROOT).as_posix())
for p in sorted((ROOT / "data/dialogue").glob("*.json")):
    for ident in re.findall(r'"sfx":\s*"([^"]+)"', p.read_text(encoding="utf-8")):
        sfx_refs.setdefault(ident, set()).add(p.relative_to(ROOT).as_posix())
missing_sfx = [f"{i} ({', '.join(sorted(srcs))})" for i, srcs in sorted(sfx_refs.items()) if not _has_sfx(i)]
if missing_sfx:
    warnings.append(f"audio: {len(missing_sfx)} sfx id(s) played by scripts or dialogue have no file under audio/sfx/ (they play silence):")
    warnings += [f"    {m}" for m in missing_sfx]
# Every Dual and Triple needs a learner: a kit entry in one of its actors (data/characters) or a dialogue `learn`
# command; otherwise the engine can never offer it. A warning, counted, until the chapter that teaches it is written.
learned = set()
for cmds in dialogue.values():
    for c in cmds:
        if isinstance(c, dict) and "learn" in c: learned.add(c["learn"])
kit_techs = {cid: {(t["id"] if isinstance(t, dict) else t) for t in d.get("techs", [])} for cid, d in chars.items()}
unlearnable = []
for tid, t in techs.items():
    if t.get("tier") not in ("dual", "triple"): continue
    if tid in learned or any(tid in kit_techs.get(a, set()) for a in t.get("actors", [])): continue
    unlearnable.append(f"{tid} ({' + '.join(t.get('actors', []))}, unlock {t.get('unlock')})")
if unlearnable:
    warnings.append(f"techs: {len(unlearnable)} Dual/Triple id(s) appear in no actor's kit and no dialogue learn command:")
    warnings += [f"    {u}" for u in unlearnable]
# Props (data/props, docs/ART_PIPELINE.md section 6): a billboard with a height in metres. Fields are a closed
# set, the key names its universe, and every delivered prop has its sheet, frames json and normal sheet under
# assets/props/u<n>/<key>/; a prop marked pending may have none yet. Every object recorded in
# data/art/pixellab_assets.json must have a props entry (the importer reads its height from there).
PROP_FIELDS = {"key", "universe", "height_m", "solid", "y_offset", "anims", "emission", "footprint", "pending", "request", "notes"}
def footprint_ok(fp):
    """[width, depth], "posts", or a list of [width, depth(, x_offset)] boxes (PropBillboard.boxes)."""
    num = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool)
    if isinstance(fp, str): return fp == "posts"
    if not isinstance(fp, list) or not fp: return False
    if not isinstance(fp[0], list): return len(fp) == 2 and all(num(v) for v in fp)
    return all(isinstance(b, list) and 2 <= len(b) <= 3 and all(num(v) for v in b) for b in fp)
PROP_ANIM_FIELDS = {"match", "fps", "loop", "holds"}
props = {}
for p in sorted((ROOT/"data/props").rglob("*.json")) if (ROOT/"data/props").exists() else []:
    d = load(p)
    if not d: continue
    for e in d.get("props", []):
        k = e.get("key")
        if not k: errors.append(f"{p.name}: prop without a key"); continue
        if k in props: errors.append(f"duplicate prop {k}")
        props[k] = e
        for f in set(e) - PROP_FIELDS: errors.append(f"prop {k}: unknown field {f}")
        u = e.get("universe")
        if not isinstance(u, int) or not 0 <= u <= 9: errors.append(f"prop {k}: universe must be 0..9")
        elif not k.startswith(f"prp_u{u}_"): errors.append(f"prop {k}: key does not name its universe u{u}")
        h = e.get("height_m")
        if not isinstance(h, (int, float)) or isinstance(h, bool) or h <= 0: errors.append(f"prop {k}: height_m must be a positive number")
        for name in ("solid", "pending"):
            if name in e and not isinstance(e[name], bool): errors.append(f"prop {k}: {name} must be true or false")
        for name in ("y_offset", "emission"):
            if name in e and (isinstance(e[name], bool) or not isinstance(e[name], (int, float))): errors.append(f"prop {k}: {name} must be a number")
        if "footprint" in e and not footprint_ok(e["footprint"]): errors.append(f"prop {k}: footprint must be [width, depth], \"posts\" or a list of [width, depth, x_offset] boxes")
        anims = e.get("anims", {})
        if not isinstance(anims, dict): errors.append(f"prop {k}: anims must be an object")
        else:
            for a, spec in anims.items():
                if not isinstance(spec, dict): errors.append(f"prop {k}: anim {a} must be an object"); continue
                for f in set(spec) - PROP_ANIM_FIELDS: errors.append(f"prop {k}: anim {a} has unknown field {f}")
        if not e.get("pending"):
            folder = ROOT / "assets" / "props" / f"u{u}" / k
            for suffix in (".png", "_frames.json", "_n.png"):
                if not (folder / f"{k}{suffix}").exists(): errors.append(f"prop {k}: missing {folder.relative_to(ROOT)}/{k}{suffix} (import it, or mark it pending)")
rec_path = ROOT / "data/art/pixellab_assets.json"
if rec_path.exists():
    rec = load(rec_path) or {}
    for k, v in rec.items():
        if isinstance(v, dict) and v.get("kind") == "object" and k not in props:
            errors.append(f"pixellab_assets: object {k} has no entry in data/props")
print(f"data lint: {len(techs)} techs, {len(enemies)} enemies, {len(bosses)} bosses, {len(chars)} characters, {len(flags)} flags, "
      f"{len(encounters)} encounters, {len(dialogue)} scripts, {len(items)} items, {len(props)} props, text layer: {len(text)} files, {len(gaps)} ids without text")
for g in gaps[:20]: print("  WARN: no text for", g)
if len(gaps) > 20: print(f"  WARN: ... and {len(gaps) - 20} more")
for w in warnings: print("  WARN:", w)
for e in errors: print("  ERROR:", e)
sys.exit(1 if errors else 0)
