pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include jedi.p8
-- ---- harness ----
local game_update,game_draw=_update,_draw
local keys,prev={},{}
function btn(i) return keys[i]==true end
function btnp(i) return keys[i]==true and prev[i]~=true end
local ok,fail=0,0
local cur="?"
function tcase(name) cur=name end
function check(cond,msg)
  if cond then ok+=1 else fail+=1 printh("FAIL: "..cur.." - "..(msg or "")) end
end
function step(n,k)
  for i=1,n do
    keys=k or {}
    game_update()
    game_draw()
    prev={} for j=0,5 do prev[j]=keys[j] end
  end
end
function fresh(seed)
  srand(seed or 1)
  new_game()
  g.state="play"
end
-- deterministic arena: no rocks, no automatic spawns
function arena()
  fresh()
  g.rocks={}
  g.spawn_cd=32000
end
function mk_trooper(x,y)
  local tr={x=x,y=y,spd=0.5,stop=30,st="walk",t=0,shot_cd=0,flip=true,anim=0,stuck=0,side_t=0,side_dir=1}
  add(g.troopers,tr)
  return tr
end
function mk_bolt(x,y,dx,dy,owner)
  local b={x=x,y=y,dx=dx,dy=dy,owner=owner or "e"}
  add(g.bolts,b)
  return b
