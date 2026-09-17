pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
-- desert strike
-- tunables (spec 14)
p_spd=1.5
swing_t=8
swing_r=13
swing_br=11
swing_cos=0.34
block_r=9
block_cos=0.5
hit_r=3.5
inv_t=45
max_hp=3
t_spd0=0.5
bolt_spd=2
bolt_spread=0.04
rbolt_spd=2.5
dead_t=90
aim_t=12
ramp_s=20
max_alive_cap=8
-- v2 (spec 14)
world_w=512
world_h=512
n_rocks_min=96
n_rocks_max=119
n_decor_min=200
n_decor_max=259
despawn_d=200
defl_exact=0.3
defl_dev=10/360
gem_n=5
gem_pts=100
saber_col=11
vader_every=15
v_spd=1.1
v_hp=5
v_reach=12
v_windup=15
v_stagger=30
v_pts=300
v_saber_col=8
worm_after=20
worm_still=300
worm_area=20
worm_tremor=90
worm_bite_r=20
-- v2.1: terrain sprite variants
rock_small_s={32,8,9}
rock_big_s={33,12,14}
decor_s={{35,10,11},{36,20,21},{37,22,23},{38,46,47}}

-- helpers
function dist(ax,ay,bx,by)
 local dx,dy=(ax-bx)/8,(ay-by)/8
 return sqrt(dx*dx+dy*dy)*8
end
function norm(dx,dy)
 local d=dist(0,0,dx,dy)
 if d==0 then return 0,0 end
 return dx/d,dy/d
end
function dot(ax,ay,bx,by)
 return ax*bx+ay*by
end
clamp=mid
-- is (x,y) inside the player's
-- cone of radius r / cos c?
function in_cone(x,y,r,c)
 local p=g.p
 if dist(x,y,p.x,p.y)>r then return false end
 local nx,ny=norm(x-p.x,y-p.y)
 return dot(p.fx,p.fy,nx,ny)>=c
end

function elapsed()
 return g.frames/30
end
function max_alive()
 return min(max_alive_cap,1+flr(elapsed()/ramp_s))
end

-- camera follows the jedi,
-- clamped to the world
function upd_cam()
 g.cam_x=clamp(g.p.x-64,0,world_w-128)
 g.cam_y=clamp(g.p.y-64,0,world_h-128)
end
-- (x,y) within m px of the view?
function in_view(x,y,m)
 return x>=g.cam_x-m and x<=g.cam_x+128+m and y>=g.cam_y-m and y<=g.cam_y+128+m
end

function _init()
 cartdata("kepes_desert_strike_1")
 poke(0x5f5c,255)
 g={best=dget(0)}
 new_game()
 g.state="title"
 music(0)
 load_title()
end

function new_game()
 g={
  state="play",
  troopers={},bolts={},rocks={},
  decor={},parts={},gems={},
  frames=0,score=0,kills=0,
  gems_got=0,cam_x=0,cam_y=0,
  next_vader=vader_every,
  best=g and g.best or 0,
  newbest=false,
  spawn_cd=0,shake=0
 }
 gen_rocks()
 gen_decor()
 g.p=new_player()
 g.worm={st="idle",t=0,still=0,ax=g.p.x,ay=g.p.y}
 upd_cam()
 gen_gems(gem_n,false)
end

function upd_play()
 if g.shake>0 then g.shake-=1 end
 upd_player()
 upd_gems()
 upd_troopers()
 if not g.vader and not g.p.dead and g.kills>=g.next_vader then
  spawn_vader()
  g.next_vader+=vader_every
 end
 upd_vader()
 upd_bolts()
 upd_worm()
 upd_parts()
 upd_cam()
 if g.frames<32000 then g.frames+=1 end
end

function _update()
 if g.state=="play" then
  upd_play()
 elseif btnp(4) then
  if g.state=="over" then
   new_game()
   music(0)
  end
  g.state="play"
  sfx(6)
 end
end

function _draw()
 local sx,sy=0,0
 if g.shake>0 then
  sx,sy=rnd(4)-2,rnd(4)-2
 end
 g.sy=sy
 camera(g.cam_x+sx,g.cam_y+sy)
 draw_world()
 local ents={g.p}
 for tr in all(g.troopers) do
  if in_view(tr.x,tr.y,16) then
   if tr.st=="dead" then
    draw_trooper(tr)
   else
    add(ents,tr)
   end
  end
 end
 for gm in all(g.gems) do
  if in_view(gm.x,gm.y,16) then add(ents,gm) end
 end
 if g.vader then add(ents,g.vader) end
 -- y-sort (insertion)
 for i=2,#ents do
  local j=i
  while j>1 and ents[j-1].y>ents[j].y do
   ents[j],ents[j-1]=ents[j-1],ents[j]
   j-=1
  end
 end
 for e in all(ents) do
  if e==g.p then
   draw_player()
  elseif e==g.vader then
   draw_vader()
  elseif e.spd then
   draw_trooper(e)
  else
   draw_gem(e)
  end
 end
 draw_bolts()
 draw_worm()
 draw_parts()
 camera()
 if g.state=="title" then
  draw_title()
 else
  draw_hud()
  if g.state=="over" then draw_over() end
 end
end
-->8
-- world
function gen_rocks()
 g.rocks={}
 local n=n_rocks_min+flr(rnd(n_rocks_max-n_rocks_min+1))
 for _=1,3000 do
  if #g.rocks>=n then break end
  local big=rnd()<0.5
  local w,h=7,5
  if big then w,h=14,11 end
  local x1=10+flr(rnd(world_w-19-w))
  local y1=12+flr(rnd(world_h-21-h))
  local x2,y2=x1+w-1,y1+h-1
  local ok=not (x2>=236 and x1<=276 and y2>=236 and y1<=276)
  for o in all(g.rocks) do
   if x1<=o.x2+14 and x2>=o.x1-14 and y1<=o.y2+14 and y2>=o.y1-14 then ok=false end
  end
  if ok then add(g.rocks,{x1=x1,y1=y1,x2=x2,y2=y2,big=big,s=rnd(big and rock_big_s or rock_small_s)}) end
 end
end

function gen_decor()
 g.decor={}
 for _=1,n_decor_min+flr(rnd(n_decor_max-n_decor_min+1)) do
  add(g.decor,{x=flr(rnd(world_w-8)),y=12+flr(rnd(world_h-20)),s=rnd(rnd(decor_s))})
 end
end

-- n gems: not in rock, >=40 px
-- from the jedi and each other,
-- >=8 px from the world edge;
-- outside=true -> off view
function gen_gems(n,outside)
 local p=g.p
 for _=1,n do
  for i=1,540 do
   local x,y=8+flr(rnd(world_w-16)),12+flr(rnd(world_h-20))
   local ok=true
   if i>500 then
    -- fallback: 100 px from the jedi
    x,y=clamp(p.x+cos(i/40)*100,8,world_w-8),clamp(p.y+sin(i/40)*100,12,world_h-8)
   else
    ok=dist(x,y,p.x,p.y)>=40 and not (outside and in_view(x,y,8))
    for gm in all(g.gems) do
     if dist(x,y,gm.x,gm.y)<40 then ok=false end
    end
   end
   if ok and not in_rock(x,y,6) then
    add(g.gems,{x=x,y=y})
    break
   end
  end
 end
end

-- point (x,y) with margin m
-- inside any rock hitbox?
function in_rock(x,y,m)
 m=m or 0
 for i=1,#g.rocks do
  local r=g.rocks[i]
  if x+m>=r.x1 and x-m<=r.x2 and y+m>=r.y1 and y-m<=r.y2 then return true end
 end
 return false
end
function solid(x,y)
 return in_rock(x,y,3)
end

-- axis-separated sliding move
function move_solid(e,dx,dy)
 local bx,by=false,false
 e.x+=dx
 if solid(e.x,e.y) then e.x-=dx bx=true end
 e.y+=dy
 if solid(e.x,e.y) then e.y-=dy by=true end
 return bx,by
end

-- off-view, in-world spawn spot
-- (troopers and vader)
function spawn_pos()
 local x,y
 for _=1,20 do
  local side=flr(rnd(4))
  x,y=g.cam_x+rnd(128),g.cam_y+rnd(128)
  if side==0 then x=g.cam_x-6
  elseif side==1 then x=g.cam_x+134
  elseif side==2 then y=g.cam_y-6
  else y=g.cam_y+134 end
  if x>=4 and x<=world_w-4 and y>=12 and y<=world_h-4 and not in_rock(x,y,6) then
   return x,y
  end
 end
 -- theoretical fallback: 90 px away
 local a=rnd()
 return clamp(g.p.x+cos(a)*90,4,world_w-4),clamp(g.p.y+sin(a)*90,12,world_h-4)
end

function draw_world()
 cls(9)
 rectfill(0,0,world_w-1,world_h-1,15)
 for d in all(g.decor) do
  if in_view(d.x,d.y,16) then spr(d.s,d.x,d.y) end
 end
 for r in all(g.rocks) do
  if in_view(r.x1,r.y1,16) then
   if r.big then
    spr(r.s,r.x1-1,r.y2-15,2,2)
   else
    spr(r.s,r.x1,r.y2-7)
   end
  end
 end
end

function draw_gem(gm)
 line(gm.x-2,gm.y+4,gm.x+1,gm.y+4,4)
 spr(44+flr(g.frames/8)%2,gm.x-4,gm.y-4)
end
-->8
-- player
function new_player()
 return {x=256,y=256,fx=0,fy=1,hp=max_hp,inv=0,swing=0,cd=0,anim=0,dying=0,dead=false,eaten=false}
end

function is_blocking()
 return btn(5) and g.p.swing==0 and not g.p.dead
end

function hurt_player()
 local p=g.p
 if p.inv>0 or p.dead then return end
 p.hp-=1
 p.inv=inv_t
 g.shake=6
 sfx(4)
 if p.hp<=0 then
  p.dying=40
  p.dead=true
  p.swing=0
  sfx(5)
  music(-1)
 end
end

function upd_player()
 local p=g.p
 if p.inv>0 then p.inv-=1 end
 if p.dead then
  p.dying-=1
  if p.dying<=0 then
   g.state="over"
   if g.score>g.best then
    g.best=g.score
    g.newbest=true
    dset(0,g.best)
   end
  end
  return
 end
 -- input
 local dx,dy=0,0
 if btn(0) then dx=-1 end
 if btn(1) then dx=1 end
 if btn(2) then dy=-1 end
 if btn(3) then dy=1 end
 -- facing: keep while its key is held
 local keep=(p.fx==-1 and btn(0)) or (p.fx==1 and btn(1)) or (p.fy==-1 and btn(2)) or (p.fy==1 and btn(3))
 if not keep then
  if dx~=0 then p.fx,p.fy=dx,0
  elseif dy~=0 then p.fx,p.fy=0,dy end
 end
 if dx~=0 or dy~=0 then
  local m=p_spd
  if dx~=0 and dy~=0 then m*=0.707 end
  move_solid(p,dx*m,dy*m)
  p.x=clamp(p.x,4,world_w-4)
  p.y=clamp(p.y,12,world_h-4)
  p.anim+=1
 else
  p.anim=0
 end
 -- swing
 if p.swing>0 then
  p.swing-=1
  if p.swing==0 then p.cd=4 end
 elseif p.cd>0 then
  p.cd-=1
 elseif btnp(4) then
  p.swing=swing_t
  sfx(0)
 end
