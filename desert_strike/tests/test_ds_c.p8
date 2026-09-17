pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../desert_strike.p8
#include test_lib.lua
function _init()
  local b,tr
  cartdata("kepes_desert_strike_test")
  tcase("12 rocks: zone, gaps, bounds")
  fresh()
  for seed=1,25 do
    srand(seed) gen_rocks()
    check(#g.rocks>=80 and #g.rocks<=120,"count seed "..seed..": "..#g.rocks)
    local bad=0
    for i,r in ipairs(g.rocks) do
      if not (r.x1>=10 and r.x2<=501 and r.y1>=12 and r.y2<=501) then bad+=1 end
      if r.x2>=236 and r.x1<=276 and r.y2>=236 and r.y1<=276 then bad+=1 end
      if not ((r.big and r.x2-r.x1==13 and r.y2-r.y1==10) or (not r.big and r.x2-r.x1==6 and r.y2-r.y1==4)) then bad+=1 end
      for j=i+1,#g.rocks do
        local o=g.rocks[j]
        if max(r.x1-o.x2-1,o.x1-r.x2-1)<14 and max(r.y1-o.y2-1,o.y1-r.y2-1)<14 then bad+=1 end
      end
    end
    check(bad==0,"bounds/zone/size/gap violations seed "..seed..": "..bad)
  end

  tcase("13 bolt dies in rock")
  arena() g.rocks={big_rock}
  mk_bolt(px-4,py-2,2,0,"p")
  step(6)
  check(#g.bolts==0,"bolt removed")
  check(#g.parts>0,"sparks")

  tcase("14 bolt leaves view / world")
  arena()
  mk_bolt(g.cam_x+120,g.cam_y+30,2,0)
  mk_bolt(g.cam_x+30,g.cam_y-5,0,-2,"p")
  step(20)
  check(#g.bolts==0,"both removed: "..#g.bolts)
  arena() place(4,py)
  b=mk_bolt(1,py+30,-2,0)
  step(1)
  check(#g.bolts==0,"removed outside the world although within view margin")
  b=mk_bolt(g.cam_x+100,py+30,2,0)
  step(22)
  check(#g.bolts==1 and b.x==144,"kept while within 16 px of the view: "..b.x)
  step(1)
  check(#g.bolts==0,"removed beyond 16 px of the view")

  tcase("15 inv absorbs bolt, block works during inv")
  arena() step(1,{[1]=true})
  g.p.inv=40
  mk_bolt(g.p.x-16,py,2,0)
  step(10)
  check(g.p.hp==3 and #g.bolts==0,"absorbed without damage")
  b=mk_bolt(g.p.x+16,py,-2,0)
  step(8,{[5]=true})
  check(b.owner=="p" and g.p.hp==3,"deflect during inv")

  tcase("16 stuck trooper sidesteps")
  arena() g.rocks={big_rock}
  tr=mk_trooper(px+36,py-2) tr.stop=10
  local sided=false
  for i=1,80 do step(1) if tr.side_t>0 then sided=true end end
  check(not solid(tr.x,tr.y),"never inside rock: "..tr.x..","..tr.y)
  check(sided,"side maneuver started")
  finish()
end
