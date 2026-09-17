pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../desert_strike.p8
#include test_lib.lua
function _init()
  local src,b,bad,tr,n
  cartdata("kepes_desert_strike_test")
  tcase("v2-5 deflect scatter 30% exact / 70% +/-10 deg")
  arena()
  srand(1)
  src=mk_trooper(px+30,py+40) src.st="aim" src.t=100
  local a0=atan2(30,40)
  local exact,dev,other=0,0,0
  for i=1,200 do
    b={x=px,y=py,dx=-2,dy=0,owner="e",src=src}
    deflect(b)
    local d=abs(atan2(b.dx,b.dy)-a0)
    d=min(d,1-d)
    if d<0.001 then exact+=1
    elseif abs(d-10/360)<0.0005 then dev+=1
    else other+=1 end
    check(b.owner=="p" and abs(dist(0,0,b.dx,b.dy)-2.5)<0.01,"owner p, speed 2.5")
  end
  check(exact>=40 and exact<=80,"exact share 20-40%: "..exact)
  check(other==0,"every other deflect exactly 10 deg off: "..other.." / dev "..dev)
  check(exact+dev==200,"all accounted")
  -- both signs occur
  local left,right=0,0
  srand(2)
  for i=1,100 do
    b={x=px,y=py,dx=-2,dy=0,owner="e",src=src}
    deflect(b)
    local d=atan2(b.dx,b.dy)-a0
    if d>0.01 then left+=1 elseif d<-0.01 then right+=1 end
  end
  check(left>10 and right>10,"both deviation signs: "..left.."/"..right)
  -- dead source: back along the velocity
  b={x=px,y=py,dx=-2,dy=0,owner="e"}
  deflect(b)
  local d=abs(atan2(b.dx,b.dy)-0)
  d=min(d,1-d)
  check(d<0.001 or abs(d-10/360)<0.0005,"no src: reverse of velocity +/-10: "..d)

  tcase("v2-6 gems: +100, counter, respawn off view")
  arena()
  g.gems={{x=px+4,y=py},{x=40,y=40},{x=40,y=480},{x=480,y=40},{x=480,y=480}}
  step(1)
  check(g.score==100,"score 100: "..g.score)
  check(g.gems_got==1,"gems_got 1: "..g.gems_got)
  check(#g.gems==4,"4 gems left: "..#g.gems)
  check(last(sfx_log)==14,"sfx 14 on pickup: "..tostr(last(sfx_log)))
  check(#g.parts==8,"8 sparkle particles: "..#g.parts)
  for i=1,3 do
    g.gems[1].x,g.gems[1].y=g.p.x+3,g.p.y
    step(1)
  end
  check(g.gems_got==4 and #g.gems==1 and g.score==400,"4 collected")
  g.gems[1].x,g.gems[1].y=g.p.x-3,g.p.y+2
  step(1)
  check(g.score==500,"score 500: "..g.score)
  check(#g.gems==5,"5 new gems: "..#g.gems)
  check(g.gems_got==0,"counter reset: "..g.gems_got)
  check(last(sfx_log)==15,"sfx 15 on respawn: "..tostr(last(sfx_log)))
  bad=0
  for i,gm in ipairs(g.gems) do
    if in_view(gm.x,gm.y,8) then bad+=1 end
    if dist(gm.x,gm.y,g.p.x,g.p.y)<40 then bad+=1 end
    for j=i+1,#g.gems do
      if dist(gm.x,gm.y,g.gems[j].x,g.gems[j].y)<40 then bad+=1 end
    end
  end
  check(bad==0,"new gems off view and spaced: "..bad)
  -- gem 7 px away is not collected
  arena()
  g.gems={{x=px+7,y=py}}
  step(1)
  check(g.score==0 and #g.gems==1,"7 px away not collected")

  tcase("v2-11 music: new game 0, game over -1")
  arena()
  g.state="over"
  step(1,{[4]=true})
  check(g.state=="play" and last(music_log)==0,"retry -> music(0): "..tostr(last(music_log)))
  check(last(sfx_log)==6,"start sfx 6")
  g.p.hp=1
  mk_bolt(g.p.x+16,g.p.y,-2,0)
  step(10)
  check(g.p.dead and last(music_log)==-1,"death -> music(-1): "..tostr(last(music_log)))
  check(last(sfx_log)==5,"death sfx 5: "..tostr(last(sfx_log)))

  tcase("v2-12 world coords: kill via deflect far from origin")
  arena() place(450,470)
  step(1,{[1]=true})
  tr=mk_trooper(g.p.x+30,g.p.y)
  b=mk_bolt(g.p.x+16,g.p.y,-2,0) b.src=tr
  step(6,{[5]=true})
  check(b.owner=="p","deflected in the corner")
  n=0
  while tr.st~="dead" and n<20 do step(1) n+=1 end
  check(tr.st=="dead" and g.score==20 and g.kills==1,"deflected bolt kills in the corner: "..g.score)
  finish()
end
