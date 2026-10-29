#!/usr/bin/env python3
"""Rebuild game sprite sheets from the art manifest (data/art/pixellab_characters.json).

    python3 tools/art/pipeline/build_characters.py            # every entry with a chosen PixelLab id
    python3 tools/art/pipeline/build_characters.py crono sera # just these
    python3 tools/art/pipeline/build_characters.py crono --listing /tmp/crono_listing.txt
        (fetch frames from a saved get_character listing while PixelLab's zip is still locked)

For each id this downloads the chosen PixelLab character (rotations + every animation) into
source_art/<group>/<id>/pixellab/, packs the eight-row sheet into assets/<group>/<id>/<id>_field.png,
writes <id>_frames.json and the .import sidecar, and saves a contact sheet next to the raw download.
Nothing here calls the PixelLab generators: generation happens through the MCP tools, and the manifest
records which character id was chosen. See docs/ART_PIPELINE.md.
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import pixellab_import as pl  # noqa: E402

MANIFEST = os.path.join(ROOT, "data", "art", "pixellab_characters.json")


def load_manifest():
    with open(MANIFEST) as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if not k.startswith("_")}


def build(game_id, entry, listing=None, skip_download=False):
    char_id = entry.get("pixellab", {}).get("chosen")
    if not char_id:
        print(f"{game_id}: no chosen PixelLab id yet, skipped")
        return False
    group = entry.get("group", "characters")
    src = os.path.join(ROOT, "source_art", group, game_id, "pixellab")
    meta_path = os.path.join(src, "metadata.json")
    if listing:
        with open(listing) as f:
            meta = pl.import_listing(f.read(), char_id, src)
    elif skip_download and os.path.exists(meta_path):
        with open(meta_path) as f:
            meta = json.load(f)
    else:
        try:
            meta = pl.download_character(char_id, src)
        except Exception as e:  # the zip is locked (HTTP 423) while jobs are pending
            if os.path.exists(meta_path):
                print(f"{game_id}: download failed ({e}); using the cached raw frames")
                with open(meta_path) as f:
                    meta = json.load(f)
            else:
                print(f"{game_id}: download failed ({e}) and no cache; pass --listing")
                return False
    out = os.path.join(ROOT, "assets", group, game_id)
    sheet, data, missing = pl.build_sheet(
        game_id, meta, src, out,
        canvas=entry.get("canvas", "u0"),
        height_m=float(entry.get("height_m", 1.7)),
        fps=float(entry.get("fps", 60)),
        anim_map=entry.get("anims", {}),
        mirror_missing=bool(entry.get("mirror_missing", False)),
    )
    pl.contact_sheet(sheet, data["cell"], os.path.join(src, "contact.png"))
    print(f"{game_id}: {sheet.width}x{sheet.height} cell {data['cell']} height {data['height_px']}px "
          f"anims {list(data['anims'].keys())}" + (f" missing {sorted(set(missing))}" if missing else ""))
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--listing", default="")
    ap.add_argument("--skip-download", action="store_true")
    args = ap.parse_args()
    manifest = load_manifest()
    ids = args.ids or list(manifest.keys())
    ok = 0
    for gid in ids:
        if gid not in manifest:
            print(f"{gid}: not in {os.path.relpath(MANIFEST, ROOT)}")
            continue
        if build(gid, manifest[gid], listing=args.listing or None, skip_download=args.skip_download):
            ok += 1
    print(f"built {ok}/{len(ids)}")


if __name__ == "__main__":
    main()
