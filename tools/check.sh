#!/usr/bin/env bash
# Full check: import, parse every script, run the headless tests, smoke-boot the game, capture screenshots.
# Usage: tools/check.sh [--no-visual] [--quick]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if ! command -v godot >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source tools/setup_godot.sh >/dev/null
fi
VISUAL=1
QUICK=0
for a in "$@"; do
  case "$a" in
    --no-visual) VISUAL=0 ;;
    --quick) QUICK=1 ;;
  esac
done
FAIL=0
step() { echo; echo "=== $* ==="; }

step "import"
timeout 600 godot --headless --path . --import > /tmp/check_import.log 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error|ERROR: " /tmp/check_import.log | grep -v "editor/import" | head -20; then
  echo "(import log had errors above)"
fi

step "parse every script"
timeout 300 godot --headless --path . --script res://tools/build/parse_all.gd > /tmp/check_parse.log 2>&1
PARSE_RC=$?
grep -E "SCRIPT ERROR|PARSE FAIL|Parse Error" /tmp/check_parse.log | head -40
if [ "$PARSE_RC" != 0 ] || grep -qE "SCRIPT ERROR|Parse Error" /tmp/check_parse.log; then echo "PARSE: FAIL"; FAIL=1; else echo "PARSE: OK"; fi

step "unit tests"
timeout 900 godot --headless --path . --script res://tests/run_tests.gd > /tmp/check_tests.log 2>&1
TEST_RC=$?
grep -E "FAIL|passed|SCRIPT ERROR" /tmp/check_tests.log | tail -40
if [ "$TEST_RC" != 0 ]; then echo "TESTS: FAIL (rc=$TEST_RC)"; FAIL=1; else echo "TESTS: OK"; fi

if [ "$QUICK" = 0 ]; then
  step "data lint"
  python3 tools/build/lint_data.py || FAIL=1
fi

if [ "$VISUAL" = 1 ]; then
  step "smoke boot (600 frames, software Vulkan)"
  mkdir -p /tmp/captures
  timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --audio-driver Dummy \
    --resolution 1280x720 --script res://tools/capture/smoke.gd -- --frames=600 > /tmp/check_smoke.log 2>&1
  SMOKE_RC=$?
  if grep -E "SCRIPT ERROR|ERROR:" /tmp/check_smoke.log | grep -v "lavapipe\|llvmpipe" | head -20; then
    echo "SMOKE: errors in log"; FAIL=1
  fi
  if [ "$SMOKE_RC" != 0 ]; then echo "SMOKE: FAIL (rc=$SMOKE_RC)"; FAIL=1; else echo "SMOKE: OK"; fi
  ls -la /tmp/captures 2>/dev/null | tail -5
fi

echo
if [ "$FAIL" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit $FAIL
