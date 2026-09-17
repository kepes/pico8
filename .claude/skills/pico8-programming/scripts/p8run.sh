#!/usr/bin/env bash
# Run a PICO-8 cart headlessly with a timeout and fail on Lua errors.
# Usage: p8run.sh [-t SECONDS] [-d SCREENSHOT_DIR] cart.p8
#   -t  timeout in seconds (default 60). A syntax error hangs pico8, so this is mandatory.
#   -d  directory for extcmd("screen") PNGs (passed as -desktop)
# Exit codes: 0 = clean run (cart called extcmd("shutdown") or ended)
#             1 = Lua error / include error / cart too large (see output)
#           142 = timeout (normal for carts that never call shutdown)
set -u
P8="${PICO8:-/Applications/PICO-8.app/Contents/MacOS/pico8}"
t=60; shots=""
while getopts "t:d:" o; do case $o in t) t=$OPTARG;; d) shots=$OPTARG;; *) exit 2;; esac; done
shift $((OPTIND-1)); cart="${1:?usage: p8run.sh [-t SECONDS] [-d DIR] cart.p8}"
args=(); [ -n "$shots" ] && { mkdir -p "$shots"; args+=(-desktop "$shots"); }
out=$(perl -e "alarm $t; exec @ARGV" -- "$P8" ${args[@]+"${args[@]}"} -x "$cart" 2>&1); code=$?   # bash 3.2 + set -u safe
echo "$out"
if echo "$out" | grep -qiE 'syntax error|runtime error|program too large|could not #include|could not load'; then
  echo "p8run: lua/cart error detected" >&2; exit 1
fi
exit $code
