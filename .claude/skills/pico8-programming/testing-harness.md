# Headless test harness for PICO-8 carts

## Layout

```
<game>/<game>.p8            the game; input only via btn()/btnp(); a thin _init calling new_game()
<game>/tests/test_lib.lua   shared harness (below)
<game>/tests/test_*.p8      one cart per group: #include ../<game>.p8, #include test_lib.lua, then tests in _init
<game>/tests/run_tests.sh   loops over test_*.p8, greps results, runs shrinko8 --count / --lint
```

Split tests into several carts as soon as one approaches the 8192-token limit (the included game counts; a 5000-token game leaves ~900 tokens of test code per cart).

## test_lib.lua

```lua
-- stubs: the game must read input only through btn/btnp
local keys,prev={},{}
function btn(i) return keys[i]==true end
function btnp(i) return keys[i]==true and prev[i]~=true end
music_log,sfx_log={},{}
function music(n) add(music_log,n) end
function sfx(n) add(sfx_log,n) end

local game_update,game_draw=_update,_draw   -- capture before overriding
ok,fail=0,0
local cur="?"
function tcase(name) cur=name end            -- never name this t(): t() is built in
function check(cond,msg)
  if cond then ok+=1 else fail+=1 printh("FAIL: "..cur.." - "..(msg or "")) end
end
function step(n,k)                           -- run n frames with keys k held
  for i=1,n do
    keys=k or {}
    game_update()
    game_draw()                              -- draw too, so draw-code errors surface
    prev={} for j=0,5 do prev[j]=keys[j] end
  end
end
function fresh(seed) srand(seed or 1) new_game() g.state="play" end  -- new_game() may set the state itself; setting it again is harmless
function finish() printh("TESTS DONE ok="..ok.." fail="..fail) extcmd("shutdown") end
function _update() end
function _draw() end
```

## A test cart

```lua
pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../game.p8
#include test_lib.lua
function _init()
  cartdata("game_tests")            -- once per run, test-only key
  tcase("move right") fresh() local x0=g.p.x step(5,{[1]=true}) check(g.p.x>x0,"x grew")
  finish()
end
```

Button indices: 0 ⬅️ 1 ➡️ 2 ⬆️ 3 ⬇️ 4 🅾️ 5 ❎.

## run_tests.sh core

```bash
cd "$(dirname "$0")"; P8=/Applications/PICO-8.app/Contents/MacOS/pico8; rc=0
for t in test_*.p8; do
  out=$(perl -e 'alarm 90; exec @ARGV' -- "$P8" -x "$t" 2>&1); code=$?
  echo "$out" | grep -v '^RUNNING:'
  [ $code -ne 0 ] && { echo "!! exit $code (timeout ⇒ syntax error / too large)"; rc=1; }
  echo "$out" | grep -qiE 'syntax error|runtime error|program too large' && rc=1
  echo "$out" | grep -q '^FAIL:' && rc=1
  echo "$out" | grep -q 'TESTS DONE ok=[0-9]* fail=0$' || rc=1
done
uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8 ../game.p8 --count
exit $rc
```

## Screenshot / playtest helper carts

Copy the game next to the helper (or use `../game.p8`), `#include` it, stub `btn`/`btnp`, drive frames from your own `_update`, call `extcmd("screen")`, then get the data sections in — either **append them** to the helper cart, or load them at runtime with `reload(dest, src, len, "../game.p8")` (e.g. `reload(0x0000,0x0000,0x3000,"../game.p8")` copies gfx + map; `0x3100,0x3100,0x1200` copies sfx + music). Test carts use the `reload` form because it needs no file surgery:

```bash
sed -n '/^__gfx__$/,$p' game.p8 >> helper.p8
perl -e 'alarm 60; exec @ARGV' -- "$P8" -desktop shots -x helper.p8
```

Bot playtests (scripted strategies over thousands of frames) fit the same harness; measure with `stat(1)` for CPU load and `printh` tables.
