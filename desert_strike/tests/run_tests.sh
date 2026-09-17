#!/usr/bin/env bash
# Desert Strike - headless tests + PICO-8 limit checks. Exit code 0 = green.
# Usage: bash desert_strike/tests/run_tests.sh   (from anywhere; the script cds into its own folder)
# The tests are split over several carts (test_ds*.p8, shared test_lib.lua) because
# every cart pulls in the whole game code (#include ../desert_strike.p8) and the PICO-8
# 8192-token limit applies per cart. The game: ../desert_strike.p8
set -u
cd "$(dirname "$0")"
P8="/Applications/PICO-8.app/Contents/MacOS/pico8"
SHRINKO=(uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8)
rc=0
tot_ok=0; tot_fail=0
for t in test_ds*.p8; do
  echo "== headless tests: $t =="
  out=$(perl -e 'alarm 90; exec @ARGV' -- "$P8" -x "$t" 2>&1); code=$?
  echo "$out" | grep -vE "^RUNNING: "
  if [ $code -ne 0 ]; then echo "!! pico8 exit code $code (timeout = probably a syntax error / cart too large)"; rc=1; fi
  echo "$out" | grep -qiE "syntax error|runtime error|program too large" && { echo "!! lua error"; rc=1; }
  echo "$out" | grep -q "^FAIL:" && { echo "!! failing tests"; rc=1; }
  done_line=$(echo "$out" | grep -o "TESTS DONE ok=[0-9]* fail=[0-9]*$")
  [ -z "$done_line" ] && { echo "!! no clean TESTS DONE line"; rc=1; }
  n_ok=$(echo "$done_line" | sed -n 's/.*ok=\([0-9]*\).*/\1/p'); n_fail=$(echo "$done_line" | sed -n 's/.*fail=\([0-9]*\)$/\1/p')
  tot_ok=$((tot_ok + ${n_ok:-0})); tot_fail=$((tot_fail + ${n_fail:-0}))
  [ "${n_fail:-1}" -ne 0 ] && rc=1
done
echo "== TOTAL ok=$tot_ok fail=$tot_fail =="
echo "== shrinko8 count =="
cnt=$("${SHRINKO[@]}" ../desert_strike.p8 --count 2>&1); echo "$cnt"
tok=$(echo "$cnt" | sed -n 's/^tokens: \([0-9]*\).*/\1/p')
[ -z "$tok" ] && { echo "!! could not parse token count"; rc=1; }
[ -n "$tok" ] && [ "$tok" -gt 8192 ] && { echo "!! token limit exceeded"; rc=1; }
echo "== shrinko8 lint (non-blocking) =="
"${SHRINKO[@]}" ../desert_strike.p8 --lint 2>&1 | head -40
[ $rc -eq 0 ] && echo "ALL GREEN" || echo "RED"
exit $rc
