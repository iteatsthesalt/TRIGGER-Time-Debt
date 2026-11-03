#!/usr/bin/env python3
"""Self-tests of the Python tooling (run by tools/check.sh after the data lint; `python3 tools/build/test_tools.py`).

What they pin (the "tools" audit cluster): one Godot uid encoder for every sidecar writer, a prop or character
re-import never mixing two deliveries, character sheets sized to the delivered directions, the hourly importer's
routes and record keys, the placeholder generator refusing PixelLab sheets, texture tiles that keep 32 px/m,
the audio loop flags read from one place, an honest manifest verdict, and render.sh's documented arguments.
And the gate itself: check.sh fails on a SCRIPT ERROR or a leak at exit in the unit-test log and on a SCRIPT ERROR
in a probe log (a stubbed Godot plays each log), the test runner fails a test that dies mid-way and a suite that
does not parse, without hanging (the real runner on fixture suites), and no capture plays on the player's files.
Scratch files go to a temporary folder under the git-ignored .tools/ and are removed afterwards.
"""
import contextlib
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# The shell for the bash-script tests, resolved once along PATH: on Nich's Windows PC (Git Bash, the Windows python
# shim) a bare "bash" goes through CreateProcess, which searches System32 first and can start WSL's bash.exe.
BASH = shutil.which("bash")
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

    def test_both_image_writers_share_one_sidecar_rule(self):
        # code health F8: the sheets' and the textures' sidecars come from tools/common/import_sidecar.py, so a uid
        # Godot cannot parse (the old base-36 text) is re-minted as the path's stable uid by either writer, which the
        # next --import keeps, instead of being kept here and replaced at random by Godot.
        import import_sidecar
        for mod in (pl, import_texture):
            with open(mod.__file__, encoding="utf-8") as f:
                src = f.read()
            self.assertIn("import_sidecar.write_import(png_path, IMPORT_TEMPLATE, ROOT, normal)", src, mod.__name__)
            self.assertNotIn("hashlib.md5", src, f"{mod.__name__} keeps no sidecar writer of its own")
        with _scratch() as d:
            for writer in (pl.write_import, import_texture.write_import):
                png = os.path.join(d, f"legacy_{writer.__module__}.png")
                _figure().save(png)
                with open(png + ".import", "w") as f:
                    f.write('[remap]\n\nuid="uid://ci94iqrbh2jac"\n')
                writer(png)
                rel = os.path.relpath(png, ROOT).replace(os.sep, "/")
                self.assertEqual(_uid_of(png + ".import"), godot_uid.godot_uid("res://" + rel), writer.__module__)
                self.assertEqual(import_sidecar.existing_uid(png + ".import"), _uid_of(png + ".import"))


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


class SetupGodot(unittest.TestCase):
    def test_sourcing_leaves_the_callers_shell_options_alone(self):
        """check.sh runs without errexit and reads each step's result itself: a sourced setup_godot.sh must not
        turn errexit on (TOOLS-1). A copy runs against a stub Godot, so nothing is downloaded."""
        if BASH is None:
            self.skipTest("bash not on PATH")
        with _scratch() as d:
            os.makedirs(os.path.join(d, "tools"))
            shutil.copy(os.path.join(ROOT, "tools", "setup_godot.sh"), os.path.join(d, "tools", "setup_godot.sh"))
            stub_dir = os.path.join(d, ".tools", "godot-4.7.2")
            os.makedirs(stub_dir)
            stub = os.path.join(stub_dir, "Godot_v4.7.2-stable_linux.x86_64")
            with open(stub, "w", newline="\n") as f:
                f.write("#!/usr/bin/env bash\necho 4.7.2.stub\n")
            os.chmod(stub, 0o755)
            script = ("set -uo pipefail; source tools/setup_godot.sh > /dev/null; echo \"rc=$?\"; "
                      "set -o | grep -E '^errexit'; echo nothing | grep -E 'SCRIPT ERROR' | head -1; echo reached")
            r = subprocess.run([BASH, "-c", script], cwd=d, capture_output=True, text=True,
                               env=dict(os.environ, GODOT_VERSION="4.7.2"))
            self.assertIn("rc=0", r.stdout, r.stderr)
            self.assertRegex(r.stdout, r"errexit\s+off")
            self.assertIn("reached", r.stdout, "a no-match grep pipeline after the source does not abort the caller")


