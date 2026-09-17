pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
#include ../jedi.p8
#include test_lib.lua
function _init()
  cartdata("kepes_desert_jedi_test")
  tcase("v2-10a worm: counter only after 60 s, tremor at 600 still")
  -- literals on purpose (spec 13/10, 14): 60 s gate; WORM_STILL = 600 = 20 s
  arena()
  local w=g.worm
  check(w~=nil and w.st=="idle" and w.still==0,"worm idle at start")
  check(w.ax==px and w.ay==py,"anchor at the jedi: "..tostr(w.ax)..","..tostr(w.ay))
  g.frames=30*59
  step(620)
  check(w.st=="idle","idle after 620 frames from 59 s: "..w.st)
  check(w.still==590,"still counts only from 60 s: "..w.still)
  step(10)
  check(w.st=="tremor" and w.t==90,"tremor at 600 still, t 90: "..w.st.." "..w.t)
  check(w.ex==px and w.ey==py,"epicentre at the jedi")
  -- moving away resets the counter (before 60 s too)
  arena() w=g.worm g.frames=30*40
  step(300)
  check(w.still==0,"no counting before 60 s: "..w.still)
  g.frames=30*60
  step(100)
  check(w.still==100,"counting at 60 s: "..w.still)
  step(14,{[1]=true})
  check(w.still==0 and w.ax==px+21,"anchor moves + reset after >20 px: "..w.still.." "..w.ax)
  step(10,{[0]=true})
  check(w.still==10,"within 20 px keeps counting: "..w.still)

  tcase("v2-10b worm eats the standing jedi")
  arena() w=g.worm g.frames=30*60
  step(600)
  check(w.st=="tremor","tremor")
  sfx_log={}
  local shook,np=0,#g.parts
  for i=1,90 do
    step(1)
    if g.shake>=2 then shook+=1 end
  end
  check(shook==90,"shake >=2 every tremor frame: "..shook)
  check(#g.parts>np+20,"dust particles: "..#g.parts)
  check(count(sfx_log,12)==3,"sfx 12 every 30 frames: "..count(sfx_log,12))
  check(w.st=="emerge" and w.t==60,"emerge after 90, t 60: "..w.st.." "..w.t)
  check(last(sfx_log)==13,"roar sfx 13: "..tostr(last(sfx_log)))
  check(not g.p.dead,"alive before the bite")
  step(9)
  check(not g.p.dead and w.t==51,"not yet at t 51")
  step(1)
  check(g.p.dead and g.p.hp==0 and g.p.eaten,"eaten at t 50: "..tostr(g.p.dead).." "..g.p.hp)
  check(g.cause=="worm","cause worm: "..tostr(g.cause))
  check(g.p.dying==40,"dying 40: "..g.p.dying)
  check(last(music_log)==-1,"music -1: "..tostr(last(music_log)))
  step(39)
  check(g.state=="play","still dying at 39")
  step(1)
  check(g.state=="over","game over 40 frames after the bite")
  step(3)
  check(g.cause=="worm","cause kept on the over screen")
  -- new game clears it
  step(1,{[4]=true})
  check(g.state=="play" and g.cause==nil and not g.p.eaten and g.worm.st=="idle","new game resets worm/cause")

  tcase("v2-10c escape during the tremor")
  arena() w=g.worm g.frames=30*60
  step(600)
  check(w.st=="tremor","tremor")
  step(20,{[1]=true})
  check(g.p.x>=px+29,"moved 30 px: "..(g.p.x-px))
  step(70)
  check(w.st=="emerge","emerges empty")
  step(10)
  check(not g.p.dead and g.p.hp==3 and g.cause==nil,"jedi escaped: "..tostr(g.p.dead))
  step(50)
  check(w.st=="sink" and w.t==30,"sink 30 after emerge: "..w.st.." "..w.t)
  step(29)
  check(w.st=="sink","still sinking at 29")
  step(1)
  check(w.st=="idle" and w.still==0,"idle after sink, counter reset: "..w.st.." "..w.still)
  check(w.ax==g.p.x and w.ay==g.p.y,"anchor reset to the jedi")
  -- bite radius: 19 px eaten, 21 px safe
  arena() w=g.worm g.frames=30*60
  step(690)
  place(px+21,py) step(10)
  check(not g.p.dead,"21 px away: safe")
  arena() w=g.worm g.frames=30*60
  step(690)
  place(px-19,py) step(10)
  check(g.p.dead and g.cause=="worm","19 px away: eaten")
  -- normal death has no cause
  arena() g.p.hp=1
  mk_bolt(g.p.x+16,g.p.y,-2,0)
  step(50)
  check(g.state=="over" and g.cause==nil and not g.p.eaten,"bolt death: no worm cause")

  tcase("v2-10d draw: worm frames and over screen run")
  arena() w=g.worm
  -- test carts carry no gfx: paint probe pixels of sprites 64/68 (local 16,16 and 16,23)
  sset(16,48,9) sset(16,55,9) sset(48,48,9) sset(48,55,9)
  w.st,w.t,w.ex,w.ey="tremor",50,px,py
  step(2)
  check(pget(64,56)==15,"sand only during the tremor: "..pget(64,56))
  w.st,w.t="emerge",50
  step(2)
  check(pget(64,56)==9,"worm body drawn at its centre: "..pget(64,56))
  w.st,w.t="sink",20
  step(2)
  check(pget(64,68)==9 and pget(64,75)==15,"sinking worm 12 px down, clipped at the sand line: "..pget(64,68).." "..pget(64,75))
  w.st="idle"
  g.p.eaten=true g.cause="worm" g.p.dead=true g.p.hp=0 g.state="over"
  step(2)
  local hit=false
  for x=26,101 do if pget(x,52)==9 then hit=true end end
  check(hit,"eaten by a sandworm line in colour 9")
  finish()
end
