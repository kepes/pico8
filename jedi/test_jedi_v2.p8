pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include jedi.p8
#include test_lib.lua
function _init()
  local tr
  cartdata("kepes_desert_jedi_test")
  tcase("v2-1 camera follows and clamps")
  arena()
  check(g.p.x==256 and g.p.y==256,"jedi starts at world centre")
  check(g.cam_x==192 and g.cam_y==192,"centre cam 192,192: "..g.cam_x..","..g.cam_y)
  step(1)
  check(g.cam_x==192 and g.cam_y==192,"cam stable after a frame")
  g.p.x,g.p.y=10,20 step(1)
  check(g.cam_x==0 and g.cam_y==0,"cam 0,0 at 10,20: "..g.cam_x..","..g.cam_y)
  g.p.x,g.p.y=500,500 step(1)
  check(g.cam_x==384 and g.cam_y==384,"cam 384,384 at 500,500: "..g.cam_x..","..g.cam_y)
  step(30,{[1]=true,[3]=true})
  check(g.p.x==508 and g.p.y==508,"world clamp 508: "..g.p.x..","..g.p.y)
  check(g.cam_x==384 and g.cam_y==384,"cam stays clamped")
  step(500,{[0]=true,[2]=true})
  check(g.p.x==4 and g.p.y==12,"world clamp 4,12: "..g.p.x..","..g.p.y)
  check(g.cam_x==0 and g.cam_y==0,"cam 0,0 at top-left")
  check(in_view(0,0,0) and in_view(128,128,0) and not in_view(129,64,0) and in_view(140,64,16),"in_view margins")

  tcase("v2-2 world gen: gems")
  for seed=1,5 do
    fresh(seed)
    check(#g.gems==5,"5 gems seed "..seed..": "..#g.gems)
    local bad=0
    for i,gm in ipairs(g.gems) do
      if in_rock(gm.x,gm.y,6) then bad+=1 end
      if dist(gm.x,gm.y,px,py)<40 then bad+=1 end
      if gm.x<8 or gm.x>504 or gm.y<8 or gm.y>504 then bad+=1 end
      for j=i+1,#g.gems do
        if dist(gm.x,gm.y,g.gems[j].x,g.gems[j].y)<40 then bad+=1 end
      end
    end
    check(bad==0,"gem rules seed "..seed..": "..bad)
    check(#g.decor>=200 and #g.decor<=259,"decor count: "..#g.decor)
  end

  tcase("v2-3 spawn_pos off view, in world")
  fresh()
  local bad=0
  for i=1,20 do
    local x,y=spawn_pos()
    if in_view(x,y,0) or not in_world(x,y) or in_rock(x,y,6) then bad+=1 end
  end
  check(bad==0,"centre spawns: "..bad)
  for _,c in ipairs({{4,12},{508,508},{4,508},{508,12}}) do
    place(c[1],c[2])
    bad=0
    for i=1,20 do
      local x,y=spawn_pos()
      if in_view(x,y,0) or not in_world(x,y) then bad+=1 end
    end
    check(bad==0,"corner "..c[1]..","..c[2].." spawns: "..bad)
  end
  place(px,60)
  bad=0
  for i=1,200 do
    local x,y=spawn_pos()
    if y<12 then bad+=1 end
  end
  check(bad==0,"no spawn in the top 12 px band: "..bad)
  g.spawn_cd=0 g.troopers={}
  step(1)
  check(#g.troopers==1 and not in_view(g.troopers[1].x,g.troopers[1].y,0),"spawn_trooper uses spawn_pos")
  local t2=spawn_trooper_at(100,200)
  check(t2.x==100 and t2.y==200 and t2.st=="walk" and abs(t2.spd-0.5)<0.01 and #g.troopers==2,"spawn_trooper_at")

  tcase("v2-4 far trooper despawns silently")
  arena()
  tr=mk_trooper(px+250,py)
  local dead=mk_trooper(px+250,py+10) dead.st="dead" dead.t=50
  local near=mk_trooper(px+190,py)
  g.score=5
  step(1)
  check(#g.troopers==2,"far live trooper removed: "..#g.troopers)
  check(g.troopers[1]==dead and g.troopers[2]==near,"dead + near troopers kept")
  check(g.kills==0 and g.score==5,"no kill, no points")
  check(last(sfx_log)~=3,"no death sfx")
  finish()
end
