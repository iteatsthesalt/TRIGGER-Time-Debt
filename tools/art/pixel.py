#!/usr/bin/env python3
"""Shared helpers for every sprite route (Reference Bible §1.5)."""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


def hexes(*codes):
    return [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in codes]


def key_out(img, tol=60, bg=None):
    """Make the flat background transparent, flood-filled from the border inward."""
    a = np.array(img.convert("RGBA"))
    if bg is None:
        # Most common border colour.
        border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
        vals, counts = np.unique(border, axis=0, return_counts=True)
        bg = vals[counts.argmax()].astype(int)
    else:
        bg = np.array(bg, dtype=int)
    near = np.abs(a[..., :3].astype(int) - bg).sum(-1) < tol
    lab, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    mask = np.isin(lab, edge[edge > 0])
    # Enclosed pockets of the key colour (between an arm and the body) are keyed too, with a tighter tolerance.
    dist0 = np.abs(a[..., :3].astype(int) - bg).sum(-1)
    if int(bg.max()) - int(bg.min()) > 100:  # only for saturated chroma keys, never for grey backdrops
        pockets = (dist0 < tol * 0.75) & ~mask
        mask = mask | pockets
    a[mask, 3] = 0
    # Soften fringe: pixels adjacent to the removed background that are still close to it.
    fringe = ndimage.binary_dilation(mask, iterations=2) & ~mask
    dist = np.abs(a[..., :3].astype(int) - bg).sum(-1)
    soft = fringe & (dist < tol * 2)
    a[soft, 3] = np.clip((dist[soft] - tol) / tol * 255, 0, 255).astype(np.uint8)
    return Image.fromarray(a)


def despill(img, bg_rgb, strength=0.8):
    """Pull the background colour out of edge pixels (magenta/green spill)."""
    a = np.array(img.convert("RGBA")).astype(float)
    bg = np.array(bg_rgb, dtype=float)
    alpha = a[..., 3:4] / 255.0
    edge = (alpha > 0) & (alpha < 1)
    rgb = a[..., :3]
    fixed = (rgb - bg * (1 - alpha)) / np.maximum(alpha, 1e-3)
    rgb = np.where(edge, rgb * (1 - strength) + np.clip(fixed, 0, 255) * strength, rgb)
    # Opaque pixels that lean toward the key hue (a pink fringe on a magenta key): pull the dominant
    # key channel down toward the other two.
    solid = alpha[..., 0] >= 1.0
    dom = int(np.argmax(bg))
    others = [c for c in range(3) if c != dom]
    lean = rgb[..., dom] - np.maximum(rgb[..., others[0]], rgb[..., others[1]])
    key_like = solid & (lean > 60) & (np.minimum(rgb[..., others[0]], rgb[..., others[1]]) > 40)
    near_edge = ndimage.binary_dilation(~solid, iterations=3)
    fix = key_like & near_edge
    rgb[fix, dom] = np.maximum(rgb[fix, others[0]], rgb[fix, others[1]]) + 20
    a[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


def reduce(img, cell, feet_pad=8, height_px=None):
    """Box-filter down so the figure is height_px tall (default cell-8), centred, feet 8 px up."""
    img = img.crop(img.getbbox())
    target_h = height_px if height_px else cell - feet_pad
    s = target_h / img.height
    if img.width * s > cell:
        s = cell / img.width
    img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.BOX)
    out = Image.new("RGBA", (cell, cell))
    out.paste(img, ((cell - img.width) // 2, cell - feet_pad - img.height), img)
    return out


def to_palette(img, palette, dither=False):
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    flat = [v for rgb in palette for v in rgb]
    pal = Image.new("P", (1, 1))
    pal.putpalette(flat + flat[:3] * (256 - len(palette)))
    mode = Image.Dither.FLOYDSTEINBERG if dither else Image.Dither.NONE
    out = rgba.convert("RGB").quantize(palette=pal, dither=mode).convert("RGBA")
    out.putalpha(alpha)
    return out


def hard_alpha(img, threshold=128):
    rgba = img.convert("RGBA")
    rgba.putalpha(rgba.getchannel("A").point(lambda v: 255 if v >= threshold else 0))
    return rgba


def outline(img, rgb, px=1):
    a = np.array(img.convert("RGBA"))
    solid = a[..., 3] > 0
    ring = ndimage.binary_dilation(solid, iterations=px) & ~solid
    a[ring] = (*rgb, 255)
    return Image.fromarray(a)


def inner_line(img, rgb, px=1, strength=0.7):
    """Darken the inside edge of the silhouette (a soft ink line for watercolour sprites)."""
    a = np.array(img.convert("RGBA")).astype(float)
    solid = a[..., 3] > 0
    inner = solid & ~ndimage.binary_erosion(solid, iterations=px)
    a[inner, :3] = a[inner, :3] * (1 - strength) + np.array(rgb) * strength
    return Image.fromarray(a.astype(np.uint8))


def desaturate(img, amount):
    a = np.array(img.convert("RGBA")).astype(float)
    lum = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    for c in range(3):
        a[..., c] = a[..., c] * amount + lum * (1 - amount)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def pack(rows, cell):
    sheet = Image.new("RGBA", (max(map(len, rows)) * cell, len(rows) * cell))
    for y, row in enumerate(rows):
        for x, frame in enumerate(row):
            sheet.paste(frame, (x * cell, y * cell))
    return sheet


def normal_from_height(height, strength=2.0):
    h = np.asarray(height, float) / 255.0
    dx = ndimage.sobel(h, 1) * strength
    dy = ndimage.sobel(h, 0) * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def value_noise(size, scale, seed=0, octaves=4, persistence=0.5):
    """Tileable fractal value noise in [0,1], size×size."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        n = max(2, int(scale * (2 ** o)))
        grid = rng.random((n, n))
        # tile by wrapping, then bilinear upscale
        ys = np.linspace(0, n, size, endpoint=False)
        xs = np.linspace(0, n, size, endpoint=False)
        y0 = np.floor(ys).astype(int) % n
        x0 = np.floor(xs).astype(int) % n
        fy = (ys - np.floor(ys))[:, None]
        fx = (xs - np.floor(xs))[None, :]
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        a = grid[y0][:, x0]
        b = grid[y0][:, (x0 + 1) % n]
        c = grid[(y0 + 1) % n][:, x0]
        d = grid[(y0 + 1) % n][:, (x0 + 1) % n]
        layer = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
        out += layer * amp
        total += amp
        amp *= persistence
    return out / total


def to_img(arr):
    return Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8))
