#!/usr/bin/env bash
# Re-import then capture a scene: tools/capture/render.sh <scene_id> <prefix> [frames] [extra args...]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
SCENE="${1:-test_diorama}"; PREFIX="${2:-shot}"; FRAMES="${3:-30}"; shift 3 2>/dev/null || shift $#
mkdir -p /tmp/captures
timeout 300 godot --headless --path . --import > /tmp/import.log 2>&1
grep -E "SCRIPT ERROR|Parse Error|compile" /tmp/import.log | head -5
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --audio-driver Dummy --resolution 1280x720 \
  --script res://tools/capture/smoke.gd -- --frames="$FRAMES" --every="$FRAMES" --scene="$SCENE" --prefix="$PREFIX" "$@" 2>&1 \
  | grep -E "SCRIPT ERROR|ERROR|captured|SMOKE" | grep -v "lavapipe" | head -10
