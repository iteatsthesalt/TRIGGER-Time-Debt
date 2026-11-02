#!/usr/bin/env python3
"""Self-tests of the Python tooling (run by tools/check.sh after the data lint; `python3 tools/build/test_tools.py`).

What they pin (the "tools" audit cluster): one Godot uid encoder for every sidecar writer, a prop or character
re-import never mixing two deliveries, character sheets sized to the delivered directions, the hourly importer's
routes and record keys, the placeholder generator refusing PixelLab sheets, texture tiles that keep 32 px/m,
the audio loop flags read from one place, an honest manifest verdict, and render.sh's documented arguments.
Scratch files go to a temporary folder under the git-ignored .tools/ and are removed afterwards.
"""
import contextlib
import glob
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
for sub in ("tools/common", "tools/art", "tools/art/pipeline", "tools/audio"):
    sys.path.insert(0, os.path.join(ROOT, sub))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import godot_uid  # noqa: E402
import pixellab_import as pl  # noqa: E402
import pixellab_objects as po  # noqa: E402
import import_incoming  # noqa: E402
import import_texture  # noqa: E402
import delivered  # noqa: E402
import godot_import  # noqa: E402


def _scratch():
    base = os.path.join(ROOT, ".tools", "tmp")
    os.makedirs(base, exist_ok=True)
    return tempfile.TemporaryDirectory(dir=base)


