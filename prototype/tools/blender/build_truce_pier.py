"""Generate the Truce pier set piece and export it as glTF.

Run:
    blender -b --factory-startup -P tools/blender/build_truce_pier.py -- [out.glb]

Default output: assets/models/truce_pier.glb (relative to the project root).
Blender is Z-up; the glTF exporter converts to Godot's Y-up. Units are metres.
Objects named "*-col" get static collision on import in Godot.
Deterministic: the same script always produces the same file.
"""

import math
import os
import random
import sys

import bpy

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_OUT = os.path.join(PROJECT_ROOT, "assets", "models", "truce_pier.glb")

DECK_Z = 1.0            # top of the pier deck
DECK_WIDTH = 3.0
DECK_START_Y = -6.0     # where the pier meets the shore
DECK_END_Y = 10.0
LAND_Z = 0.6            # top of the grass
WATER_Z = 0.0


# ------------------------------------------------------------------ mesh helpers

class MeshAcc:
    """Accumulates vertices and faces so many parts become one object."""

    def __init__(self):
        self.verts = []
        self.faces = []

    def add(self, verts, faces):
        base = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(i + base for i in f) for f in faces)


def add_box(acc, center, size):
    cx, cy, cz = center
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [(cx + sx * hx, cy + sy * hy, cz + sz * hz)
         for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    # 0..3 bottom, 4..7 top; index = x + 2y + 4z
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    acc.add(v, f)


def add_cylinder(acc, center, radius, z0, z1, sides=8):
    cx, cy = center
    ring = [(cx + radius * math.cos(2 * math.pi * i / sides),
             cy + radius * math.sin(2 * math.pi * i / sides)) for i in range(sides)]
    v = [(x, y, z0) for x, y in ring] + [(x, y, z1) for x, y in ring]
    f = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    f += [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
    acc.add(v, f)


def add_quad_strip(acc, rows):
    """rows: list of (left_xyz, right_xyz) pairs; makes a quad strip between them."""
    v = []
    for left, right in rows:
        v += [left, right]
    f = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(len(rows) - 1)]
    acc.add(v, f)


def material(name, rgb, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1.0)
    if hasattr(mat, "use_nodes"):
        mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
    return mat


def make_object(name, acc, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(acc.verts, [], acc.faces)
    mesh.validate()
    mesh.update()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# ------------------------------------------------------------------ set pieces

def build_water(mats):
    acc = MeshAcc()
    s = 40.0
    acc.add([(-s, -12, WATER_Z), (s, -12, WATER_Z), (s, 30, WATER_Z), (-s, 30, WATER_Z)], [(0, 1, 2, 3)])
    make_object("Water", acc, mats["water"])


def build_shoreline(mats):
    # Flat grass behind the beach, then a sand slope that dips under the water line.
    grass = MeshAcc()
    add_box(grass, (0, -15, LAND_Z / 2 - 1.0), (80, 18, LAND_Z + 2.0))
    make_object("Grass-col", grass, mats["grass"])

    sand = MeshAcc()
    rows = []
    for y, z in ((-6.0, LAND_Z), (-4.5, 0.35), (-3.0, 0.05), (-1.5, -0.4)):
        rows.append(((-40, y, z), (40, y, z)))
    add_quad_strip(sand, rows)
    make_object("Beach-col", sand, mats["sand"])


def build_pier(mats, rng):
    deck = MeshAcc()
    plank_depth = 0.28
    gap = 0.04
    y = DECK_START_Y
    while y + plank_depth <= DECK_END_Y:
        jitter = rng.uniform(-0.015, 0.015)
        add_box(deck, (0, y + plank_depth / 2, DECK_Z - 0.04 + jitter), (DECK_WIDTH, plank_depth, 0.08))
        y += plank_depth + gap
    # Stringers under the planks
    for x in (-DECK_WIDTH / 2 + 0.2, DECK_WIDTH / 2 - 0.2):
        add_box(deck, (x, (DECK_START_Y + DECK_END_Y) / 2, DECK_Z - 0.18),
                (0.16, DECK_END_Y - DECK_START_Y, 0.2))
    make_object("PierDeck-col", deck, mats["plank"])

    posts = MeshAcc()
    py = DECK_START_Y + 1.0
    while py <= DECK_END_Y:
        for x in (-DECK_WIDTH / 2 + 0.1, DECK_WIDTH / 2 - 0.1):
            add_cylinder(posts, (x, py), 0.14, -1.5, DECK_Z + 0.9)
        py += 2.0
    # Rope rail between the post tops
    for x in (-DECK_WIDTH / 2 + 0.1, DECK_WIDTH / 2 - 0.1):
        add_box(posts, (x, (DECK_START_Y + 1.0 + py - 2.0) / 2, DECK_Z + 0.75),
                (0.05, py - 2.0 - DECK_START_Y - 1.0, 0.05))
    make_object("PierPosts", posts, mats["post"])


def build_boathouse(mats):
    # Sits on stilts beside the far end of the pier, door facing the deck.
    x0, x1 = DECK_WIDTH / 2 + 0.6, DECK_WIDTH / 2 + 6.6
    y0, y1 = 3.0, 9.0
    floor_z, wall_h, ridge_h = DECK_Z, 2.6, 1.6
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    stilts = MeshAcc()
    for sx in (x0 + 0.3, x1 - 0.3):
        for sy in (y0 + 0.3, cy, y1 - 0.3):
            add_cylinder(stilts, (sx, sy), 0.16, -1.5, floor_z)
    add_box(stilts, (cx, cy, floor_z - 0.06), (x1 - x0 + 0.4, y1 - y0 + 0.4, 0.12))
    # Short walkway from the pier to the door
    add_box(stilts, ((DECK_WIDTH / 2 + x0) / 2, cy, floor_z - 0.04), (x0 - DECK_WIDTH / 2 + 0.1, 1.4, 0.08))
    make_object("BoathouseFloor-col", stilts, mats["plank"])

    walls = MeshAcc()
    add_box(walls, (cx, cy, floor_z + wall_h / 2), (x1 - x0, y1 - y0, wall_h))
    make_object("BoathouseWalls-col", walls, mats["wall"])

    door = MeshAcc()
    add_box(door, (x0 - 0.02, cy, floor_z + 1.0), (0.06, 1.2, 2.0))
    make_object("BoathouseDoor", door, mats["trim"])

    # Gable roof: ridge runs along Y, overhangs the walls
    roof = MeshAcc()
    o = 0.4
    top = floor_z + wall_h
    ridge = top + ridge_h
    v = [(x0 - o, y0 - o, top - 0.2), (cx, y0 - o, ridge), (x1 + o, y0 - o, top - 0.2),
         (x0 - o, y1 + o, top - 0.2), (cx, y1 + o, ridge), (x1 + o, y1 + o, top - 0.2)]
    roof.add(v, [(0, 3, 4, 1), (1, 4, 5, 2)])
    make_object("BoathouseRoof", roof, mats["roof"])

    gables = MeshAcc()
    gables.add([(x0, y0, top), (cx, y0, ridge - 0.05), (x1, y0, top),
                (x0, y1, top), (cx, y1, ridge - 0.05), (x1, y1, top)],
               [(0, 2, 1), (3, 4, 5)])
    make_object("BoathouseGables", gables, mats["wall"])


# ------------------------------------------------------------------ main

def parse_out_path():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else DEFAULT_OUT
    if not os.path.isabs(out):
        out = os.path.join(PROJECT_ROOT, out)
    return out


def main():
    out = parse_out_path()
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    mats = {
        "water": material("Water", (0.12, 0.38, 0.52), 0.15),
        "grass": material("Grass", (0.33, 0.52, 0.24)),
        "sand": material("Sand", (0.82, 0.74, 0.52)),
        "plank": material("Plank", (0.55, 0.38, 0.22)),
        "post": material("Post", (0.36, 0.25, 0.16)),
        "wall": material("BoathouseWall", (0.78, 0.70, 0.56)),
        "trim": material("Trim", (0.30, 0.42, 0.55)),
        "roof": material("Roof", (0.62, 0.24, 0.18)),
    }
    rng = random.Random(1999)

    build_water(mats)
    build_shoreline(mats)
    build_pier(mats, rng)
    build_boathouse(mats)

    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
    print("TRUCE_PIER_OK %s objects=%d" % (out, len(bpy.data.objects)))


if __name__ == "__main__":
    main()
