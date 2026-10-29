#!/usr/bin/env bash
# Downloads Godot 4.7.2 (Linux, x86_64) into .tools/ so a fresh machine can build and test.
# Usage:  source tools/setup_godot.sh      (then run: godot --headless --version)
set -euo pipefail
VERSION="${GODOT_VERSION:-4.7.2}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.tools/godot-$VERSION"
BIN="$DEST/Godot_v${VERSION}-stable_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$DEST"
  URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip"
  echo "Downloading Godot $VERSION ..."
  curl -fsSL "$URL" -o "$DEST/godot.zip"
  (cd "$DEST" && unzip -q -o godot.zip && rm godot.zip)
  chmod +x "$BIN"
fi
mkdir -p "$ROOT/.tools/bin"
ln -sf "$BIN" "$ROOT/.tools/bin/godot"
export PATH="$ROOT/.tools/bin:$PATH"
echo "Godot ready: $("$BIN" --headless --version 2>/dev/null | tail -1)"
