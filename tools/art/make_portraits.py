#!/usr/bin/env python3
"""Portraits and stand-in sprites from the catalog paintings (Route G → A).
For each catalog image with a flat chroma background: key it out, save a 512 PRT bust
(assets/<group>/<id>/<id>_portrait_neutral.png) and a painted full-body stand-in at 128/256
(assets/<group>/<id>/<id>_painted.png) used as a proof sprite until the generated sheets exist."""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from pixel import key_out, despill, reduce, hard_alpha, desaturate

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CAT = os.path.join(ROOT, "design", "images", "catalog")

# id -> (catalog file, group, cell for the painted stand-in, height px, desaturate)
SOURCES = {
    "crono": ("playable_crono.jpg", "characters", 128, 114, 0.85),
    "sera": ("playable_sera.jpg", "characters", 128, 104, 0.9),
    "krona": ("playable_krona.jpg", "characters", 128, 110, 0.7),
    "xyloph": ("playable_xyloph.jpg", "characters", 256, 200, 1.0),
    "vesper": ("playable_vesper.jpg", "characters", 128, 125, 1.0),
    "glenn": ("playable_pierrot_glenn.jpg", "characters", 128, 118, 0.6),
    "static": ("playable_static.jpg", "characters", 128, 93, 1.0),
    "omega": ("playable_omega_spekkio.jpg", "characters", 256, 154, 0.8),
    "marle": ("npc_marle.jpg", "npcs", 128, 108, 0.85),
    "glenn_marshall": ("npc_glenn.jpg", "npcs", 128, 115, 0.85),
    "magus": ("npc_magus.jpg", "npcs", 128, 118, 0.85),
    "johnny": ("npc_johnny_gramophone_vendor.jpg", "npcs", 256, 160, 0.9),
    "vaelos": ("enemy_vaelos.jpg", "bosses", 256, 175, 0.95),
    "weaver": ("enemy_porcelain_weaver.jpg", "bosses", 256, 122, 0.9),
    "r66y": ("enemy_arch_curator_r_66y.jpg", "bosses", 512, 390, 0.9),
    "citizen_husk": ("enemy_weeping_porcelain_citizen_husks.jpg", "enemies", 128, 110, 0.9),
    "bike_bros": ("enemy_bike_bros_daltonized_models.jpg", "enemies", 256, 150, 0.9),
    "traveler": ("npc_faceless_porcelain_travelers.jpg", "npcs", 128, 110, 0.8),
}


def process(cid, fname, group, cell, height, desat):
    src = Image.open(os.path.join(CAT, fname)).convert("RGBA")
    a = np.array(src)
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]]).astype(int)
    vals, counts = np.unique(border, axis=0, return_counts=True)
    bg = vals[counts.argmax()]
    spread = border.std(axis=0).mean()
    if spread > 18:
        print(f"  {cid}: background not flat (spread {spread:.1f}), skipping key")
        keyed = src
    else:
        keyed = despill(key_out(src, tol=70, bg=bg), bg)
    out_dir = os.path.join(ROOT, "assets", group, cid)
    os.makedirs(out_dir, exist_ok=True)
    bbox = keyed.getbbox()
    fig = keyed.crop(bbox)
    # Portrait: a square around the head and shoulders (top 42% of the figure), centred on the
    # horizontal centre of mass of the top fifth of the silhouette.
    w, h = fig.size
    alpha = np.array(fig.getchannel("A"))
    top_band = alpha[: max(1, h // 5)]
    cols = np.where(top_band.sum(axis=0) > 0)[0]
    cx = int((cols.min() + cols.max()) / 2) if cols.size else w // 2
    side = max(int(h * 0.42), 32)
    left = max(0, min(w - side, cx - side // 2))
    bust = fig.crop((left, 0, left + side, side))
    portrait = bust.resize((512, 512), Image.LANCZOS)
    portrait.save(os.path.join(out_dir, f"{cid}_portrait_neutral.png"))
    # Stand-in sprite.
    painted = reduce(fig, cell, feet_pad=8, height_px=height)
    painted = hard_alpha(painted, 110)
    if desat < 1.0:
        painted = desaturate(painted, desat)
    painted.save(os.path.join(out_dir, f"{cid}_painted.png"))
    print(f"  {cid}: portrait + painted {cell}px")


if __name__ == "__main__":
    only = sys.argv[1:] or list(SOURCES.keys())
    for cid in only:
        process(cid, *SOURCES[cid])
