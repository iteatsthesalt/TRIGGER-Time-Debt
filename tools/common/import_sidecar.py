"""The Godot `.import` sidecar of an image, shared by every image writer (the art pipeline's sheets,
tools/art/pipeline/pixellab_import.py, and its world textures, tools/art/import_texture.py), so a change to how a
uid is kept or minted lands for both. Each caller passes its own template (the two differ only in
mipmaps/generate) and the project root.
"""
import hashlib
import os

from godot_uid import godot_uid, is_canonical


def existing_uid(import_path):
    """The `uid://...` text of an existing sidecar, or None (no file, or no uid line)."""
    if not os.path.exists(import_path):
        return None
    with open(import_path) as f:
        for line in f:
            if line.startswith("uid="):
                return line.strip()[len("uid="):].strip('"')
    return None


def write_import(png_path, template, root, normal=False):
    """Write `<png_path>.import` from `template` ({uid}, {name}, {md5}, {rel}, {normal}). The uid of an existing
    sidecar is kept when it is one Godot itself would print (its own, after an import); a missing one, or one
    Godot cannot parse (it would re-mint it at random on the next import, and the sidecar would churn), becomes
    the path's stable uid (tools/common/godot_uid.py), which the next `--import` keeps."""
    rel = os.path.relpath(png_path, root).replace(os.sep, "/")
    imp = png_path + ".import"
    uid = existing_uid(imp)
    if uid is None or not is_canonical(uid):
        uid = godot_uid("res://" + rel)
    md5 = hashlib.md5(("res://" + rel).encode()).hexdigest()
    with open(imp, "w") as f:
        f.write(template.format(uid=uid[len("uid://"):], name=os.path.basename(png_path), md5=md5, rel=rel,
                                normal=1 if normal else 0))
