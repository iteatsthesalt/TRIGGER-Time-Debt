#!/usr/bin/env python3
"""Which sprite files a PixelLab delivery owns, so the placeholder generators (spritegen.py) never overwrite one.

The PixelLab import (import_pixellab.py) records every sheet in data/art/pixellab_assets.json under its stem
(`<id>[_<variant>]_<tier>`, path `assets/<group>/<id>`) and writes `<stem>_frames.json` with a `source` naming
the PixelLab character or object.
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def delivered_owner(cid, out_dir, record_path=None, stem=None):
    """Why `out_dir/<stem>.png` (default stem `<cid>_field`) belongs to a PixelLab delivery (a reason string),
    or "" when a placeholder may be written there: the record names that stem in that folder, or the folder
    holds the importer's `<stem>_frames.json`."""
    record_path = record_path or os.path.join(ROOT, "data", "art", "pixellab_assets.json")
    rel_dir = os.path.relpath(out_dir, ROOT).replace(os.sep, "/")
    stem = stem or f"{cid}_field"
    if os.path.exists(record_path):
        with open(record_path) as f:
            record = json.load(f)
        entry = record.get(stem)
        if isinstance(entry, dict) and str(entry.get("path", "")).rstrip("/") == rel_dir:
            return f"{stem} is the PixelLab import {entry.get('pixellab_id', '?')} (data/art/pixellab_assets.json)"
    frames = os.path.join(out_dir, f"{stem}_frames.json")
    if os.path.exists(frames):
        try:
            with open(frames) as f:
                src = json.load(f).get("source", {})
        except ValueError:
            src = {}
        if src.get("pixellab_character") or src.get("pixellab_object"):
            return f"{rel_dir}/{stem}_frames.json is a PixelLab import table"
    return ""
