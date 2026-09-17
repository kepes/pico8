pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include jedi.p8
#include test_lib.lua
function _init()
  local tr,n,b
  cartdata("kepes_desert_jedi_test")
  tcase("17 swing kill lies exactly 90 frames")
  arena() step(1,{[1]=true})
  tr=mk_trooper(g.p.x+10,py)
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

  tcase("19 trooper must enter view before aiming")
  arena() place(10,py)
  tr=mk_trooper(-6,py) tr.stop=40
  step(1)
  check(tr.st=="walk","no aim from off view")
  n=0
  while tr.st=="walk" and n<60 do step(1) n+=1 end
  check(tr.st=="aim" and tr.x>=0 and tr.x<2,"aims once in view: "..tr.x)
  arena() place(px,20)
  tr=mk_trooper(px,-6) tr.stop=40
  step(1) check(tr.st=="walk","no aim from above the view")
  n=0
  while tr.st=="walk" and n<60 do step(1) n+=1 end
  check(tr.st=="aim" and tr.y>=12 and tr.y<14,"aims only below the hud band: "..tr.y)
  -- the hud band scrolls with the camera
  arena() place(px,300)
  tr=mk_trooper(px,g.cam_y+6) tr.stop=80
  step(1) check(tr.st=="walk","no aim under the hud band of a scrolled view")
  n=0
  while tr.st=="walk" and n<60 do step(1) n+=1 end
  check(tr.st=="aim" and tr.y>=g.cam_y+12 and tr.y<g.cam_y+14,"aims below the scrolled hud: "..(tr.y-g.cam_y))
  arena() place(20,py)
  tr=mk_trooper(0.5,py) tr.stop=40 tr.st="aim" tr.t=5
  tr.x=-1 step(1)
  check(tr.st=="walk" and #g.bolts==0,"pushed off view -> walk, no shot")
  step(4) check(tr.st=="aim" and tr.x>=0,"re-aims when back in view: "..tr.x)
  -- view moves with the camera: same trooper, jedi far right
  arena() place(400,py)
  tr=mk_trooper(g.cam_x-6,py) tr.stop=80
  step(1) check(tr.st=="walk","no aim just left of a scrolled view")
  n=0
  while tr.st=="walk" and n<60 do step(1) n+=1 end
  check(tr.st=="aim" and tr.x>=g.cam_x,"aims once inside the scrolled view: "..tr.x)

  -- tuned: spec says 0.02 / block_r 7; bot playtests (E5) showed
  -- those fail the balance gate (idle < 10 s, blocker < 60 s)
  tcase("20 blaster spread +/-0.04")
  arena()
  tr=mk_trooper(px+36,py) tr.st="aim"
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
  b=mk_bolt(g.p.x-8,py+16,0,-2)
  local b2=mk_bolt(g.p.x-10,py+16,0,-2)
  step(12,{[5]=true})
  check(b.owner=="p","8 px bolt deflected")
  check(b2.owner=="e" and b2.y<py,"10 px bolt passes undeflected: "..b2.y)
  check(g.p.hp==3,"no damage: "..g.p.hp)
  finish()
end
