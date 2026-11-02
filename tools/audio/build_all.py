#!/usr/bin/env python3
"""Rebuild every audio asset of TRIGGER: Time Debt and measure it.

    python3 tools/audio/build_all.py                 # everything: motifs, music, SFX, ambience
    python3 tools/audio/build_all.py --only battle   # anything whose id contains "battle"
    python3 tools/audio/build_all.py --music --sfx   # just those groups
    python3 tools/audio/build_all.py --check         # measure the files already in audio/ (no rebuild)

Prints peak dBFS and integrated loudness (ITU-R BS.1770 K-weighting, gated) for every file, writes
audio/AUDIO_MANIFEST.json and the Godot `.import` sidecars (loop points, QOA) via godot_import.py. Music targets −20 LUFS integrated, ambience −26 LUFS, SFX peak
−1 dBFS. Every generator is seeded, so a rebuild reproduces the same bytes.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ("", "tracks", "sfx"):
    sys.path.insert(0, os.path.join(HERE, sub))
import synth as S  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
AUDIO = os.path.join(ROOT, "audio")

MUSIC_BUILDERS = {
    "mus_title": ("title", "build"),
    "mus_u0_guardia_morning": ("guardia_morning", "build"),
    "mus_u0_wind_scene_1024": ("wind_scene", "build"),
    "mus_u0_truce_1024": ("truce", "build"),
    "mus_u0_fair_1024": ("fair", "build"),
    "mus_battle_core_u0": ("battle", "build_u0"),
    "mus_battle_core_u1": ("battle", "build_u1"),
    "mus_boss_atrium_cradle": ("boss_atrium_cradle", "build"),
    "mus_vaelos_theme": ("character_themes", "build_vaelos"),
    "mus_sera_theme": ("character_themes", "build_sera"),
    "mus_u1_ashen_morning": ("u1", "build_ashen_morning"),
    "mus_u1_krona_duel": ("u1", "build_krona_duel"),
    "mus_transit_chronoslip": ("transit_and_stings", "build_transit"),
    "mus_stings": ("transit_and_stings", "build_stings"),
}


def decode(path: str) -> np.ndarray:
    """Decode any audio file to float stereo/mono at 48 kHz with ffmpeg (so OGGs are measured as encoded)."""
    if path.endswith(".wav"):
        return S.read_wav(path)
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels", "-of", "default=nw=1:nk=1", path],
                           capture_output=True, text=True)
    ch = int(probe.stdout.strip() or "2")
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ar", str(S.SR), "-"], capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, ch) if ch > 1 else x


def measure_file(path: str) -> dict:
    x = decode(path)
    m = S.measure(x)
    m["file"] = os.path.relpath(path, ROOT)
    m["size_bytes"] = os.path.getsize(path)
    return m


def fmt_row(m: dict) -> str:
    lufs = f"{m['lufs_i']:6.1f}" if m.get("lufs_i") is not None else "   —  "
    return f"{m['file']:58s} {m['duration_s']:7.2f}s  ch{m['channels']}  peak {m['peak_dbfs']:6.1f} dBFS  LUFS {lufs}  {m['size_bytes'] / 1024:8.0f} KB"


def check_only() -> list[dict]:
    files = sorted(glob.glob(os.path.join(AUDIO, "**", "*.ogg"), recursive=True) + glob.glob(os.path.join(AUDIO, "**", "*.wav"), recursive=True))
    rows = [measure_file(p) for p in files]
    for r in rows:
        print(fmt_row(r))
    return rows


def write_manifest(manifest: dict, path: str) -> None:
    counts = {"music_files": sum(len(v["stems"]) for v in manifest["music"].values()), "sfx_files": len(manifest["sfx"]),
              "ambience_files": len(manifest["ambience"]), "motif_files": len(manifest["motifs"])}
    manifest["counts"] = counts
    print(f"\nFiles: {counts}")
    S.write_json(path, manifest)


def refresh_manifest() -> dict:
    """Rebuild the manifest from what is on disk: track and bed sidecars, measured SFX files."""
    manifest = {"music": {}, "sfx": [], "ambience": [], "motifs": [], "targets": {"music_lufs": -20.0, "ambience_lufs": -26.0, "sfx_peak_dbfs": -1.0}, "problems": []}
    for p in sorted(glob.glob(os.path.join(AUDIO, "music", "*.json"))):
        side = json.load(open(p, encoding="utf-8"))
        manifest["music"][side["id"]] = side
    for p in sorted(glob.glob(os.path.join(AUDIO, "ambience", "*.json"))):
        manifest["ambience"].append(json.load(open(p, encoding="utf-8")))
    for p in sorted(glob.glob(os.path.join(AUDIO, "sfx", "**", "*.wav"), recursive=True)):
        m = measure_file(p)
        m["family"] = os.path.basename(os.path.dirname(p))
        manifest["sfx"].append(m)
    manifest["motifs"] = [os.path.relpath(p, ROOT) for p in sorted(glob.glob(os.path.join(AUDIO, "music", "motifs", "*.*")))]
    return manifest


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", default=None, help="substring filter on asset ids / family names")
    ap.add_argument("--music", action="store_true")
    ap.add_argument("--sfx", action="store_true")
    ap.add_argument("--ambience", action="store_true")
    ap.add_argument("--motifs", action="store_true")
    ap.add_argument("--check", action="store_true", help="measure existing files only")
    ap.add_argument("--refresh-manifest", action="store_true", help="rebuild audio/AUDIO_MANIFEST.json from the files and sidecars, no rendering")
    args = ap.parse_args(argv)
    if args.check:
        rows = check_only()
        total = sum(r["size_bytes"] for r in rows)
        print(f"\n{len(rows)} files, {total / 1024 / 1024:.1f} MB")
        return 0
    manifest_path = os.path.join(AUDIO, "AUDIO_MANIFEST.json")
    if args.refresh_manifest:
        write_manifest(refresh_manifest(), manifest_path)
        return 0
    groups = {"music": args.music, "sfx": args.sfx, "ambience": args.ambience, "motifs": args.motifs}
    if not any(groups.values()):
        groups = {k: True for k in groups}
    t0 = time.time()
    # partial builds update the existing manifest instead of replacing it
    manifest = {"music": {}, "sfx": [], "ambience": [], "motifs": []}
    if os.path.exists(manifest_path):
        try:
            manifest.update({k: v for k, v in json.load(open(manifest_path, encoding="utf-8")).items() if k in manifest})
        except (ValueError, OSError):
            pass
    manifest["targets"] = {"music_lufs": -20.0, "ambience_lufs": -26.0, "sfx_peak_dbfs": -1.0}
    problems = []

    if groups["motifs"] and (not args.only or "motif" in args.only):
        import motifs
        import music_box
        out_dir = os.path.join(AUDIO, "music", "motifs")
        written = motifs.export_cells(out_dir)
        music_box.main(["--out", out_dir])
        manifest["motifs"] = [os.path.relpath(p, ROOT) for p in written] + [os.path.relpath(p, ROOT) for p in sorted(glob.glob(os.path.join(out_dir, "*.wav")))]
        print(f"motifs: {len(manifest['motifs'])} files in audio/music/motifs/")

    if groups["music"]:
        import importlib
        for track_id, (module, fn) in MUSIC_BUILDERS.items():
            if args.only and args.only not in track_id:
                continue
            t1 = time.time()
            mod = importlib.import_module(module)
            result = getattr(mod, fn)()
            results = result if isinstance(result, list) else [result]
            for side in results:
                manifest["music"][side["id"]] = side
                lufs = side["mix"]["lufs_i"]
                print(f"\n{side['id']}: {side['duration_s']} s, loop from {side['loop_start_s']} s, mix LUFS {lufs}, peak {side['mix']['peak_dbfs']} dBFS  ({time.time() - t1:.0f} s)")
                for name, st in side["stems"].items():
                    p = os.path.join(AUDIO, "music", st["file"])
                    m = measure_file(p)
                    flag = "" if st.get("default_on", True) else "  (optional layer)"
                    print("  " + fmt_row(m) + flag)
                    if m["size_bytes"] > 6 * 1024 * 1024:
                        problems.append(f"{m['file']} is over 6 MB")
                    if m["duration_s"] > 150.0:
                        problems.append(f"{m['file']} is over 2:30")
                if lufs is not None and side["id"].startswith("mus_") and not side["id"].startswith("mus_stings") and side["id"] != "mus_transit_chronoslip":
                    if abs(lufs - (-20.0)) > 1.5:
                        problems.append(f"{side['id']} mix is {lufs} LUFS (target −20)")

    if groups["sfx"]:
        import families
        wanted = [f for f in families.FAMILIES if not args.only or args.only in f]
        rows = []
        if wanted:
            print("\nSFX:")
            for fam in wanted:
                rows += families.build_all(fam)
        for r in rows:
            print("  " + fmt_row(r) + ("  loop" if r.get("loop") else ""))
            if abs(r["peak_dbfs"] + 1.0) > 0.2:
                problems.append(f"{r['file']} peak {r['peak_dbfs']} (target −1 dBFS)")
        manifest["sfx"] = [r for r in manifest["sfx"] if r.get("family") not in wanted] + rows

    if groups["ambience"] and (not args.only or "amb" in args.only):
        import ambience
        print("\nAmbience:")
        manifest["ambience"] = []
        for r in ambience.build_all():
            m = measure_file(os.path.join(AUDIO, "ambience", r["file"]))
            print("  " + fmt_row(m) + "  loop")
            manifest["ambience"].append(r)

    import godot_import
    godot_import.main()
    manifest["build_seconds"] = round(time.time() - t0, 1)
    manifest["problems"] = problems
    write_manifest(manifest, manifest_path)
    total = sum(os.path.getsize(p) for p in glob.glob(os.path.join(AUDIO, "**", "*.*"), recursive=True))
    print(f"\nDone in {manifest['build_seconds']} s. audio/ holds {total / 1024 / 1024:.1f} MB. Manifest: audio/AUDIO_MANIFEST.json")
    if problems:
        print("Problems:")
        for p in problems:
            print("  - " + p)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