end

-- gem pickup + respawn
function upd_gems()
 local p=g.p
 for gm in all(g.gems) do
  if dist(p.x,p.y,gm.x,gm.y)<=6 then
   del(g.gems,gm)
   g.score=min(g.score+gem_pts,32000)
   g.gems_got+=1
   sfx(14)
   spawn_parts(gm.x,gm.y,8,12,7)
  end
 end
 if #g.gems==0 then
  gen_gems(gem_n,true)
  g.gems_got=0
  sfx(15)
 end
end

function draw_player()
 local p=g.p
 if p.eaten then return end
 line(p.x-2,p.y+4,p.x+1,p.y+4,4)
 if p.dead then
  spr(7,p.x-4,p.y-4)
  return
 end
 if p.inv%2==1 then return end
 local s,fl=1,false
 if p.fy==-1 then
  s=3
 elseif p.fx~=0 then
  s=5
  fl=p.fx==-1
 end
 if p.anim%16>=8 then s+=1 end
 spr(s,p.x-4,p.y-4,1,1,fl)
 draw_saber(p.x,p.y,p.fx,p.fy,saber_col,p.swing>0 and p.swing or (is_blocking() and "b"))
end

-- saber from (x,y) facing fx,fy in
-- colour col. mode: nil = held
-- forward, "b" = held across
-- (block), number = swing frame
-- (sweeps -60..+60 deg)
function draw_saber(x,y,fx,fy,col,mode)
 local a=atan2(fx,fy)
 local hx,hy,l0=x+fx*2,y+fy*2,0
 if mode=="b" then
  hx,hy,l0,a=x+fx*3,y+fy*3,-3,a+0.25
 elseif mode then
  a+=(4.5-mode)/21
 end
 local cx,cy=cos(a),sin(a)
 local x0,y0,x1,y1=hx+cx*(l0+1),hy+cy*(l0+1),hx+cx*(l0+5),hy+cy*(l0+5)
 -- glow either side, spine, white core
 line(x0-cy,y0+cx,x1-cy,y1+cx,col)
 line(x0+cy,y0-cx,x1+cy,y1-cx,col)
 line(hx+cx*l0,hy+cy*l0,hx+cx*(l0+6),hy+cy*(l0+6),col)
 line(x0,y0,x1,y1,7)
end
-->8
-- troopers
function spawn_trooper()
 return spawn_trooper_at(spawn_pos())
end

function spawn_trooper_at(x,y)
 local e=elapsed()
 local tr={
  x=x,y=y,
  spd=t_spd0+min(0.3,e/240),
  stop=max(20,56-e*0.15)+rnd(12),
  st="walk",t=0,shot_cd=0,
  flip=false,anim=0,stuck=0,
  side_t=0,side_dir=1
 }
 add(g.troopers,tr)
 return tr
end

-- one chase step along nx,ny with
-- the rock-dodging side manoeuvre
-- (troopers and vader)
function chase(e,nx,ny,spd)
 local mx,my=nx,ny
 if e.side_t>0 then
  e.side_t-=1
  mx,my=-ny*e.side_dir,nx*e.side_dir
 end
 local ox,oy=e.x,e.y
 move_solid(e,mx*spd,my*spd)
 if abs(e.x-ox)+abs(e.y-oy)<0.05 then
  e.stuck+=1
  if e.stuck>=6 then
   e.side_t=24
   e.side_dir=rnd()<0.5 and -1 or 1
   e.stuck=0
  end
 else
  e.stuck=0
 end
end

function alive_count()
 local n=0
 for tr in all(g.troopers) do
  if tr.st~="dead" then n+=1 end
 end
 return n
end

function kill_trooper(tr,pts)
 tr.st="dead"
 tr.t=dead_t
 g.score=min(g.score+pts,32000)
 g.kills+=1
 sfx(3)
 spawn_parts(tr.x,tr.y,6,4,15)
end

-- live troopers left far behind
-- vanish silently (no kill)
function despawn_far()
 for tr in all(g.troopers) do
  if tr.st~="dead" and dist(tr.x,tr.y,g.p.x,g.p.y)>despawn_d then
   del(g.troopers,tr)
  end
 end
end

function upd_troopers()
 despawn_far()
 if alive_count()<max_alive() and g.spawn_cd<=0 then
  spawn_trooper()
  g.spawn_cd=max(30,90-elapsed()*0.4)
 end
 g.spawn_cd=max(0,g.spawn_cd-1)
 local p=g.p
 for tr in all(g.troopers) do
  local d=dist(tr.x,tr.y,p.x,p.y)
  local nx,ny=norm(p.x-tr.x,p.y-tr.y)
  if tr.st=="dead" then
   tr.t-=1
   if tr.t<=0 then del(g.troopers,tr) end
  else
   tr.flip=p.x<tr.x
   -- shoot only while in view
   -- (and below the hud band, v1 4.2)
   local vis=in_view(tr.x,tr.y,0) and tr.y>=g.cam_y+12
   if tr.st=="walk" then
    tr.anim+=1
    if d<=tr.stop and vis then
     tr.st="aim"
     tr.t=aim_t
    else
     chase(tr,nx,ny,tr.spd)
    end
   else
    -- aim
    tr.t-=1
    if d>tr.stop+8 or not vis then
     tr.st="walk"
    elseif tr.t<=0 then
     fire(tr)
     tr.stop=max(16,tr.stop-6)
     tr.shot_cd=45+flr(rnd(30))
     tr.t=tr.shot_cd
    end
   end
  end
 end
 -- soft separation
 for i=1,#g.troopers do
  local a=g.troopers[i]
  if a.st~="dead" then
   for j=i+1,#g.troopers do
    local b=g.troopers[j]
    if b.st~="dead" and dist(a.x,a.y,b.x,b.y)<8 then
     local nx,ny=norm(b.x-a.x,b.y-a.y)
     move_solid(a,-nx*0.3,-ny*0.3)
     move_solid(b,nx*0.3,ny*0.3)
    end
   end
   if dist(a.x,a.y,p.x,p.y)<6 then
    local nx,ny=norm(a.x-p.x,a.y-p.y)
    move_solid(a,nx*0.3,ny*0.3)
   end
  end
 end
end

function draw_trooper(tr)
 if tr.st=="dead" then
  spr(19,tr.x-4,tr.y-4,1,1,tr.flip)
  return
 end
 line(tr.x-2,tr.y+4,tr.x+1,tr.y+4,4)
 local s=16
 if tr.st=="aim" and tr.t<=aim_t then
  s=18
  pal(1,8)
  if tr.t%4<2 then
   local mx,sx=tr.x+4,1
   if tr.flip then mx,sx=tr.x-5,-1 end
   line(mx,tr.y,mx+sx*2,tr.y,10)
   line(mx,tr.y+1,mx+sx,tr.y+1,9)
  end
 elseif tr.anim%16>=8 then
  s=17
 end
 spr(s,tr.x-4,tr.y-4,1,1,tr.flip)
 pal()
end
-->8
-- vader
function spawn_vader()
 local x,y=spawn_pos()
 g.vader={x=x,y=y,hp=v_hp,st="walk",t=0,fx=0,fy=1,flip=false,anim=0,stuck=0,side_t=0,side_dir=1,cd=0}
 for i=0,2 do
  local ex,ey=clamp(x+i*12-12,4,world_w-4),clamp(y+i%2*24-12,12,world_h-4)
  if in_rock(ex,ey,6) then ex,ey=spawn_pos() end
  spawn_trooper_at(ex,ey)
 end
 music(4)
end

function upd_vader()
 local v,p=g.vader,g.p
 if not v then return end
 local d=dist(v.x,v.y,p.x,p.y)
 local nx,ny=norm(p.x-v.x,p.y-v.y)
 -- 4-way facing toward the jedi
 if abs(nx)>=abs(ny) then
  v.fx,v.fy=sgn(nx),0
 else
  v.fx,v.fy=0,sgn(ny)
 end
 v.flip=p.x<v.x
 v.t-=1
 if v.st=="walk" then
  v.cd=max(0,v.cd-1)
  if d>v_reach then
   v.anim+=1
   chase(v,nx,ny,v_spd)
  elseif v.cd==0 then
   v.st="windup"
   v.t=v_windup
  end
 elseif v.st=="windup" then
  if v.t<=0 then
   v.st="strike"
   v.t=8
   v.hit=false
   sfx(8)
  end
 elseif v.st=="strike" then
  if v.t>=3 and v.t<=7 and not v.hit and d<=swing_r and dot(v.fx,v.fy,nx,ny)>=swing_cos then
   v.hit=true
   if is_blocking() and in_cone(v.x,v.y,14,block_cos) then
    -- parry
    sfx(9)
    spawn_parts(p.x+p.fx*4,p.y+p.fy*4,10,saber_col,v_saber_col)
   else
    hurt_player()
   end
  end
  if v.t<=0 then
   v.st="walk"
   v.cd=30
  end
 elseif v.st=="stagger" then
  -- 8 px knockback over 3 frames
  if v.t>=27 then
   move_solid(v,-nx*8/3,-ny*8/3)
   v.x=clamp(v.x,4,world_w-4)
   v.y=clamp(v.y,12,world_h-4)
  end
  if v.t<=0 then v.st="walk" end
 elseif v.t<=0 then
  g.vader=nil
 end
end

-- jedi's swing lands on vader
function hit_vader()
 local v=g.vader
 -- invulnerable while staggered or dying (spec 7.2)
 if v.st=="stagger" or v.st=="dying" then return end
 v.hp-=1
 v.st="stagger"
 v.t=v_stagger
 sfx(10)
 spawn_parts(v.x,v.y,6,v_saber_col,7)
 if v.hp<=0 then
  v.st="dying"
  v.t=60
  g.score=min(g.score+v_pts,32000)
  sfx(11)
  music(0)
 end
end

function draw_vader()
 local v=g.vader
 line(v.x-2,v.y+4,v.x+1,v.y+4,4)
 local s=24
 if v.st=="windup" then
  s=26
 elseif v.st=="dying" then
  s=27
 elseif v.anim%16>=8 then
  s=25
 end
 -- saber origin: below the feet facing down,
 -- above the helmet (behind the body) facing up
 local held,mode,sy=v.st~="windup" and v.st~="dying",v.st=="strike" and v.t,v.y-3
 if v.fy==1 then sy=v.y elseif v.fy==-1 then sy=v.y-8 end
 local behind=held and v.fy==-1 and not mode
 if behind then draw_saber(v.x,sy,0,-1,v_saber_col) end
 if (v.st=="stagger" or v.st=="dying") and g.frames%2==0 then
  pal(0,7)
  pal(5,7)
 end
 palt(0,false)
 palt(3,true)
 spr(s,v.x-4,v.y-12,1,2,v.flip)
 pal()
 if v.st=="windup" then
  -- from the raised hand, clear of the helmet
  draw_saber(v.x+(v.flip and -3 or 3),v.y-10,0,-1,v_saber_col)
 elseif held and not behind then
  draw_saber(v.x,sy,v.fx,v.fy,v_saber_col,mode)
 end
