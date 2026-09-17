pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../jedi.p8
#include test_lib.lua
function _init()
  local tr,n
  cartdata("kepes_desert_jedi_test")
  tcase("7 block from behind -> hp-1")
  arena() step(1,{[1]=true})
  mk_bolt(g.p.x-16,py,2,0)
  step(10,{[5]=true})
  check(g.p.hp==2,"hit from behind: "..g.p.hp)
  check(#g.bolts==0,"bolt consumed")

  tcase("8 deflected bolt kills, 90 frames")
  arena()
  tr=mk_trooper(px+36,py)
  mk_bolt(px+16,py,2.5,0,"p")
  n=0
  while tr.st~="dead" and n<20 do step(1) n+=1 end
  check(tr.st=="dead","trooper dead")
  check(g.score==20,"score 20: "..g.score)
  check(g.kills==1,"kills 1: "..g.kills)
  check(#g.bolts==0,"bolt gone")
  check(tr.t==90,"dead timer 90 after kill frame: "..tr.t)
  step(89)
  check(#g.troopers==1 and tr.t==1,"still lying")
  step(1)
  check(#g.troopers==0,"removed after 90 frames")
  check(alive_count()==0,"alive_count 0")

  tcase("9 swing kills in front only")
  arena() step(1,{[1]=true})
  local ta=mk_trooper(g.p.x+10,py)
  local tb=mk_trooper(g.p.x-10,py)
  step(1,{[4]=true})
  check(g.p.swing==8,"swing started")
  check(ta.st~="dead","no kill on frame 1 (window 3..7)")
  step(1)
  check(ta.st=="dead","front trooper killed")
  check(tb.st~="dead","back trooper alive")
  check(g.score==10,"score 10: "..g.score)
  check(g.kills==1,"kills 1: "..g.kills)
  step(8)
  check(g.score==10,"no double kill")
  check(g.p.swing==0 and g.p.cd>0,"cooldown after swing")

  tcase("10 max_alive ramp")
  fresh() g.rocks={}
  check(max_alive()==1,"0s -> 1")
  local worst=0
  g.p.hp=999
  for i=1,599 do step(1,{[5]=true}) worst=max(worst,alive_count()) end
  check(worst<=1,"never >1 in first 20s: "..worst)
  g.frames=600 check(max_alive()==2,"20s -> 2")
  g.frames=6000 check(max_alive()==8,"200s -> 8")
  g.spawn_cd=0
  for i=1,120 do step(1,{[5]=true}) end
  check(alive_count()>=2,"more troopers at 200s: "..alive_count())
  check(alive_count()<=8,"cap 8")

  tcase("11 game over + retry")
  arena() g.p.hp=1 g.score=50
  mk_bolt(px+16,py,-2,0)
  step(10)
  check(g.p.hp==0 and g.p.dead,"dead")
  check(g.state=="play","dying still in play")
  step(40)
  check(g.state=="over","state over")
  check(g.best==50 and dget(0)==50 and g.newbest,"best saved")
  step(5)
  check(g.state=="over","stays frozen")
  step(1,{[4]=true})
  check(g.state=="play","retry -> play")
  check(g.score==0 and g.p.hp==3 and g.best==50,"reset score/hp keep best")
  g.state="title"
  step(1) step(1,{[4]=true})
  check(g.state=="play","title -> play on o")
  finish()
end
