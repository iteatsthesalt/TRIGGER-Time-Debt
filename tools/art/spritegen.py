#!/usr/bin/env python3
"""Paper-doll pixel sprite generator (Reference Bible §1.5 Route A, §1.4 CHR-F/CHR-B).

A character is a rig of simple shapes (capsules, ellipses, polygons) with joints. Each frame poses the
joints, the rig is painted at 4× the cell size with a two-tone cel shade from an upper-left light, then
box-reduced to the cell, palette-snapped, inner-lined and packed into a sheet whose rows are directions
S, W, E, N and whose columns follow SpriteLibrary.DEFAULT_TABLE. Deterministic.

Usage: python3 tools/art/spritegen.py crono [sera marle ...]   (ids from tools/art/characters.py)
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from pixel import hexes, to_palette, inner_line, pack, desaturate, value_noise  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SS = 4  # supersample factor
DIRS = ["s", "w", "e", "n"]

# Column layout shared with scripts/actors/sprite_library.gd DEFAULT_TABLE.
ANIMS = [
    ("idle", 4), ("walk", 6), ("run", 6), ("interact", 3), ("emote", 4), ("ready", 4), ("attack", 6),
    ("charge", 4), ("release", 6), ("hurt", 3), ("ko", 6), ("revive", 5), ("victory", 6), ("break", 1), ("death", 6),
]
TOTAL_COLS = sum(n for _, n in ANIMS)


def col_of(name):
    c = 0
    for n, k in ANIMS:
        if n == name:
            return c
        c += k
    raise KeyError(name)


# ----------------------------------------------------------------------------- painting helpers

class Canvas:
    """RGBA float canvas at supersampled resolution with a two-tone cel shader."""

    def __init__(self, size):
        self.size = size
        self.rgb = np.zeros((size, size, 3), dtype=np.float32)
        self.a = np.zeros((size, size), dtype=np.float32)

    def _mask_from_pil(self, draw_fn):
        m = Image.new("L", (self.size, self.size), 0)
        d = ImageDraw.Draw(m)
        draw_fn(d)
        return np.asarray(m, dtype=np.float32) / 255.0

    def paint(self, mask, color, shade=None, light=None, shade_px=None, light_px=None, shade_dir=(1, 1)):
        """Composite a shape mask in `color`, with a dark band along the lower-right edge and a
        light band along the upper-left (cel shading from an upper-left key light)."""
        ys, xs = np.nonzero(mask > 0.001)
        if len(ys) == 0:
            return
        pad = 3 * SS
        y0, y1 = max(0, ys.min() - pad), min(self.size, ys.max() + pad + 1)
        x0, x1 = max(0, xs.min() - pad), min(self.size, xs.max() + pad + 1)
        m = mask[y0:y1, x0:x1]
        if shade_px is None:
            shade_px = 2 * SS
        if light_px is None:
            light_px = SS
        col = np.array(color, dtype=np.float32) / 255.0
        layer = np.empty((y1 - y0, x1 - x0, 3), dtype=np.float32)
        layer[...] = col
        if shade is not None:
            sh = np.array(shade, dtype=np.float32) / 255.0
            shifted = np.roll(np.roll(m, -shade_px * shade_dir[1], axis=0), -shade_px * shade_dir[0], axis=1)
            band = np.clip(m - shifted, 0, 1)
            layer = layer * (1 - band[..., None]) + sh * band[..., None]
        if light is not None:
            li = np.array(light, dtype=np.float32) / 255.0
            shifted = np.roll(np.roll(m, light_px * shade_dir[1], axis=0), light_px * shade_dir[0], axis=1)
            band = np.clip(m - shifted, 0, 1)
            layer = layer * (1 - band[..., None]) + li * band[..., None]
        sub = self.rgb[y0:y1, x0:x1]
        self.rgb[y0:y1, x0:x1] = sub * (1 - m[..., None]) + layer * m[..., None]
        a = self.a[y0:y1, x0:x1]
        self.a[y0:y1, x0:x1] = np.clip(a + m * (1 - a), 0, 1)

    def capsule(self, p0, p1, w, color, shade=None, light=None, **kw):
        # narrow shapes get a proportionally narrow shade band so blades and straps keep their colour
        if "shade_px" not in kw:
            kw["shade_px"] = int(max(SS * 0.5, min(2 * SS, w * 0.28)))
        if "light_px" not in kw:
            kw["light_px"] = int(max(1, min(SS, w * 0.12)))

        def fn(d):
            x0, y0 = p0
            x1, y1 = p1
            r = w / 2
            d.line([(x0, y0), (x1, y1)], fill=255, width=int(max(1, w)))
            d.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=255)
            d.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=255)
        self.paint(self._mask_from_pil(fn), color, shade, light, **kw)

    def ellipse(self, cx, cy, rx, ry, color, shade=None, light=None, **kw):
        self.paint(self._mask_from_pil(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)), color, shade, light, **kw)

    def polygon(self, pts, color, shade=None, light=None, **kw):
        self.paint(self._mask_from_pil(lambda d: d.polygon(pts, fill=255)), color, shade, light, **kw)

    def rect(self, x0, y0, x1, y1, color, shade=None, light=None, radius=0, **kw):
        def fn(d):
            if radius > 0:
                d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=255)
            else:
                d.rectangle([x0, y0, x1, y1], fill=255)
        self.paint(self._mask_from_pil(fn), color, shade, light, **kw)

    def line(self, pts, color, w):
        self.paint(self._mask_from_pil(lambda d: d.line(pts, fill=255, width=int(max(1, w)))), color)

    def to_image(self):
        rgb = np.clip(self.rgb * 255, 0, 255).astype(np.uint8)
        a = np.clip(self.a * 255, 0, 255).astype(np.uint8)
        return Image.fromarray(np.dstack([rgb, a]), "RGBA")


def lerp(a, b, t):
    return a + (b - a) * t


def rot(p, ang):
    c, s = math.cos(ang), math.sin(ang)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)


# ----------------------------------------------------------------------------- the rig

class Pose:
    """Joint angles in radians (0 = hanging straight down for limbs) and offsets in cell pixels."""

    def __init__(self, **kw):
        self.bob = 0.0            # vertical offset of the whole body (px, +down)
        self.lean = 0.0           # torso lean (rad, +forward for side views)
        self.head_tilt = 0.0
        self.sh_l = 0.0           # shoulder swing (rad; + = forward/toward +x in side view)
        self.sh_r = 0.0
        self.el_l = 0.0           # elbow bend (rad)
        self.el_r = 0.0
        self.hip_l = 0.0
        self.hip_r = 0.0
        self.kn_l = 0.0
        self.kn_r = 0.0
        self.crouch = 0.0         # 0..1 lowers the body
        self.arm_raise = 0.0      # 0..1 lifts both arms sideways (front views)
        self.weapon_out = 0.0     # 0..1 draws the weapon
        self.scale_y = 1.0
        self.fallen = 0.0         # 0..1 lying down
        self.eyes_closed = False
        self.weapon_swing = 0.0   # rad, extra swing of the weapon
        for k, v in kw.items():
            setattr(self, k, v)

    def copy(self, **kw):
        p = Pose(**self.__dict__)
        for k, v in kw.items():
            setattr(p, k, v)
        return p


def blend(a, b, t):
    p = Pose()
    for k in a.__dict__:
        va, vb = getattr(a, k), getattr(b, k)
        if isinstance(va, bool):
            setattr(p, k, vb if t > 0.5 else va)
        else:
            setattr(p, k, lerp(va, vb, t))
    return p


class Character:
    """Proportions, palette and styling. Sizes are in cell pixels (before supersampling)."""

    def __init__(self, spec):
        self.spec = spec
        self.height = spec.get("height", 114)
        self.palette = spec["palette"]
        self.hair_style = spec.get("hair", "spiky")
        self.build = spec.get("build", 1.0)          # width multiplier
        self.feet_pad = 8
        self.accessories = spec.get("accessories", [])
        self.weapon = spec.get("weapon", None)
        self.hover = spec.get("hover", 0)
        self.female = spec.get("female", False)
        self.age = spec.get("age", "adult")

    def c(self, key, default=(200, 0, 200)):
        v = self.palette.get(key, default)
        return v if isinstance(v, tuple) else hexes(v)[0]


# Proportions as fractions of height: a chunky HD-2D figure about 4 heads tall (plate-06).
def proportions(ch):
    H = ch.height
    child = ch.age == "child"
    head_r = H * (0.15 if child else 0.13)
    return dict(H=H, head_r=head_r, neck_y=H * 0.30, shoulder_y=H * 0.34, hip_y=H * 0.63, knee_y=H * 0.80, ankle_y=H * 0.95,
                shoulder_w=H * 0.34 * ch.build, hip_w=H * 0.24 * ch.build, upper_arm=H * 0.15, fore_arm=H * 0.14,
                thigh=H * 0.17, shin=H * 0.15, limb_w=H * 0.085 * ch.build, leg_w=H * 0.105 * ch.build)


def dark(c, f):
    return tuple(int(v * f) for v in c)


def light_of(c, f=1.12):
    return tuple(min(255, int(v * f)) for v in c)


def draw_character(ch, pose, direction, cell):
    """Paint one frame at SS× and return the supersampled RGBA image (cell*SS square).

    Views: 's' faces the camera, 'n' faces away, 'e' faces screen-right. 'w' is drawn facing right with the
    near and far sides swapped (so an asymmetric character keeps his gauntlet on his right arm) and mirrored
    at the end."""
    size = cell * SS
    cv = Canvas(size)
    P = proportions(ch)
    cx = size / 2
    ground = (cell - ch.feet_pad - ch.hover) * SS
    s = SS
    H = P["H"] * s
    bob = pose.bob * s + pose.crouch * H * 0.06
    top = ground - H * pose.scale_y + bob

    def Y(frac):  # body y at a height fraction (0 = top of head, 1 = ankles)
        return top + frac * H * pose.scale_y

    skin, skin_sh = ch.c("skin"), ch.c("skin_shadow", dark(ch.c("skin"), 0.72))
    hair, hair_sh = ch.c("hair"), ch.c("hair_shadow", dark(ch.c("hair"), 0.65))
    top_c, top_sh = ch.c("top"), ch.c("top_shadow", dark(ch.c("top"), 0.65))
    bot_c, bot_sh = ch.c("bottom"), ch.c("bottom_shadow", dark(ch.c("bottom"), 0.65))
    boot, boot_sh = ch.c("boots"), ch.c("boots_shadow", dark(ch.c("boots"), 0.6))
    accent = ch.c("accent", top_c)
    scarf = ch.c("scarf", accent)
    metal, metal_sh = ch.c("metal", (190, 170, 110)), ch.c("metal_shadow", (120, 100, 55))
    belt_c = ch.c("belt", (90, 60, 35))
    cape_c, cape_sh = ch.c("cape", (60, 60, 70)), ch.c("cape_shadow", (35, 35, 45))
    pauld, pauld_sh = ch.c("pauldron", (110, 112, 105)), ch.c("pauldron_shadow", (70, 72, 66))

    side = direction in ("w", "e")
    back = direction == "n"
    flip = direction == "w"
    near_is_right = direction != "w"   # which body side faces the camera in side views
    lw, legw = P["limb_w"] * s, P["leg_w"] * s
    shoulder_y, hip_y = Y(0.34), Y(0.63)
    half_sh = P["shoulder_w"] * s * 0.5
    half_hip = P["hip_w"] * s * 0.5
    one_armed = ch.spec.get("one_armed", False)

    if pose.fallen > 0.5:
        _draw_fallen(cv, ch, P, s, cx, ground, direction, skin, hair, top_c, top_sh, bot_c, boot)
        img = cv.to_image()
        return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img

    lean = pose.lean if side else 0.0
    torso_h = hip_y - shoulder_y
    dx = math.sin(lean) * torso_h

    # ---- limbs -------------------------------------------------------------------------------------
    def leg(hx, hip_ang, knee_ang, near):
        thigh, shin = P["thigh"] * s * pose.scale_y, P["shin"] * s * pose.scale_y
        if side:
            kx = hx + math.sin(hip_ang) * thigh
            ky = hip_y + math.cos(hip_ang) * thigh
            ax = kx + math.sin(hip_ang + knee_ang) * shin
            ay = ky + math.cos(hip_ang + knee_ang) * shin
        else:
            kx = hx + math.sin(hip_ang) * thigh * 0.2
            ky = hip_y + math.cos(hip_ang * 0.6) * thigh
            ax = kx
            ay = ky + math.cos((hip_ang + knee_ang) * 0.6) * shin
        f = 1.0 if near else 0.82
        col, sh = dark(bot_c, f), dark(bot_sh, f)
        cv.capsule((hx, hip_y), (kx, ky), legw, col, sh)
        cv.capsule((kx, ky), (ax, ay), legw * 0.92, col, sh)
        bcol, bsh = dark(boot, f), dark(boot_sh, f)
        if side:
            cv.capsule((ax - legw * 0.1, ay + legw * 0.1), (ax + legw * 0.8, ay + legw * 0.25), legw * 1.1, bcol, bsh)
        else:
            cv.capsule((ax, ay), (ax, ay + legw * 0.45), legw * 1.2, bcol, bsh)
        return ax, ay

    def arm(sx, sh_ang, el_ang, near, gauntlet, sleeve_col=None):
        ua, fa = P["upper_arm"] * s, P["fore_arm"] * s
        raise_ = pose.arm_raise
        if side:
            ex = sx + math.sin(sh_ang) * ua
            ey = shoulder_y + math.cos(sh_ang) * ua
            hx = ex + math.sin(sh_ang + el_ang) * fa
            hy = ey + math.cos(sh_ang + el_ang) * fa
        else:
            out = (1 if sx > cx else -1)
            ang = 0.12 + raise_ * 1.3 + abs(sh_ang) * 0.35
            ex = sx + out * math.sin(ang) * ua
            ey = shoulder_y + math.cos(ang) * ua
            fang = ang + el_ang * out * 0.8
            hx = ex + out * math.sin(fang) * fa
            hy = ey + math.cos(fang) * fa - abs(el_ang) * fa * 0.3
        f = 1.0 if near else 0.8
        sl = sleeve_col or top_c
        cv.capsule((sx, shoulder_y), (ex, ey), lw, dark(sl, f), dark(top_sh, f))
        if gauntlet:
            cv.capsule((ex, ey), (hx, hy), lw * 1.25, dark(metal, f), dark(metal_sh, f))
            cv.ellipse(hx, hy, lw * 0.75, lw * 0.75, dark(metal, f), dark(metal_sh, f))
            cv.rect(ex - lw * 0.7, ey - lw * 0.3, ex + lw * 0.7, ey + lw * 0.3, dark(metal_sh, f), None, radius=int(lw * 0.3))
        else:
            cv.capsule((ex, ey), (hx, hy), lw * 0.9, dark(skin, f), dark(skin_sh, f))
            cv.ellipse(hx, hy, lw * 0.6, lw * 0.6, dark(skin, f), dark(skin_sh, f))
        return hx, hy

    def scabbard(near):
        # a sheathed katana at the left hip when the weapon is not drawn
        kind = ch.weapon.get("kind") if ch.weapon else None
        if kind not in ("katana", "nodachi") or pose.weapon_out > 0.05:
            return
        L = ch.weapon.get("length", 44) * s * 0.9
        col = (46, 36, 32) if kind == "katana" else (30, 28, 26)
        if side:
            x0 = cx + dx * 0.4 - half_hip * 0.1
            y0 = Y(0.60)
            # tilts back and down behind the hips
            cv.capsule((x0, y0), (x0 - L * 0.95, y0 + L * 0.30), s * 3.0, col, dark(col, 0.6))
            cv.capsule((x0 + s * 2, y0 - s), (x0 + s * 5, y0 - s * 2), s * 3.2, (60, 45, 35))
        elif not back:
            x0 = cx - half_hip * 1.05
            cv.capsule((x0, Y(0.58)), (x0 - L * 0.22, Y(0.58) + L * 0.9), s * 3.0, col, dark(col, 0.6))
        else:
            x0 = cx + half_hip * 1.05
            cv.capsule((x0, Y(0.58)), (x0 + L * 0.22, Y(0.58) + L * 0.9), s * 3.0, col, dark(col, 0.6))

    def pauldron(px, py, big):
        r = lw * (1.35 if big else 1.1)
        cv.ellipse(px, py, r, r * 0.8, pauld, pauld_sh, light_of(pauld, 1.15))
        cv.ellipse(px - r * 0.25, py - r * 0.35, r * 0.45, r * 0.3, ch.c("moss", (115, 129, 75)))
        cv.ellipse(px + r * 0.35, py + r * 0.1, r * 0.25, r * 0.2, ch.c("moss", (115, 129, 75)))

    # ---- layer order --------------------------------------------------------------------------------
    gauntlet_right = "gauntlet" in ch.accessories
    weapon_hand = None
    if side:
        # far side first: far arm (with the weapon if it is the right arm and we face west), far leg
        far_right = not near_is_right
        far_x = cx - half_sh * 0.15 + dx
        if not (one_armed and not far_right):
            fh = arm(far_x, pose.sh_l if near_is_right else pose.sh_r, pose.el_l if near_is_right else pose.el_r,
                     near=False, gauntlet=gauntlet_right and far_right)
            if far_right:
                weapon_hand = fh
                if ch.weapon and pose.weapon_out > 0.05:
                    _draw_weapon(cv, ch, fh, pose, direction, s, dark(metal, 0.85), metal_sh, accent, far=True)
        if "cape" in ch.accessories:
            cape = [(cx - half_sh * 0.7 + dx, shoulder_y), (cx + half_sh * 0.1 + dx, shoulder_y), (cx - half_hip * 0.4, Y(0.86)), (cx - half_hip * 1.6, Y(0.90))]
            cv.polygon(cape, cape_c, cape_sh)
        scabbard(False)
        leg(cx - half_hip * 0.3, pose.hip_l if near_is_right else pose.hip_r, pose.kn_l if near_is_right else pose.kn_r, near=False)
    else:
        if "cape" in ch.accessories:
            cape = [(cx - half_sh * 1.05, shoulder_y + s), (cx + half_sh * 1.05, shoulder_y + s), (cx + half_hip * 1.45, Y(0.88)), (cx - half_hip * 1.45, Y(0.88))]
            cv.polygon(cape, cape_c if back else cape_sh, cape_sh)
        if back:
            scabbard(False)
        leg(cx - half_hip * 0.6, pose.hip_l, pose.kn_l, near=True)
        leg(cx + half_hip * 0.6, pose.hip_r, pose.kn_r, near=True)
        if not back:
            scabbard(False)

    # torso: a rounded trapezoid, broad at the shoulders
    w_top = half_sh * (0.78 if side else 1.0)
    w_bot = half_hip * 1.1
    torso = [(cx - w_top + dx, shoulder_y - lw * 0.3), (cx + w_top + dx, shoulder_y - lw * 0.3),
             (cx + w_bot, hip_y + legw * 0.35), (cx - w_bot, hip_y + legw * 0.35)]
    cv.polygon(torso, top_c, top_sh, light_of(top_c, 1.08))
    if ch.female and not back:
        cv.ellipse(cx + dx * 0.7, Y(0.44), w_top * 0.72, torso_h * 0.2, top_c, top_sh)
    # tunic hem / skirt line
    cv.rect(cx - w_bot, hip_y - lw * 0.1, cx + w_bot, hip_y + legw * 0.35, dark(top_c, 0.9), top_sh)
    belt_y = Y(0.60)
    cv.rect(cx - w_bot, belt_y - 2.2 * s, cx + w_bot, belt_y + 2.2 * s, belt_c, dark(belt_c, 0.65))
    if not back:
        cv.rect(cx + dx * 0.3 - 2.5 * s, belt_y - 2.5 * s, cx + dx * 0.3 + 2.5 * s, belt_y + 2.5 * s, metal, metal_sh)
    if "pouch" in ch.accessories and not back:
        px = cx + (w_bot * 0.45 if not side else -w_bot * 0.3)
        cv.rect(px, belt_y + s, px + w_bot * 0.55, belt_y + 8 * s, (120, 85, 50), (80, 55, 30), radius=2 * s)

    # pauldrons
    if "pauldron" in ch.accessories:
        if side:
            pauldron(cx + half_sh * 0.45 + dx, shoulder_y + s, True)
        else:
            pauldron(cx - half_sh * 1.0 + dx, shoulder_y + s * 1.5, True)
            pauldron(cx + half_sh * 1.0 + dx, shoulder_y + s * 1.5, True)

    # neck and scarf
    cv.capsule((cx + dx, Y(0.27)), (cx + dx, Y(0.34)), lw * 1.0, skin, skin_sh)
    if "scarf" in ch.accessories:
        cv.ellipse(cx + dx, Y(0.325), half_sh * (0.6 if side else 0.9), P["head_r"] * s * 0.5, scarf, dark(scarf, 0.7), light_of(scarf, 1.1))
        tail_dir = 1 if (not side) else (1 if near_is_right else -1)
        if not back:
            tail = [(cx + dx + half_sh * 0.3 * tail_dir, Y(0.36)), (cx + dx + half_sh * (0.95 if side else 0.8) * tail_dir, Y(0.50)),
                    (cx + dx + half_sh * (0.6 if side else 0.5) * tail_dir, Y(0.54)), (cx + dx + half_sh * 0.05 * tail_dir, Y(0.40))]
            cv.polygon(tail, scarf, dark(scarf, 0.7))
        else:
            tail = [(cx - half_sh * 0.3, Y(0.36)), (cx - half_sh * 0.85, Y(0.56)), (cx - half_sh * 0.5, Y(0.60)), (cx - half_sh * 0.05, Y(0.40))]
            cv.polygon(tail, scarf, dark(scarf, 0.7))

    # ---- head ---------------------------------------------------------------------------------------
    head_r = P["head_r"] * s
    head_cx = cx + dx * 1.2 + math.sin(pose.head_tilt) * head_r * 0.5 + (head_r * 0.08 if side else 0)
    head_cy = Y(0.15)
    face_w = head_r * (0.9 if side else 1.0)
    if back:
        cv.ellipse(head_cx, head_cy, face_w, head_r * 1.05, hair, hair_sh)
    else:
        cv.ellipse(head_cx, head_cy, face_w, head_r * 1.05, skin, skin_sh, light_of(skin, 1.1))
    _draw_hair(cv, ch, head_cx, head_cy, head_r, direction, hair, hair_sh, s)
    if not back:
        ey = head_cy + head_r * 0.18
        eye_dx = head_r * 0.42
        eye_col = ch.c("eyes", (30, 30, 40))
        ew, eh = s * 2.0, s * 2.8
        if pose.eyes_closed:
            xs = [head_cx + head_r * 0.35] if side else [head_cx - eye_dx, head_cx + eye_dx]
            for ex in xs:
                cv.line([(ex - s * 2, ey + s), (ex + s * 2, ey + s)], (40, 30, 30), s * 1.1)
        elif side:
            ex = head_cx + head_r * 0.42
            cv.ellipse(ex, ey, ew * 0.8, eh, (245, 245, 250))
            cv.ellipse(ex + s * 0.4, ey + s * 0.3, ew * 0.55, eh * 0.8, eye_col)
            cv.line([(ex - s * 2.2, ey - eh - s * 0.5), (ex + s * 1.8, ey - eh - s)], hair_sh, s * 1.0)
        else:
            for i, ex in enumerate([head_cx - eye_dx, head_cx + eye_dx]):
                cv.ellipse(ex, ey, ew, eh, (245, 245, 250))
                ecol = eye_col if not (ch.spec.get("heterochromia") and i == 1) else hexes(ch.spec["heterochromia"])[0]
                cv.ellipse(ex, ey + s * 0.4, ew * 0.62, eh * 0.78, ecol)
                cv.ellipse(ex - s * 0.5, ey - s * 0.6, s * 0.6, s * 0.7, (255, 255, 255))
                cv.line([(ex - s * 2.2, ey - eh - s * 0.5), (ex + s * 2.2, ey - eh - s)], hair_sh, s * 1.0)
            cv.line([(head_cx - s * 1.6, head_cy + head_r * 0.62), (head_cx + s * 1.6, head_cy + head_r * 0.62)], skin_sh, s * 0.9)
            if "stubble" in ch.accessories:
                cv.ellipse(head_cx, head_cy + head_r * 0.68, head_r * 0.55, head_r * 0.3, dark(skin, 0.88))
        if "stubble" in ch.accessories and side:
            cv.ellipse(head_cx + head_r * 0.2, head_cy + head_r * 0.68, head_r * 0.5, head_r * 0.3, dark(skin, 0.88))
    if "headband" in ch.accessories:
        hb = ch.c("headband", (240, 236, 220))
        cv.rect(head_cx - face_w * 1.02, head_cy - head_r * 0.42, head_cx + face_w * 1.02, head_cy - head_r * 0.16, hb, dark(hb, 0.78))
        # trailing tails behind the head (left side when facing the camera)
        if not side:
            tx = head_cx - face_w if not back else head_cx + face_w
            sgn = -1 if not back else 1
            cv.polygon([(tx, head_cy - head_r * 0.35), (tx + sgn * head_r * 1.1, head_cy + head_r * 0.9), (tx + sgn * head_r * 0.65, head_cy + head_r * 1.0)], hb, dark(hb, 0.78))
        else:
            tx = head_cx - face_w * 0.9
            cv.polygon([(tx, head_cy - head_r * 0.35), (tx - head_r * 0.9, head_cy + head_r * 0.9), (tx - head_r * 0.45, head_cy + head_r * 1.0)], hb, dark(hb, 0.78))

    # ---- near arm(s) and the drawn weapon ------------------------------------------------------------
    if side:
        near_x = cx + half_sh * 0.3 + dx
        nr = near_is_right
        if not (one_armed and not nr):
            nh = arm(near_x, pose.sh_r if nr else pose.sh_l, pose.el_r if nr else pose.el_l, near=True, gauntlet=gauntlet_right and nr)
            if nr:
                weapon_hand = nh
                if ch.weapon and pose.weapon_out > 0.05:
                    _draw_weapon(cv, ch, nh, pose, direction, s, metal, metal_sh, accent)
        elif one_armed and not nr:
            # the empty sleeve hangs
            cv.capsule((near_x, shoulder_y), (near_x + s, shoulder_y + P["upper_arm"] * s * 0.7), lw * 0.8, top_sh, dark(top_sh, 0.8))
    else:
        # screen-left arm is the character's right when facing the camera, left when facing away
        left_is_right = not back
        lx, rx = cx - half_sh * 0.95 + dx, cx + half_sh * 0.95 + dx
        hl = hr = None
        if not (one_armed and not left_is_right):
            hl = arm(lx, pose.sh_r if left_is_right else pose.sh_l, pose.el_r if left_is_right else pose.el_l, near=True, gauntlet=gauntlet_right and left_is_right)
        else:
            cv.capsule((lx, shoulder_y), (lx - s, shoulder_y + P["upper_arm"] * s * 0.7), lw * 0.8, top_sh, dark(top_sh, 0.8))
        if not (one_armed and left_is_right):
            hr = arm(rx, pose.sh_l if left_is_right else pose.sh_r, pose.el_l if left_is_right else pose.el_r, near=True, gauntlet=gauntlet_right and not left_is_right)
        else:
            cv.capsule((rx, shoulder_y), (rx + s, shoulder_y + P["upper_arm"] * s * 0.7), lw * 0.8, top_sh, dark(top_sh, 0.8))
        weapon_hand = hl if left_is_right else hr
        if ch.weapon and pose.weapon_out > 0.05 and weapon_hand is not None:
            _draw_weapon(cv, ch, weapon_hand, pose, direction, s, metal, metal_sh, accent)

    # near leg for side view
    if side:
        leg(cx + half_hip * 0.3, pose.hip_r if near_is_right else pose.hip_l, pose.kn_r if near_is_right else pose.kn_l, near=True)

    img = cv.to_image()
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def _draw_hair(cv, ch, hx, hy, r, direction, hair, hair_sh, s):
    style = ch.hair_style
    back = direction == "n"
    side = direction in ("w", "e")
    hl = light_of(hair, 1.12)
    if style == "spiky":
        # a crown of long spikes swept back and up (Crono); the fringe hides the hairline
        n = 11
        pts = []
        for i in range(n + 1):
            a = math.pi + (i / n) * math.pi
            base = (hx + math.cos(a) * r * 1.0, hy + math.sin(a) * r * 1.0)
            if i % 2 == 0:
                length = r * (0.75 if i in (0, n) else 1.35)
                ang = a - 0.3 - (0.25 if side else 0.0)
                tip = (hx + math.cos(ang) * (r + length), hy + math.sin(ang) * (r + length) - r * 0.15)
                pts.append(tip)
            else:
                pts.append(base)
        pts.append((hx + r * 1.0, hy + r * 0.25))
        pts.append((hx - r * 1.0, hy + r * 0.25))
        cv.polygon(pts, hair, hair_sh, hl)
        cv.ellipse(hx, hy - r * 0.55, r * 1.05, r * 0.62, hair, hair_sh, hl)
        if not back:
            # fringe spikes pointing down over the brow
            for k, (ax, bx, cxx) in enumerate([(-1.0, -0.55, -0.15), (-0.35, 0.05, 0.4), (0.3, 0.6, 1.0)]):
                cv.polygon([(hx + r * ax, hy - r * 0.45), (hx + r * bx, hy + r * (0.05 if k == 1 else 0.22)), (hx + r * cxx, hy - r * 0.45)], hair, hair_sh)
        if side:
            cv.polygon([(hx - r * 1.0, hy - r * 0.3), (hx - r * 0.75, hy + r * 0.5), (hx - r * 0.35, hy - r * 0.2)], hair, hair_sh)
    elif style == "bob":
        cv.ellipse(hx, hy - r * 0.55, r * 1.15, r * 0.62, hair, hair_sh, hl)
        cv.rect(hx - r * 1.15, hy - r * 0.3, hx - r * 0.6, hy + r * 0.85, hair, hair_sh, radius=int(r * 0.3))
        cv.rect(hx + r * 0.6, hy - r * 0.3, hx + r * 1.15, hy + r * 0.85, hair, hair_sh, radius=int(r * 0.3))
        if back:
            cv.rect(hx - r * 1.1, hy - r * 0.3, hx + r * 1.1, hy + r * 0.9, hair, hair_sh, radius=int(r * 0.3))
        else:
            cv.polygon([(hx - r * 1.0, hy - r * 0.45), (hx + r * 0.15, hy - r * 1.0), (hx + r * 0.7, hy - r * 0.25), (hx + r * 0.1, hy + r * 0.1), (hx - r * 0.6, hy + r * 0.05)], hair, hair_sh, hl)
    elif style == "ponytail":
        cv.ellipse(hx, hy - r * 0.55, r * 1.12, r * 0.62, hair, hair_sh, hl)
        tail_x = hx - r * 0.95 if side else hx
        cv.capsule((tail_x, hy - r * 0.5), (tail_x - (r * 0.5 if side else 0), hy + r * 2.6), r * 0.6, hair, hair_sh)
        if not back:
            cv.polygon([(hx - r * 0.9, hy - r * 0.55), (hx + r * 0.1, hy - r * 1.05), (hx + r * 0.95, hy - r * 0.35), (hx + r * 0.35, hy + r * 0.05), (hx - r * 0.4, hy + r * 0.0)], hair, hair_sh, hl)
    elif style == "warknot":
        cv.ellipse(hx, hy - r * 0.55, r * 1.08, r * 0.62, hair, hair_sh, hl)
        cv.ellipse(hx, hy - r * 1.35, r * 0.55, r * 0.6, hair, hair_sh)
        for i in range(5):
            a = -math.pi / 2 + (i - 2) * 0.4
            cv.polygon([(hx + math.cos(a) * r * 0.3, hy - r * 1.3), (hx + math.cos(a) * r * 1.5, hy - r * 1.4 + math.sin(a) * r * 1.5), (hx + math.cos(a + 0.25) * r * 0.3, hy - r * 1.2)], hair, hair_sh)
        cv.rect(hx - r * 0.6, hy - r * 1.05, hx + r * 0.6, hy - r * 0.82, (240, 236, 220), (190, 186, 170))
        if not back:
            cv.polygon([(hx - r * 1.0, hy - r * 0.5), (hx - r * 0.3, hy + r * 0.2), (hx + r * 0.2, hy - r * 0.5)], hair, hair_sh)
            cv.polygon([(hx + r * 0.1, hy - r * 0.5), (hx + r * 0.6, hy + r * 0.15), (hx + r * 1.0, hy - r * 0.5)], hair, hair_sh)
    elif style == "long":
        cv.ellipse(hx, hy - r * 0.55, r * 1.15, r * 0.62, hair, hair_sh, hl)
        cv.rect(hx - r * 1.2, hy - r * 0.3, hx - r * 0.65, hy + r * 2.8, hair, hair_sh, radius=int(r * 0.3))
        cv.rect(hx + r * 0.65, hy - r * 0.3, hx + r * 1.2, hy + r * 2.8, hair, hair_sh, radius=int(r * 0.3))
        if back:
            cv.rect(hx - r * 1.1, hy - r * 0.3, hx + r * 1.1, hy + r * 3.0, hair, hair_sh, radius=int(r * 0.3))
        else:
            cv.polygon([(hx - r * 1.05, hy - r * 0.4), (hx - r * 0.2, hy - r * 1.0), (hx + r * 0.9, hy - r * 0.45), (hx + r * 0.5, hy + r * 0.1)], hair, hair_sh, hl)
    elif style == "short":
        cv.ellipse(hx, hy - r * 0.55, r * 1.1, r * 0.62, hair, hair_sh, hl)
        if not back:
            cv.polygon([(hx - r * 1.05, hy - r * 0.3), (hx - r * 0.3, hy - r * 0.95), (hx + r * 1.0, hy - r * 0.5), (hx + r * 0.7, hy - r * 0.1), (hx - r * 0.4, hy - r * 0.1)], hair, hair_sh)
    elif style == "curly":
        cv.ellipse(hx, hy - r * 0.55, r * 1.18, r * 0.62, hair, hair_sh, hl)
        for a in (-2.8, -2.2, -1.6, -1.0, -0.4):
            cv.ellipse(hx + math.cos(a) * r * 0.95, hy - r * 0.35 + math.sin(a) * r * 0.85, r * 0.4, r * 0.4, hair, hair_sh)
    elif style == "hood":
        cv.ellipse(hx, hy - r * 0.2, r * 1.3, r * 1.2, hair, hair_sh, hl)
        if not back:
            cv.ellipse(hx, hy + r * 0.15, r * 0.88, r * 0.9, ch.c("skin"), ch.c("skin_shadow", (120, 100, 80)))
    elif style == "bald":
        pass
    elif style == "none":
        # a ring of grey hair for elders
        if not back:
            cv.rect(hx - r * 1.05, hy - r * 0.2, hx - r * 0.75, hy + r * 0.5, hair, hair_sh, radius=int(r * 0.15))
            cv.rect(hx + r * 0.75, hy - r * 0.2, hx + r * 1.05, hy + r * 0.5, hair, hair_sh, radius=int(r * 0.15))
        else:
            cv.ellipse(hx, hy + r * 0.1, r * 1.05, r * 0.7, hair, hair_sh)


def _draw_weapon(cv, ch, hand, pose, direction, s, metal, metal_sh, accent, far=False):
    hx, hy = hand
    kind = ch.weapon.get("kind", "katana")
    length = ch.weapon.get("length", 46) * s
    swing = pose.weapon_swing
    side = direction in ("w", "e")
    f = 0.85 if far else 1.0
    if kind == "katana":
        base_ang = (-math.pi * 0.38 if side else -math.pi * 0.22) + swing
        if direction == "n":
            base_ang = -math.pi * 0.25 + swing
        tip = (hx + math.cos(base_ang) * length, hy + math.sin(base_ang) * length)
        # tsuka (grip) wired to the gauntlet, then the blade
        g0 = (hx - math.cos(base_ang) * s * 5, hy - math.sin(base_ang) * s * 5)
        cv.capsule(g0, (hx + math.cos(base_ang) * s * 3, hy + math.sin(base_ang) * s * 3), s * 3.4, dark((70, 50, 40), f), (40, 30, 20))
        cv.capsule((hx + math.cos(base_ang) * s * 3, hy + math.sin(base_ang) * s * 3), tip, s * 4.4, dark((226, 228, 236), f), dark((150, 155, 170), f))
        # rainbow sheen along the edge
        n = (-math.sin(base_ang), math.cos(base_ang))
        for i, col in enumerate([(255, 120, 120), (255, 220, 120), (140, 255, 170), (140, 180, 255)]):
            t0 = 0.3 + i * 0.16
            p0 = (hx + math.cos(base_ang) * length * t0 - n[0] * s, hy + math.sin(base_ang) * length * t0 - n[1] * s)
            p1 = (hx + math.cos(base_ang) * length * (t0 + 0.14) - n[0] * s, hy + math.sin(base_ang) * length * (t0 + 0.14) - n[1] * s)
            cv.line([p0, p1], dark(col, f), s * 0.9)
        # tsuba
        cv.ellipse(hx + math.cos(base_ang) * s * 3, hy + math.sin(base_ang) * s * 3, s * 2.4, s * 2.4, dark(metal, f), metal_sh)
    elif kind == "daggers":
        for sgn in (1, -1):
            ang = -math.pi * 0.5 + sgn * 0.45 + swing
            tip = (hx + math.cos(ang) * length, hy + math.sin(ang) * length)
            cv.capsule((hx, hy), tip, s * 3.2, (226, 228, 236), (150, 155, 170))
            # clock-hand head
            cv.polygon([tip, (tip[0] - math.cos(ang + 0.5) * s * 4, tip[1] - math.sin(ang + 0.5) * s * 4), (tip[0] - math.cos(ang - 0.5) * s * 4, tip[1] - math.sin(ang - 0.5) * s * 4)], (212, 175, 55), (140, 110, 30))
        cv.ellipse(hx, hy, s * 2.6, s * 2.6, (212, 175, 55), (140, 110, 30))
    elif kind == "nodachi":
        base_ang = (-math.pi * 0.45 if side else -math.pi * 0.25) + swing
        tip = (hx + math.cos(base_ang) * length, hy + math.sin(base_ang) * length)
        g0 = (hx - math.cos(base_ang) * s * 8, hy - math.sin(base_ang) * s * 8)
        cv.capsule(g0, (hx, hy), s * 3.6, (40, 30, 28), (20, 15, 14))
        cv.capsule((hx, hy), tip, s * 5.0, dark((232, 232, 236), f), dark((140, 140, 150), f))
        n = (-math.sin(base_ang), math.cos(base_ang))
        cv.line([(hx + math.cos(base_ang) * length * 0.15 + n[0] * s * 1.2, hy + math.sin(base_ang) * length * 0.15 + n[1] * s * 1.2), (tip[0] + n[0] * s, tip[1] + n[1] * s)], ch.c("accent", (20, 60, 162)), s * 1.4)
        cv.ellipse(hx, hy, s * 2.8, s * 2.8, (120, 40, 35), (70, 20, 18))
    elif kind == "crossbow":
        cv.rect(hx - s * 3, hy - s * 2.5, hx + s * 14, hy + s * 2.5, (120, 85, 50), (80, 55, 30), radius=s)
        cv.line([(hx + s * 9, hy - s * 9), (hx + s * 9, hy + s * 9)], metal, s * 2.0)
        cv.line([(hx + s * 9, hy - s * 9), (hx - s * 2, hy), (hx + s * 9, hy + s * 9)], (230, 230, 230), s * 0.8)
    elif kind == "cane":
        cv.capsule((hx, hy), (hx + s * 2, hy + length), s * 2.0, (90, 65, 40), (60, 45, 25))
        cv.ellipse(hx, hy - s, s * 3.5, s * 2.5, metal, metal_sh)
    elif kind == "staff":
        cv.capsule((hx, hy - length * 0.6), (hx + s * 2, hy + length * 0.5), s * 2.4, (90, 65, 40), (60, 45, 25))
        cv.ellipse(hx, hy - length * 0.62, s * 4, s * 4, accent, dark(accent, 0.6))


def _draw_fallen(cv, ch, P, s, cx, ground, direction, skin, hair, top_c, top_sh, bot_c, boot):
    """Lying on the ground (KO/death): the standing figure rotated onto its back."""
    standing = draw_character(ch, Pose(eyes_closed=True, weapon_out=0.0), "s" if direction != "n" else "n", cv.size // SS)
    # rotate so the head points screen-left and the figure lies along the ground
    rotated = standing.rotate(90, resample=Image.BICUBIC, expand=False)
    arr = np.asarray(rotated, dtype=np.float32) / 255.0
    a = arr[..., 3]
    ys, xs = np.nonzero(a > 0.05)
    if len(ys) == 0:
        return
    # drop the body so its lowest point sits a little above the ground line, and squash it slightly
    shift_y = int(ground - P["leg_w"] * s * 1.3 - ys.max())
    shift_x = int(cx - (xs.min() + xs.max()) / 2)
    moved = Image.fromarray((arr * 255).astype(np.uint8), "RGBA").transform(
        rotated.size, Image.AFFINE, (1, 0, -shift_x, 0, 1, -shift_y), resample=Image.NEAREST)
    m = np.asarray(moved, dtype=np.float32) / 255.0
    cv.rgb = cv.rgb * (1 - m[..., 3:4]) + m[..., :3] * m[..., 3:4]
    cv.a = np.clip(cv.a + m[..., 3] * (1 - cv.a), 0, 1)


# ----------------------------------------------------------------------------- animation

def make_poses(name, count, ch):
    """Return `count` poses for an animation."""
    poses = []
    idle = Pose()
    if name == "idle":
        for i in range(count):
            t = i / count
            br = math.sin(t * 2 * math.pi)
            poses.append(idle.copy(bob=0.6 * br, scale_y=1.0 + 0.006 * br, sh_l=0.04 * br, sh_r=-0.04 * br))
    elif name in ("walk", "run"):
        amp = 0.55 if name == "walk" else 0.85
        for i in range(count):
            t = i / count * 2 * math.pi
            swing = math.sin(t)
            lift = max(0.0, math.sin(t))
            lift2 = max(0.0, -math.sin(t))
            poses.append(Pose(bob=-abs(math.sin(t)) * (1.2 if name == "walk" else 2.0),
                              hip_l=amp * swing, hip_r=-amp * swing, kn_l=lift2 * 0.9 * amp, kn_r=lift * 0.9 * amp,
                              sh_l=-0.7 * amp * swing, sh_r=0.7 * amp * swing, el_l=0.3 * amp, el_r=0.3 * amp,
                              lean=0.08 if name == "run" else 0.03))
    elif name == "interact":
        a = idle.copy(sh_r=0.3, el_r=-0.6)
        b = idle.copy(sh_r=0.9, el_r=-1.2, arm_raise=0.3)
        poses = [a, b, a.copy(sh_r=0.5)]
    elif name == "emote":
        for i in range(count):
            poses.append(idle.copy(head_tilt=0.25 * math.sin(i / count * 2 * math.pi), bob=-1.0 if i == 1 else 0.0))
    elif name == "ready":
        base = idle.copy(crouch=0.25, lean=0.12, weapon_out=1.0, sh_r=0.5, el_r=-1.1, sh_l=-0.3, el_l=0.6, hip_l=-0.2, hip_r=0.25, kn_r=0.3)
        for i in range(count):
            br = math.sin(i / count * 2 * math.pi)
            poses.append(base.copy(bob=0.5 * br, weapon_swing=0.03 * br))
    elif name == "attack":
        ready = idle.copy(crouch=0.25, lean=0.12, weapon_out=1.0, sh_r=0.5, el_r=-1.1, sh_l=-0.3, el_l=0.6)
        wind = ready.copy(sh_r=-1.3, el_r=-0.4, lean=-0.1, weapon_swing=-1.2, crouch=0.35)
        strike = ready.copy(sh_r=1.4, el_r=-0.2, lean=0.3, weapon_swing=1.3, crouch=0.2, hip_r=0.5, kn_r=0.4, bob=-1.0)
        follow = strike.copy(sh_r=1.6, weapon_swing=1.6, lean=0.25)
        poses = [blend(ready, wind, 0.6), wind, blend(wind, strike, 0.45), strike, follow, blend(follow, ready, 0.5)]
    elif name == "charge":
        base = idle.copy(crouch=0.2, weapon_out=1.0, sh_r=0.2, el_r=-1.6, sh_l=0.2, el_l=-1.6, arm_raise=0.2)
        for i in range(count):
            br = math.sin(i / count * 2 * math.pi)
            poses.append(base.copy(bob=0.8 * br, arm_raise=0.2 + 0.08 * br))
    elif name == "release":
        base = idle.copy(crouch=0.2, weapon_out=1.0, sh_r=0.2, el_r=-1.6, sh_l=0.2, el_l=-1.6, arm_raise=0.2)
        up = base.copy(arm_raise=0.9, sh_r=-2.2, sh_l=-2.2, el_r=0.0, el_l=0.0, weapon_swing=-1.8, crouch=0.0, bob=-2.0)
        down = base.copy(arm_raise=0.1, sh_r=1.2, sh_l=1.2, el_r=-0.4, el_l=-0.4, weapon_swing=1.4, crouch=0.35, lean=0.3)
        poses = [blend(base, up, 0.5), up, blend(up, down, 0.3), down, down.copy(bob=1.0), blend(down, base, 0.5)]
    elif name == "hurt":
        a = idle.copy(lean=-0.25, head_tilt=-0.3, bob=1.0, sh_l=-0.6, sh_r=-0.6, el_l=-0.8, el_r=-0.8, eyes_closed=True)
        poses = [a, a.copy(bob=2.0, lean=-0.35), a.copy(bob=0.5, lean=-0.15)]
    elif name in ("ko", "death"):
        a = idle.copy(lean=-0.3, bob=1.0, eyes_closed=True)
        b = idle.copy(crouch=0.8, lean=-0.6, bob=3.0, eyes_closed=True, kn_l=1.0, kn_r=1.0)
        f = idle.copy(fallen=1.0, eyes_closed=True)
        poses = [a, blend(a, b, 0.6), b, blend(b, f, 0.4), f, f]
    elif name == "revive":
        f = idle.copy(fallen=1.0, eyes_closed=True)
        b = idle.copy(crouch=0.8, lean=0.3, bob=3.0, kn_l=1.0, kn_r=1.0)
        poses = [f, blend(f, b, 0.5), b, blend(b, idle, 0.5), idle]
    elif name == "victory":
        up = idle.copy(arm_raise=1.0, sh_r=-2.6, el_r=-0.3, weapon_out=1.0, weapon_swing=-1.5, bob=-1.5)
        for i in range(count):
            t = i / count
            poses.append(blend(idle, up, min(1.0, t * 2.5)).copy(bob=-2.0 * max(0.0, math.sin(t * math.pi))))
    elif name == "break":
        poses = [idle.copy(lean=-0.2, head_tilt=-0.4, bob=1.5, eyes_closed=True, sh_l=-0.4, sh_r=0.5, el_r=-0.9)]
    else:
        poses = [idle] * count
    while len(poses) < count:
        poses.append(poses[-1])
    return poses[:count]


# ----------------------------------------------------------------------------- finishing

def finish_frame(img_ss, cell, canvas, palette=None):
    """Reduce from SS× to the cell and apply the canvas's line and palette treatment."""
    img = img_ss.resize((cell, cell), Image.BOX)
    a = np.asarray(img.getchannel("A"))
    img.putalpha(Image.fromarray(np.where(a >= 92, 255, 0).astype(np.uint8)))
    if canvas == "u0":
        img = inner_line(img, (44, 44, 44), 1, 0.7)
        img = desaturate(img, 0.92)
    elif canvas == "u1":
        img = inner_line(img, (20, 20, 20), 1, 0.9)
        img = desaturate(img, 0.25)
        if palette:
            img = to_palette(img, palette)
    elif canvas == "u2":
        img = inner_line(img, (40, 30, 25), 1, 0.6)
    elif canvas == "u3":
        img = inner_line(img, (10, 10, 10), 2, 1.0)
    elif canvas == "u5":
        img = inner_line(img, (20, 18, 16), 2, 1.0)
        img = desaturate(img, 0.35)
    elif canvas == "u6":
        img = inner_line(img, (12, 12, 20), 1, 0.95)
    else:
        img = inner_line(img, (40, 40, 40), 1, 0.5)
    return img