end
-->8
-- bolts
function fire(tr)
 local p=g.p
 local a=atan2(p.x-tr.x,p.y-tr.y)+rnd(bolt_spread*2)-bolt_spread
 add(g.bolts,{x=tr.x+(tr.flip and -5 or 4),y=tr.y,dx=cos(a)*bolt_spd,dy=sin(a)*bolt_spd,owner="e",src=tr})
 sfx(2)
end

-- 30% exactly at the shooter,
-- 70% exactly +/-10 degrees off
function deflect(b)
 local nx,ny
 if b.src and b.src.st~="dead" then
  nx,ny=norm(b.src.x-b.x,b.src.y-b.y)
 else
  nx,ny=norm(-b.dx,-b.dy)
 end
 local a=atan2(nx,ny)
 if rnd()>=defl_exact then
  a+=(rnd()<0.5 and -1 or 1)*defl_dev
 end
 b.dx,b.dy,b.owner=cos(a)*rbolt_spd,sin(a)*rbolt_spd,"p"
 sfx(1)
 spawn_parts(b.x,b.y,4,saber_col,7)
end

function upd_bolts()
 local p=g.p
 local sw=p.swing>=3 and p.swing<=7
 -- swing hits (after upd_troopers so a
 -- killed trooper lies the full dead_t)
 if sw then
  for tr in all(g.troopers) do
   if tr.st~="dead" and in_cone(tr.x,tr.y,swing_r,swing_cos) then
    kill_trooper(tr,10)
   end
  end
  if g.vader and in_cone(g.vader.x,g.vader.y,swing_r,swing_cos) then
   hit_vader()
  end
 end
 for b in all(g.bolts) do
  b.x+=b.dx
  b.y+=b.dy
  local gone=false
  if not in_view(b.x,b.y,16) or b.x<0 or b.x>world_w or b.y<0 or b.y>world_h then
   gone=true
  elseif in_rock(b.x,b.y) then
   spawn_parts(b.x,b.y,4,9,10)
   gone=true
  elseif b.owner=="e" then
   if sw and in_cone(b.x,b.y,swing_br,swing_cos) then
    deflect(b)
   elseif is_blocking() and in_cone(b.x,b.y,block_r,block_cos) then
    deflect(b)
   elseif dist(b.x,b.y,p.x,p.y)<=hit_r then
    hurt_player()
    gone=true
   end
  elseif g.vader and dist(b.x,b.y,g.vader.x,g.vader.y)<=6 then
   -- reflected bolt fizzles on vader
   spawn_parts(b.x,b.y,4,v_saber_col,7)
   gone=true
  else
   for tr in all(g.troopers) do
    if tr.st~="dead" and dist(b.x,b.y,tr.x,tr.y)<=5 then
     kill_trooper(tr,20)
     sfx(7)
     gone=true
     break
    end
   end
  end
  if gone then del(g.bolts,b) end
 end
end

function draw_bolts()
 for b in all(g.bolts) do
  line(b.x,b.y,b.x-b.dx*1.5,b.y-b.dy*1.5,b.owner=="e" and 8 or 12)
 end
end
-->8
-- worm
function upd_worm()
 local w,p=g.worm,g.p
 -- anchor watch (only from worm_after s)
 if elapsed()>=worm_after then
  if dist(p.x,p.y,w.ax,w.ay)>worm_area then
   w.ax,w.ay,w.still=p.x,p.y,0
  else
   w.still+=1
  end
 end
 if w.st=="idle" then
  if w.still>=worm_still then
   w.st,w.t,w.ex,w.ey="tremor",worm_tremor,p.x,p.y
  end
  return
 end
 w.t-=1
 if w.st=="tremor" then
  g.shake=max(g.shake,2)
  for _=1,2 do
   spawn_parts(w.ex+rnd(16)-8,w.ey+rnd(16)-8,1,4,9)
  end
  if w.t%30==29 then sfx(12) end
  if w.t<=0 then
   w.st,w.t="emerge",60
   sfx(13)
  end
 elseif w.st=="emerge" then
  if w.t==50 and not p.dead and dist(p.x,p.y,w.ex,w.ey)<=worm_bite_r then
   p.dead,p.hp,p.eaten,p.swing,p.dying,g.cause=true,0,true,0,40,"worm"
   music(-1)
  end
  if w.t<=0 then w.st,w.t="sink",30 end
 elseif w.t<=0 then
  -- sink done
  w.st,w.still,w.ax,w.ay="idle",0,p.x,p.y
 end
end

-- 32x32 sprite centred on (ex,ey-8);
-- a (64) closed mouth, b (68) open
function draw_worm()
 local w=g.worm
 if w.st=="emerge" or w.st=="sink" then
  local dy=0
  if w.st=="sink" then
   dy=30-w.t
   clip(0,0,128,w.ey+8-g.cam_y-g.sy)
  end
  spr(w.t>=45 and 64 or 68,w.ex-16,w.ey-24+dy,4,4)
  clip()
 end
end
-->8
-- fx + hud
function spawn_parts(x,y,n,c1,c2)
 for _=1,n do
  add(g.parts,{x=x,y=y,dx=rnd(2)-1,dy=rnd(2)-1,life=8+flr(rnd(8)),col=rnd()<0.5 and c1 or c2})
  if #g.parts>60 then deli(g.parts,1) end
 end
end

function upd_parts()
 for q in all(g.parts) do
  q.x+=q.dx
  q.y+=q.dy
  q.life-=1
  if q.life<=0 then del(g.parts,q) end
 end
end

function draw_parts()
 for q in all(g.parts) do
  pset(q.x,q.y,q.col)
 end
end

function pad(n)
 return (n<10 and "0" or "")..n
end

