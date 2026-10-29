#!/usr/bin/env python3
"""Import one finished PixelLab asset into the game with a single command.

    python3 tools/art/import_pixellab.py <pixellab_id | download url | character page url> <asset_key> [options]

    python3 tools/art/import_pixellab.py 8d699d00-eb9f-4da7-a408-a1f70039fa1c crono
    python3 tools/art/import_pixellab.py https://api.pixellab.ai/mcp/characters/<id>/download enm_u0_porcelain_shardling
    python3 tools/art/import_pixellab.py <id> marle --listing /tmp/marle_listing.txt    # zip still locked (jobs pending)

The asset key is the game's sprite id. The target folder, sheet suffix, canvas, frame rate and height are
resolved from the game data:

    data/characters/<key>.json          -> assets/characters/<key>/<key>_field.png   (height_m from the kit)
    an enemy whose key or sprite is <key> -> assets/enemies/u<n>/<key>/<key>_sheet.png (fps from the def)
    a boss whose sprite is <key>        -> assets/bosses/u<n>/<key>/<key>_sheet.png
    anything else (an NPC)              -> assets/npcs/<key>/<key>_field.png

Every import writes the sheet (eight direction rows: s, w, e, n, sw, se, nw, ne), a `_n` normal sheet, the
`_frames.json` table, the `.import` sidecars, a contact sheet under source_art/, and records the asset in
data/art/pixellab_assets.json (PixelLab id, key, date, settings). Re-running on the same key rebuilds the sheet
(for example after more animations were generated). Options override the resolved defaults:
    --height-m 1.78   --canvas u1   --fps 24   --group npcs   --map walk=sad-walk,attack=slash-v3
    --no-mirror (never mirror a missing direction; the default for asymmetric characters)
    --mirror    (fill a missing west-side direction from the east side; fine for symmetric creatures)
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(HERE, "pipeline"))
import pixellab_import as pl  # noqa: E402

RECORD = os.path.join(ROOT, "data", "art", "pixellab_assets.json")
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def load_json(path):
    with open(path) as f:
        return json.load(f)


def resolve_target(key):
    """-> dict(group, subdir, suffix, canvas, fps, height_m, universe)"""
    char_path = os.path.join(ROOT, "data", "characters", f"{key}.json")
    if os.path.exists(char_path):
        kit = load_json(char_path)
        u = int(kit.get("home_universe", 0))
        # Sera has no home universe (-1): she is drawn on the U0 watercolour canvas with her ghost layers added in-engine.
        canvas = f"u{u}" if u >= 0 else "u0"
        return {"group": "characters", "subdir": key, "suffix": "_field", "canvas": canvas,
                "fps": float(kit.get("canvas_fps", 60)), "height_m": kit.get("height_m"), "universe": max(u, 0)}
    for f in glob.glob(os.path.join(ROOT, "data", "enemies", "u*", "*.json")):
        for e in load_json(f).get("enemies", []):
            if key in (e.get("key"), e.get("sprite")):
                u = int(e.get("universe", 0))
                return {"group": "enemies", "subdir": f"u{u}/{key}", "suffix": "_sheet", "canvas": f"u{u}",
                        "fps": float(e.get("fps", 60)), "height_m": e.get("height_m"), "universe": u}
    for f in glob.glob(os.path.join(ROOT, "data", "bosses", "*.json")):
        b = load_json(f)
        if key in (b.get("sprite"), b.get("id")):
            u = int(b.get("universe", 0))
            return {"group": "bosses", "subdir": f"u{u}/{key}", "suffix": "_sheet", "canvas": f"u{u}",
                    "fps": float(b.get("fps", 60)), "height_m": b.get("height_m", b.get("size")), "universe": u}
    npc_canvas = "u0"
    return {"group": "npcs", "subdir": key, "suffix": "_field", "canvas": npc_canvas, "fps": 60.0,
            "height_m": None, "universe": 0}


def extract_id(text):
    m = UUID.search(text)
    if not m:
        raise SystemExit(f"no PixelLab id in '{text}'")
    return m.group(0)


def record(key, entry):
    data = load_json(RECORD) if os.path.exists(RECORD) else {"_readme": [
        "Every PixelLab asset imported into the game: asset key -> PixelLab id, kind, import date and the settings",
        "the sheet was built with. Written by tools/art/import_pixellab.py; rebuild any entry with",
        "python3 tools/art/import_pixellab.py <pixellab_id> <key>. Nich's picks in the Character Creator are",
        "matched by the PixelLab name recorded here. Nothing in the PixelLab library is ever deleted."]}
    old = data.get(key, {})
    history = old.get("history", [])
    if old.get("pixellab_id") and old.get("pixellab_id") != entry["pixellab_id"]:
        history.append({"pixellab_id": old["pixellab_id"], "imported": old.get("imported")})
    entry["history"] = history
    data[key] = entry
    with open(RECORD, "w") as f:
        json.dump(data, f, indent=1, sort_keys=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="PixelLab character id, download URL or character page URL")
    ap.add_argument("key", help="asset key = the game's sprite id")
    ap.add_argument("--group", default=None, choices=["characters", "npcs", "enemies", "bosses"])
    ap.add_argument("--canvas", default=None)
    ap.add_argument("--fps", type=float, default=None)
    ap.add_argument("--height-m", type=float, default=None)
    ap.add_argument("--map", default="", help="game=pixellab animation name overrides")
    ap.add_argument("--mirror", action="store_true")
    ap.add_argument("--no-mirror", action="store_true")
    ap.add_argument("--listing", default="", help="a saved get_character listing (zip locked while jobs run)")
    ap.add_argument("--skip-download", action="store_true", help="rebuild from the cached raw frames")
    args = ap.parse_args()

    pid = extract_id(args.source)
    t = resolve_target(args.key)
    if args.group:
        t["group"] = args.group
        if args.group in ("characters", "npcs"):
            t["subdir"], t["suffix"] = args.key, "_field"
        else:
            t["subdir"], t["suffix"] = f"u{t['universe']}/{args.key}", "_sheet"
    canvas = args.canvas or t["canvas"]
    fps = args.fps or t["fps"]
    height_m = args.height_m if args.height_m is not None else t["height_m"]
    anim_map = dict(kv.split("=") for kv in args.map.split(",") if "=" in kv)
    mirror = args.mirror and not args.no_mirror

    src = os.path.join(ROOT, "source_art", t["group"], t["subdir"], "pixellab")
    meta_path = os.path.join(src, "metadata.json")
    if args.listing:
        with open(args.listing) as f:
            meta = pl.import_listing(f.read(), pid, src)
    elif args.skip_download and os.path.exists(meta_path):
        meta = load_json(meta_path)
    else:
        try:
            meta = pl.download_character(pid, src)
        except Exception as e:
            if os.path.exists(meta_path):
                print(f"download failed ({e}); rebuilding from the cached frames")
                meta = load_json(meta_path)
            else:
                raise SystemExit(f"download failed ({e}). While jobs are pending the zip is locked: save the "
                                 f"get_character listing to a file and pass --listing <file>.")
    out = os.path.join(ROOT, "assets", t["group"], t["subdir"])
    sheet, data, missing = pl.build_sheet(
        args.key, meta, src, out, canvas=canvas, height_m=height_m, fps=fps, anim_map=anim_map,
        mirror_missing=mirror, suffix=t["suffix"])
    contact = os.path.join(src, "contact.png")
    pl.contact_sheet(sheet, data["cell"], contact)
    name = meta["states"][0]["character"].get("name", "") if meta.get("states") else ""
    record(args.key, {
        "pixellab_id": pid,
        "pixellab_name": name,
        "kind": "character",
        "group": t["group"],
        "path": os.path.relpath(out, ROOT).replace(os.sep, "/"),
        "imported": datetime.date.today().isoformat(),
        "canvas": canvas, "fps": fps, "height_m": data["height_m"], "height_px": data["height_px"],
        "cell": data["cell"], "anims": {k: v["count"] for k, v in data["anims"].items()},
        "missing": sorted(set(f"{d}:{a}" for d, a in missing)),
    })
    rel_sheet = os.path.relpath(os.path.join(out, f"{args.key}{t['suffix']}.png"), ROOT)
    print(f"{args.key} <- {pid}: {rel_sheet} {sheet.width}x{sheet.height} cell {data['cell']} "
          f"height {data['height_px']}px = {data['height_m']} m, anims {list(data['anims'].keys())}")
    if missing:
        print("  directions filled with the rotation:", sorted(set(f"{d}:{a}" for d, a in missing)))
    print(f"  contact sheet: {os.path.relpath(contact, ROOT)}")
    print(f"  review: bash tools/capture/render.sh test_lineup lineup 30 -- --ids={args.key} --anim=walk")


if __name__ == "__main__":
    main()
