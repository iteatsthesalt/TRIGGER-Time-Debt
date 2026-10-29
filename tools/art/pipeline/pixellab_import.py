#!/usr/bin/env python3
"""PixelLab → game sheet pipeline (Reference Bible §1.1, §1.4 CHR-F/CHR-B, §1.11, §1.12).

The generation itself happens through the PixelLab MCP tools (create_character / animate_character);
this module takes a finished PixelLab character id and writes the game's contract:

    assets/<group>/<id>/<id>_field.png      8 direction rows (s, w, e, n, sw, se, nw, ne) × animation columns
    assets/<group>/<id>/<id>_frames.json    cell, per-anim {col, count, fps, loop, holds}, height_px, height_m
    assets/<group>/<id>/<id>_field.png.import   lossless, no mipmaps, fix alpha border
    source_art/<group>/<id>/pixellab/       the raw download (zip, unpacked frames, metadata) so a sheet can be rebuilt

Usage:
    python3 tools/art/pipeline/pixellab_import.py <character_id> <game_id> [--group characters]
        [--canvas u0] [--height-m 1.78] [--fps 60] [--map walk=walking,run=running-6-frames,...]

Downloads need no token (the UUID is the key), so this runs on any machine.
"""
import argparse
import io
import json
import os
import sys
import urllib.request
import zipfile

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
import pixel  # noqa: E402

PIXELLAB = "https://api.pixellab.ai/mcp"
# Row order of the game's sheets. The first four match the old 4-row sheets, so every existing reader still works.
ROWS = ["south", "west", "east", "north", "south-west", "south-east", "north-west", "north-east"]
SHORT = {"south": "s", "west": "w", "east": "e", "north": "n", "south-west": "sw", "south-east": "se",
         "north-west": "nw", "north-east": "ne"}
FEET_PAD = 8

# Game animation name -> (PixelLab animation display names to look for, fps, loop)
DEFAULT_MAP = {
    "idle": (["idle", "breathing-idle"], 5, True),
    "walk": (["walk", "walking"], 10, True),
    "run": (["run", "running-6-frames", "running"], 12, True),
    "interact": (["interact", "picking-up"], 8, False),
    "emote": (["emote"], 5, False),
    "ready": (["ready", "fight-stance-idle-8-frames", "fight-stance-idle"], 8, True),
    "attack": (["attack", "slash", "cross-punch"], 14, False),
    "charge": (["charge", "tech-charge"], 8, True),
    "release": (["release", "fireball", "cast"], 12, False),
    "hurt": (["hurt", "taking-punch"], 12, False),
    "ko": (["ko", "shutdown", "falling-back-death"], 10, False),
    "revive": (["revive", "getting-up", "boot"], 10, False),
    "victory": (["victory"], 8, False),
    "death": (["death", "dissolve"], 10, False),
}


def fetch(url, dest=None):
    req = urllib.request.Request(url, headers={"User-Agent": "trigger-time-debt-pipeline"})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    if dest:
        with open(dest, "wb") as f:
            f.write(data)
    return data


def download_character(char_id, dest_dir):
    """Download and unpack a PixelLab character; returns the parsed metadata."""
    os.makedirs(dest_dir, exist_ok=True)
    zpath = os.path.join(dest_dir, "character.zip")
    data = fetch(f"{PIXELLAB}/characters/{char_id}/download", zpath)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        z.extractall(dest_dir)
    with open(os.path.join(dest_dir, "metadata.json")) as f:
        return json.load(f)


def load_state(meta, src_dir, state_index=0):
    """Return (rotations: {direction: Image}, animations: {display_name: {direction: [Image...]}})."""
    state = meta["states"][state_index]
    frames = state["frames"]
    rotations = {d: Image.open(os.path.join(src_dir, p)).convert("RGBA") for d, p in frames["rotations"].items()}
    animations = {}
    for name, dirs in frames.get("animations", {}).items():
        anim = {}
        if isinstance(dirs, dict):
            for d, paths in dirs.items():
                if isinstance(paths, dict):
                    paths = [paths[k] for k in sorted(paths.keys())]
                anim[d] = [Image.open(os.path.join(src_dir, p)).convert("RGBA") for p in paths]
        animations[name] = anim
    return rotations, animations


def feet_line(img, alpha_min=128):
    """Y of the lowest opaque row (the feet), or None for an empty frame."""
    a = np.asarray(img.getchannel("A"))
    rows = np.where(a.max(axis=1) >= alpha_min)[0]
    return int(rows.max()) if rows.size else None


def centre_x(img, alpha_min=128):
    a = np.asarray(img.getchannel("A")) >= alpha_min
    cols = np.where(a.any(axis=0))[0]
    return (int(cols.min()) + int(cols.max())) / 2.0 if cols.size else img.width / 2.0