function draw_hud()
 rectfill(0,0,127,7,0)
 for i=1,max_hp do
  print("♥",i*8-7,1,g.p.hp>=i and 8 or 5)
 end
 print("◆ "..g.gems_got.."/"..gem_n,26,1,12)
 local s=flr(elapsed())
 print(pad(flr(s/60))..":"..pad(s%60),54,1,7)
 local sc=tostr(g.score)
 print(sc,127-#sc*4,1,7)
 if g.vader then
  for i=1,v_hp do
   rectfill(47+i*5,9,50+i*5,11,g.vader.hp>=i and 8 or 2)
  end
 end
end

function cprint(s,y,c)
 print(s,64-#s*2,y,c)
end

function draw_over()
 rectfill(20,40,107,90,0)
 rect(20,40,107,90,7)
 cprint("game over",46,8)
 if g.cause=="worm" then cprint("eaten by a sandworm",52,9) end
 cprint("score "..g.score,58,7)
 cprint("best "..g.best..(g.newbest and " new!" or ""),66,10)
 if t()%1<0.7 then
  print("press 🅾️ to retry",30,80,6)
 end
end
-->8
-- title screen (v2.1, spec 2)
--
-- px9 decoder by zep & co.
-- (bbs #34058, px9 v11), used
-- under cc by-nc-sa 4.0.
-- the title image is px9 data
-- at 0x1000..0x2123 (4388 bytes):
-- the empty lower half of the
-- sprite sheet (__gfx__ rows
-- 64-127 = __map__ rows 32-63)
-- plus __map__ rows 0-2. sprites
-- 128-255 hold data: never draw them.

-- x0,y0 where to draw to
-- src   compressed data address
-- vget  read function (x,y)
-- vset  write function (x,y,v)
function px9_decomp(x0,y0,src,vget,vset)
 -- move val to the list head
 local function vlist_val(l,val)
  local v,i=l[1],1
  while v!=val do
   i+=1
   v,l[i]=l[i],v
  end
  l[1]=val
 end
 -- read an m-bit number from src
 local function getval(m)
  local res=$src>>src%1*8<<32-m>>>16-m
  src+=m>>3
  return res
 end
 -- read a number, add n
 local function gnp(n)
  local bits=0
  repeat
   bits+=1
   local vv=getval(bits)
   n+=vv
  until vv<(1<<bits)-1
  return n
 end
 -- header: w-1,h-1,bits,colours
 local w_1,h_1,eb,el,pr,splen,predict=gnp"0",gnp"0",gnp"1",{},{},0
 for i=1,gnp"1" do
  add(el,getval(eb))
 end
 for y=y0,y0+h_1 do
  for x=x0,x0+w_1 do
   splen-=1
   if splen<1 then
    splen,predict=gnp"1",not predict
   end
   -- predict from the pixel above
   local a=y>y0 and vget(x,y-1) or 0
   local l=pr[a] or {unpack(el)}
   pr[a]=l
   local v=l[predict and 1 or gnp"2"]
   vlist_val(l,v)
   vlist_val(el,v)
   vset(x,y,v)
  end
 end
end

-- decode the title image to the
-- screen once and cache it in
-- extended memory 0x8000-0x9fff
function load_title()
 px9_decomp(0,0,0x1000,pget,pset)
 memcpy(0x8000,0x6000,0x2000)
end

-- restore the cached image and
-- draw the text overlay
function draw_title()
 memcpy(0x6000,0x8000,0x2000)
 rectfill(0,114,127,127,0)
 if t()%1<0.7 then
  cprint("press 🅾️ to start",116,7)
 end
 cprint("best "..g.best,122,9)
end
__gfx__
00000000004444000044440000444400004444000044440000444400000000000000000000000000000000000000000000000000000000000000000000099000
0000000004eeee4004eeee4004444440044444400044eee00044eee0000000000000000000000000094000000000094000009900009900000000000000994000
0000000004e1e14004e1e14004444440044444400044e1e00044e1e0000000000000000000000940000009400099400000099440009940000000000009944200
00000000044ee440044ee44000444400004444000044ee000044ee00044000000099094000009442000000000094400000994444099444000000000099444200
000000000447744004477440044444400444444000444700004447004ee444470944494200099442009400000000000009944444944444000000000994444200
000000000449944004499440049999400499994000449900004499004e1e49540444244209944422000000000940000009944444444442000009900994444200
00000000044774400447444004444440044444400044470000444400044000050442222204444222000094000000009409444444444442000099449944444200
00000000005005000500005000500500050000500005500000500500000000000022222000222220000000000000000009444444444444200994444444444420
00777700007777000077770000000000090000000009000000000000000000003330033333300333333003553333333309444442444444200944444444444420
07777770077777700777777000000000009000000009400006700760007776003300003333000033330000303333333309444422444444200944444444444420
07711110077111100771111000000000000900000000900006666660076666603006600330066003300660303333333309444224444442200944444444444220
0677717006777170067777000770000000094000000940000d6006d006d66d603006000330060003300600303333333309442244444422200944444444442220
06777700067777000677555571177777000909000094000000000000066666600000000000000000000000303330033309444444444222200944444444422220
0777755507777555077755507677776500009090004900000000670d00d6d6003050500330505003305050303300003300444444422222200044444442222220
00767700007677000076770007700000000000900090000000000000000606003055500330555003305550303006600300222222222222000022222222222200
07000070007007000700007000000000000000000000000000000000000000003300003333000033330000303006000300022222222220000002222222222000
00000000000000099400000000000000000009000000000000000000000000003000000330000003300000000000000000000000000007000000000000000900
00000000000000994440000000940000000090000666666d090409000ee00ee030080003300800033008000330505003000cc000000cc0000000000000009400
00099400000009944444000000000000000940000060060000494000e888e888300bc003300bc003300bc0033055500300c7cc0000cccc000900909009040900
00944440000099444444200000000940000900000666666d09044490e8888888300000033000000330000003300000030c7cccc00cccc7c00094940000490400
0944444200099444444422000900000000940000006006000044940008888880300500033005000330050003300800030ccccc100ccc7c100904440900044900
04444422009944444444420000000000004900000666666d0004400000888800300000033000000330000003000bc00000ccc10000ccc1000049490000940000
044422220994444444444200000940000940000000000d00000400000008800000000000300000030000000000000000000c1000000c10000004000000040000
00222220094444444444442000000000000000000000000000000000000000003050350333050503305035030500005000000000000000000000000000000000
00000000094444444444442000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000094444444444442000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000094444444444422000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000094444444444222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000094444444442222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004444444222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000002222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000222222222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000044499999994440000000000000000000444999999944400000000000000000000000000000000000000000000000000000000000000000000000000
00000004499999999999994400000000000000044999999999999944000000000000000000000000000000000000000000000000000000000000000000000000
00000049ff999999999999994000000000000049ff99999299999999400000000000000000000000000000000000000000000000000000000000000000000000
0000049fff99999999999999940000000000049fff22222222222999940000000000000000000000000000000000000000000000000000000000000000000000
00004999999999999999999999400000000049997227117117117227994000000000000000000000000000000000000000000000000000000000000000000000
00004999999999999999999999400000000049927117117117117127994000000000000000000000000000000000000000000000000000000000000000000000
00044999992992992992992999440000000449221111111111111112294400000000000000000000000000000000000000000000000000000000000000000000
00004992229999999999992229400000000049221111111111111112294000000000000000000000000000000000000000000000000000000000000000000000
00004992222222222222222229400000000049221111111111111112294000000000000000000000000000000000000000000000000000000000000000000000
00000499992222222222229994000000000004922111111111111122940000000000000000000000000000000000000000000000000000000000000000000000
00000049999999999999999940000000000000492721711711712729400000000000000000000000000000000000000000000000000000000000000000000000
00000004499999999999994440000000000000044722722722722744400000000000000000000000000000000000000000000000000000000000000000000000
00000004944499999994444440000000000000049444999299944444400000000000000000000000000000000000000000000000000000000000000000000000
00000000499999949999944440000000000000004999999499999444400000000000000000000000000000000000000000000000000000000000000000000000
00000000444444444444444440000000000000004444444444444444400000000000000000000000000000000000000000000000000000000000000000000000
00000000499999999999994440000000000000004999999999999944400000000000000000000000000000000000000000000000000000000000000000000000
00000000499999999999994444000000000000004999999999999944440000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994444000000000000000499999999999944440000000000000000000000000000000000000000000000000000000000000000000000
00000000044444444444444444000000000000000444444444444444440000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994444000000000000000499999999999944440000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994444000000000000000499999999999944440000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994444000000000000000499999999999944440000000000000000000000000000000000000000000000000000000000000000000000
00000000044444444444444444000000000000000444444444444444440000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994440000000000000000499999999999944400000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994440000000000000000499999999999944400000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999994440000000000000000499999999999944400000000000000000000000000000000000000000000000000000000000000000000000
00000000044444444444444440000000000000000444444444444444400000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999944440000000000000000499999999999444400000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999944400000000000000000499999999999444000000000000000000000000000000000000000000000000000000000000000000000000
00000000049999999999944400000000000000000499999999999444000000000000000000000000000000000000000000000000000000000000000000000000
00000000444444444444444400000000000000004444444444444444000000000000000000000000000000000000000000000000000000000000000000000000
00000000499999999999444000000000000000004999999999994440000000000000000000000000000000000000000000000000000000000000000000000000
ffffff0ffffff0df96a38be59c0c35e61dffff73094000000000000000000000000000000081e21cff80cfff903c994c62e2294cfff7ccc248000294c0930cff
ffc26b1e3382b522191f8d0803c42c000c2611069d61127446149d6f94639d3bd4c4691118f09dce867b29349dc2d5322b4a2c26124b98625016c32521288004
c1c88c62a2219ce0d709ac1e96e0e852eac5e133dc5397a4be1ea5e27c11fc142bee06c9b3c29ec3f88e1d3e2b5ea95f7297decc8d6e90f52e47c7afbc115740
74e88f22902136020216c401099702932e03d190840c0340cf01f42e04816d5f844270783e44269dea27504295ea628e46bfe919ec64a940e12e3a2194a9c25b
4c409a1b89c0bc2f0d5ab0f94b16f6e936bc211c17014e8f27c6b679575b52b2bc4caa33afc26e2db6bc15b5d26cc195fac2d81d29daa175ae83add19e2b3694
d3909b27c59a50e85e852dc426a9015747f46807c65ab1fe37d12dc69e37d42bc2b4346d4c6d1aa2b27c42c229e49c19344a7807c36db2b35707c5503409a011
58b4125336bb2b34ab4298409abe8c3e085a8656f52231946d04237c3369e99b394ae8a53126ef0315126d56f846eb523764442940230c14652c11938de06942
9596c0bb4a942a70c04c0e83ea4e503d405b1bc31bc311b53112a854420c283650a7468402a93e0a1b32d08e73bf45f4bf524e9ee9bae219013370756905f7c0
9e154e16bfabace1e0f477806ac98425743644074f0853bc1b76487e177f04398094210bf697694f62ace6b7243215a194c1e852ed3442f872bd2a6b0b8de984
6194917409c1f5e36f469de788479633af30590799df0d7450601a403fc2f4270746919324c832603c88013f5485b39c19701b3abf1eaf14eb4e482abb8c3fe4
0219661d3883854e07c4274621142b326b890f4942740eea07d6b33744cc663b529442b50a2fd0ea04c9232198c28891426346b098202401976125361ef8bc32
1060ea9c8c2004c2809428438f16020c462ba0954e90f7401c835424524e02251b44287221c0b7e30b7421c30c4a141c1089019ff70518c414488c19502a7d78
64032622940d8c8888ad23112622f409c4429f3402e850213322942100a468c48b00a402f94082ce1406b12c6c40c61b3b932934e114868b3c92ff23e9222106
698885424a4219502201c9222e204e600871001c7009b006932ebc0034e008cc24001068010b7085231a94814211401650184a142432b022022888a880902980
96219902b443c601093022483280282d8298013c19461a184294280442424802169858b4431ee0844c242140852c1cec33f4f846315582b1190c802c44261958
1e14242480842ea0903198620750183b7c0c14832122429090784016814048e2807584521c6feb95a23040c6c1a112e88deba4fa4a8473cc29444485346bc1f5
e1484464cc51105874c0bd3796263669030d429804e013af548442220909888c41271bd0e9e218f7601093ea3657c6644202121422917454d919803905229888
3404c29365f3c44c799842b480280a0d09093ac1e1298708d200983038202122030688a52c5c80e0138422cf5121e938f3e079309c811145212b0d00b4285503
1855c1e94046a938c5f44e8f9e0000c358e1b3717622e0101c122e00651c51121c0ea5278012d95824294e87d21ff57858d31fcf1f877f8c3331ec3810ce0219
902e497402bf56a269c88b6bc37d11f3c10001e90b0972ea4c92960125742f9814311942804c83c39909c6e7c405946f38f16932b758f531f46c61742ea14eb9
e91b323974e85012e04c19329e622b999d57d631014a76e8b464014148f243b3ce8fc3901a9c5f3d7ec3699029f421c7e9c019f5262214e8469501c393fbd1f6
4e79ccf1fc6bccbd0754ef81c29ad6233c3c309c1188562168b2707094e01789380b02c24242807c329c7e84458cb1eb3830901cad8c44ca5d44201902836940
13c798f3f94c574e8c44a583f00e8da94d1446222b142a16fc4a28535a6bf00eb090b0d34e79c37abef9024844c4876919cc66261a1c2278811c1b5d79946ec0
7d58c3f46b978c21f400432c12483463bf5069522161e8b4ae78c023b44e8d1e98c84dfe226743f942c9109e60c3f4fb3d47fe71dde04e80b09d114c666a9aca
1f93a11d4cf524c797693e06690750143c2f9bc221d7343590907c9bfc6784f219348d138481d4cf294c5bfe78a5e00f5921c77c3fd39a86ab3ca73675a616db
52f0e800237972f048f3711f42b8c64eb07ca7c1e82901d7e017c9fe0d5ae8094153c8848583e10d05efb7853f78d69f12326137d5de434c37d37ee8993e8ca3
c69aaeabba9a29304ae0d781f3e77cea33be1e9428fa12ec027de801fc53fc31623f46b373862f43972b4531e0793428091c0a0f4093bead56e2211af7002ede
24883e83ecd4b1ce1466987a1785e8ad37c8d463e9d22603c01a14038dec88b5f9c643242109b6b43a488c60bc593d3231be333624a894c3624248b8114a450f
ce8d2290753f7cde98a0e022e17df19746e978cad3a11e25d9faa78afc3ac55cf1e1c3e1994744b9074e97a9036e02943b60beef83c6e792b6a33b42cb6291d0
850328f4aeab5142875ced2468fef1589e2d7a9d29b84d4eacf2fee0932bc80e208858b7e1f382319c3de0632c222cc803f83f9369c397e4bdc44021793421e8
da746af50487f092f6e03785e8913468644129dc3fb8df17427527d39c66677df02e8cc4a7ee8d278775e24027587cc3c669892c5fb020d43b448197e9073f67
a9943955e47421f1bc16a93cbf884d6f5450924661561f4e793278027c3e07934e0ea3267f39fc9121a97e8fb22f9524c17cf07c574d9d341284290884c396e9
d16fe5283b577e901784274f932e0f4883e8d19ef29417d0c925f86e8c3eaaf46978ca681c593695a2f8d5a5dc79b2383eb3e8bd16a12e8729cf168b8cf52e97
ce0063e7a763e787e79bfc85a6397df57a3ed74f9f3e01dc7ce8b428e3b6ed3e93f886eb52f8eaddde3d2ed667127c8f323e2231512215017ea29cf2e49acea6
2305af46e9d175ff877ce002ca394e4004c520e8725229b6a31eb194e09d4c5227aa88320c4c1578c0116374a960de1783845c1c1743cbb94ce15834a9342c3c
14094de83059c8b28c23a9da612d5e0b62dc23cbd41e19deb2a2c806e2f6661ddc1469183c4f952633690f468d2c3624e12b729c797e84075023785081111c7d
2a718d6890b9942e78c22175cc5ead61f1d14221932d07d71fe59467009fe0f404c58b56bb4d21677de8e6b5434b1d43cf113514ebc37c153f44c05018f2990a
249f3abfa2ac3c269430d746129cd7c43f742983617d1b763b3ec219212708e1e2b820a480772b62b423e07c112a9c29c4659988d3e854e8c7ecd2b084e93888
c12e98d5467016c9cdb6c775617c68c6198c5ac83229c599a63dd522523dfae0f340295476301efcc15bbed412d72d32ce1290c6d62ba5d37cc3b46b76194635
e0694c5742981c60e261e2b0783856b056ce05b9303136f441a78740b373930295e1275c4f013c8640f7043492fe278cc16b96c6294c197e0106ba567c19629b
37b99a4421f29c21fb09d53b84c46ebc2b3eaca235934880f8086c3217e011c0901274e8ee0211b321cf12191bac70261ed95ea68cad1748321f38449b010bf8
a548a6293c29cf0998c51f2ea4c92a1dc38d950c39b270f012285e09074e0b7e93e942d42f7f1c1fcefa04e47c1c517c4f1e08c393858ef6a7283e8d5ecc39d5
1e29fe82fa7d074e321f40980f78709036c33793c39287e0f8d18ff83d3e9a1e9d1617017421a9ce0ea98cac10a275dab883286658efc2fe7c9b97c9fe659952
b425e379c1b0680f8fe11bd8658442e099b084df4c57c2d7a4de9fe953806c695c014872804b40097c1e838d616970bbeb32174907d1d30279c20c1fc5cbe976
7da674d97c6911adc605f079d73b72dc698d3aaf525902dd19c92e87e9b21f60d3004c179d04a5b9932fc590838ee84698d4f0884c195c17f2f0d36f3c34c42d
b6b42b44ce9001c52c96836d383281172b33b55c27ee69568303662c60f44384d2b078cf3ff8c8723e584239262b4c1c6a2d4f96427d6d3e8cd796e8b6479883
2d3a6f09c27c7e80d4c232b012d3aa27429b293278d0766e49d0dc3934b29ae3bee836e97eadbf3c3eadd39dcd743147f427481f4cea7e39b29e7fbce1bc217d
172d862e9c6f8a63b0c397e8196d42397a7d3217e598083f09d2119b29b2d5ee724201ae93c83874e90d43766932f4f84d324a746e9c6fcf62d0bd1b532b7425
31521b322b3adc422cc5c127437c7eab29cc283cd66228d6e1ca8d174887078093696311f3a269956b465c1194427a6e0943c12c577299bd2b2122fc89fe856b
34c69936956c169437c2c4e044f0bc18c189dd98d63a9801e896293c5fc23759329c3e93274097caa6c217936139ad86216a1907c211996e02b32d3a4bf4ab32
1ea84c51223ca64d37c5f429d9976b23b79c23bf80a9674cf3bb27409eabe3258431916b2ba9b2bd6993c68c1e97739d6106b044f85a830b6c139c1b45e019c3
ca134c37023f4e87eb9a875a39465928c11c4690e8f216704c21f829c24c120191e0ba8c3228f81adace7872c1634ae124cc718e8a270b32bc3603439324c214
ec42134e0e02d4a4e856e909f14ac423b3c594ece60944e82dc462393912b02852b44c19440a1c14e0f0c2ba4942270b446de177a90687a5d8221bc174268c66
9ca1c256195321e90b5842ea191785f0700ec44b3f5a2d0f746397213c16a1110fc756701e8544847d0d142698f368842a93dc5460ff2dc90f8ad86e9c230149
8e91434422b6c1ce104833952ae3787a987827722923178c4ea48c12fc6d10b095a244519360c361e9584393e1dcead39326e295aec22b74f111199f522619c3
368e2870103200bd004e8369c4a2f38321524c17874675424e01f7ce9dca9e9d8e217722bafc3111963279ce1b48422409ce1b89b29c2da89407cac17d42d32d
d49189ea98423184cb42308037806120298a42004ece69994a4297c103c598eebc626b3857a90cf0ce9f2b443481e2c6028fa10bf1e0b5854c018e11eed4e844
8462cf571944032f66229882161060cf12933980cd17d46b9d9cb860f745444ec1198061901c074e27ace88c28f12b446b6029345e6ef23343719a8942242c11
e94858720175321135f782b01942acff244e962144224e181111258a8a05cc2eb29540f22bc4ac42f803f7b144857746ecc280f44086019fa91d84609970d429
70452702efd884c8a4039444261083021e21505440f0716fd5bb842f852bc443bdefd48b0a468038021e6746a9fc48429422fa346124a9c2dc72941f899f17b8
da246470c2807508080f5347709091c59629095efacc2700ecdf013115b9764e494075c52194c7880e987e8de17c2974f840a921cc3b64429f9e063b9780e8ae
a1de38040378f8c212296a439309e8d593ae947940d4d193c394c27de70261142b0b5f95d326298a26a11e110904e62a08cc56653c23b5ea43c17d211ef06b3e
8956129da25645845ea42c23f4a09028014932fde05398b661e1dd6bce8369442984cf4c2e1787c111d92bc19c19c2901b093190944219518ede0936224852ae
b34f845559d1629d8700e9d54a746274b74fa4ce0748587c190614e1c0b3448c136bc278306782196c197aa984ccc3956f80119462ea6e1b6674724e01e3c426
__label__
3d31d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3
3d3d3d3d3d3d313d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d313d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3dcd3d3d3d3d3d
3d31d3d13d13d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3dc1c1cd3d3d3dcd3dcd3d3
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3dd3dcdcdd3d3d3d3d3d
13d31d31311313d3d31313131c1c131c13d3d313d131c131c131c1d3131c131c1c1d3d3d131c1c1c13d3d31c13d1c1c1dc1d3cd3d3d3d31c3d313d3d3dcdc1cd
d31c1c1ddddddd53d5ddddddd5d3dddddd1c5ddddddd55dddddd53dddddddddd53d3d31ddddd5d5dddddddd5ddddddd53d5dd55ddd5d3ddd55ddddddd53d3d3d
3d3d3d1ffafafff535fffffffa1dffffffd55fffffff45fffffffd1dffffffff51c1c1dffffff55ffffffff44fffffffd3dff45fff5d1fff54fffffff41cd3d3
3d31d314fffffaff55fffffff45ffffffff55fffffff45ffffffff5dffffffff53d31dffffffff5ffffffff54ffffffff54ff45fff51dfff54fffffff45d3dcd
d3d3d356ff444fff45fff444445fff44fff45fff444455fff44fff4544fffd4451dc1dfff44fff444ffff4454fff44fff54ff45fff55fff414fff444451cd3d3
3d31c114ff4104ff45fff511115fff5154455fff011155fff504ff4151fff40153d35dff4054445104ff4151dff415fff44ffd5fff5fff415dffa1111553dd3d
3d3d3d3fff455dff45fff5555d5fff4551155fff55553dfff51dff45d5fff45d3d3d16fffd55115d3dffd5d1dff455fff54ff45fff4fff1534fff55d5dd3c1cd
d3d3d31fff453dff45ffffff455ffffffd5ddffffff45dfff4dfff41c5fff43d3d3d35ffffff5d3d16ff45c5dfff5dfff45ffd5ffffff55d5dffffff43dd3d3d
3d3d3d1dff455dff45ffffffa1554fffffd55ffffff41dffffffff5535fff41d3d3dd14ffffffd5c5dff4535dfffffffd54ff45fffff45d3d4ffffff41c1d3d3
d3d3d35fff455dff45fff4f445d5544ffaf55fff44f41dfffffff55dd1fff43d3d3d3d154dffff535dff45c1dffffff455dff45ffafff55c5dfff4a445d3dcdd
3d3d3c14ff4534ff45fff50551d35155aff44faf550555faf4faf53d35fff41c1d3dd3d1504fff5d3dff45d3dff44ffa51dff45aff4faf5d34ff451551cd3d3d
d3d3d35daf45dfaf45afa55513ddd451eaf45ff451553dffa04ffa1dd5fff45d3d3d3ddd555faf53d4ff45c54af45fff55daf45faf44faf5d4faf1515d3dd3d3
3d3d3d14aa4dafaf45fae4fdf45aff4fafa45afa4fdf55af455aff53d1afa43d3d3d1faffdaffa5d3daf45d3dfa454faf54fa45faf55afad54faf4fdf55c3dcd
d3d3d3d4f9fafaf455afafaaf45faafafa454a4fa9aa45af9514aa45c54fa41cd3dc14faafafa45d14fa45c54af455afa44af459f9514faf44aeaaaaa41dd3d3
3d3d3d14af9f9f42559f9f4fa4524f9fa4415faeaeaf45ae4554fa45d5aea453d3d3d54fafaf421d34ff45d34fa4554ff44fa45fae5d14fa44faeaeff45cddcd
d3d3d355252554553525444544555452525554545424552545d52455c154555c1d3d3d142524553dd54455cd54525d544554525244535545554545444553d3d3
3d3d3d311115115dd351111511531111515d15111111551515351515dd1151d3d3d3d3d115115dd3d111553d15153d1151515551515dd1515151511151ddcddd
d3d3d3dd3d3d3d3d3d3d3dd3dd3ddddd3d3dcd3d3dd3d3dddcdcd3d3d3ddd3dd3dddcd3d3dd3d3d3ddddcdd3ddddd3ddddddcdcd3dc3ddcddddd3ddddc3d3dcd
3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d66d3d3d3d3dddd3d3d31d3dddd6d3d3d3d3d6dd3ddd3d3d3d63d3d3dd636d3d3d3d3d3d3d3d3dd3d3d3d3dd3d3dddcdd3d
d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3ddddddd6ddd6ddddd6dd6d33dd36d6dd6d3d65d6d6dd6d3dd666d6d3d666d6dd6d6dddd3ddcd3dcddcd3dcdcdc3d3dcdcd
d3dd3d3d3d3d3d3d3dcd3dc1c1cd3dddd66d6d63ddd6dd6ddd6dddd6d6dd66dd36d3d66dd6ddd3dd66dd61d6d666d6ddddd6dd3d3dcd3d3ddcd3d3dddcdd3ddd
dd3d3d3d3d3d3dc1d3d3d3d3d3d3d3dd3ddddddd3dddddddddddd3dddddddddd3dd3ddddddddd3ddddddd3dd3dddddddddd63dcdd3dddcd3d3ddcd3cd3dcdcdc
3ddd3d3dd3dcd3d3dd3d3d3d3d3dcd3dd3d3d3d3d3d3d3d3d3d3dd3d3d3d3d3dd3dd3d3d3d3ddd3d3d3d3dc5c53d3d3d3dddd3d3dc3d3ddcddc3ddd3dcdd3ddd
d3ddd3d3dd3d3ddc3dd3d3dc1cd3d3d3dcd3dcddcddcddcddcdcdcddcddcd3d3dc3dcdd3d3d3dcdcddcdd3dddcddcddcdd3dcddcdddcd3dd3dddc3dcdd3cdcdd
dd3ddddd3dddd3d3d3dd3d3dd3d3dd3d3d3d3d3d3d3d3d3d3d111d3d3d3d3dcd3dd3d3dcdcdd3d3d3d3dcdc3d3d3d3d3dcd3d3d3d3d3dcdcdc3ddddd3ddddddd
dcd3d3dddddddddddd3dd3d3d3dc3dcdd3dcd3dcdcddcddc1000015cddcdd3ddc3dcdcd3d3d3dcddcddd3ddddcddcdcd3ddcdcddcdcdd3d3dddcdc3dcdcddcdd
d3dddd3dddddddd3ddd3ddddcd3dd3d3dcd3dcd3d3d3d3d30000001d3d3d3dc3dd3d3ddcddcd3d3d3dcddc3d3d3d3d3dcd3ddd3dd3d3dcdcdcd3ddddddddddcd
ddc3dcddddde4dddd3ddd3d3ddd3dd3d3ddc1d3ddcddcdc100010555cd3dcddd3dcddc3d3d3ddcddcd3d3ddcdcdd66663ddcdcdcdcdcdddd3dcddcdcddcdcddd
dddd3dd3ddd4feddddd3dddd3dcd3dcdd3ddcddc3d3dd3d100000555d3d3d3dcd3d3dddcddcd3d3ddddcdd3d3d6666f6dcd3dddddddd3cdcdddddddddddddddd
dcdcddcdddddefedddddd3dcd3ddcd3dcdc3d3dddcdcdc5000011105dcddcd3ddcdd3c3d3d3ddcdd3d3d3cdd66666f63dddcdc3cdc3dddddcddcddcddcddcdcd
ddddcdddcddddefeddddddd3ddcd3ddd3dddcd3d3ddd3d1000000105d3d3ddcd3d3ddddcdddcd3dcdcdddd666f66f6dcdcdd5dd55ddcddcddddddddddddddddd
dcdddcdddddddde7edddddddd3ddddcddcd3ddcddc3ddc1001000101ddcd3d3dcdcd3c3d3cd3ddd3dd3d666f66f663ddddd5554444ddddddcdcdcdcdcdcdcdcd
ddddddcdcddddd4ef4ddddddddddcddd3ddcd3d3dddcd500000010005d3dcdcd3d3ddddcddddcdcd3d666f66f666ddcdd555515554ffd5dddddddddddddddddd
ddcdcddddcddddd4f74ddddddddddd3dcddddcddcdddc100000000100dcd3dddcddc3d3d3dcdd3dd666f66f666bdddddd5510505554fff4ddcdcdcdcdcdcddcd
ddddddcddddcdddd4f74ddddddddddcddcdcdddcdcd35100000000001ddddcd3dcdddcddcd3dcd666f66f666bdddcdcd4505512025554f64dddddddddddddddd
ddddddddcdddddddd4f74ddddddcddddddddcdcd11100000000010005d3cdddcd3dcdd3dddcdd66666f6f6bdddcdddd55150501010554dd4f5dcddcddcddcdcd
dcdddddddddcddddddeffedddddddcddcddddd1100000000000000000015dcdddcdd3dcdcdd666f6f6f6bdddcdddcdd45051150101554455465ddddddddddddd
dddcdddddddddddddddeff4dddddddddddcdc100000000000000001011115ddcdddcddd3d6666f6f666dddcdddcdddd41520101010144555454dcddddcddcddd
dcdddcdddcddcdddddddeffeddddddcddddd10000000000001000000000155dddcddcdd6666f6f666bddddddcdddcdd511505010101544555555ddddddddddcd
dddddddddddddddddddddeff4eddddddcddd000001010000000000101010015cddddd6666f6f666bddddcdddddcdddd415201010100545555544ddcdcdcdcddd
ddddddcdddcddddcdddddde7feddddddddd1000000000000000100111101111ddcdd66f6f6f66bdddcddddcdddddcdd40551010501544555554d5ddddddddd6d
ddcddddddddddcddddddddde7f4eddddcd10000010000000100101151000151dcd66f677666ddddcdddcddddcdddddd45052101015544545555445ddcdd6dddd
dddddddddddddddddddddddee7fedddd500000100000000001001001101101356f6f777666ddcddddddddcddddcddd64415550105244444555554dddddddcd6d
ddddcdddddddddddddddddddde7f46d5010000000100000000100100110313df6f77766a6adddddcdddcdddcddddddda455255255544445545554ddd6d6d6dd6
dddddddddcdddddddddddddddee7f4201000000010000000000101110113dff6777766dadfaffddddddddcddddcdddd64455555554454554555544ddddddd6dd
666dddddddddddddddddddddddee7f42010000101000000001010111335ff6777766badadadfaff4dcddddddcddd6dd6f445555444545555545555dd6d6d6d66
66666dddddddddddddddddddd6d447e420000000000000010011113356f6777766544fa6aff4f4ffadddddcddddddddd66444444555555554555544d6d6d6d6d
ddd66ddddddddddddddddddd65524e7e420101000000000010113156ff777766b54afffff4fffffff4dddddddddd6d6666f6444555552555554554ddd6d66d66
dddd666d6dd6d6ddddddd6dd10022447e400101000001010110356ff777766b5544fafafffaff4ffff4ddddddd6dd6ddd6666d445555555545555546d66d66d6
dddddd666666ddd6dd6d6d510100024ee455010000100101135df6777766b55555affffffffffff4fffddddd6dd6d6d6d66d6644455555555545554d6d666666
66ddddddd66f66dd6dd511001010102420515010100101133567777776b55555544affaffffffffff4ffdd6dd66d6d6d6d66d664455555555545554466666666
fff666d6ddd66f66d5100010000101050500100001031335f7777776b55555554fffafffafffffffffffddd66666d66666d66d64455555555555555d66666666
fffff66d66dd66d50000100010101010101051010113356f777776b455555544afffffffffffffffaeaffd6d6dd6d6d6d66d66d4445555555555554466666666
fffffffff66665000100010001010010010105111335a6777776d3455555444afffaffffffff44affffffdd6d66666666666d664445555555555545fd6666666
ffff6ffffffd50101010001010101010100100533ba6777776db5545555449afffffffffffff4444fafffad66666f6666666666454555555554455546666666f
fffffff66f650101001010010101010011501553a67777766b5555555544504fffffffffffaff444ffffffd666666666666666d4455555555554555d6666ffff
9e9ffaffff1010101001010110100555056155bf7777766b55515455544000004fffffffff9ff4444fffff466666666666666644445555555555554d66ffffff
fae9feaea401050101010111010554ff55d3bb7777766b55351154554400000000f7ffffffaff444affffffd66666666666666f455555555554544edf6ffffff
aeaf9faea5155011010110101104444f515b5f77776b553515154554400000000000f7fffffff4444ffffff4666666666666664455555555444554dfffafafaf
faeafeafe49f9e4501101111054424f5005ba7676b5355515155454500000000000005f7fffff94444ffffffd6666666666664f554555555555554d9ffffffff
9e9e9ffafffafaf410515111544444401055bbab53553151551544400000004000000004ffffff4444ffffaff6f6f6f66f666444555545454545454ffafafaff
fafae9ffafffeae9115115104424445050155b55355151551554540000022444004000000fffff9449ffff44fdffffff6ff64f5545555555555544ffffffffff
affffaeaeafaffa4151511154444244000055d551515151555544500002444444004444200fffff449fffff4ffffffffffffd455554555544455deffffffffff
fafffffafaff9ff4151555154444242520005551115555555544400002444444444244422047fffa29fffff44f4ffffffff4f4555555454544544ff77fffffff
ffafafffffaffafa444455504424544444500544d551555555440000224444444444444420047fff44fffff54ffffffffff4d4555555545454554fff7f7f7f7f
ff7ffffffffffffffffff50054242244444455ff4ff55555544000002444444444444444222047ff94fffff454fdfffffff45454555555545444dff7777f77ff
77f77ffffffffffffff450000022202244455544f5ffff5554100000224444444444444440000ffff9fffff544fa677ff4f455554545444544d4f777f7f77777
7f7f777ffffffffffff500000555522222050555446ffff4450500000004444444999940000000fffffffff4544ffffff4dd455454545544d44ff7777ffff777
77777777777ffffffff400015555500000001514554ff47ff405000000000449999992000044200ffffffff4554f4ffff4d4d4d54d444454544f7777f7fff777
77777777777fffffffff55df5555555000005015505ffff474500000420000444444000000024000fffffff4544ff44f4d4dd45454d454d444ff77ffffffff77
77f77777777777fffffffffff545545500100005105fff4ff440000040440004944444f1002440000ffffff45444ff4dd4d4dd4d4d4d4d44ffffffffffffffff
77777fffff77777ffffffffff4dd4d4d50000100005fff4fff40000024240044994444444444420002fffff45444fff4dd4d4d4d4464d4d44fffffffffffffff
fffd44444ffff777ffffffffffffff5d450000100054f444f4400000244444429444444444442200004ffff455444ff446df6f4f4d4f444ffffffffffffff777
44444444ffaffff7777fffffffffff4dd40000001054f445445000002444444494444444444440002204fff4544444ff4df4f4d4f44d4dffffffffffffff7fff
44444444fefffffffff7ffffffffffd4d450000000545545554000000944444444444449994442200000fff45444444f4df6dff4444f44ffffffffffffffffff
444444444aeafffffffffffffffffffff6500000005555555450000009999944444449999994422000005ff554444454a4fdf4df4d46f64ffffffff4ffffffff
4444444444ff9fffffffffff66ffffff7f550000005455055400000009999944994444999944420000000fa55444455544f4fdfd46ffffffffffffffffffffff
444444444444ffafafffffffafddd66ffd405000005555055400000004944494994444449944440000000fa1444555454dfd4fffffffffffffffffffffffffff
f444444444444fd6ff9ffffffffff4ddf4550200004555054500000000994499944999444444420000005f454455055444ffff6ffffffff66ff4ffffffffffff
fffff44444444d6676444aeffffafffff445050001554505540100000049444999999944499440000000ff044500004444fdffffffffff6d6f4ff444ffffffff
aeaeaf6fff4f4fdd67f4e4449efffffafa55050205455505045050000009992099994204999920000004f554500554555544ffffffffff6456f4ff4f4faeaeae
fffafd6faffaf455dfdf4aef444466ffff4520500555550555450000000099944e44249949940000005f454505555445544f4ffffffff6dd46fffffffaeaeffa
f44444d66faedd446d66764ff4f4d66faf455050555545050554500200000999988899944940220005ff545055444ffffff4fdfffff6dd54ddddae44454faf9e
ff455555544dd5555dd677f44f4f546fea45520504555505055044000000009999999949940240004ff2450544fffaea4f4f4ffffffd6ddd550151144faee4e4
49f4d4d4510555d5dd5d67f9d5dd4dd66f4455050555550450500440000000099999999920240004f455054ff44444444fae44ffa4fd45d55515014fa4e49494
f4eaedddf41005ddd655d664f505dddd67f45502545555555040004400000000999999900240054a45055445444f44445444f44ffffddd6dd45554ffffffffea
fae4a4ddf455554ddd655664f455dd64d6f45550554552055055050544000000049994004200444502505544f4f4ffff445544f44f6dfd44554ddfffffffffff
4eaef4df745544d44546d67fed44d4ddf6f455254555550452500050054000000002002220444500100444445454444ffff5054a44ff4ddddff4dffaffffaea4
f4f4aedfff4fff44d4ddf66fa6ff4d4d4ff4455545525505550505055004200000022202545200000444444444f4fada4fff4054f44fd44444fffaef49444444
faeae466faffaf45dd455f4fefff4dd4dff4452544545250450205205000500000002054450000554455444ffffffffef44ff4054a44dddddffffff444444444
ffffafdff4feff4555dd6dafafff45dd64fa45544555452054050550550000000000545500005545555555555444f4fafff4ff45444d646dd6fff44444444444
fffffffdfffafad45dd46d4fefffdfdf64f49554445454052450055004505000055450000054555555555555444444f4f4ff4ff4549d6d4dd6e4444444444444
44ffffffffffffd5dd4df7faeaffd4d67fef44544545445055402550054005444455005044554545555554444a4a444faffaf4fff4446d4d6d644444444444df
ff44f4fffffff6dd44ddf7fffffd64df7fffa454445454450440055000545000050050555545555555545444444444444444ff4f4f4464ff466e44444fffffff
fffffffffffffdddd4dd67fffffdf466fffff444444445452045052000555500001555454550555545555555555555545444444ffff44f9f4d664fffffffffff
fffffffffffffddddfad67fffffddff6fffffa44445444455554055000050545454545550055555555550505055055555555554444fff4ffe4dffffffff44444
ffffffffffffddddfffd6ffffff44ffdfffffff4fff4445425245550500540505555050505555550500555555545455555550555544ae44fdf4fffff94449444
faffffffffffd4dffffd76fafffff4fdfffffffffffff44445045250050054505050550555550000055555545455544dffff455055544f446ffafa44e4a44444
ffa4a4fffffff44da4add669fafff4ff6fffffffffffff444452455050000545555555550000015055554555454554fffffffff5005544fa44feffffafffaf9e
ffffff94affff446fff44dff4faffff4fffafffffffffff4444045505500055545505000550005505554545455544fffffffffff4500544f444444aefaeaeffa
fffffffffffffd46fffffd6ff44fffff6fffffffffffffff44450450050005050500005550014504555455445455fffffffffffff4500554f44f4ffaffffffff
4fffffffffffff4dfffff46fffffafffdfffffffffffffffff444550550005555015054500154555545454455454ffffffffffffff4500544f4fffffffffffff
455554444a4fff44ffffffdfffffffffffafaffffffffffffff45040050005555050545500545045554544454545fffdfffffffffff4000544f4ffffffffffff
ff44455555444f446fffffdffffffffffffffffffffffffffff450550500015505054550505555455545544545454ff44fffffff4fff5200544f4fafffffffff
fffffff444444444ffffffdffffffffffffffffffffffffffff40025055000505055450055455454545454545454ff44ffffff4446fff50205444fffffffffff
44afffffffff4444444faf46ffffffffffffffffffffffffff440004055000150554550505455454554555454544ff5fffffffff444ff4500044f4ffafffffff
4444afffffffff44444444fffaffffffffffffffffffffffff450205004000050545505054554545545554545454f444ffffffffff44ff4050554f4ff9f9ffff
a494449ffffffffffa4444449eafffffffffffffffffffffff405004505500005454050545554544545554545454d4454fffffffffff4ff502004444f944afaf
ff4944449ffffffffffffaffafeafffffffffffffffffffff44505555054000545450555455554545455545445444544544ffffffffff4ff505054f4ffffffff
ffff94444449ffffffffffffffffffaffff6ff66fffffffff46555554555515d5d5555d445454ddd4554d4545d4d44d4454546ffffffffff4020054f4fffffaf
fafffa44444444afffffffffffffffffaf66ff666d66d6646dd555ddddd5d50ddd55dddd6dd5464ddddd6dd64dddddd454444446fffffffff405205444fffffa
ffffffa4444444444aefffffffffffffff4fffddfdf64644445525555555d554555d5454d4d554545454d4d45444d454454545444fffffffff50500444faffff
49ffffff444444af4449ffffffffffffffffffafaf9faf44452050205005505550205554545545454545444545454454545444546ffffffffff50505444fafaf
9494affffa444f4ffa444ffffffffffffffffffffffdffd4545525555545504d555554d55545454455dd5d44445454545445454fffffffffffff50205444fafa
4a4949eaffff94fffff944affffaf66ff66dddd6df4dd6dddddd556d5dddd5555dddddddddddd4ddd4d4ddd6dd6ddddd65d454fff4444dfffffff50505444fae
44ae49444ffff449fffff949fffffd4ff4fdf464dd4dd4545d555045555555555dd54dd4d44d554545544d4545d44d45d4d44ff45445444dffffff40254444fa
944944944444ff944fffffff4affafffa4444444455555555050250000500250000554545554555554554545445555545544f4444444444454dffff4055444ff
fa4f944444444fff49fffafff49ffa4444464d455555552525d4525555505d525d5555dd45555454555454dd45445455454454545555455454454fff4055444a
ffa4fae44444449ff4fffffffff4444455555d5dd4d4dd4d55555dd5d5d5555ddd5504ddd4dddd56dd5d45d5dddd5d455445455555454545454454dff4554444
afffaeafaf444494ffaf9fffa44444555554d5ddd555d5dd55d5dd5255550ddd5dd550d455454d5d5d4d4545d4d54655445455555444444444544544ff454444
fafaffffffffffffafff44a444445505255555555555555d505050050005050500505055555555454554554545455554454550544ffffffffff544544ff45444
ffffafafafafafaffafffa44445505550505020555552050250205000055005555020000505555545545454545550444550554fffffffffffffd454544444544
faffff9ffffffffaffaf444445052502525255525555052505050205005000055550502002055555454554545455545550544fffffffffffffffd44454444454
ffafaff9fafafaffaff4444450505050505050555525505052020500005000005555050000025554554554545505445505444ffffffffffffffffd4545444444
__map__
f04883077158c622b2e4985d3c115b8f6dd9c491f1d8e82cc2823922ea201149b6c7e1f0e4928425d94112e0480903cf58f85a6d22261972b083e30a75480e2e4226382e97e7398707d6cca5735993050a2187242c18380c0b68ccd356e2b178927c79dad417116884321d9825c917c006d9e260db1e4a6224e209266c10021c
470ad955087b645f1651498658232138a8184449d2192c3e57124413b5891b7180b070053149455681210c214f1211d1a9c86b1251ec5300a7d584300ca908f99e43208924233f040082e690986d9807951e49124945f608244232d48484218992666bef1edb44164c80e2094ab26a638e95c8406620888c048700dd108a8508
91f821c7c1641afc223001026b08897448862c49893424084b12139ec7048b847f1609070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
fffffff0ffff0ffd693ab85ec9c0536ed1ffff379004000000000000000000000000000000182ec1ff08fcff09c399c4262e92c4ff7fcc2c840020490c39c0ffff2cb6e133285b2291f1d880304cc200c0621160d91621476441d9f64936d9b34d4c9611810fd9ec68b79243d92c5d23b2a4c26221b4892605613c5212820840
1c8cc8262a12c90e7d90cae1690e8e25ae5c1e33cd35794aebe15a2ec711cf41b2ee609c3b2ce93c8fe8d1e3b2e59af52779edccd8e6095fe2747cfacb117504478ef8220912632020614c1090792039e2301d0948c03004fc104fe24018d6f548240787e34462d9ae72052459ae26e864fb9e91ce469a041ee2a312499a2cb5
c404a9b1980ccbf2d0a50b9fb4616f9e63cb12c17110e4f8726c6b9775b5252bcbc4aa33fa2ce6d26bcb515b2dc61c59af2c8dd192ad1a57ea38da1de9b263493d09b9725ca9058ee558d24c629a1075744f86706ca51bef731dd26ce9734db22c4b43d6c4d6a12a2bc7242c924ec99143a487703cd62b3b75705c0543900a11
854b213563bbb243ba248904a9ebc8e380a568655f221349d64032c733969eb993a48e5a1362fe305121d6658f64be25734644920432c04156c21139d80e962459690cbba449a2070cc4e038aee405d304b5b13cb13c115b13218a4524c08263057a6448209ae3a0b1230de837fb544ffb25e4e99eab2e911033075796507f0c
e951e461fbbaca1e0e4f7708a69c485247634470f48035cbb16784e771f74093084912b06f7996f426ca6e7b4223511a491c8e25de43248f27dba2b6b0d89e4816491947901c5f3ef664d97e88746933fa03957099fdd0470506a104f32c4f7270641939428c2306c38810f345583bc99107b1a3fbe1fa41bee484a2bbc8f34e
209166d1833858e4704c72641241b223b698f0942447e0ae706d3b7344cc66b32549245ba0f20dae409c3212892c88192436640b8902421079165263e18fcb230106aec9c802402c08498234f86120c064b20a59e4097f04c138454225e42052b1448227120c7b3eb047123cc0a441c1019810f97f50814c4184c89105a2d787
4630622249d0c88888da321162224f904c24f943208e051233224912004a864cb8004a209f0428ec41601bc2c6046cb1b33992431e4168b8c329ff329e22126096885824a424910522109c22e202e406801700c107900b6039e2cb00430e80cc4200018610b0075832a14918241104610581a44142230b222082888a08099208
691299204b346c1090032284230882d2288910c39164a18124498240242484206189854b34e10e48c442120458c2c1ce334f8f641355281b91c008c244629185e14142420848e20a09138926700581b3c7c0413812222409098704611804842e08574825c1f6be592a03046c1c1a218ed8be4aafa44837cc9244445843b61c5f
1e844446cc150185470cdb736962639630d02489400e31fa45482422909088c81472b10d9e2e817f060139ae63756c4624202141221947459d9108935022898843402c39563f4cc49789244b0882a0d09090a31c1e9278802d008903830212223060885ac2c5080e314822fc15129e833f0e9703c918115412b2d0004b825530
81551c9e04649a835c4fe4f8e900003c851e3b1767220e01c121e20056c11521c1e05a7208219d854292e4782df15f87853df1fcf178f7c83313ce8301ec209109e2944720fb652a968cb8b63cd7113f1c00109eb09027aec42969105247f2894113912408c4383c99906c7e4c5049f6831f96237b855f134fc61647e21ae49b
9eb12393478e05210ec49123e926b299d9756d1310a4678e4b461014842f343becf83c09a1c9f5d3e73c9609924f127c9e0c915f6222418e6459103c39bf1d6fe497cc1fcfb6ccdb7045fe182ca96d32c3c303c911886512862b0707490e719883b0202c242408c723c9e74854c81bbe830309c1dac844acd544029120389604
317c893f9fc475e4c8445a380fe0d89ad4416422b241a261cfa48235a5b60fe00b090b3de4973ca7eb9f2084444c789691cc6662a1c1228718c1b1d59749e60cd7853c4fb679c8124f0034c221844336fb05962512168e4bea870c324be4d8e1898cd4ef2276349f249c01e9063c4fbfd374ef17dd0ee4080bd911c466a6a9ac
f1391ad1c45f427c7996e36096700541c3f2b92c127d43530909c7b9cf76482f9143d83148184dfc92c4b5ef875a0ef095127cc7f33da968bac37a63576a61bd250f8e003297270f843f17f1248b6ce40bc77a1c8e92107d0e719cefd0a58e9014358c4858381ed050fe7b58f3876df9212316735ded34c4733de78e99e3c83a
6ca9eabaaba99203a40e7d183f7ec7ae33ebe14982af21ce20d78e10cf35cf1326f3643b3768f23479b254130e97438290c1a0f00439ebda652e12a17f00e2ed4288e338ce4d1bec416689a771588eda738c4d369e2d62300ca14130d8ce885b9f6c344212906b4ba384c806cb95d32313eb3363428a493c2624848b11a454f0
ecd8220957f3c7ed890a0e221ed71f79649e87ac3d1ae1529daf7aa8cfa35cc51f1e3c1e9974449b70e4799a30e62049b306ebfe386c7e296b3ab324bc26190d5830824feaba152478c5de4286ef1f85e9d2a7d9928bd4e4ca2fef0e39b28ce00288857b1e3f2813c9d30e36c222c28c308ff339963c794edb4c04129743128e
ad47a65f40780f296f0e73588e194386461492cdf38bfd712457723dc96676d70fe2c84c7aeed87278572e047285c73c6c9698c2f50b024db34418799e70f3769a4993554e47121fcb619ac3fb88d4f6450529641665f1e497238720c7e37039e4e03a62f793cf19129ae7f82bf259421cc70fc775d4d94321489280483c699e
1df65e82b375e709714872f439e2f084388e1de92f49710d9c528fe6c8e3aa4f9687ac86c19563592a8f5d5acd972b83e33b8edb611ae27892fc61b8c85fe279ec00367e7a367e787eb9cf586a93d75fa7e37df4f9e310cdc78e4b823e6bdee3398f68be258faeddedd3e26d7621c7f823e3221315225110e72ac92f4ea9ec6a
3250fa649e1d57ff78c70e20ac93e404405c028e2725926b3ae11b490ed9c42572aa8823c0c451870c1136479a06ed713848c5c17134bc9bc41e85439a43c2c34190d48e03958c2bc8329aad16d2e5b026cd32bc4de191ed2b2a8c602e6f66d1cd419681c3f459623396f064d8c263421eb227c997e74870053287051811c1d7
a217d886099b49e2872c1257cce5da161f1d241239d2707df15e497600f90e4f405cb865bbd41276d78e6e5b34b4d134fc115341be3cc751f3440c05812f99a042f9a3fb2acac36249037d6421c97d4cf347923816d7b167b3e32c911272801e2e8b024a0877b2264b320ec711a2c9924c5699883d8e458e7cce2d0b489e8388
1ce2895d6407619cdc6b7c5716c7866c91c8a58c23925c996ad35d2225d3af0e3f0492456703e1cf1cb5eb4d217dd223ec21096c6db25a3dc73c4bb6679164530e96c4752489c1062e162e0b8783650b65ec509b0313634f147a78043b373920591e72c5f410c368047f404329ef72c81cb6696c92c491e71060ab65c79126b9
739ba944122fc912bf905db3484ce6cbb2e3ca2a533984088f80c623710e110c0921478eee20113b12fc2191b1ca0762e19de56ac8da718423f18344b910b08f5a846a92c392fc90895cf1e24a9ca2d13cd859c0932b070f2182e59070e4b0e7399e244df2f7c1f1ecaf404ec7c115c7f4e1803c3958e86f7a82e3d8e5cc935d
e192ef28afd770e423f10489f0870709633c73393c29780e8f1df88fd3e3a9e1d961711047129aece09ac8ca012a57ad8b38826685fe2cefc7b9799cef5699254b523e971c0b86f0f81eb18d5648240e990b48fdc4752c7d4aedf99e3508c696c510842708b40490c7e138d8169607bbbe237194701d3d20972cc0f15cbc9e67
d76a479dc79611da6c500f977db327cd96d8a3fa259520dd919ce2789e2bf1063d00c471d9405a9b39f25c0938e88e64894d0f88c491c5712f0f3df6c3434cd26b4bb244ec09105cc26938d683231871b2335bc572ee9665383066c2064f34482d0b87fcf38f8c27e385249362b2c4c1a6d2f46924d7d6e3c87d698e6b748938
d2a3f6902cc7e7084d2c230b213daa7224b99223870d67e6940dcd93432ba93eeb8e639ee7dafbc3e3da3dd9dc4713744f7284f1c4aee7932be9f7cb1ecb12d771d268e2c9f6a8360b3c798e91d62493a7d723715e8980f3902d11b9922b5dee272410ea398c83479ed0346796234f8fd423a447e6c9f6fc260ddbb135b24752
1325b123b2a3cd24c25c1c7234c7e7ba92cc82c36d26826d1eacd87184787008399636113f2a9659b664c5114924a7e690341cc2752799dbb21222cf98ef58b6436c996359c66149732c4c0e440fcb811c98dd896da389108e6992c3f52c739523c9e339720479ac6a2c71391693da6812a691702c1199e6203bd2a3b44fba23
e18ac41522c36ad4735c4f929d79b6327bc932fb089a76c43fbb7204e9ba3e52481319b6b29a2bdb96396cc8e17937d916600b448fa538b0c631c9b1540e913cac31c47320f3e478bea978a5936495821cc164098e2f6107c4128f922cc42110190eabc823828fa1adec87271c36a41e42cc17e8a872b023cb63303439422c41
ce2431e4e0204d4a8e659e901fa44c323b5c49ce6e90448ed24c269393210b82254bc49144a0c1410e0f2cab942472b044d61e779a60785a8d22b11c4762c866c91a2c659135129eb08524ae9171580f07e04cb4f3a5d2f047367912c3611a11f07c6507e1584448d7d04162893f8648a239cd4506ffd29cf0a88de6c9321094
e8193444226b1cec01843359a23e87a789877227923271c8e44ac821cfd6010b592a441539063c169e8534391ecdae3d39622e59ea2cb2471f1191f92562913c63e88207012300db00e438964c2a3f381225c47178645724e4107fecd9ace9d9e8127722abcf1311692397ecb184244290ecb1982bc9d28a4970ac1cd7243dd2
4d1998ae89241348bc2403087308160292a82400e4ec9699a424791c305c89eecb26b683759ac00fecf9b24443182e6c20f81ab01f0e5b58c410e811ee4d8e444826fc75914430f266228928610106fc21399308dc714db6d9c98b067f5444e41c91081609c170e472ca8ec8821fb244b6069243e5e62f333417a9982442c211
9e84852710572311537f280b9124caff42e469124422e481111152a8a850cce22b59042fb24cca248f307f1b44587764ce2c084f046810f99ad1480699074d9207547220fe8d488c4a30494462013820e1120545040f17f65dbb48f258b24c34dbfe4db8a064088320e176649acf84244922af4316429a2ccd2749f198f9718b
ad4246072c08578080f035740709195c699290e5afcc7200cefd1013519b67e49404575c12497c88e089e7d81ec792478f049a12ccb34624f9e960b379088eea1aed834030878f2c2192a63439908e5d39ea4997044d1d393c492cd77e201641b2b0f5593d6292a8621ae11190406ea280cc6556c3325bae341cd712e10fb6e3
986521d92a655448e54ac2324f0a0982109423df0e35896b161eddb6ec3896449248fcc4e271781c119db21cc9912c09b190130949249115e8ed9063228425ea3bf44855951d26d978009e5da44726477bf44aec708485c79160411e0c3b44c831b62c8703762891c691a79a48cc3c59f608114926aee6b1664727e4103e4c62
__sfx__
000400003a66136661326512e6512a64126631226211e611000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400003f3703f3603b3503b04537025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002c3712837124371203711c360183500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001865314640106400c63508625000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001426012650102510e6450c2350a6250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000304612d4612a4612745124451214511e4411b4411843115431124210f4110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006000026550265502d5502d55032560325603255532535000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400003c3703c360206501c64018635146250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0005000016661156611466112661106510e6510c6410a641086310662104611000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003c770377703c760377403c735377150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006000010650163601436012353103430e3350c31500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001e2621d2621c2621a26218262162521425212252102420e2420c2320a2320822206630056250461500000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000464005650066500564004650056500664005650046500564006650056500464005650066500564004650056500664005650046500564006650056500464005650066500563004620056100000000000
00060000086700a6700c2720f2721227214272142721327212262102620e2520c2550a64008630066200461500000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000024550285502b5603056034570375703c5703c5553c5353c51500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000037560375453c5603c5453e5703e5603e5453e525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000030350303503035032350343503435034350343503735037350373503735037350373503c3503c3503b3503b3503b35039350373503735034350343503235032350323503235032350323503235032350
0010000024530245352b5302b53528530285352b5302b53524530245352b5302b53528530285352b5302b5351f5301f5352653026535235302353526530265351f5301f535265302653523530235352653026535
001000002c645180401804018045130401304500000000002c645180401804018045130401304500000000002c6451f0401f0401f0451a0401a04500000000002c6451f0401f0401f0451a0401a0450000000000
00100000303503035030350323503435034350343503435037350373503735037350373503735039350393503b3503b3503b3503c3503e3503e3503b3503b3503c3503c3503c3503c3503c3503c3503c3503c350
0010000024530245352b5302b53528530285352b5302b53524530245352b5302b53528530285352b5302b5351f5301f53529530295352353023535295302953524530245352b5302b53528530285352b5302b535
001000002c645180401804018045130401304500000000002c645180401804018045130401304500000000002c6451f0401f0401f0451a0401a04500000000002c64518040180401804513040130450000000000
0010000035350353503535037350393503935039350393503c3503c3503c3503c3503c3503c350393503935037350373503735035350343503435032350323503435034350343503435034350343503435034350
00100000295302953530530305352d5302d5353053030535295302953530530305352d5302d53530530305351f5301f53529530295352353023535295302953524530245352b5302b53528530285352b5302b535
001000002c6451d0401d0401d045180401804500000000002c6451d0401d0401d045180401804500000000002c6451f0401f0401f0451a0401a04500000000002c64518040180401804513040130450000000000
001000003235032350323503435035350353503535035350373503735037350373503735037350323503235030350303503035032350343503435037350373503c3503c3503c3503c3503c3503c3500000000000
0010000026530265352d5302d53529530295352d5302d5351f5301f53526530265352353023535265302653524530245352b5302b53528530285352b5302b53524530245352b5302b53528530285352b5302b535
001000002c6451a0401a0401a045150401504500000000002c6451f0401f0401f0451a0401a04500000000002c645180401804018045130401304500000000002c64518040180401804513040130450000000000
00120000263502635026350263502b3502b3502b3502b3502e3502e3502e3502e3502d3502e3502e3502e350303502e3502e3502e3502d3502b3502b3502b3502a3502a3502a3502a3502b3502b3502b3502b350
001200001f0401f0401f0401f0401f0401f0401f0401f04526040260402604026040260402604026040260451f0401f0401f0401f0401f0401f0401f0401f0452604026040260402604026040260402604026045
001200000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a660086350000000000
001200002b3502b3502b3502b3502e3502e3502e3502e350323503235032350323503135032350323503235033350323503235032350303502e3502e3502e3502d3502d3502d3502d35026350263502635026350
001200001f0401f0401f0401f0401f0401f0401f0401f04526040260402604026040260402604026040260451a0401a0401a0401a0401a0401a0401a0401a0452104021040210402104021040210402104021045
001200000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a660086350000000000
001200002b3502b3502b3502b3502a3502a3502a3502a3502b3502b3502b3502b3502e3502d3502d3502d3502b3502a3502a3502a3502b3502d3502d3502d3502e3502e3502e3502e35032350323503235032350
001200001f0401f0401f0401f0401f0401f0401f0401f04526040260402604026040260402604026040260451f0401f0401f0401f0401f0401f0401f0401f0452604026040260402604026040260402604026045
001200000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a660086350000000000
001200003335033350333503335032350323503235032350303503035030350303502e350303503035030350323503035030350303502e3502d3502d3502d3502b3502b3502b3502b3502b3502b3502b3502b350
001200001b0401b0401b0401b0401b0401b0401b0401b04522040220402204022040220402204022040220451a0401a0401a0401a0401a0401a0401a0401a0451f0401f0401f0401f0401f0401f0401f0401f045
001200000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a6600863500000000000a660086350000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 10111244
00 13141544
00 16171844
02 191a1b44
01 1c1d1e44
00 1f202144
00 22232444
02 25262744
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
