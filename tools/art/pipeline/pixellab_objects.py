#!/usr/bin/env python3
"""PixelLab *object* → prop sheet (Reference Bible §1.4 PRP-S/PRP-M, §5.7, §11.7; docs/ART_PIPELINE.md §6).

Objects come from `create_1_direction_object`, `create_8_direction_object` and `create_object_pro_flash`.
`/mcp/objects/<id>/download` returns either a bare PNG (one rotation, no animations) or a zip holding
`rotations/<direction>.png` (a single rotation is named `unknown`) and optionally
`animations/<slug>/<direction>/frame_NNN.png`. This module turns either into the game's prop contract:

    assets/props/u<n>/<key>/<key>.png          one row per rotation (1, 4 or 8 rows), columns = idle, then clips
    assets/props/u<n>/<key>/<key>_frames.json  cell, rows, anims, height_px, width_px, height_m (from data/props)
    assets/props/u<n>/<key>/<key>_n.png        normal sheet, plus the .import sidecars
    source_art/props/<key>/pixellab/           raw download, unpacked frames, metadata.json, contact.png

The sheet pipeline (ground line, cell, normal map, sidecars, contact sheet) is the character route's
(`pixellab_import`); this module only adds what objects do differently. Height comes from
`data/props/props.json` (`height_m` per key), so the same prop stands at the same size in every room.
"""
import io
import json
import os
import re
import zipfile

import numpy as np
from PIL import Image

import pixellab_import as pl
import pixel

PNG_SIG = b"\x89PNG\r\n\x1a\n"
DEFAULT_CLIP_FPS = 6
## PixelLab writes a single rotation as "unknown"; other spellings seen in object exports.
DIRECTION_ALIASES = {"unknown": "south", "front": "south", "back": "north", "left": "west", "right": "east",
                     "s": "south", "n": "north", "e": "east", "w": "west", "sw": "south-west", "se": "south-east",
                     "nw": "north-west", "ne": "north-east"}
OPPOSITE = {"west": "east", "east": "west", "south-west": "south-east", "south-east": "south-west",
            "north-west": "north-east", "north-east": "north-west"}


def _direction(name):
    n = name.lower().replace("_", "-")
    return DIRECTION_ALIASES.get(n, n)


def download_object(obj_id, dest_dir):
    """Download a PixelLab object into `dest_dir` (PNG or zip), unpack it, write metadata.json in the
    character export's layout (so `pixellab_import.load_state` reads it) and return that metadata.
    A re-import replaces the previous delivery: once the download has arrived, the old frames, metadata and
    archive are removed first, so a v2 never inherits v1's rotations or clips (write_metadata scans the folder)."""
    os.makedirs(dest_dir, exist_ok=True)
    data = pl.fetch(f"{pl.PIXELLAB}/objects/{obj_id}/download")
    if data[:2] != b"PK" and data[:8] != PNG_SIG:
        head = data[:120].decode("utf-8", "replace")
        raise RuntimeError(f"object {obj_id}: the download is neither a PNG nor a zip ({head!r})")
    pl.clear_download(dest_dir)
    if data[:2] == b"PK":
        with open(os.path.join(dest_dir, "object.zip"), "wb") as f:
            f.write(data)
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for member in z.namelist():
                # only the frame folders; never let an archive write outside its own directory
                if member.startswith(("rotations/", "animations/")) and ".." not in member:
                    z.extract(member, dest_dir)
    elif data[:8] == PNG_SIG:
        rot_dir = os.path.join(dest_dir, "rotations")
        os.makedirs(rot_dir, exist_ok=True)
        with open(os.path.join(rot_dir, "unknown.png"), "wb") as f:
            f.write(data)
    return write_metadata(obj_id, dest_dir)


