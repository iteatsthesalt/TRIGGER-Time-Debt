#!/usr/bin/env python3
"""Generate the shared ground and paper textures (Reference Bible §2.3, §2.5):
cold-press watercolour paper, washi, clay dust, bristol, vellum, newsprint, acetate, kozo;
mossy stone albedo/normal/moss mask; gravel; wood planks; a galaxy cubemap strip; a gold-leaf mask.
Deterministic. Output: assets/textures/."""
import os, sys
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from pixel import value_noise, to_img, normal_from_height

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")
os.makedirs(OUT, exist_ok=True)
S = 1024


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def paper(seed, base, fibre_amount, grain_scale, tint_var=0.04, size=S):
    g = value_noise(size, grain_scale, seed, octaves=5, persistence=0.55)
    fine = value_noise(size, grain_scale * 8, seed + 1, octaves=2, persistence=0.5)
    rng = np.random.default_rng(seed + 7)
    fibres = np.zeros((size, size))
    for _ in range(int(fibre_amount * 1200)):
        x, y = rng.integers(0, size, 2)
        length = rng.integers(8, 40)
        ang = rng.random() * np.pi
        for t in range(length):
            px = int(x + np.cos(ang) * t) % size
            py = int(y + np.sin(ang) * t) % size
            fibres[py, px] = 1.0
    fibres = np.array(Image.fromarray((fibres * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))) / 255.0
    lum = 1.0 - 0.10 * (g - 0.5) - 0.06 * (fine - 0.5) - 0.12 * fibres
    img = np.zeros((size, size, 3))
    for c in range(3):
        img[..., c] = np.clip(base[c] / 255.0 * lum * (1 + (g - 0.5) * tint_var * (c - 1)), 0, 1)
    return to_img(img)


# Papers (one per canvas), 1024, tileable.
save(paper(1, (246, 240, 226), 1.0, 6), "paper_coldpress_u0.png")
save(paper(2, (242, 238, 216), 2.0, 4), "paper_washi_u1.png")
save(paper(3, (208, 190, 168), 0.4, 10), "paper_claydust_u2.png")
save(paper(4, (250, 246, 238), 0.1, 3, tint_var=0.0), "paper_bristol_u3.png")
save(paper(5, (226, 228, 232), 0.3, 5), "paper_vellum_u4.png")
save(paper(6, (216, 201, 155), 1.5, 7), "paper_newsprint_u5.png")
save(paper(7, (200, 205, 220), 0.05, 2, tint_var=0.0), "paper_acetate_u6.png")
save(paper(8, (252, 250, 244), 2.5, 5), "paper_kozo_u7.png")
save(paper(9, (255, 255, 255), 0.2, 4, tint_var=0.0), "paper_porcelain_u8.png")

# Mossy stone (albedo, normal, moss mask) at 64 px/m: 1024 px = 16 m.
stone_h = value_noise(S, 8, 11, octaves=6, persistence=0.6)
cracks = value_noise(S, 24, 12, octaves=3, persistence=0.7)
crack_lines = np.clip(1.0 - np.abs(cracks - 0.5) * 14.0, 0, 1)
# flagstone cells: a jittered grid of darker seams
cell = 128
yy, xx = np.mgrid[0:S, 0:S]
jit = value_noise(S, 4, 13, octaves=2) * 10
seam_x = np.abs(((xx + jit) % cell) - cell / 2) > cell / 2 - 3
seam_y = np.abs(((yy + jit * 0.7) % cell) - cell / 2) > cell / 2 - 3
seams = (seam_x | seam_y).astype(float)
seams = np.array(Image.fromarray((seams * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))) / 255.0
height = np.clip(stone_h * 0.8 + 0.2 - seams * 0.35 - crack_lines * 0.15, 0, 1)
slate = np.array([105, 108, 111]) / 255.0  # slate #696C6F
cool = np.array([86, 86, 84]) / 255.0      # gravel #565654
alb = np.zeros((S, S, 3))
tone = 0.75 + 0.5 * (height - 0.5)
var = value_noise(S, 3, 14, octaves=2)
for c in range(3):
    alb[..., c] = (slate[c] * (1 - var) + cool[c] * var) * tone
alb -= seams[..., None] * 0.25
alb -= crack_lines[..., None] * 0.12
save(to_img(np.clip(alb, 0, 1)), "stone_albedo.png")
save(normal_from_height(to_img(height), 3.0), "stone_normal.png")
moss = value_noise(S, 5, 15, octaves=5, persistence=0.6)
moss_mask = np.clip((moss - 0.45) * 3.0 + seams * 0.6 - height * 0.3, 0, 1)
save(to_img(moss_mask), "stone_moss_mask.png")
moss_col = np.array([115, 129, 75]) / 255.0  # moss #73814B
alb_m = alb * (1 - moss_mask[..., None] * 0.85) + moss_col * (moss_mask[..., None] * 0.85) * (0.8 + 0.4 * moss[..., None])
save(to_img(np.clip(alb_m, 0, 1)), "stone_mossy_albedo.png")

