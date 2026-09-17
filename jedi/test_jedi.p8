pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include jedi.p8
#include test_lib.lua
function _init()
  cartdata("kepes_desert_jedi_test")
  tcase("1 move right + clamp")
  arena() local x0=g.p.x
  step(5,{[1]=true}) check(g.p.x>x0,"x should grow")
  step(200,{[1]=true}) check(g.p.x<=508,"x clamp 508: "..g.p.x)
  check(g.p.x>=504,"x reached right edge: "..g.p.x)
  check(g.p.fx==1 and g.p.fy==0,"facing right")
  step(200,{[2]=true}) check(g.p.y==12,"y clamp 12: "..g.p.y)
  step(500,{[0]=true,[3]=true}) check(g.p.x==4 and g.p.y==508,"lower-left clamp "..g.p.x..","..g.p.y)

  tcase("2 facing")
  arena()
  check(g.p.fx==0 and g.p.fy==1,"starts facing down")
  step(1,{[0]=true}) check(g.p.fx==-1 and g.p.fy==0,"left")
  step(1,{[0]=true,[2]=true}) check(g.p.fx==-1 and g.p.fy==0,"held left stays while up added")
  step(1,{[2]=true}) check(g.p.fx==0 and g.p.fy==-1,"up after left released")
  step(1,{[3]=true}) check(g.p.fx==0 and g.p.fy==1,"down")
  step(1,{}) check(g.p.fx==0 and g.p.fy==1,"facing kept when idle")

  tcase("3 rock collision slides")
  arena() g.rocks={big_rock}
  step(20,{[1]=true})
  check(g.p.x<px+3 and g.p.x>=px,"blocked before rock x: "..g.p.x)
  check(g.p.y==py,"y unchanged: "..g.p.y)
  step(4,{[1]=true,[3]=true})
  check(g.p.x<px+3,"still blocked in x: "..g.p.x)
  check(g.p.y>py+3,"slid down along rock: "..g.p.y)
  step(20,{[1]=true,[3]=true})
  check(g.p.x>px+6,"passes rock after sliding below: "..g.p.x)

  tcase("4 spawn, approach, stop, telegraph, fire")
  fresh() g.rocks={}
  check(#g.troopers==0,"no trooper before first frame")
  step(1)
  check(#g.troopers==1,"spawned on first frame")
  local tr=g.troopers[1]
  check(not in_view(tr.x,tr.y,0) and in_world(tr.x,tr.y),"spawned off view, in world "..tr.x..","..tr.y)
  check(tr.spd==0.5,"spd0 "..tr.spd)
  check(tr.stop>=56 and tr.stop<68,"stop range "..tr.stop)
  g.troopers={} g.spawn_cd=32000
  tr=mk_trooper(px+46,py)
  step(10)
  check(tr.x<px+46 and tr.x>=px+40,"approaches: "..tr.x)
  local n=0
  while tr.st=="walk" and n<100 do step(1) n+=1 end
  check(tr.st=="aim","reached aim")
  check(tr.t==12,"telegraph 12 frames: "..tr.t)
  check(dist(tr.x,tr.y,g.p.x,g.p.y)<=30.5,"stopped at stop dist")
  local tx=tr.x
  step(11) check(#g.bolts==0 and tr.x==tx,"no bolt yet, stands still")
  step(1)
  check(#g.bolts==1,"fired after telegraph")
  check(g.bolts[1].owner=="e" and g.bolts[1].dx<0,"enemy bolt toward player")
  check(tr.stop==24,"stop shrinks by 6: "..tr.stop)
  check(tr.t>=45 and tr.t<=75,"shot cooldown set: "..tr.t)
  -- player walks away -> back to walk
  step(60,{[0]=true,[5]=true})
  check(tr.st=="walk","re-walks when player leaves")

  tcase("5 enemy bolt hit -> hp-1, inv")
  arena()
  mk_bolt(px+16,py,-2,0)
  step(10)
  check(g.p.hp==2,"hp 2: "..g.p.hp)
  check(g.p.inv>30,"inv set: "..g.p.inv)
  check(#g.bolts==0,"bolt consumed")
  check(g.shake>0,"shake happened")

  tcase("6 block in cone deflects")
  arena() step(1,{[1]=true})
  local b=mk_bolt(g.p.x+16,py,-2,0)
  step(8,{[5]=true})
  check(g.p.hp==3,"no damage")
  check(#g.bolts==1 and b.owner=="p","deflected owner p")
  check(abs(dist(0,0,b.dx,b.dy)-2.5)<0.01 and b.dx>2.4,"reversed at 2.5: "..b.dx..","..b.dy)
  check(b.x>g.p.x,"flying away")
  arena() step(1,{[1]=true})
  local src=mk_trooper(g.p.x+16,py+22) src.st="aim" src.t=100
  b=mk_bolt(g.p.x+16,py,-2,0) b.src=src
  step(8,{[5]=true})
  check(b.owner=="p" and g.p.hp==3,"deflected with live src")
  check(b.dx>0 and b.dy>0,"homes on shooter: "..b.dx..","..b.dy)
  check(abs(dist(0,0,b.dx,b.dy)-2.5)<0.01,"speed 2.5")
  finish()
end
