pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include jedi.p8
#include test_lib.lua
function _init()
  local tr
  cartdata("kepes_desert_jedi_test")
  tcase("v2-9 five swings kill vader: +300, music 0, gone after 60")
  arena() step(1,{[1]=true})
  -- cd keeps him in walk
  local v=mk_vader(g.p.x+10,g.p.y) v.cd=200
  for i=1,5 do
    local hp=v.hp
    step(1,{[4]=true})
    check(v.hp==hp,"no hit on swing frame 1")
    step(1)
    check(v.hp==hp-1,"hit "..i..": "..v.hp)
    check(last(sfx_log)==(i<5 and 10 or 11),"sfx "..i..": "..tostr(last(sfx_log)))
    if i<5 then
      check(v.st=="stagger" and v.t==30,"stagger 30: "..v.st.." "..v.t)
      step(3)
      check(v.x>g.p.x+16,"knocked back 8 px: "..(v.x-g.p.x))
      step(28)
      check(v.st=="walk","stagger over")
      v.x,v.y=g.p.x+10,g.p.y
    end
  end
  check(v.st=="dying" and v.t==60,"dying 60: "..v.st.." "..v.t)
  check(g.score==300,"score 300: "..g.score)
  check(last(music_log)==0,"music 0: "..tostr(last(music_log)))
  check(g.p.hp==3,"jedi untouched")
  step(59)
  check(g.vader==v,"still dying at 59")
  step(1)
  check(g.vader==nil,"vader gone after 60")
  check(g.score==300,"no double score")

  tcase("v2-9b two swings during stagger: one hit only")
  arena() step(1,{[1]=true})
  v=mk_vader(g.p.x+10,g.p.y) v.cd=200
  step(1,{[4]=true}) step(1)
  check(v.hp==4,"first hit")
  step(12)
  v.x,v.y=g.p.x+10,g.p.y
  step(1,{[4]=true}) step(1)
  check(v.hp==4 and v.st=="stagger","invulnerable while staggered: "..v.hp)
  -- spec 7.2: walk, windup and strike are all hittable
  arena() step(1,{[1]=true})
  v=mk_vader(g.p.x+10,g.p.y)
  step(1)
  check(v.st=="windup","windup")
  step(1,{[4]=true}) step(1)
  check(v.hp==4 and v.st=="stagger","hit during windup: "..v.hp.." "..v.st)
  v.x,v.y,v.st,v.t=g.p.x+10,g.p.y,"strike",8
  step(1,{[4]=true}) step(1)
  check(v.hp==3 and v.st=="stagger","hit during strike: "..v.hp.." "..v.st)
  -- knockback never leaves the world
  arena() place(14,py) step(1,{[0]=true})
  v=mk_vader(6,py) v.cd=100
  step(1,{[4]=true}) step(4)
  check(v.hp==4 and v.st=="stagger" and v.x==4,"knockback clamped at the world edge: "..v.x)
  -- spec 7.2: knockback never pushes vader into a rock
  arena() step(1,{[1]=true})
  g.rocks={{x1=g.p.x+16,y1=py-8,x2=g.p.x+30,y2=py+3}}
  v=mk_vader(g.p.x+10,g.p.y) v.cd=200
  step(1,{[4]=true}) step(4)
  check(v.st=="stagger" and not solid(v.x,v.y) and v.x<g.p.x+13,"knockback stops at the rock: "..(v.x-g.p.x))

  tcase("v2-9c bolts vs vader")
  arena()
  v=mk_vader(px+30,py)
  local b=mk_bolt(px+16,py,2.5,0,"p")
  step(6)
  check(#g.bolts==0,"reflected bolt destroyed on vader")
  check(v.hp==5,"no damage from bolt: "..v.hp)
  check(#g.parts>=4,"sparks on vader")
  arena()
  v=mk_vader(px+30,py)
  mk_bolt(px+40,py,-2,0)
  step(20)
  check(g.p.hp==2,"enemy bolt passes through vader: "..g.p.hp)
  -- reflected bolt still kills a trooper when vader is elsewhere
  arena()
  v=mk_vader(px,py+100)
  tr=mk_trooper(px+36,py)
  mk_bolt(px+16,py,2.5,0,"p")
  step(10)
  check(tr.st=="dead" and g.kills==1,"trooper still killable")

  tcase("v2-9d draw: hud pips + all vader poses run")
  arena()
  v=mk_vader(px+10,py)
  step(1)
  check(pget(52,10)==8 and pget(72,10)==8,"5 full hp pips: "..pget(52,10).." "..pget(72,10))
  v.hp=2 step(1)
  check(pget(57,10)==8 and pget(62,10)==2 and pget(72,10)==2,"2 full + 3 empty pips: "..pget(62,10))
  for _,s in ipairs({"walk","windup","strike","stagger","dying"}) do
    v.st=s v.t=8
    step(1)
  end
  check(pget(57,10)==8 and pget(62,10)==2,"pips still drawn while dying")
  v.t=1 step(1)
  check(g.vader==nil and pget(62,10)~=2 and pget(57,10)~=8,"pips gone with vader")
  finish()
end
