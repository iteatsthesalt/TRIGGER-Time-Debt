#!/usr/bin/env bash
# Re-import then capture a scene:
#   tools/capture/render.sh [scene_id] [prefix] [frames] [-- extra args...]
# Up to three positionals (defaults test_diorama, shot, 30), then an optional `--` and the arguments passed to the
# game (e.g. `-- --ids=crono --anim=walk`); the `--` may come after any of the positionals.
# RENDER_DRY_RUN=1 prints the smoke arguments it would pass and stops (tools/build/test_tools.py checks it).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
POS=()
while [ $# -gt 0 ] && [ "$1" != "--" ] && [ "${#POS[@]}" -lt 3 ]; do
  POS+=("$1"); shift
done
if [ $# -gt 0 ] && [ "$1" = "--" ]; then shift; fi
SCENE="${POS[0]:-test_diorama}"; PREFIX="${POS[1]:-shot}"; FRAMES="${POS[2]:-30}"
case "$FRAMES" in
  ''|*[!0-9]*) echo "render.sh: frames must be a positive number, got '$FRAMES'" >&2; exit 2 ;;
esac
if [ "$FRAMES" -lt 1 ]; then echo "render.sh: frames must be at least 1" >&2; exit 2; fi
SMOKE_ARGS=(--frames="$FRAMES" --every="$FRAMES" --scene="$SCENE" --prefix="$PREFIX")
if [ "${RENDER_DRY_RUN:-0}" = 1 ]; then echo "${SMOKE_ARGS[*]} $*"; exit 0; fi
mkdir -p /tmp/captures
# Godot is a native executable: under Git Bash it needs the Windows spelling of /tmp/captures.
CAP_DIR=/tmp/captures
if command -v cygpath >/dev/null 2>&1; then CAP_DIR="$(cygpath -m /tmp/captures)"; fi
timeout 300 godot --headless --path . --import > /tmp/import.log 2>&1
grep -E "SCRIPT ERROR|Parse Error|compile" /tmp/import.log | head -5
if command -v xvfb-run >/dev/null 2>&1; then
  RUN=(xvfb-run -a -s "-screen 0 1280x720x24" godot)
else
  RUN=(godot)  # a desktop with a real GPU: run the window directly
fi
timeout 900 "${RUN[@]}" --path . --rendering-driver vulkan --audio-driver Dummy --resolution 1280x720 \
  --script res://tools/capture/smoke.gd -- "${SMOKE_ARGS[@]}" --out="$CAP_DIR" "$@" 2>&1 \
  | grep -E "SCRIPT ERROR|ERROR|captured|SMOKE" | grep -v "lavapipe\|resources still in use at exit" | head -10
