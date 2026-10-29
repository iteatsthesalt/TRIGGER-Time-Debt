"""Write Godot `.import` sidecars for every file under audio/ so music and beds loop on their bar
lines without anyone touching the import dock (Reference Bible §1.12).

    python3 tools/audio/godot_import.py

OGG music: loop on, loop_offset = the end of the intro, bpm / beat_count / bar_beats from the track
sidecar (Godot then loops at the beat count and folds the tail into the loop start). Stings: loop off.
OGG ambience: loop on. WAV: QOA, trim on for one-shots; loops get loop_mode forward and no trim.
UIDs are derived from the path so a rebuild writes identical files. Godot regenerates the
`.godot/imported/` cache from these on its next scan.
"""
from __future__ import annotations

import glob
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
AUDIO = os.path.join(ROOT, "audio")

LOOPED_WAVS = {"telegraph_loop", "galaxy_hum_432", "galaxy_hum_220", "grief_whisper", "vhs_fog", "mercury_slosh", "ruin_tear", "oil_drip"}


def godot_uid(res_path: str) -> str:
    """Godot's ResourceUID text form (base 34: a–y then 0–8) of a 63-bit hash of the path."""
    h = int.from_bytes(hashlib.sha1(res_path.encode()).digest()[:8], "big") & 0x7FFFFFFFFFFFFFFF
    if h == 0:
        h = 1
    txt = ""
    while h:
        c = h % 34
        txt = (chr(ord("a") + c) if c < 25 else chr(ord("0") + (c - 25))) + txt
        h //= 34
    return "uid://" + txt


def res_path(path: str) -> str:
    return "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")


def imported_path(rp: str, ext: str) -> str:
    name = rp.rsplit("/", 1)[-1]
    return f"res://.godot/imported/{name}-{hashlib.md5(rp.encode()).hexdigest()}.{ext}"


def _write(path: str, text: str) -> bool:
    old = open(path, encoding="utf-8").read() if os.path.exists(path) else None
    if old == text:
        return False
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return True


def ogg_import(path: str, loop: bool, loop_offset: float, bpm: float, beat_count: int, bar_beats: int) -> str:
    rp = res_path(path)
    dest = imported_path(rp, "oggvorbisstr")
    return (
        "[remap]\n\n"
        'importer="oggvorbisstr"\n'
        'type="AudioStreamOggVorbis"\n'
        f'uid="{godot_uid(rp)}"\n'
        f'path="{dest}"\n\n'
        "[deps]\n\n"
        f'source_file="{rp}"\n'
        f'dest_files=["{dest}"]\n\n'
        "[params]\n\n"
        f"loop={'true' if loop else 'false'}\n"
        f"loop_offset={loop_offset:g}\n"
        f"bpm={bpm:g}\n"
        f"beat_count={beat_count}\n"
        f"bar_beats={bar_beats}\n"
    )


def wav_import(path: str, loop: bool, mono: bool) -> str:
    rp = res_path(path)
    dest = imported_path(rp, "sample")
    return (
        "[remap]\n\n"
        'importer="wav"\n'
        'type="AudioStreamWAV"\n'
        f'uid="{godot_uid(rp)}"\n'
        f'path="{dest}"\n\n'
        "[deps]\n\n"
        f'source_file="{rp}"\n'
        f'dest_files=["{dest}"]\n\n'
        "[params]\n\n"
        "force/8_bit=false\n"
        f"force/mono={'true' if mono else 'false'}\n"
        "force/max_rate=false\n"
        "force/max_rate_hz=44100\n"
        f"edit/trim={'false' if loop else 'true'}\n"
        "edit/normalize=false\n"
        f"edit/loop_mode={2 if loop else 1}\n"  # 2 = Forward, 1 = Disabled (0 would mean "detect from WAV")
        "edit/loop_begin=0\n"
        "edit/loop_end=-1\n"
        "compress/mode=2\n"
    )


def music_params(ogg_path: str) -> tuple[bool, float, float, int, int]:
    """Find the track sidecar for a music file (stems share their track's sidecar)."""
    name = os.path.basename(ogg_path)[:-4]
    track = name.split("__")[0]
    side_path = os.path.join(AUDIO, "music", f"{track}.json")
    if not os.path.exists(side_path):
        return True, 0.0, 0.0, 0, 4
    side = json.load(open(side_path, encoding="utf-8"))
    g = side.get("godot_import", {})
    return bool(g.get("loop", True)), float(g.get("loop_offset", 0.0)), float(g.get("bpm", 0.0)), int(g.get("beat_count", 0)), int(g.get("bar_beats", 4))


def wav_channels(path: str) -> int:
    import struct
    with open(path, "rb") as f:
        head = f.read(64)
    i = head.find(b"fmt ")
    return struct.unpack("<H", head[i + 10: i + 12])[0] if i >= 0 else 1


def main() -> int:
    written = 0
    for p in sorted(glob.glob(os.path.join(AUDIO, "music", "*.ogg"))):
        loop, off, bpm, beats, bar = music_params(p)
        written += _write(p + ".import", ogg_import(p, loop, off, bpm, beats, bar))
    for p in sorted(glob.glob(os.path.join(AUDIO, "ambience", "*.ogg"))):
        written += _write(p + ".import", ogg_import(p, True, 0.0, 0.0, 0, 4))
    for p in sorted(glob.glob(os.path.join(AUDIO, "sfx", "**", "*.wav"), recursive=True)):
        name = os.path.basename(p)[:-4]
        written += _write(p + ".import", wav_import(p, name in LOOPED_WAVS, wav_channels(p) == 1))
    for p in sorted(glob.glob(os.path.join(AUDIO, "music", "motifs", "*.wav"))):
        written += _write(p + ".import", wav_import(p, False, True))
    print(f"godot_import: {written} .import files written or updated under audio/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
