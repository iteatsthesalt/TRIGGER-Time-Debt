"""Godot's ResourceUID text form, shared by every tool that writes `.import` sidecars (the art pipeline's
sheets and textures, tools/audio/godot_import.py's audio).

Godot 4 prints a uid as `uid://` + the id in base 34, most significant digit first, with the digits a–y (0–24)
then 0–8 (25–33), and ids are positive 63-bit integers. A sidecar written with this text keeps its uid on the
next `godot --import` (Godot re-encodes, and so rewrites, any uid it cannot parse), so a rebuild of the same
path writes identical files and nothing churns in git.
"""
import hashlib

BASE = 34


def encode(n: int) -> str:
    """`uid://…` for a positive 63-bit id."""
    n &= 0x7FFFFFFFFFFFFFFF
    if n == 0:
        n = 1
    txt = ""
    while n:
        c = n % BASE
        txt = (chr(ord("a") + c) if c < 25 else chr(ord("0") + (c - 25))) + txt
        n //= BASE
    return "uid://" + txt


def decode(text: str) -> int:
    """The id of a `uid://…` text, or -1 when Godot would not parse it."""
    body = text[len("uid://"):] if text.startswith("uid://") else text
    if not body:
        return -1
    n = 0
    for ch in body:
        if "a" <= ch <= "y":
            c = ord(ch) - ord("a")
        elif "0" <= ch <= "8":
            c = ord(ch) - ord("0") + 25
        else:
            return -1
        n = n * BASE + c
    return n if 0 < n <= 0x7FFFFFFFFFFFFFFF else -1


def is_canonical(text: str) -> bool:
    """True when `text` is exactly what Godot itself would print for its id."""
    n = decode(text)
    return n > 0 and encode(n) == (text if text.startswith("uid://") else "uid://" + text)


def godot_uid(res_path: str) -> str:
    """A stable uid for a `res://` path: a 63-bit hash of the path, in Godot's text form."""
    return encode(int.from_bytes(hashlib.sha1(res_path.encode()).digest()[:8], "big"))