# Gravel-worn geo (for paths)
grav = value_noise(S, 40, 21, octaves=4, persistence=0.65)
gh = np.clip(grav, 0, 1)
ga = np.zeros((S, S, 3))
for c in range(3):
    ga[..., c] = (0.42 + 0.3 * gh) * (np.array([176, 134, 82])[c] / 255.0 * 0.55 + cool[c] * 0.45)
save(to_img(np.clip(ga, 0, 1)), "gravel_albedo.png")
save(normal_from_height(to_img(gh), 2.0), "gravel_normal.png")

# Wood planks (for tables, beams), 1024 = 16 m: plank width 0.25 m = 16 px? Use 64 px planks (1 m).
wood = value_noise(S, 2, 31, octaves=5, persistence=0.7)
rings = (np.sin(xx / 7.0 + wood * 6.0) * 0.5 + 0.5)
plank_seam = (np.abs(((yy) % 64) - 32) > 30).astype(float)
wh = np.clip(0.55 + 0.25 * rings - plank_seam * 0.5 + (wood - 0.5) * 0.3, 0, 1)
wa = np.zeros((S, S, 3))
base = np.array([139, 90, 43]) / 255.0  # kiln brown
for c in range(3):
    wa[..., c] = base[c] * (0.6 + 0.6 * wh)
save(to_img(np.clip(wa, 0, 1)), "wood_albedo.png")
save(normal_from_height(to_img(wh), 1.5), "wood_normal.png")

# Plaster / castle wall (kept unnaturally clean)
plas = value_noise(S, 6, 41, octaves=5, persistence=0.5)
blocks_x = np.abs(((xx + (yy // 96 % 2) * 96) % 192) - 96) > 92
blocks_y = np.abs((yy % 96) - 48) > 45
bl = (blocks_x | blocks_y).astype(float)
bl = np.array(Image.fromarray((bl * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))) / 255.0
ph = np.clip(0.6 + 0.3 * plas - bl * 0.5, 0, 1)
pa = np.zeros((S, S, 3))
bone = np.array([211, 195, 173]) / 255.0  # bone cloth #D3C3AD
for c in range(3):
    pa[..., c] = (bone[c] * 0.8 + slate[c] * 0.2) * (0.65 + 0.4 * ph)
save(to_img(np.clip(pa, 0, 1)), "castle_wall_albedo.png")
save(normal_from_height(to_img(ph), 2.5), "castle_wall_normal.png")

# Galaxy interior cubemap strip (6 faces 256x256 in a row): starfield + Lavos fibre threads.
F = 256
faces = []
rng = np.random.default_rng(99)
for f in range(6):
    neb = value_noise(F, 2, 100 + f, octaves=5, persistence=0.6)
    img = np.zeros((F, F, 3))
    deep = np.array([8, 12, 40]) / 255.0
    violet = np.array([70, 40, 120]) / 255.0
    teal = np.array([30, 90, 120]) / 255.0
    for c in range(3):
        img[..., c] = deep[c] + violet[c] * (neb ** 2) * 1.2 + teal[c] * np.clip(neb - 0.55, 0, 1) * 1.5
    fibre = value_noise(F, 10, 200 + f, octaves=3, persistence=0.5)
    fl = np.clip(1.0 - np.abs(fibre - 0.5) * 30.0, 0, 1) * 0.35
    img[..., 0] += fl * 0.6
    img[..., 1] += fl * 0.12
    stars = rng.random((F, F)) > 0.996
    big = rng.random((F, F)) > 0.9993
    img[stars] = [0.9, 0.93, 1.0]
    img[big] = [1.0, 1.0, 0.95]
    faces.append(np.clip(img, 0, 1))
strip = np.concatenate(faces, axis=1)
save(to_img(strip), "galaxy_cubemap_6x1.png")
save(to_img(faces[0]), "galaxy_face.png")

# Gold-leaf mask (kirikane flakes) and a crack mask seed noise
gold = value_noise(S, 30, 55, octaves=2, persistence=0.4)
flakes = (gold > 0.62).astype(float)
save(to_img(flakes), "gold_leaf_mask.png")
cr = value_noise(S, 12, 66, octaves=4, persistence=0.65)
crack = np.clip(1.0 - np.abs(cr - 0.5) * 22.0, 0, 1)
save(to_img(crack), "crack_noise.png")
print("done")