def generate(spec, out_dir, cell=128):
    ch = Character(spec)
    canvas = spec.get("canvas", "u0")
    palette = [hexes(c)[0] for c in spec.get("snap_palette", [])] or None
    rows = []
    for d in DIRS:
        row = []
        for name, count in ANIMS:
            for pose in make_poses(name, count, ch):
                row.append(finish_frame(draw_character(ch, pose, d, cell), cell, canvas, palette))
        rows.append(row)
    sheet = pack(rows, cell)
    os.makedirs(out_dir, exist_ok=True)
    cid = spec["id"]
    sheet.save(os.path.join(out_dir, f"{cid}_field.png"))
    fps = spec.get("fps", 60)
    anims = {}
    for name, count in ANIMS:
        loop = name in ("idle", "walk", "run", "ready", "charge")
        rate = {"idle": 4, "walk": 9, "run": 12, "ready": 4, "charge": 6, "attack": 14, "release": 12, "hurt": 10, "ko": 8, "death": 8, "revive": 8, "victory": 8, "interact": 6, "emote": 4, "break": 1}[name]
        if fps <= 12:
            rate = min(rate, 8)
        anims[name] = {"col": col_of(name), "count": count, "fps": rate, "loop": loop}
    with open(os.path.join(out_dir, f"{cid}_frames.json"), "w") as f:
        json.dump({"cell": cell, "mirror_w": False, "fps": fps, "anims": anims}, f, indent=1)
    return sheet


if __name__ == "__main__":
    from characters import CHARACTERS  # noqa: E402
    ids = sys.argv[1:] or list(CHARACTERS.keys())
    for cid in ids:
        spec = CHARACTERS[cid]
        group = spec.get("group", "characters")
        out = os.path.join(ROOT, "assets", group, cid)
        sheet = generate(spec, out)
        print(f"{cid}: {sheet.size[0]}x{sheet.size[1]} -> {out}")