def place_in_cell(img, cell, ground_y, cx=None):
    """Paste `img` into a cell so its ground line (y in img coords) sits FEET_PAD px above the cell's bottom edge.
    The horizontal placement keeps the frame's own canvas centre (so animations do not jitter), unless `cx`
    is given."""
    out = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    if cx is None:
        cx = img.width / 2.0
    ox = int(round(cell / 2.0 - cx))
    oy = (cell - FEET_PAD - 1) - ground_y
    out.paste(img, (ox, oy), img)
    return out


def finish(img, canvas):
    """The per-canvas finish applied to every generated frame (hard alpha, line colour, saturation)."""
    img = pixel.hard_alpha(img, 128)
    a = np.array(img).astype(float)
    solid = a[..., 3] > 0
    if canvas == "u0":
        # Watercolour: ink #2C2C2C line instead of pure black, saturation 0.92.
        dark = solid & (a[..., :3].max(axis=2) < 40)
        a[dark, :3] = a[dark, :3] * 0.4 + np.array([44, 44, 44]) * 0.6
        img = pixel.desaturate(Image.fromarray(a.astype(np.uint8)), 0.92)
    elif canvas == "u1":
        dark = solid & (a[..., :3].max(axis=2) < 40)
        a[dark, :3] = [20, 20, 18]
        img = pixel.desaturate(Image.fromarray(a.astype(np.uint8)), 0.3)
    elif canvas == "u7":
        dark = solid & (a[..., :3].max(axis=2) < 50)
        a[dark, :3] = [58, 46, 31]
        img = Image.fromarray(a.astype(np.uint8))
    return img


def build_sheet(game_id, meta, src_dir, out_dir, canvas="u0", height_m=1.78, fps=60.0, anim_map=None,
                extra_rows=None, mirror_missing=True):
    """Pack rotations and animations into the game sheet and write the frame table."""
    anim_map = anim_map or {}
    rotations, animations = load_state(meta, src_dir)
    # Ground line and height from the south rotation (the idle reference).
    south = rotations["south"]
    ground = feet_line(south)
    top = int(np.where(np.asarray(south.getchannel("A")).max(axis=1) >= 128)[0].min())
    height_px = ground - top + 1

    # Resolve which PixelLab animation feeds each game animation.
    chosen = {}
    for game_name, (cands, rate, loop) in DEFAULT_MAP.items():
        override = anim_map.get(game_name)
        names = [override] if override else cands
        for n in names:
            if n in animations and animations[n]:
                chosen[game_name] = (n, rate, loop)
                break

    # Cell: the smallest multiple of 32 that holds every frame around the pivot.
    need = 128
    for name, (pl_name, _, _) in chosen.items():
        for d, frames in animations[pl_name].items():
            for fr in frames:
                g = feet_line(fr)
                if g is None:
                    continue
                need = max(need, fr.width, g + FEET_PAD + 1 + 0, (fr.height - 0))
    cell = int(np.ceil(need / 32.0) * 32)

    # Columns: idle first (rotation if no idle animation), then the rest in DEFAULT_MAP order.
    table = {}
    col = 0
    columns = []  # list of (game_name, pl_name or None, count)
    if "idle" not in chosen:
        columns.append(("idle", None, 1))
    for game_name in DEFAULT_MAP:
        if game_name in chosen:
            pl_name, rate, loop = chosen[game_name]
            counts = [len(v) for v in animations[pl_name].values() if v]
            columns.append((game_name, pl_name, max(counts)))
    for game_name, pl_name, count in columns:
        if pl_name is None:
            table[game_name] = {"col": col, "count": 1, "fps": 1, "loop": True}
        else:
            _, rate, loop = chosen[game_name]
            table[game_name] = {"col": col, "count": count, "fps": rate, "loop": loop}
        col += count
    total_cols = col

    sheet = Image.new("RGBA", (total_cols * cell, len(ROWS) * cell), (0, 0, 0, 0))
    missing = []
    for r, direction in enumerate(ROWS):
        rot = rotations.get(direction)
        for game_name, pl_name, count in columns:
            c0 = table[game_name]["col"]
            if pl_name is None:
                frames = [rot] if rot is not None else []
            else:
                frames = animations[pl_name].get(direction, [])
                if not frames and mirror_missing:
                    # Mirror the opposite side when a direction was not generated (never for asymmetric heroes
                    # unless asked; the caller decides by passing mirror_missing).
                    opp = {"west": "east", "east": "west", "south-west": "south-east", "south-east": "south-west",
                           "north-west": "north-east", "north-east": "north-west"}.get(direction)
                    if opp and animations[pl_name].get(opp):
                        frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in animations[pl_name][opp]]
                if not frames:
                    missing.append((direction, game_name))
                    frames = [rot] if rot is not None else []
            for i in range(count):
                if not frames:
                    break
                fr = frames[min(i, len(frames) - 1)]
                g = feet_line(fr)
                if g is None:
                    continue
                # Animation frames keep the rotation's ground line when their canvas matches it, so a jump
                # or crouch reads as motion rather than being re-grounded frame by frame.
                anchor = ground if (fr.size == south.size and pl_name is not None) else g
                if fr.size != south.size and pl_name is not None:
                    # Larger generated canvases (v3) are pivot-centred: use the first frame's feet as the anchor.
                    first = animations[pl_name][direction][0] if animations[pl_name].get(direction) else fr
                    anchor = feet_line(first) if feet_line(first) is not None else g
                placed = place_in_cell(fr, cell, anchor)
                sheet.paste(finish(placed, canvas), (c0 * cell + i * cell, r * cell))
    os.makedirs(out_dir, exist_ok=True)
    sheet_path = os.path.join(out_dir, f"{game_id}_field.png")
    sheet.save(sheet_path, optimize=True)
    data = {
        "cell": cell,
        "rows": [SHORT[d] for d in ROWS],
        "mirror_w": False,
        "fps": fps,
        "height_px": int(height_px),
        "height_m": float(height_m),
        "source": {"pixellab_character": meta["states"][0]["character"]["id"], "canvas": canvas},
        "anims": table,
    }
    with open(os.path.join(out_dir, f"{game_id}_frames.json"), "w") as f:
        json.dump(data, f, indent=1)
    write_import(sheet_path)
    return sheet, data, missing


IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{rel}"
dest_files=["res://.godot/imported/{name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(png_path, normal=False):
    """Write the Godot .import sidecar (§1.12) for a sheet, keeping an existing uid when there is one."""
    import hashlib
    rel = os.path.relpath(png_path, ROOT).replace(os.sep, "/")
    imp = png_path + ".import"
    uid = None
    if os.path.exists(imp):
        with open(imp) as f:
            for line in f:
                if line.startswith("uid="):
                    uid = line.strip().split("uid://")[1].rstrip('"')
    if uid is None:
        h = hashlib.sha1(rel.encode()).hexdigest()
        alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
        n = int(h[:16], 16)
        uid = ""
        for _ in range(13):
            uid += alphabet[n % 36]
            n //= 36
    md5 = hashlib.md5(("res://" + rel).encode()).hexdigest()
    with open(imp, "w") as f:
        f.write(IMPORT_TEMPLATE.format(uid=uid, name=os.path.basename(png_path), md5=md5, rel=rel,
                                       normal=1 if normal else 0))


def contact_sheet(sheet, cell, path, scale=2, max_cols=12):
    """A quick preview: the first `max_cols` columns of every row, scaled up with nearest sampling."""
    cols = min(max_cols, sheet.width // cell)
    rows = sheet.height // cell
    crop = sheet.crop((0, 0, cols * cell, rows * cell))
    bg = Image.new("RGBA", crop.size, (58, 60, 70, 255))
    bg.paste(crop, (0, 0), crop)
    bg = bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST)
    bg.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("character_id")
    ap.add_argument("game_id")
    ap.add_argument("--group", default="characters")
    ap.add_argument("--canvas", default="u0")
    ap.add_argument("--height-m", type=float, default=1.78)
    ap.add_argument("--fps", type=float, default=60.0)
    ap.add_argument("--map", default="", help="game=pixellab,... animation name overrides")
    ap.add_argument("--no-mirror", action="store_true", help="never mirror a missing direction")
    ap.add_argument("--skip-download", action="store_true")
    args = ap.parse_args()
    anim_map = dict(kv.split("=") for kv in args.map.split(",") if "=" in kv)
    src = os.path.join(ROOT, "source_art", args.group, args.game_id, "pixellab")
    if args.skip_download and os.path.exists(os.path.join(src, "metadata.json")):
        with open(os.path.join(src, "metadata.json")) as f:
            meta = json.load(f)
    else:
        meta = download_character(args.character_id, src)
    out = os.path.join(ROOT, "assets", args.group, args.game_id)
    sheet, data, missing = build_sheet(args.game_id, meta, src, out, canvas=args.canvas, height_m=args.height_m,
                                       fps=args.fps, anim_map=anim_map, mirror_missing=not args.no_mirror)
    contact_sheet(sheet, data["cell"], os.path.join(src, "contact.png"))
    print(f"{args.game_id}: sheet {sheet.width}x{sheet.height}, cell {data['cell']}, height {data['height_px']} px, "
          f"anims {list(data['anims'].keys())}")
    if missing:
        print("missing (filled with the rotation):", sorted(set(missing)))


if __name__ == "__main__":
    main()
