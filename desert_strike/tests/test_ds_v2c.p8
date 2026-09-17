pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../desert_strike.p8
#include test_lib.lua
function _init()
  local tr,n
  cartdata("kepes_desert_strike_test")
  tcase("v2-7 vader threshold, escorts, music 4, one at a time")
  arena()
  check(g.next_vader==15 and g.vader==nil,"starts with next_vader 15, no vader")
  g.kills=14
  tr=mk_trooper(px+36,py)
  mk_bolt(px+16,py,2.5,0,"p")
  n=0
  while tr.st~="dead" and n<20 do step(1) n+=1 end
  check(g.kills==15 and g.vader==nil,"15th kill, spawn next frame: "..g.kills)
  step(1)
  local v=g.vader
  check(v~=nil,"vader spawned")
  check(g.next_vader==30,"next_vader 30: "..g.next_vader)
  check(last(music_log)==4,"music 4: "..tostr(last(music_log)))
  check(#g.troopers==4,"3 escorts + corpse: "..#g.troopers)
  check(not in_view(v.x,v.y,0) and in_world(v.x,v.y),"vader off view in world: "..v.x..","..v.y)
  check(v.hp==5 and v.st=="walk","hp 5, walking")
  local bad=0
  for i=2,4 do
    local e=g.troopers[i]
    if e.st~="dead" and dist(e.x,e.y,v.x,v.y)>20 then bad+=1 end
    if abs(e.spd-0.5)>0.01 then bad+=1 end
  end
  check(bad==0,"escorts near vader with current spd: "..bad)
  g.kills=30
  step(1)
  check(g.vader==v and g.next_vader==30,"no second vader while alive")
  v.st="dying" v.t=1
  step(1)
  check(g.vader==nil,"vader removed at t 0")
  step(1)
  check(g.vader~=nil and g.vader~=v and g.next_vader==45,"new vader the frame after death")
  check(count(music_log,4)==2,"music 4 twice: "..count(music_log,4))
  -- escorts are never placed inside a rock
  bad=0
  for seed=1,50 do
    fresh(seed) g.troopers={}
    spawn_vader()
    for e in all(g.troopers) do
      if solid(e.x,e.y) or not in_world(e.x,e.y) then bad+=1 end
    end
  end
  check(bad==0,"escorts in rocks over 50 seeds: "..bad)
  -- threshold reached while the jedi is dying: no vader, game over stays silent (spec 9)
  arena() g.kills=14 g.p.hp=1
  mk_bolt(px+16,py,-2,0)
  step(10)
  check(g.p.dead and last(music_log)==-1,"jedi dying, music -1")
  tr=mk_trooper(px+36,py)
  mk_bolt(px+16,py,2.5,0,"p")
  step(10)
  check(g.kills==15 and tr.st=="dead","15th kill during dying")
  step(30)
  check(g.state=="over" and g.vader==nil and last(music_log)==-1,"no vader, no music 4 on the over screen: "..tostr(last(music_log)))

  tcase("v2-8 vader walk 1.1, windup 15, strike, hurt, parry")
  arena()
  v=mk_vader(px+60,py)
  step(1)
  check(abs(v.x-(px+58.9))<0.01 and v.y==py,"1.1 px/frame toward jedi: "..v.x)
  check(v.flip,"faces the jedi (left)")
  check(v.fx==-1 and v.fy==0,"4-way facing")
  step(20)
  check(v.x>px+12 and v.x<px+40,"still approaching: "..v.x)
  n=0
  while v.st=="walk" and n<60 do step(1) n+=1 end
  check(v.st=="windup" and v.t==15,"windup 15: "..v.st.." "..v.t)
  check(dist(v.x,v.y,px,py)<=12,"within reach 12")
  local vx=v.x
  step(14)
  check(v.st=="windup" and v.x==vx and g.p.hp==3,"telegraph: stands, no damage")
  step(1)
  check(v.st=="strike" and v.t==8 and last(sfx_log)==8,"strike + sfx 8: "..v.st)
  step(1)
  check(g.p.hp==2 and g.p.inv>0,"unblocked strike hurts: "..g.p.hp)
  step(7)
  check(v.st=="walk" and v.cd==30,"back to walk, cd 30: "..v.st.." "..tostr(v.cd))
  n=0
  while v.st=="walk" and n<40 do step(1) n+=1 end
  check(n>=29 and n<=31,"next windup after cooldown: "..n)
  -- parry: jedi faces right and blocks
  arena() step(1,{[1]=true})
  v=mk_vader(g.p.x+10,g.p.y)
  n=0
  while v.st~="strike" and n<40 do step(1,{[5]=true}) n+=1 end
  check(v.st=="strike","strike reached while blocking")
  sfx_log={}
  step(1,{[5]=true})
  check(#g.parts>=10,"parry sparks: "..#g.parts)
  step(7,{[5]=true})
  check(g.p.hp==3,"parry: no damage")
  check(count(sfx_log,9)==1,"sfx 9 exactly once: "..count(sfx_log,9))
  check(v.st=="walk","strike finished")
  -- blocking away from vader does not parry
  arena() step(1,{[0]=true})
  v=mk_vader(g.p.x+10,g.p.y)
  n=0
  while v.st~="walk" or n==0 do step(1,{[5]=true}) n+=1 if n>40 then break end end
  step(8,{[5]=true})
  check(g.p.hp==2,"block facing away: hit "..g.p.hp)
  finish()
end
