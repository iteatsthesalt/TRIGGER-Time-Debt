#!/usr/bin/env bash
# Full check: import, parse every script, run the headless tests, lint the data, play the three headless probes,
# smoke-boot the game and capture screenshots.
# Usage: tools/check.sh [--no-visual] [--quick]
#   --no-visual  skip the windowed smoke boot and captures (a cloud container without xvfb, data/system work)
#   --quick      import, parse and unit tests only (no lint, no tool tests, no probes)
# Every step decides the verdict: a failed or timed-out import, a parse error, a failing test (GDScript suites or
# tools/build/test_tools.py), a lint error, a probe that does not print `PROBE_END ok=true`, or an error in a
# smoke or capture log ends in CHECKS FAILED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if ! command -v godot >/dev/null 2>&1 && [ -x "$ROOT/.tools/bin/godot" ]; then
  export PATH="$ROOT/.tools/bin:$PATH"
fi
if ! command -v godot >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source tools/setup_godot.sh >/dev/null
fi
if ! command -v godot >/dev/null 2>&1; then
  echo "godot is not on PATH and tools/setup_godot.sh could not provide it"
  echo
  echo "CHECKS FAILED"
  exit 1
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
timeout 600 godot --headless --path . --import > /tmp/check_import.log 2>&1
IMPORT_RC=$?
# "editor/import" lines are the editor's own progress noise, not import failures
IMPORT_ERRORS="$(grep -E "SCRIPT ERROR|Parse Error|ERROR: " /tmp/check_import.log | grep -v "editor/import" | head -20)"
if [ -n "$IMPORT_ERRORS" ]; then echo "$IMPORT_ERRORS"; fi
if [ "$IMPORT_RC" = 124 ]; then echo "IMPORT: FAIL (timed out after 600 s)"; FAIL=1
elif [ "$IMPORT_RC" != 0 ]; then echo "IMPORT: FAIL (rc=$IMPORT_RC)"; FAIL=1
elif [ -n "$IMPORT_ERRORS" ]; then echo "IMPORT: FAIL (errors in the import log)"; FAIL=1
else echo "IMPORT: OK"; fi

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

  step "tool tests"
  if python3 tools/build/test_tools.py > /tmp/check_tool_tests.log 2>&1; then
    echo "TOOL TESTS: OK ($(grep -E "^Ran " /tmp/check_tool_tests.log))"
  else
    tail -30 /tmp/check_tool_tests.log; echo "TOOL TESTS: FAIL"; FAIL=1
  fi

  # The headless probes play the game without a window (no GPU needed; README "Headless probes"). Each must
  # end with `PROBE_END ok=true`: a stall, a lost battle or a timeout prints ok=false (or nothing) and fails.
  probe() {
    local name="$1" limit="$2"; shift 2
    local log="/tmp/check_probe_${name}.log"
    timeout "$limit" godot --headless --path . --script "res://tools/build/${name}.gd" -- "$@" > "$log" 2>&1
    local rc=$?
    local verdict
    verdict="$(grep -E "^PROBE_END" "$log" | tail -1)"
    echo "$name: ${verdict:-no PROBE_END line} (rc=$rc)"
    if [ "$rc" = 124 ]; then echo "  timed out after $limit s; the log is $log"; fi
    if [ "$rc" != 0 ] || ! grep -qE "^PROBE_END ok=true" "$log"; then
      grep -E "PROBE (STALL|FAIL)|SCRIPT ERROR" "$log" | head -10
      FAIL=1
    fi
  }
  step "headless probes"
  probe prologue_probe 600 --autobattle
  probe ch1_probe 900 --autobattle
  probe battle_probe 600 --scene=test_arena --autobattle --boss=atrium_cradle --party=crono,sera,marle --level=4
fi

if [ "$VISUAL" = 1 ]; then
  step "smoke boot (600 frames, software Vulkan)"
  mkdir -p /tmp/captures
  # Godot is a native executable: under Git Bash it needs the Windows spelling of /tmp/captures.
  CAP_DIR=/tmp/captures
  if command -v cygpath >/dev/null 2>&1; then CAP_DIR="$(cygpath -m /tmp/captures)"; fi
  if command -v xvfb-run >/dev/null 2>&1; then
    timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --audio-driver Dummy \
      --resolution 1280x720 --script res://tools/capture/smoke.gd -- --frames=600 --out="$CAP_DIR" > /tmp/check_smoke.log 2>&1
  else
    # A desktop with a real GPU (Nich's Windows machine): run the window directly.
    timeout 900 godot --path . --rendering-driver vulkan --audio-driver Dummy \
      --resolution 1280x720 --script res://tools/capture/smoke.gd -- --frames=600 --out="$CAP_DIR" > /tmp/check_smoke.log 2>&1
  fi
  SMOKE_RC=$?
  # "resources still in use at exit" is the known-harmless ObjectDB leak report (PROGRESS known issues)
  if grep -E "SCRIPT ERROR|ERROR:" /tmp/check_smoke.log | grep -v "lavapipe\|llvmpipe\|resources still in use at exit" | head -20; then
    echo "SMOKE: errors in log"; FAIL=1
  fi
  if [ "$SMOKE_RC" != 0 ]; then echo "SMOKE: FAIL (rc=$SMOKE_RC)"; FAIL=1; else echo "SMOKE: OK"; fi

  # Two short scene captures, so a Location, the ActorSprite sheets and the compositor are rendered by every
  # check (the boot above only reaches the title): the character lineup and an arena battle. Look at them.
  capture() {
    local scene="$1" frames="$2"; shift 2
    local log="/tmp/check_capture_${scene}.log" rc
    local run=(godot)
    if command -v xvfb-run >/dev/null 2>&1; then run=(xvfb-run -a -s "-screen 0 1280x720x24" godot); fi
    timeout 900 "${run[@]}" --path . --rendering-driver vulkan --audio-driver Dummy --resolution 1280x720 \
      --script res://tools/capture/smoke.gd -- --frames="$frames" --every="$frames" --scene="$scene" \
      --prefix="check_${scene}" --out="$CAP_DIR" "$@" > "$log" 2>&1
    rc=$?
    if grep -E "SCRIPT ERROR|ERROR:" "$log" | grep -v "lavapipe\|llvmpipe\|resources still in use at exit" | head -20; then
      echo "CAPTURE $scene: errors in log"; FAIL=1
    fi
    if [ "$rc" != 0 ] || ! grep -q "SMOKE_OK" "$log"; then echo "CAPTURE $scene: FAIL (rc=$rc)"; FAIL=1
    else echo "CAPTURE $scene: OK ($(grep -c "^captured" "$log") png)"; fi
  }
  step "scene captures (lineup, arena battle)"
  capture test_lineup 60 --ids=crono,sera,krona,marle --anim=walk
  capture test_arena 120 --autobattle --party=crono,sera,marle --level=4
  ls -la /tmp/captures 2>/dev/null | tail -5
fi

echo
if [ "$FAIL" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit $FAIL