end
local big_rock={x1=70,y1=60,x2=84,y2=71,big=true}
function _update() end
function _draw() end
function _init()
  cartdata("kepes_desert_jedi_test")
  -- ---- tests ----
  tcase("1 move right + clamp")
  arena() local x0=g.p.x
  step(5,{[1]=true}) check(g.p.x>x0,"x should grow")
  step(200,{[1]=true}) check(g.p.x<=124,"x clamp 124: "..g.p.x)
  check(g.p.x>=120,"x reached right edge: "..g.p.x)
  check(g.p.fx==1 and g.p.fy==0,"facing right")
  step(200,{[2]=true}) check(g.p.y==12,"y clamp 12: "..g.p.y)
  step(200,{[0]=true,[3]=true}) check(g.p.x==4 and g.p.y==124,"lower-left clamp "..g.p.x..","..g.p.y)

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
  check(g.p.x<67 and g.p.x>=64,"blocked before rock x: "..g.p.x)
  check(g.p.y==68,"y unchanged: "..g.p.y)
  step(4,{[1]=true,[3]=true})
  check(g.p.x<67,"still blocked in x: "..g.p.x)
  check(g.p.y>68+3,"slid down along rock: "..g.p.y)
  step(20,{[1]=true,[3]=true})
  check(g.p.x>70,"passes rock after sliding below: "..g.p.x)

  tcase("4 spawn, approach, stop, telegraph, fire")
  fresh() g.rocks={}
  check(#g.troopers==0,"no trooper before first frame")
  step(1)
  check(#g.troopers==1,"spawned on first frame")
  local tr=g.troopers[1]
  check(tr.x<-2 or tr.x>130 or tr.y<-2 or tr.y>130,"spawned off screen "..tr.x..","..tr.y)
  check(tr.spd==0.5,"spd0 "..tr.spd)
  check(tr.stop>=56 and tr.stop<68,"stop range "..tr.stop)
  g.troopers={} g.spawn_cd=32000
  tr=mk_trooper(110,68)
  step(10)
  check(tr.x<110 and tr.x>=104,"approaches: "..tr.x)
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
  mk_bolt(80,68,-2,0)
  step(10)
  check(g.p.hp==2,"hp 2: "..g.p.hp)
  check(g.p.inv>30,"inv set: "..g.p.inv)
  check(#g.bolts==0,"bolt consumed")
  check(g.shake>0,"shake happened")

  tcase("6 block in cone deflects")
  arena() step(1,{[1]=true})
  local b=mk_bolt(g.p.x+16,68,-2,0)
  step(8,{[5]=true})
  check(g.p.hp==3,"no damage")
  check(#g.bolts==1 and b.owner=="p","deflected owner p")
  check(b.dx==2.5 and b.dy==0,"reversed at 2.5: "..b.dx..","..b.dy)
  check(b.x>g.p.x,"flying away")
  arena() step(1,{[1]=true})
  local src=mk_trooper(g.p.x+16,90) src.st="aim" src.t=100
  b=mk_bolt(g.p.x+16,68,-2,0) b.src=src
  step(8,{[5]=true})
  check(b.owner=="p" and g.p.hp==3,"deflected with live src")
  check(b.dx>0 and b.dy>0,"homes on shooter: "..b.dx..","..b.dy)
  check(abs(dist(0,0,b.dx,b.dy)-2.5)<0.01,"speed 2.5")

  tcase("7 block from behind -> hp-1")
  arena() step(1,{[1]=true})
  mk_bolt(g.p.x-16,68,2,0)
  step(10,{[5]=true})
  check(g.p.hp==2,"hit from behind: "..g.p.hp)
  check(#g.bolts==0,"bolt consumed")

  tcase("8 deflected bolt kills, 90 frames")
  arena()
  tr=mk_trooper(100,68)
  mk_bolt(80,68,2.5,0,"p")
  n=0
  while tr.st~="dead" and n<20 do step(1) n+=1 end
  check(tr.st=="dead","trooper dead")
  check(g.score==20,"score 20: "..g.score)
  check(#g.bolts==0,"bolt gone")
  check(tr.t==90,"dead timer 90 after kill frame: "..tr.t)
  step(89)
  check(#g.troopers==1 and tr.t==1,"still lying")
  step(1)
  check(#g.troopers==0,"removed after 90 frames")
  check(alive_count()==0,"alive_count 0")

  tcase("9 swing kills in front only")
  arena() step(1,{[1]=true})
  local ta=mk_trooper(g.p.x+10,68)
  local tb=mk_trooper(g.p.x-10,68)
  step(1,{[4]=true})
  check(g.p.swing==8,"swing started")
  check(ta.st~="dead","no kill on frame 1 (window 3..7)")
  step(1)
  check(ta.st=="dead","front trooper killed")
  check(tb.st~="dead","back trooper alive")
  check(g.score==10,"score 10: "..g.score)
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
  mk_bolt(80,68,-2,0)
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

  tcase("12 rocks: zone, gaps, bounds")
  for seed=1,25 do
    srand(seed) gen_rocks()
    check(#g.rocks>=5 and #g.rocks<=8,"count seed "..seed..": "..#g.rocks)
    for i,r in ipairs(g.rocks) do
      check(r.x1>=10 and r.x2<=117 and r.y1>=12 and r.y2<=117,"bounds seed "..seed)
      check(not (r.x2>=44 and r.x1<=84 and r.y2>=48 and r.y1<=88),"spawn zone seed "..seed)
      check((r.big and r.x2-r.x1==13 and r.y2-r.y1==10) or (not r.big and r.x2-r.x1==6 and r.y2-r.y1==4),"hitbox size")
      for j=i+1,#g.rocks do
        local o=g.rocks[j]
        local gx=max(r.x1-o.x2-1,o.x1-r.x2-1)
        local gy=max(r.y1-o.y2-1,o.y1-r.y2-1)
        check(gx>=14 or gy>=14,"gap seed "..seed)
      end
    end
  end

  tcase("13 bolt dies in rock")
  arena() g.rocks={big_rock}
  mk_bolt(60,66,2,0,"p")
  step(6)
  check(#g.bolts==0,"bolt removed")
  check(#g.parts>0,"sparks")

  tcase("14 bolt leaves screen")
  arena()
  mk_bolt(120,30,2,0)
  mk_bolt(30,-5,0,-2,"p")
  step(10)
  check(#g.bolts==0,"both removed: "..#g.bolts)

  tcase("15 inv absorbs bolt, block works during inv")
  arena() step(1,{[1]=true})
  g.p.inv=40
  mk_bolt(g.p.x-16,68,2,0)
  step(10)
  check(g.p.hp==3 and #g.bolts==0,"absorbed without damage")
  b=mk_bolt(g.p.x+16,68,-2,0)
  step(8,{[5]=true})
  check(b.owner=="p" and g.p.hp==3,"deflect during inv")

  tcase("16 stuck trooper sidesteps")
  arena() g.rocks={big_rock}
  tr=mk_trooper(100,66) tr.stop=10
  local sided=false
  for i=1,80 do step(1) if tr.side_t>0 then sided=true end end
  check(not solid(tr.x,tr.y),"never inside rock: "..tr.x..","..tr.y)
  check(sided,"side maneuver started")

  tcase("17 swing kill lies exactly 90 frames")
  arena() step(1,{[1]=true})
  tr=mk_trooper(g.p.x+10,68)
  step(1,{[4]=true}) step(1)
  check(tr.st=="dead" and g.score==10,"swing killed")
  check(tr.t==90,"t 90 on kill frame: "..tr.t)
  step(89)
  check(#g.troopers==1 and tr.t==1,"still lying after 89")
  step(1)
  check(#g.troopers==0,"removed exactly 90 frames after kill")

  tcase("18 frame counter saturates, no wrap")
  arena() g.frames=32000 g.spawn_cd=0
  step(3,{[5]=true})
  check(g.frames==32000,"frames capped: "..g.frames)
  check(elapsed()>1000 and max_alive()==8,"elapsed/max_alive sane")
  check(alive_count()>=1,"still spawns late")
  check(g.troopers[1].spd==0.8,"late spd 0.8: "..g.troopers[1].spd)
  g.spawn_cd=-5 step(1,{[5]=true})
  check(g.spawn_cd>=0,"spawn_cd never negative: "..g.spawn_cd)

  tcase("19 trooper must enter screen before aiming")
  arena() g.p.x=10
  tr=mk_trooper(-6,68) tr.stop=40
  step(1)
  check(tr.st=="walk","no aim from off screen")
  n=0
  while tr.st=="walk" and n<60 do step(1) n+=1 end
  check(tr.st=="aim" and tr.x>=0 and tr.x<2,"aims once on screen: "..tr.x)
  arena() g.p.y=20
  tr=mk_trooper(64,-6) tr.stop=40
  step(1) check(tr.st=="walk","no aim from above hud")
  n=0
  while tr.st=="walk" and n<60 do step(1) n+=1 end
  check(tr.st=="aim" and tr.y>=12 and tr.y<14,"aims below hud: "..tr.y)
  arena() g.p.x=20
  tr=mk_trooper(0.5,68) tr.stop=40 tr.st="aim" tr.t=5
  tr.x=-1 step(1)
  check(tr.st=="walk" and #g.bolts==0,"pushed off screen -> walk, no shot")
  step(4) check(tr.st=="aim" and tr.x>=0,"re-aims when back on screen: "..tr.x)

  -- tuned: spec says 0.02 / block_r 7; bot playtests (E5) showed
  -- those fail the balance gate (idle < 10 s, blocker < 60 s)
  tcase("20 blaster spread +/-0.04")
  arena()
  tr=mk_trooper(100,68) tr.st="aim"
  local maxdev=0
  for i=1,200 do
    g.bolts={}
    fire(tr)
    maxdev=max(maxdev,abs(atan2(g.bolts[1].dx,g.bolts[1].dy)-0.5))
  end
  check(maxdev>0.025,"spread wider than 0.02: "..maxdev)
  check(maxdev<=0.041,"spread within 0.04: "..maxdev)

  tcase("21 block radius 9: 8 px deflected, 10 px passes")
  arena() step(1,{[0]=true})
  b=mk_bolt(g.p.x-8,84,0,-2)
  local b2=mk_bolt(g.p.x-10,84,0,-2)
  step(12,{[5]=true})
  check(b.owner=="p","8 px bolt deflected")
  check(b2.owner=="e" and b2.y<68,"10 px bolt passes undeflected: "..b2.y)
  check(g.p.hp==3,"no damage: "..g.p.hp)

  tcase("22 shake visible for 6 frames")
  arena()
  mk_bolt(g.p.x+4,68,-2,0)
  n=0
  for i=1,30 do step(1) if g.shake>0 then n+=1 end end
  check(n==6,"shake frames: "..n)

  tcase("23 score saturates at 32000")
  arena() g.score=31990
  kill_trooper(mk_trooper(100,68),20)
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
  b=mk_bolt(g.p.x+8,68,-2,0)
  step(3,{[4]=true})
  check(b.owner=="p" and g.p.hp==3,"swing deflects bolt")
  arena() step(1,{[1]=true})
  mk_bolt(g.p.x+4,68,-2,0)
  step(1,{[4]=true,[5]=true})
  check(g.p.hp==2,"block suspended during swing: "..g.p.hp)
  arena() step(1,{[1]=true})
  mk_bolt(g.p.x+4,68,-2,0)
  step(1,{[5]=true})
  check(g.p.hp==3,"same bolt blocked without swing")
  arena()
  spawn_parts(64,68,70,9,10)
  check(#g.parts==60,"parts capped at 60: "..#g.parts)
  arena()
  ta=mk_trooper(90,68) tb=mk_trooper(94,68)
  step(1)
  check(dist(ta.x,ta.y,tb.x,tb.y)>4,"troopers separated")

  printh("TESTS DONE ok="..ok.." fail="..fail)
  extcmd("shutdown")
end
