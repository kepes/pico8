pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../jedi.p8
#include test_lib.lua
function _init()
  local n,tr,b,ta,tb
  cartdata("kepes_desert_jedi_test")
  tcase("22 shake visible for 6 frames")
  arena()
  mk_bolt(g.p.x+4,py,-2,0)
  n=0
  for i=1,30 do step(1) if g.shake>0 then n+=1 end end
  check(n==6,"shake frames: "..n)

  tcase("23 score saturates at 32000")
  arena() g.score=31990
  kill_trooper(mk_trooper(px+36,py),20)
  check(g.score==32000,"score capped: "..g.score)

  tcase("24 death clears swing, no posthumous kills")
  arena() g.p.hp=1 g.p.swing=6
  mk_bolt(g.p.x,g.p.y-2,0,0)
  step(1)
  check(g.p.dead and g.p.swing==0,"swing cleared on death: "..g.p.swing)
  tr=mk_trooper(g.p.x,g.p.y+10)
  step(1)
  check(tr.st~="dead" and g.score==0,"no kill while dying")

  tcase("25 swing deflect, block suspended, parts cap, separation")
  arena() step(1,{[1]=true})
  b=mk_bolt(g.p.x+8,py,-2,0)
  step(3,{[4]=true})
  check(b.owner=="p" and g.p.hp==3,"swing deflects bolt")
  arena() step(1,{[1]=true})
  mk_bolt(g.p.x+4,py,-2,0)
  step(1,{[4]=true,[5]=true})
  check(g.p.hp==2,"block suspended during swing: "..g.p.hp)
  arena() step(1,{[1]=true})
  mk_bolt(g.p.x+4,py,-2,0)
  step(1,{[5]=true})
  check(g.p.hp==3,"same bolt blocked without swing")
  arena()
  spawn_parts(px,py,70,9,10)
  check(#g.parts==60,"parts capped at 60: "..#g.parts)
  arena()
  ta=mk_trooper(px+26,py) tb=mk_trooper(px+30,py)
  step(1)
  check(dist(ta.x,ta.y,tb.x,tb.y)>4,"troopers separated")

  finish()
end