class RenderArgs(unittest.TestCase):
    def _dry(self, *args):
        if BASH is None:
            self.skipTest("bash not on PATH")
        env = dict(os.environ, RENDER_DRY_RUN="1")
        r = subprocess.run([BASH, os.path.join(ROOT, "tools", "capture", "render.sh"), *args], env=env,
                           capture_output=True, text=True, cwd=ROOT)
        return r.returncode, r.stdout.strip()

    def test_the_documented_forms(self):
        self.assertEqual(self._dry("test_lineup", "lineup", "--", "--ids=crono"),
                         (0, "--frames=30 --every=30 --scene=test_lineup --prefix=lineup --no-save --ids=crono"))
        self.assertEqual(self._dry("test_lineup", "lineup", "30", "--", "--ids=crono,sera", "--anim=walk"),
                         (0, "--frames=30 --every=30 --scene=test_lineup --prefix=lineup --no-save --ids=crono,sera --anim=walk"))
        self.assertEqual(self._dry()[1], "--frames=30 --every=30 --scene=test_diorama --prefix=shot --no-save")
        self.assertEqual(self._dry("a", "b", "x")[0], 2, "a frame count that is not a number is refused")

    def test_a_capture_never_writes_the_players_saves(self):
        """F2: a capture that reaches an autosave (a Chapter 1 beat, --demo=cradle) must not write user://saves."""
        for args in [(), ("atrium", "loft", "120", "--", "--checkpoint=ch1_loft")]:
            rc, out = self._dry(*args)
            self.assertEqual(rc, 0)
            self.assertIn("--no-save", out.split(), f"render.sh {' '.join(args)} passes --no-save")
        with open(os.path.join(ROOT, "tools", "capture", "smoke.gd"), encoding="utf-8") as f:
            self.assertIn('get_node("Saves").set("suspended", true)', f.read(), "smoke.gd suspends Saves itself")

    def test_the_gates_battle_capture_follows_the_battle(self):
        """RA-2: a fixed frame of the arena run lands on the walk on a GPU and on the empty field after the win
        under xvfb, so the gate shoots its battle a set time after battle_started, with Sera faded by her Debt,
        and smoke.gd fails a run whose awaited signal never fires instead of passing it with no battle shot."""
        with open(os.path.join(ROOT, "tools", "check.sh"), encoding="utf-8") as f:
            check = f.read().replace("\\\n", " ")
        arena = [l for l in check.splitlines() if l.strip().startswith("capture test_arena")]
        self.assertEqual(len(arena), 1, "check.sh captures the arena battle once")
        self.assertRegex(arena[0], r"--capture_after=battle_started:\d", "shot after battle_started, not on a frame")
        self.assertRegex(arena[0], r"--debt=[1-9]", "with Sera faded, so the fade pass is rendered")
        with open(os.path.join(ROOT, "tools", "capture", "smoke.gd"), encoding="utf-8") as f:
            smoke = f.read()
        self.assertIn("SMOKE_FAIL", smoke)
        self.assertIn("quit(1)", smoke, "a missing battle_started fails the capture (rc != 0, no SMOKE_OK)")


# The fake Godot and Python a gate test runs check.sh with: each step's log is what the environment says.
_STUB_GODOT = """#!/usr/bin/env bash
case "$*" in
  *run_tests.gd*) printf '%b\\n' "${STUB_TESTS:-3 passed, 0 failed (1 suites)}"; exit "${STUB_TESTS_RC:-0}" ;;
  *tools/build/*probe.gd*) printf '%b\\n' "${STUB_PROBE:-}" "PROBE_END ok=true"; exit 0 ;;
  *) exit 0 ;;
esac
"""
_STUB_PYTHON = "#!/usr/bin/env bash\necho 'Ran 1 test'\nexit 0\n"