def write_metadata(obj_id, dest_dir, name=""):
    """Scan rotations/ and animations/ under dest_dir into a character-shaped metadata.json."""
    rotations = {}
    rot_dir = os.path.join(dest_dir, "rotations")
    if os.path.isdir(rot_dir):
        for f in sorted(os.listdir(rot_dir)):
            if f.endswith(".png"):
                rotations[_direction(f[:-4])] = f"rotations/{f}"
    animations = {}
    anim_dir = os.path.join(dest_dir, "animations")
    if os.path.isdir(anim_dir):
        for slug in sorted(os.listdir(anim_dir)):
            dirs = {}
            for d in sorted(os.listdir(os.path.join(anim_dir, slug))):
                frames = sorted(f for f in os.listdir(os.path.join(anim_dir, slug, d)) if f.endswith(".png"))
                if frames:
                    dirs[_direction(d)] = [f"animations/{slug}/{d}/{f}" for f in frames]
            if dirs:
                animations[slug] = dirs
    if not rotations:
        raise RuntimeError(f"object {obj_id}: no rotations found under {dest_dir}")
    meta = {"group_id": "", "export_version": "object",
            "states": [{"character": {"id": obj_id, "name": name}, "folder": "",
                        "frames": {"rotations": rotations, "animations": animations}}]}
    with open(os.path.join(dest_dir, "metadata.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return meta


def finish_object(img, canvas):
    """The per-canvas finish for props: the character route's, except that U1 keeps its saturation (the
    four inks arrive on-palette; desaturating would grey the cinnabar) and only has its line pulled to
    sumi black."""
    if canvas != "u1":
        return pl.finish(img, canvas)
    img = pixel.hard_alpha(img, 128)
    a = np.array(img).astype(float)
    dark = (a[..., 3] > 0) & (a[..., :3].max(axis=2) < 40)
    a[dark, :3] = [20, 20, 18]
    return Image.fromarray(a.astype(np.uint8))


def _extent(img, cx, alpha_min=128):
    """(half width around cx, drawn height) of a frame's opaque pixels, or None for an empty frame."""
    a = np.asarray(img.getchannel("A")) >= alpha_min
    if not a.any():
        return None
    cols = np.where(a.any(axis=0))[0]
    rows = np.where(a.any(axis=1))[0]
    half = max(cx - cols.min(), cols.max() + 1 - cx)
    return half, int(rows.max() - rows.min() + 1)


def plan_rows(rotations):
    """Which direction rows the sheet gets (1, 4 or 8) and where each row's frames come from when a rotation
    is missing (the mirrored opposite side, else the nearest drawn rotation). Returns (rows, source, mirror)."""
    have = [d for d in pl.ROWS if d in rotations]
    if len(have) <= 1:
        return ["south"], {"south": have[0] if have else None}, {"south": False}
    rows = pl.ROWS[:4] if all(d in pl.ROWS[:4] for d in have) else pl.ROWS
    source, mirror = {}, {}
    for d in rows:
        if d in rotations:
            source[d], mirror[d] = d, False
        elif OPPOSITE.get(d) in rotations:
            source[d], mirror[d] = OPPOSITE[d], True
        else:
            source[d], mirror[d] = have[0], False
    return rows, source, mirror


def plan_columns(animations, anim_table):
    """Column plan: `idle` (an ambient clip when the object has one, else the rotation), `still` (the
    rotation, only when idle is a clip), then every other clip. `anim_table` (from data/props) may name
    clips: {"idle": {"match": "flicker", "fps": 6, "loop": true, "holds": [...]}, ...}; a clip nobody
    names is `clip<n>`. Returns a list of (game_name, pixellab_slug or None, fps, loop, holds)."""
    anim_table = anim_table or {}
    slugs = list(animations.keys())
    named = {}
    for game_name, spec in anim_table.items():
        match = str(spec.get("match", game_name)).lower()
        for s in slugs:
            if match in s.lower() and s not in named.values():
                named[game_name] = s
                break
    if "idle" not in named and slugs:
        free = [s for s in slugs if s not in named.values()]
        if free:
            named["idle"] = free[0]
    columns = []
    idle_spec = anim_table.get("idle", {})
    if "idle" in named:
        columns.append(("idle", named["idle"], float(idle_spec.get("fps", DEFAULT_CLIP_FPS)),
                        bool(idle_spec.get("loop", True)), list(idle_spec.get("holds", []))))
        columns.append(("still", None, 1.0, True, []))
    else:
        columns.append(("idle", None, 1.0, True, []))
    n = 1
    for s in slugs:
        if s == named.get("idle"):
            continue
        game_name = next((g for g, v in named.items() if v == s), None)
        if game_name is None:
            n += 1
            game_name = f"clip{n}"
        spec = anim_table.get(game_name, {})
        columns.append((game_name, s, float(spec.get("fps", DEFAULT_CLIP_FPS)), bool(spec.get("loop", True)),
                        list(spec.get("holds", []))))
    return columns


def build_object_sheet(key, meta, src_dir, out_dir, canvas="u0", height_m=1.0, fps=60.0, anim_table=None):
    """Pack an object's rotations and clips into the prop sheet and write the frame table.
    Returns (sheet, data) where data is the frames json content."""
    rotations, animations = pl.load_state(meta, src_dir)
    rows, source, mirror = plan_rows(rotations)
    columns = plan_columns(animations, anim_table)
    ref = rotations.get("south") or next(iter(rotations.values()))
    ground = pl.feet_line(ref)
    if ground is None:
        raise RuntimeError(f"{key}: the rotation is empty")
    alpha = np.asarray(ref.getchannel("A")) >= 128
    top = int(np.where(alpha.any(axis=1))[0].min())
    cols = np.where(alpha.any(axis=0))[0]
    height_px = ground - top + 1
    width_px = int(cols.max() - cols.min() + 1)

    # Every frame placed about its own canvas centre, feet FEET_PAD above the cell bottom: the cell is the
    # smallest multiple of 32 that holds all of them (a 64 px gourd stays in a 64 cell, an arch in 224).
    need = 32
    frames_of = {}
    for game_name, slug, _, _, _ in columns:
        for d in rows:
            src = source[d]
            frames = [rotations[src]] if (slug is None or src is None) else animations[slug].get(src) or [rotations[src]]
            frames_of[(game_name, d)] = frames
            for fr in frames:
                ext = _extent(fr, fr.width / 2.0)
                if ext is None:
                    continue
                # the frame stands on its anchor line (below), so what must fit is anchor → its top row
                anchor = ground if fr.size == ref.size else (pl.feet_line(frames[0]) or pl.feet_line(fr))
                top_fr = int(np.where((np.asarray(fr.getchannel("A")) >= 128).any(axis=1))[0].min())
                need = max(need, int(np.ceil(ext[0] * 2)) + 2, anchor - top_fr + 1 + pl.FEET_PAD + 2)
    cell = int(np.ceil(need / 32.0) * 32)

    table = {}
    col = 0
    for game_name, slug, rate, loop, holds in columns:
        count = max(len(frames_of[(game_name, d)]) for d in rows)
        entry = {"col": col, "count": count, "fps": rate, "loop": loop}
        if holds:
            entry["holds"] = holds
        table[game_name] = entry
        col += count
    sheet = Image.new("RGBA", (col * cell, len(rows) * cell), (0, 0, 0, 0))
    for r, d in enumerate(rows):
        for game_name, slug, _, _, _ in columns:
            frames = frames_of[(game_name, d)]
            c0 = table[game_name]["col"]
            for i in range(table[game_name]["count"]):
                fr = frames[min(i, len(frames) - 1)]
                if mirror[d]:
                    fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
                g = pl.feet_line(fr)
                if g is None:
                    continue
                # Clips on the rotation's canvas keep its ground line so a swing or flicker is not re-grounded
                # frame by frame; a clip on another canvas is anchored on its own first frame's feet.
                anchor = ground if fr.size == ref.size else (pl.feet_line(frames[0]) or g)
                placed = pl.place_in_cell(fr, cell, anchor)
                sheet.paste(finish_object(placed, canvas), ((c0 + i) * cell, r * cell))
    os.makedirs(out_dir, exist_ok=True)
    sheet_path = os.path.join(out_dir, f"{key}.png")
    sheet.save(sheet_path, optimize=True)
    pl.write_import(sheet_path)
    n_path = os.path.join(out_dir, f"{key}_n.png")
    pl.normal_sheet(sheet, cell).save(n_path, optimize=True)
    pl.write_import(n_path, normal=True)
    data = {
        "cell": cell,
        "rows": [pl.SHORT[d] for d in rows],
        "mirror_w": False,
        "fps": fps,
        "height_px": int(height_px),
        "width_px": int(width_px),
        "height_m": round(float(height_m), 3),
        "source": {"pixellab_object": meta["states"][0]["character"]["id"], "canvas": canvas,
                   "rotations": sorted(rotations.keys()), "clips": {g: s for g, s, _, _, _ in columns if s}},
        "anims": table,
    }
    with open(os.path.join(out_dir, f"{key}_frames.json"), "w") as f:
        json.dump(data, f, indent=1)
    return sheet, data


def load_props_table(root):
    """data/props/*.json -> {key: entry}."""
    out = {}
    props_dir = os.path.join(root, "data", "props")
    if not os.path.isdir(props_dir):
        return out
    for f in sorted(os.listdir(props_dir)):
        if f.endswith(".json"):
            with open(os.path.join(props_dir, f)) as fh:
                for entry in json.load(fh).get("props", []):
                    out[entry["key"]] = entry
    return out


def canvas_fps(root, universe):
    """The canvas drawing rate of a universe (data/universes), 60 when unknown."""
    path = os.path.join(root, "data", "universes", "universes.json")
    try:
        with open(path) as f:
            for u in json.load(f).get("universes", []):
                if int(u.get("id", -1)) == universe:
                    return float(u.get("fps", 60))
    except OSError:
        pass
    return 60.0


def resolve_prop_target(root, key, universe=None, height_m=None):
    """-> dict(group, subdir, canvas, fps, height_m, universe, anims, request) for a prop key, from
    data/props (universe and height are required there unless given explicitly)."""
    entry = load_props_table(root).get(key, {})
    if universe is None:
        universe = entry.get("universe")
        if universe is None:
            m = re.match(r"prp_u(\d)_", key)
            universe = int(m.group(1)) if m else 0
    universe = int(universe)
    if height_m is None:
        height_m = entry.get("height_m")
    if height_m is None:
        raise SystemExit(f"{key}: add it to data/props/props.json (universe, height_m) before importing, "
                         f"or pass --height-m")
    return {"group": "props", "subdir": f"u{universe}/{key}", "canvas": f"u{universe}", "fps": canvas_fps(root, universe),
            "height_m": float(height_m), "universe": universe, "anims": entry.get("anims", {}),
            "request": entry.get("request", "")}
