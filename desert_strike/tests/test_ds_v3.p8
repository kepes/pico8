pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../desert_strike.p8
#include test_lib.lua
-- true if s is one of the entries of list
function has(list,s)
  for v in all(list) do if v==s then return true end end
  return false
end
function _init()
  local seen,bad,n,miss
  cartdata("kepes_desert_strike_test")
  tcase("v3-1 rock variants: allowed set, all six used")
  seen,bad,n={},0,0
  for seed=1,3 do
    fresh(seed)
    for r in all(g.rocks) do
      n+=1
      if has(r.big and rock_big_s or rock_small_s,r.s) then seen[r.s]=true else bad+=1 end
    end
  end
  check(n>=100,"at least 100 rocks over 3 seeds: "..n)
  check(bad==0,"rock s outside the variant table: "..bad)
  miss=0
  for s in all({32,8,9,33,12,14}) do if not seen[s] then miss+=1 end end
  check(miss==0,"every rock variant used, missing: "..miss)

  tcase("v3-2 decor variants: allowed set, all twelve used")
  seen,bad,n={},0,0
  for seed=1,3 do
    fresh(seed)
    for d in all(g.decor) do
      n+=1
      local ok=false
      for v in all(decor_s) do if has(v,d.s) then ok=true end end
      if ok then seen[d.s]=true else bad+=1 end
    end
  end
  check(n>=100,"at least 100 decor over 3 seeds: "..n)
  check(bad==0,"decor s outside the variant table: "..bad)
  miss=0
  for v in all(decor_s) do for s in all(v) do if not seen[s] then miss+=1 end end end
  check(miss==0,"every decor variant used, missing: "..miss)
  check(#decor_s==4 and #rock_small_s==3 and #rock_big_s==3,"table sizes")

  tcase("v3-3 worm: 20 s gate, tremor at 300 still")
  arena() local w=g.worm
  g.frames=30*19 step(320)
  check(w.st=="idle","no tremor from 19 s + 320 frames: "..w.st)
  check(w.still==290,"still counts only from 20 s: "..w.still)
  arena() w=g.worm
  g.frames=30*20 step(299)
  check(w.st=="idle","idle at 299 still")
  step(1)
  check(w.st=="tremor" and w.t==90,"tremor at 20 s + 300 frames: "..w.st)

  tcase("v3-4 title image: px9 cache and draw_title")
  -- #include pulls in lua only: fetch the px9 map rows from the game cart
  reload(0x1000,0x1000,0x2000,"../desert_strike.p8")
  memset(0x8000,0,0x400)
  load_title()
  seen,n={},0
  for k=0,0x3ff do
    local b=peek(0x8000+k)
    if not seen[b] then seen[b]=true n+=1 end
  end
  check(n>=8,"distinct byte values in the first 1024 cache bytes: "..n)
  fresh() g.state="title"
  cls(0)
  draw_title()
  bad=0
  for k=0,63 do if peek(0x6000+k)~=peek(0x8000+k) then bad+=1 end end
  check(bad==0,"screen row 0 differs from the cache in "..bad.." bytes")
  finish()
end
