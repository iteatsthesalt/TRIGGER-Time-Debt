#!/usr/bin/env python3
"""Import a generated texture as a SceneKit material pair (DECISIONS "Direction": 32 px per metre).

    python3 tools/art/import_texture.py <png | pixellab image job id> <material_name> [--universe u0]
        [--colours 15] [--border 12] [--tool create_image_pixen --model pixen --seed 1024 --prompt "..."]

Writes assets/textures/generated/<name>_albedo.png and <name>_normal.png (1024 px = 32 m, so a 256 px source
repeats every 8 m and a 128 px one every 4 m), after quantising the source to its own material palette (the
breakdown's seven material families of 15 colours, median cut, no dither) and wrap-blending a thin border so
it tiles. SceneKit.named("<name>") picks the pair up at once. A row goes to source_art/MANIFEST.csv (the
AI-disclosure log: tool, model, seed, prompt, post-process); it lives outside assets/ because Godot imports
any CSV under the project as a translation table.
"""
import argparse
import csv
import datetime
import os
import re
import ssl
import sys
import urllib.request

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
import pixel  # noqa: E402

OUT = os.path.join(ROOT, "assets", "textures", "generated")
MANIFEST = os.path.join(ROOT, "source_art", "MANIFEST.csv")
SHEET = 1024
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def fetch_job(job_id, index=0):
    """The finished image of a PixelLab raw-image job (no token needed)."""
    ca = "/root/.ccr/ca-bundle.crt"
    ctx = ssl.create_default_context(cafile=ca) if os.path.exists(ca) else ssl.create_default_context()
    url = f"https://api.pixellab.ai/mcp/images/{job_id}/download?index={index}"
    req = urllib.request.Request(url, headers={"User-Agent": "trigger-time-debt"})
    with urllib.request.urlopen(req, timeout=120, context=ctx) as r:
        import io
        return Image.open(io.BytesIO(r.read())).convert("RGB")


def to_material_palette(img, colours=15):
    q = img.convert("RGB").quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert("RGB")


def wrap_blend(a, border=12):
    """Blend each edge into the opposite one over `border` px so the tile repeats without a seam."""
    h, w, _ = a.shape
    out = a.astype(float).copy()
    ramp = np.cos(np.linspace(0, np.pi, border)) * 0.5 + 0.5
    for i in range(border):
        t = ramp[i] * 0.5
        out[:, i] = out[:, i] * (1 - t) + a[:, w - 1 - i] * t
        out[:, w - 1 - i] = out[:, w - 1 - i] * (1 - t) + a[:, i] * t
    b = out.copy()
    for i in range(border):
        t = ramp[i] * 0.5
        out[i] = out[i] * (1 - t) + b[h - 1 - i] * t
        out[h - 1 - i] = out[h - 1 - i] * (1 - t) + b[i] * t
    return np.clip(out, 0, 255).astype(np.uint8)


def import_texture(src, name, universe="u0", colours=15, border=12, strength=1.6, tool="", model="", seed="", prompt="", note=""):
    img = fetch_job(src) if UUID.match(src) else Image.open(src).convert("RGB")
    tile = to_material_palette(img, colours)
    tile = to_material_palette(Image.fromarray(wrap_blend(np.asarray(tile), border)), colours)
    reps = max(1, SHEET // tile.width)
    sheet = Image.new("RGB", (tile.width * reps, tile.height * reps))
    for x in range(reps):
        for y in range(reps):
            sheet.paste(tile, (x * tile.width, y * tile.height))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, f"{name}_albedo.png"), optimize=True)
    lum = np.asarray(sheet.convert("L")).astype(float) / 255.0
    pixel.normal_from_height(pixel.to_img(lum), strength).save(os.path.join(OUT, f"{name}_normal.png"), optimize=True)
    new = not os.path.exists(MANIFEST)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "a", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        if new:
            w.writerow(["file", "kind", "universe", "tool", "model", "seed", "generated_on", "post_process", "prompt"])
        w.writerow([f"assets/textures/generated/{name}_albedo.png", "texture", universe, tool, model, seed,
                    datetime.date.today().isoformat(),
                    f"{colours}-colour material palette (median cut, no dither), wrap-blend {border} px, tiled {reps}x{reps} to {SHEET} at 32 px/m, normal from luminance" + (f"; {note}" if note else ""),
                    prompt])
    print(f"{name}: {tile.width} px tile x{reps} -> {sheet.width} px sheet ({sheet.width / 32:.0f} m), {colours} colours")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", help="a PNG path or a PixelLab raw-image job id")
    ap.add_argument("name", help="the material name SceneKit.named() asks for")
    ap.add_argument("--universe", default="u0")
    ap.add_argument("--colours", type=int, default=15)
    ap.add_argument("--border", type=int, default=12)
    ap.add_argument("--strength", type=float, default=1.6, help="normal map strength")
    ap.add_argument("--tool", default="")
    ap.add_argument("--model", default="")
    ap.add_argument("--seed", default="")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--note", default="")
    a = ap.parse_args()
    import_texture(a.source, a.name, a.universe, a.colours, a.border, a.strength, a.tool, a.model, a.seed, a.prompt, a.note)


if __name__ == "__main__":
    main()