def _figure(w=64, h=64, colour=(120, 80, 60, 255), top=10, bottom=55):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    a = np.array(img)
    a[top:bottom + 1, w // 2 - 12:w // 2 + 12] = colour
    return Image.fromarray(a)


def _png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _manifest():
    with open(os.path.join(ROOT, "audio", "AUDIO_MANIFEST.json"), encoding="utf-8") as f:
        return json.load(f)


def _uid_of(import_path):
    with open(import_path) as f:
        m = re.search(r'uid="(uid://[^"]+)"', f.read())
    return m.group(1) if m else ""


class GodotUid(unittest.TestCase):
    def test_round_trip_and_alphabet(self):
        for n in (1, 33, 34, 35, 2 ** 40 + 7, 0x7FFFFFFFFFFFFFFF):
            t = godot_uid.encode(n)
            self.assertEqual(godot_uid.decode(t), n)
            self.assertTrue(godot_uid.is_canonical(t))
            self.assertNotRegex(t[6:], r"[z9]", "Godot's digits are a-y and 0-8")

    def test_the_old_base36_text_is_not_godots(self):
        # what write_import used to fabricate for crono_field.png (TOOLS-5); Godot rewrote it to wu168f6u7h1x
        self.assertFalse(godot_uid.is_canonical("uid://ci94iqrbh2jac"))
        self.assertTrue(godot_uid.is_canonical("uid://wu168f6u7h1x"))

    def test_matches_the_audio_sidecars_godot_kept(self):
        files = sorted(glob.glob(os.path.join(ROOT, "audio", "**", "*.import"), recursive=True))
        self.assertGreater(len(files), 50)
        for p in files:
            with open(p) as f:
                src = re.search(r'source_file="([^"]+)"', f.read()).group(1)
            self.assertEqual(godot_uid.godot_uid(src), _uid_of(p), p)

    def test_sheet_and_texture_sidecars_get_a_canonical_uid_and_keep_it(self):
        with _scratch() as d:
            for writer in (pl.write_import, import_texture.write_import):
                png = os.path.join(d, f"sheet_{writer.__module__}.png")
                _figure().save(png)
                writer(png)
                uid = _uid_of(png + ".import")
                self.assertTrue(godot_uid.is_canonical(uid), f"{writer.__module__}: {uid}")
                writer(png, normal=True)
                self.assertEqual(_uid_of(png + ".import"), uid, "a rewrite keeps the uid")


def _object_zip(rotations, clip_dirs=()):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        for d in rotations:
            z.writestr(f"rotations/{d}.png", _png_bytes(_figure()))
        for d in clip_dirs:
            for i in range(3):
                z.writestr(f"animations/swing/{d}/frame_{i:03d}.png", _png_bytes(_figure(top=10 + i)))
    return buf.getvalue()


class ReImport(unittest.TestCase):
    def setUp(self):
        self._fetch = pl.fetch

    def tearDown(self):
        pl.fetch = self._fetch

    def test_a_single_png_delivery_replaces_a_four_rotation_zip(self):
        with _scratch() as d:
            src, out = os.path.join(d, "pixellab"), os.path.join(d, "out")
            pl.fetch = lambda url, dest=None: _object_zip(["south", "west", "east", "north"], ["south", "west"])
            v1 = po.download_object("obj-v1", src)
            self.assertEqual(len(v1["states"][0]["frames"]["rotations"]), 4)
            self.assertIn("swing", v1["states"][0]["frames"]["animations"])
            pl.fetch = lambda url, dest=None: _png_bytes(_figure())
            v2 = po.download_object("obj-v2", src)
            frames = v2["states"][0]["frames"]
            self.assertEqual(frames["rotations"], {"south": "rotations/unknown.png"})
            self.assertEqual(frames["animations"], {})
            self.assertEqual(os.listdir(os.path.join(src, "rotations")), ["unknown.png"])
            self.assertFalse(os.path.exists(os.path.join(src, "animations")), "v1's clip is gone")
            sheet, data = po.build_object_sheet("prp_test", v2, src, out)
            self.assertEqual(data["rows"], ["s"])
            self.assertEqual(list(data["anims"].keys()), ["idle"])
            self.assertEqual(data["source"]["pixellab_object"], "obj-v2")

    def test_a_failed_download_keeps_the_cached_frames(self):
        with _scratch() as d:
            src = os.path.join(d, "pixellab")
            pl.fetch = lambda url, dest=None: _object_zip(["south"])
            po.download_object("obj-v1", src)
            pl.fetch = lambda url, dest=None: b"<html>locked</html>"
            with self.assertRaises(RuntimeError):
                po.download_object("obj-v2", src)
            self.assertTrue(os.path.exists(os.path.join(src, "metadata.json")), "the fallback cache survives")

    def test_a_listing_for_another_character_starts_clean(self):
        with _scratch() as d:
            old = {"states": [{"character": {"id": "old-id"}, "frames": {"rotations": {"south": "Idle/rotations/south.png"},
                                                                          "animations": {}}}]}
            os.makedirs(os.path.join(d, "Idle", "rotations"))
            _figure().save(os.path.join(d, "Idle", "rotations", "south.png"))
            with open(os.path.join(d, "metadata.json"), "w") as f:
                json.dump(old, f)
            meta = pl.import_listing("", "new-id", d)
            self.assertEqual(meta["states"][0]["character"]["id"], "new-id")
            self.assertEqual(meta["states"][0]["frames"]["rotations"], {})
            self.assertFalse(os.path.exists(os.path.join(d, "Idle", "rotations", "south.png")))


def _character(d, rotations, clip_dirs):
    """A fake character export with `rotations` and a 4-frame walk in `clip_dirs`."""
    meta = {"states": [{"character": {"id": "char-1"}, "frames": {"rotations": {}, "animations": {"walking": {}}}}]}
    fr = meta["states"][0]["frames"]
    for r in rotations:
        p = f"rotations/{r}.png"
        os.makedirs(os.path.join(d, "rotations"), exist_ok=True)
        _figure().save(os.path.join(d, p))
        fr["rotations"][r] = p
    for r in clip_dirs:
        os.makedirs(os.path.join(d, "walk", r), exist_ok=True)
        paths = []
        for i in range(4):
            p = f"walk/{r}/{i}.png"
            _figure(top=10 + i % 2).save(os.path.join(d, p))
            paths.append(p)
        fr["animations"]["walking"][r] = paths
    return meta


class CharacterRows(unittest.TestCase):
    def _build(self, rotations, clip_dirs):
        with _scratch() as d:
            meta = _character(d, rotations, clip_dirs)
            with contextlib.redirect_stdout(io.StringIO()):
                sheet, data, missing = pl.build_sheet("tester", meta, d, os.path.join(d, "out"), height_m=1.0)
            return sheet, data, missing

    def test_four_cardinal_rotations_make_a_four_row_sheet(self):
        cards = ["south", "west", "east", "north"]
        sheet, data, missing = self._build(cards, cards)
        self.assertEqual(data["rows"], ["s", "w", "e", "n"])
        self.assertEqual(sheet.height, 4 * data["cell"], "no blank diagonal rows")
        self.assertEqual(missing, [])
        self.assertEqual(data["source"]["rotations"], sorted(cards))
        self.assertEqual(data["source"]["clips"], {"walk": "walking"})

    def test_eight_rotations_keep_eight_rows(self):
        sheet, data, _ = self._build(pl.ROWS, ["south", "south-east"])
        self.assertEqual(len(data["rows"]), 8)
        self.assertEqual(sheet.height, 8 * data["cell"])

    def test_a_missing_rotation_is_recorded(self):
        _, data, missing = self._build(["south", "west", "east"], [])
        self.assertIn(("north", "idle"), missing, "the idle-from-rotation gap is listed")


class Incoming(unittest.TestCase):
    def test_record_key_reads_the_pixellab_name(self):
        self.assertEqual(import_incoming.record_key({"asset_key": "sera", "pixellab_name": "TRIGGER Sera px64 field v1"}),
                         "sera_px64_field")
        self.assertEqual(import_incoming.record_key({"asset_key": "sera", "tier": "action", "pixellab_name": "TRIGGER Sera px64 field v1"}),
                         "sera_px64_action", "the item's own fields win")
        self.assertEqual(import_incoming.record_key({"asset_key": "crono"}), "crono_field")
        self.assertEqual(import_incoming.record_key({"asset_key": "prp_u0_hearth", "kind": "object"}), "prp_u0_hearth")

    def test_kinds_without_a_route_are_skipped_not_imported(self):
        with _scratch() as d:
            inc, rec = os.path.join(d, "incoming.json"), os.path.join(d, "record.json")
            with open(inc, "w") as f:
                json.dump([{"asset_key": "ui_menu_kit", "kind": "ui", "pixellab_id": "x", "pixellab_name": "TRIGGER Menu Kit v1"}], f)
            with open(rec, "w") as f:
                json.dump({}, f)
            saved = (import_incoming.INCOMING, import_incoming.RECORD, sys.argv)
            import_incoming.INCOMING, import_incoming.RECORD, sys.argv = inc, rec, ["import_incoming.py", "--dry-run"]
            out = io.StringIO()
            try:
                with contextlib.redirect_stdout(out):
                    rc = import_incoming.main()
            finally:
                import_incoming.INCOMING, import_incoming.RECORD, sys.argv = saved
            self.assertEqual(rc, 0)
            self.assertIn("kind ui has no import route", out.getvalue())
            self.assertNotIn("--kind character", out.getvalue(), "never sent down the character route")


class Placeholders(unittest.TestCase):
    def test_spritegen_refuses_a_pixellab_sheet(self):
        with _scratch() as d:
            rec = os.path.join(d, "record.json")
            folder = os.path.join(ROOT, "assets", "characters", "crono")
            rel = os.path.relpath(folder, ROOT).replace(os.sep, "/")
            with open(rec, "w") as f:
                json.dump({"crono_field": {"pixellab_id": "abc", "path": rel}}, f)
            self.assertIn("PixelLab import abc", delivered.delivered_owner("crono", folder, rec))
            # the importer's frames table alone is enough
            frames_dir = os.path.join(d, "npc")
            os.makedirs(frames_dir)
            with open(os.path.join(frames_dir, "npc_field_frames.json"), "w") as f:
                json.dump({"source": {"pixellab_character": "abc"}}, f)
            self.assertNotEqual(delivered.delivered_owner("npc", frames_dir, rec), "")
            self.assertEqual(delivered.delivered_owner("guard", os.path.join(d, "guard"), rec), "")

    def test_the_shipped_pixellab_cast_is_guarded(self):
        for cid in ("crono", "sera", "krona", "marle"):
            self.assertNotEqual(delivered.delivered_owner(cid, os.path.join(ROOT, "assets", "characters", cid)), "", cid)


class Textures(unittest.TestCase):
    def test_only_square_divisors_of_the_sheet_tile(self):
        for w in (16, 32, 64, 128, 256, 512, 1024):
            self.assertEqual(import_texture.tile_error(w, w), "", w)
        self.assertIn("does not divide", import_texture.tile_error(192, 192))
        self.assertIn("does not divide", import_texture.tile_error(300, 300))
        self.assertIn("square", import_texture.tile_error(256, 128))


class Audio(unittest.TestCase):
    def test_loop_flags_come_from_the_rows(self):
        rows = [{"file": "audio/sfx/status/new_loop.wav", "loop": True}, {"file": "audio/sfx/ui/tick.wav", "loop": False},
                {"file": "audio/sfx/ui/old.wav"}]
        self.assertEqual(godot_import.sfx_loop_flags(rows), {"audio/sfx/status/new_loop.wav": True, "audio/sfx/ui/tick.wav": False})

    def test_the_manifest_loop_flags_match_the_sidecars(self):
        rows = _manifest()["sfx"]
        loops = {r["file"] for r in rows if r.get("loop")}
        self.assertEqual(len(loops), 8, "the eight families.py loops")
        for r in rows:
            self.assertEqual(godot_import.sidecar_loops(os.path.join(ROOT, r["file"]) + ".import"), bool(r.get("loop")), r["file"])

    def test_a_manifest_without_both_groups_measured_has_no_verdict(self):
        m = _manifest()
        checked = set(m.get("checked_groups") or [])
        if not {"music", "sfx"} <= checked:
            self.assertIsNone(m.get("problems"), "an empty list would read as a passed loudness gate")
        else:
            self.assertIsInstance(m.get("problems"), list)


class RenderArgs(unittest.TestCase):
    def _dry(self, *args):
        env = dict(os.environ, RENDER_DRY_RUN="1")
        r = subprocess.run(["bash", os.path.join(ROOT, "tools", "capture", "render.sh"), *args], env=env,
                           capture_output=True, text=True, cwd=ROOT)
        return r.returncode, r.stdout.strip()

    def test_the_documented_forms(self):
        self.assertEqual(self._dry("test_lineup", "lineup", "--", "--ids=crono"),
                         (0, "--frames=30 --every=30 --scene=test_lineup --prefix=lineup --ids=crono"))
        self.assertEqual(self._dry("test_lineup", "lineup", "30", "--", "--ids=crono,sera", "--anim=walk"),
                         (0, "--frames=30 --every=30 --scene=test_lineup --prefix=lineup --ids=crono,sera --anim=walk"))
        self.assertEqual(self._dry()[1], "--frames=30 --every=30 --scene=test_diorama --prefix=shot")
        self.assertEqual(self._dry("a", "b", "x")[0], 2, "a frame count that is not a number is refused")


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
