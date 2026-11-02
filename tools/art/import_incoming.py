#!/usr/bin/env python3
"""Import everything the bot has registered in data/art/incoming.json that is not yet in the game.

    python3 tools/art/import_incoming.py            # import every unimported PixelLab item
    python3 tools/art/import_incoming.py --dry-run  # list what would be imported
    python3 tools/art/import_incoming.py --only prp_u0_hearth,prp_u0_oak_table

The hourly check from CLAUDE.md: `git pull --rebase`, run this, wire the new assets in, screenshot them.
Each item goes through tools/art/import_pixellab.py (objects to the prop route, characters to the character
route); successes are stamped `"imported": "<date>"` in incoming.json, failures are listed and left alone.
Items without a PixelLab id (hand-made files under assets/incoming/) are reported, not imported. Items whose
PixelLab name starts with TEST or REJECTED are skipped and listed (the asset team's rule: they never ship);
--force imports them anyway, and also re-imports items already recorded.
"""
import argparse
import datetime
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
INCOMING = os.path.join(ROOT, "data", "art", "incoming.json")
RECORD = os.path.join(ROOT, "data", "art", "pixellab_assets.json")
IMPORTER = os.path.join(HERE, "import_pixellab.py")
sys.path.insert(0, HERE)
from import_pixellab import is_never_import  # noqa: E402


def load(path, default):
    if not os.path.exists(path):
        return default
    with open(path) as f:
        return json.load(f)


def items_of(doc):
    """incoming.json is a list of items, or an object with an `items` list."""
    return doc if isinstance(doc, list) else doc.get("items", [])


def record_key(item):
    """The key the importer records an item under (<key>[_<variant>]_<tier> for characters, the key itself
    for objects)."""
    key = item["asset_key"]
    if item.get("kind", "character") != "character":
        return key
    variant = item.get("variant", "") or ""
    tier = item.get("tier", "field") or "field"
    return key + ("_" + variant if variant else "") + "_" + tier


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", default="", help="comma-separated asset keys")
    ap.add_argument("--force", action="store_true", help="re-import items already recorded")
    args = ap.parse_args()
    doc = load(INCOMING, [])
    items = items_of(doc)
    recorded = load(RECORD, {})
    only = set(k for k in args.only.split(",") if k)
    done, failed, skipped = [], [], []
    for item in items:
        key = item.get("asset_key", "")
        if only and key not in only:
            continue
        pid = item.get("pixellab_id")
        if not pid:
            skipped.append(f"{key}: no PixelLab id ({item.get('note', item.get('path', 'hand-made?'))})")
            continue
        rk = record_key(item)
        if rk in recorded and recorded[rk].get("pixellab_id") == pid and not args.force:
            continue
        name = item.get("pixellab_name", "")
        if is_never_import(name) and not args.force:
            skipped.append(f"{key}: '{name}' is a TEST/REJECTED item and never ships (--force overrides)")
            continue
        kind = "object" if item.get("kind") == "object" else "character"
        cmd = [sys.executable, IMPORTER, pid, key, "--kind", kind, "--name", name,
               "--request", str(item.get("request", ""))]
        if args.force:
            cmd.append("--force")
        if kind == "character":
            if item.get("tier"):
                cmd += ["--tier", item["tier"]]
            if item.get("variant"):
                cmd += ["--variant", item["variant"]]
        print(" ".join(cmd[1:]))
        if args.dry_run:
            continue
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
        tail = (r.stdout.strip().splitlines() or [""])[-3:]
        if r.returncode == 0:
            item["imported"] = datetime.date.today().isoformat()
            done.append(key)
            for line in tail:
                print("   ", line)
        else:
            failed.append(f"{key}: {(r.stderr.strip().splitlines() or [r.stdout.strip()])[-1]}")
    if not args.dry_run and done:
        with open(INCOMING, "w") as f:
            json.dump(doc, f, indent=1)
    print(f"\nimported {len(done)}, failed {len(failed)}, skipped {len(skipped)}")
    for line in failed:
        print("  FAILED", line)
    for line in skipped:
        print("  skipped", line)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
