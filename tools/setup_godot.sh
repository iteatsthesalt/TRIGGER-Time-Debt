#!/usr/bin/env bash
# Downloads Godot 4.7.2 (Linux, x86_64) into .tools/ so a fresh machine can build and test.
# Usage:  source tools/setup_godot.sh      (then run: godot --headless --version)
#         bash tools/setup_godot.sh        (download only; put .tools/bin on PATH yourself)
# Sourced, it must not change the caller's shell options (tools/check.sh runs without errexit and reads every
# step's result itself), so it sets no `set -e` and returns non-zero from the one function below on failure.
_trigger_setup_godot() {
  local version="${GODOT_VERSION:-4.7.2}"
  local root dest bin url
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || return 1
  dest="$root/.tools/godot-$version"
  bin="$dest/Godot_v${version}-stable_linux.x86_64"
  if [ ! -x "$bin" ]; then
    mkdir -p "$dest" || return 1
    url="https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip"
    echo "Downloading Godot $version ..."
    curl -fsSL "$url" -o "$dest/godot.zip" || { echo "setup_godot: download failed ($url)" >&2; return 1; }
    (cd "$dest" && unzip -q -o godot.zip && rm godot.zip) || { echo "setup_godot: unzip failed" >&2; return 1; }
    chmod +x "$bin" || return 1
  fi
  mkdir -p "$root/.tools/bin" || return 1
  ln -sf "$bin" "$root/.tools/bin/godot" || return 1
  export PATH="$root/.tools/bin:$PATH"
  echo "Godot ready: $("$bin" --headless --version 2>/dev/null | tail -1)"
}
_trigger_setup_godot
_trigger_setup_godot_rc=$?
unset -f _trigger_setup_godot
# `return` works when sourced; executed as a script it fails and `exit` runs instead
return "$_trigger_setup_godot_rc" 2>/dev/null || exit "$_trigger_setup_godot_rc"
