#!/usr/bin/env bash
# Re-import then capture a scene: tools/capture/render.sh <scene_id> <prefix> [frames] [extra args...]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
SCENE="${1:-test_diorama}"; PREFIX="${2:-shot}"; FRAMES="${3:-30}"; shift 3 2>/dev/null || shift $#
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
  --script res://tools/capture/smoke.gd -- --frames="$FRAMES" --every="$FRAMES" --scene="$SCENE" --prefix="$PREFIX" --out="$CAP_DIR" "$@" 2>&1 \
  | grep -E "SCRIPT ERROR|ERROR|captured|SMOKE" | grep -v "lavapipe\|resources still in use at exit" | head -10