class Gate(unittest.TestCase):
    """H2, H6: a test that dies with a SCRIPT ERROR after its first checks exits 0 from a runner that does not
    count it, and a leaked node shows only as a line at exit; a probe that threw mid-run can still print ok=true.
    check.sh reads its logs for all three. A copy of check.sh runs on a stub Godot (and a stub python3 for the
    lint and these tool tests), its logs in a scratch CHECK_LOG_DIR, so /tmp and the real gate are untouched."""

    def _gate(self, **env):
        if BASH is None:
            self.skipTest("bash not on PATH")
        with _scratch() as d:
            os.makedirs(os.path.join(d, "tools"))
            shutil.copy(os.path.join(ROOT, "tools", "check.sh"), os.path.join(d, "tools", "check.sh"))
            stubs = os.path.join(d, "stubs")
            os.makedirs(stubs)
            for name, body in (("godot", _STUB_GODOT), ("python3", _STUB_PYTHON)):
                with open(os.path.join(stubs, name), "w", newline="\n") as f:
                    f.write(body)
                os.chmod(os.path.join(stubs, name), 0o755)
            run_env = dict(os.environ, PATH=stubs + os.pathsep + os.environ.get("PATH", ""),
                           CHECK_LOG_DIR=os.path.join(d, "logs").replace(os.sep, "/"), **env)
            r = subprocess.run([BASH, os.path.join(d, "tools", "check.sh"), "--no-visual"], cwd=d, env=run_env,
                               capture_output=True, text=True, timeout=120)
            return r.returncode, r.stdout

    def test_a_clean_run_passes(self):
        rc, out = self._gate()
        self.assertEqual(rc, 0, out)
        self.assertIn("TESTS: OK", out)
        self.assertIn("ALL CHECKS PASSED", out)

    def test_a_script_error_in_the_tests_fails_whatever_the_exit_code(self):
        rc, out = self._gate(STUB_TESTS="SCRIPT ERROR: Invalid call. Nonexistent function 'free' in base 'Nil'.\n"
                                        "4 passed, 0 failed (1 suites)")
        self.assertEqual(rc, 1, out)
        self.assertIn("TESTS: FAIL (a SCRIPT ERROR in the log)", out)
        self.assertIn("CHECKS FAILED", out)

    def test_a_leak_at_exit_fails_the_tests(self):
        for line in ("WARNING: 3 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
                     "ERROR: 1 resources still in use at exit (run with --verbose for details)."):
            rc, out = self._gate(STUB_TESTS="3 passed, 0 failed (1 suites)\n" + line)
            self.assertEqual(rc, 1, out)
            self.assertIn("TESTS: FAIL (a leak at exit", out, line)

    def test_a_timed_out_test_run_says_so(self):
        rc, out = self._gate(STUB_TESTS_RC="124")
        self.assertEqual(rc, 1, out)
        self.assertIn("TESTS: FAIL (timed out", out)

    def test_a_script_error_in_a_probe_fails_it_even_with_ok_true(self):
        rc, out = self._gate(STUB_PROBE="SCRIPT ERROR: Invalid get index 'stats' (on base: 'null instance').")
        self.assertEqual(rc, 1, out)
        self.assertIn("a SCRIPT ERROR in", out)
        self.assertIn("CHECKS FAILED", out)

    def test_every_capture_runs_off_the_players_files(self):
        """H7: Game._ready adopts the settings file before smoke.gd's own code runs, so the gate's smoke boot and
        captures pass --no-save (Saves.suspended from the start: the scratch settings, which are the defaults),
        and smoke.gd resets the options itself for a bare run."""
        with open(os.path.join(ROOT, "tools", "check.sh"), encoding="utf-8") as f:
            check = f.read().replace("\\\n", " ")
        smoke_calls = [l for l in check.splitlines() if "tools/capture/smoke.gd" in l and "--script" in l]
        self.assertGreaterEqual(len(smoke_calls), 3, "the smoke boot (xvfb and desktop) and capture()")
        for l in smoke_calls:
            self.assertIn("--no-save", l.split(), l.strip())
        with open(os.path.join(ROOT, "tools", "capture", "smoke.gd"), encoding="utf-8") as f:
            self.assertIn('get_node("Game").call("reset_settings")', f.read(), "smoke.gd plays on the default options")


# Fixture suites for the real runner: two tests that die part way (before and after an await) between a clean one,
# and a suite that does not parse.
_CRASH_SUITE = """extends "res://tests/suite_base.gd"


func test_a_crash_before_an_await() -> void:
\tcheck(true, "the first check")
\tvar n: Object = null
\tn.free()
\tcheck(false, "NEVER REACHED before")


func test_a_crash_after_an_await() -> void:
\tcheck(true, "the first check")
\tawait get_tree().process_frame
\tvar n: Object = null
\tn.free()
\tcheck(false, "NEVER REACHED after")


func test_a_clean_test() -> void:
\tcheck(true, "fine")
"""
_BROKEN_SUITE = 'extends "res://tests/suite_base.gd"\n\n\nfunc test_x() -> void:\n\tcheck(true, "x"\n'


class TestRunner(unittest.TestCase):
    """H2: the real tests/run_tests.gd on fixture suites (--suites=<dir>): a SCRIPT ERROR fails the test it
    stopped, by name, and the run; the suites after it still run; a suite with a parse error is a failed suite,
    not a hang until check.sh's 900 s timeout."""

    def test_a_crash_mid_test_and_a_broken_suite_fail_by_name(self):
        if BASH is None:
            self.skipTest("bash not on PATH")
        with _scratch() as d:
            with open(os.path.join(d, "suite_a_crash.gd"), "w", newline="\n") as f:
                f.write(_CRASH_SUITE)
            with open(os.path.join(d, "suite_b_broken.gd"), "w", newline="\n") as f:
                f.write(_BROKEN_SUITE)
            # through bash, so the Git Bash shim in .tools/bin (an extensionless script) is found as check.sh finds it
            r = subprocess.run([BASH, "-c", 'command -v godot > /dev/null || exit 77; exec godot "$@"', "godot",
                                "--headless", "--path", ROOT, "--script", "res://tests/run_tests.gd", "--",
                                "--suites=" + d.replace(os.sep, "/")], capture_output=True, text=True, timeout=120)
        if r.returncode == 77:
            self.skipTest("godot not on PATH (tools/check.sh puts it there)")
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 1, out)
        self.assertIn("FAIL [test_a_crash_before_an_await]: raised 1 SCRIPT ERROR", out)
        self.assertIn("FAIL [test_a_crash_after_an_await]: raised 1 SCRIPT ERROR", out)
        self.assertNotIn("NEVER REACHED", out)
        self.assertIn("suite_a_crash.gd: 3 passed, 2 failed", out, "the clean test still ran; no pass for a guard")
        self.assertRegex(out, r"FAIL cannot load \S*suite_b_broken\.gd")
        self.assertIn("3 passed, 3 failed (2 suites)", out)
        self.assertIn("FAIL 3 SCRIPT ERROR(s) during the run", out)


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
