-- shared headless test harness (included by every test_*.p8)
music_log,sfx_log={},{}
function music(n) add(music_log,n) end
function sfx(n) add(sfx_log,n) end
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
-- world start point of the jedi
local px,py=256,256
function fresh(seed)
  srand(seed or 1)
  music_log,sfx_log={},{}
  new_game()
  g.state="play"
end
-- deterministic arena: no rocks, no automatic
-- spawns, one gem far out of reach
function arena()
  fresh()
  g.rocks={}
  g.gems={{x=440,y=60}}
  g.spawn_cd=32000
end
-- teleport the jedi and settle the camera
function place(x,y)
  g.p.x,g.p.y=x,y
  upd_cam()
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
function last(t) return t[#t] end
function mk_vader(x,y)
  g.vader={x=x,y=y,hp=5,st="walk",t=0,flip=false,anim=0,stuck=0,side_t=0,side_dir=1,cd=0}
  return g.vader
end
function count(log,n)
  local c=0
  for s in all(log) do if s==n then c+=1 end end
  return c
end
function in_world(x,y) return x>=4 and x<=world_w-4 and y>=12 and y<=world_h-4 end
local big_rock={x1=px+6,y1=py-8,x2=px+20,y2=py+3,big=true}
function _update() end
function _draw() end
function finish()
  printh("TESTS DONE ok="..ok.." fail="..fail)
  extcmd("shutdown")
end
