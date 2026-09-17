# Desert Jedi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. *(Ebben a sessionben a végrehajtás a Workflow tool-lal történik, a lenti „Sub Agent" csoportok szerint.)*

**Goal:** Egy önálló, tesztelt PICO-8 cart (`carts/desert_strike/desert_strike.p8`): felülnézetes jedi-túlélő játék sivatagban, blokkolható és visszaverhető lézerlövésekkel, egyre több birodalmi katonával.

**Architecture:** Egyetlen `.p8` fájl (kód + gfx + sfx + music). A kód tab-okra bontva (main / world / player / troopers / bolts / fx-hud), globális `g` állapottáblával, OOP nélkül. A tesztek egy külön cart-ban (`test_ds.p8`) élnek, ami `#include desert_strike.p8`-tal behúzza a kódot, stubolja a `btn`/`btnp`-t, és headless (`pico8 -x`) fut.

**Tech Stack:** PICO-8 0.2.x (cart version 30), PICO-8 Lua; shrinko8 (token-számláló + lint, `uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8`); Python 3 + Pillow (sprite-preview, csak fejlesztési segédeszköz, `uv run --with pillow`).

**Spec:** `carts/desert_strike/docs/specs/2026-09-16-desert-jedi-design.md` — a terv a spec-ből érvel; a végrehajtó MINDKETTŐT olvassa.

## Tartalomjegyzék

- [Global Constraints](#global-constraints)
- [Fájlstruktúra](#fájlstruktúra)
- [Kanonikus kontrakt (ne vezesd le újra)](#kanonikus-kontrakt-ne-vezesd-le-újra)
- [.p8 fájlformátum jegyzet](#p8-fájlformátum-jegyzet)
- [Megvalósítási sorrend táblázat](#megvalósítási-sorrend-táblázat)
- [Task 1: Játékkód + teszt-harness (Agent A)](#task-1-játékkód--teszt-harness-agent-a)
- [Task 2: Sprite sheet (Agent B)](#task-2-sprite-sheet-agent-b)
- [Task 3: SFX + zene (Agent C)](#task-3-sfx--zene-agent-c)
- [Task 4: Összefűzés (Agent D)](#task-4-összefűzés-agent-d)
- [Task 5: Verifikáció (Agent E1–E5, párhuzamos)](#task-5-verifikáció-agent-e1e5-párhuzamos)
- [Task 6: Javítás (Agent F)](#task-6-javítás-agent-f)
- [Task 7: README (Agent G)](#task-7-readme-agent-g)
- [Dispatch promptok](#dispatch-promptok)
- [Verification gate-ek](#verification-gate-ek)

## Global Constraints

- PICO-8 limitek: **≤ 8192 token**, **≤ 15360 byte tömörített** (shrinko8 `--count` méri). Cél: ≤ 6500 token, hogy maradjon hangolási tartalék.
- **30 fps**: `_update` (nem `_update60`). Minden idő frame-ben: 1 mp = 30 frame.
- Bemenet **kizárólag** `btn(i)` / `btnp(i)` hívásokon át (0=⬅️ 1=➡️ 2=⬆️ 3=⬇️ 4=🅾️ 5=❎). `stat()` billentyűzet-olvasás tilos (a teszt-stub miatt).
- Nincs metatábla/OOP, nincs `#include` a játék-cartban (önálló cart), nincs map-szekció használat.
- Rekord: `cartdata("kepes_desert_jedi_1")`, `dget(0)`/`dset(0, v)`.
- A cart fejléce pontosan: `pico-8 cartridge // http://www.pico-8.com` + `version 30`.
- A `__gfx__` szekció 128 sor × 128 hex; `__sfx__` 64 sor × 168 karakter; `__music__` 64 sor `XX YYYYYYYY`.
- Szövegek angolul a játékban (`DESERT JEDI`, `GAME OVER`, `SCORE`, `BEST`), a doksik magyarul.
- Nincs Claude-attribúció sehol; a carts mappa nem git repo — commit lépés nincs.

## Fájlstruktúra

| Fájl | Felelősség | Ki írja |
|---|---|---|
| `carts/desert_strike/desert_strike.p8` | a játék, önálló cart | Agent A (kód), B (gfx), C (sfx/music), D (összefűzés), F (javítás) |
| `carts/desert_strike/test_ds.p8` | headless tesztek, `#include desert_strike.p8` | Agent A, F |
| `carts/desert_strike/run_tests.sh` | tesztek + token-limit + lint futtató | Agent A |
| `carts/desert_strike/README.md` | leírás, irányítás, futtatás, teszt | Agent G |
| `carts/desert_strike/src/gfx.txt` | ideiglenes: 128 sor gfx hex (Task 4 után törlendő) | Agent B |
| `carts/desert_strike/src/sfx.txt`, `src/music.txt` | ideiglenes: 64+64 sor (Task 4 után törlendő) | Agent C |
| scratchpad: `gfx_preview.py`, `shots.p8`, `bot.p8`, `check_audio.py` | eldobható segédeszközök | B, E2, E5, C |

## Kanonikus kontrakt (ne vezesd le újra)

### Sprite-indexek (`__gfx__`, 16 sprite/sor, `spr(n, x-4, y-4, 1, 1, flip)`)

| Index | Tartalom | Megjegyzés |
|---|---|---|
| 0 | üres (átlátszó) | PICO-8 konvenció |
| 1, 2 | jedi **lefelé** néz: idle, lépés | barna köpeny 4, arc 15, haj 0/4, öv 9 |
| 3, 4 | jedi **felfelé** néz: idle, lépés | hátulról: csuklya |
| 5, 6 | jedi **jobbra** néz: idle, lépés | balra: `flip_x=true` |
| 7 | jedi **fekve** (halál) | vízszintesen fekvő alak |
| 16, 17 | katona **jobbra** néz: lépés 1, 2 | fehér 7, rések 0, árnyék 6, lencse 1; blaster 5/0; balra flip |
| 18 | katona **célzó** póz (blaster előre nyújtva) | torkolattűz pixelt a kód rajzolja, nem a sprite |
| 19 | katona **fekve** (halál) | |
| 32 | kis szikla 8×8 | barna 4, él 9, árnyék 2 |
| 33, 34, 49, 50 | nagy szikla 16×16 (`spr(33, x, y, 2, 2)`) | bal-felső 33 |
| 35 | kavicsok (dekor) | 9/4, ritkás |
| 36 | repedés (dekor) | 9 |
| 37 | csont-borda (dekor) | 7/6 |
| 38 | száraz bokor (dekor) | 4/9 |
| 39 | szív ikon 8×8 (HUD; tele) | 8/14 — vagy `print("♥")`, a kód dönt |
| többi | üres | |

Rajzolási pozíció: az entitás `x,y` a sprite **közepe**: `spr(n, e.x-4, e.y-4, 1, 1, flip)`. Nagy szikla: a hitbox `x1,y1,x2,y2`; sprite bal-felső = `(x1-1, y2-15)` úgy, hogy a 16×16 sprite alsó 11 px-e a hitbox (spec 5.).

### SFX-slotok (`sfx(n)`)

| Slot | Esemény |
|---|---|
| 0 | suhintás |
| 1 | blokk / visszaverés |
| 2 | blaster lövés |
| 3 | katona összeesik |
| 4 | jedi sérül |
| 5 | jedi halál |
| 6 | menü / start |
| 7 | visszavert lövés talál |
| 8–11 | zene-sfx (music pattern 0–1 használja) |

Zene: `music(0)` cím + játék; `music(-1)` game over.

### Globális állapot `g` és függvények (Agent A implementálja, E-k és F erre hivatkoznak)

```lua
g = {
  state="title",      -- "title" | "play" | "over"
  p=nil,              -- new_player()
  troopers={}, bolts={}, rocks={}, decor={}, parts={},
  frames=0,           -- play alatt nő
  score=0, best=0, newbest=false,
  spawn_cd=0, shake=0,
}
-- p: {x,y,fx,fy,hp,inv,swing,cd,anim,dying,dead}
-- trooper: {x,y,spd,stop,st="walk"|"aim"|"dead",t,shot_cd,flip,anim,stuck,side_t,side_dir}
-- bolt: {x,y,dx,dy,owner="e"|"p",src}
-- rock: {x1,y1,x2,y2,big=true|false}
-- decor: {x,y,s}   (s = sprite index)
-- part: {x,y,dx,dy,life,col}
```

Függvények (globálisak, pontosan ezekkel a nevekkel):

| Tab | Függvény | Szerződés |
|---|---|---|
| main | `_init()` | `cartdata`, `g.best=dget(0)`, `new_game()`, `g.state="title"`, `music(0)` |
| main | `new_game()` | `g` újraépítése (`best` marad), `gen_rocks()`, `gen_decor()`, `g.p=new_player()`, `spawn_cd=0` |
| main | `_update()`, `_draw()` | state-diszpécser |
| main | `upd_play()` | `upd_player()` → `upd_troopers()` → `upd_bolts()` → `upd_parts()` → `g.frames+=1`; shake csökkentés |
| main | `elapsed()` | `g.frames/30` |
| main | `max_alive()` | `min(8, 1+flr(elapsed()/20))` |
| main | `dist(ax,ay,bx,by)`, `norm(dx,dy)`, `dot(ax,ay,bx,by)`, `clamp(v,lo,hi)` | segédek; `norm(0,0)` → `0,0` |
| world | `gen_rocks()` | 5–8 szikla a spec 5. szabályaival → `g.rocks` |
| world | `gen_decor()` | 12–18 dekor → `g.decor` |
| world | `solid(x,y)` | igaz, ha a (x±3, y±3) doboz metszi bármely szikla hitboxát |
| world | `in_rock(x,y)` | pont-a-hitboxban (lövedékhez) |
| world | `move_solid(e,dx,dy)` | tengelyenkénti csúszó mozgás; visszatér `bx,by` (bool: blokkolt x, blokkolt y) |
| world | `draw_world()` | háttér, dekor, sziklák |
| player | `new_player()` | `{x=64,y=68,fx=0,fy=1,hp=3,inv=0,swing=0,cd=0,anim=0,dying=0,dead=false}` |
| player | `upd_player()` | input, fordulás, mozgás+clamp, suhintás, blokk, dying |
| player | `is_blocking()` | `btn(5) and g.p.swing==0 and not g.p.dead` |
| player | `hurt_player()` | ha `inv==0` és nem dead: `hp-=1, inv=45, shake=6, sfx(4)`; `hp==0` → `dying=40, dead=true, sfx(5), music(-1)` |
| player | `draw_player()`, `draw_saber()` | |
| troopers | `spawn_trooper()` | spec 4.2 spawn |
| troopers | `upd_troopers()` | spawn-logika (`max_alive`, `spawn_cd`) + állapotgép + szétlökés |
| troopers | `kill_trooper(tr,pts)` | `st="dead", t=90, score+=pts, sfx(3), por-részecskék` |
| troopers | `alive_count()` | nem-dead katonák száma |
| troopers | `draw_trooper(tr)` | |
| bolts | `fire(tr)` | ellenséges lövedék a jedi felé (±0,04 fordulat szórás, `bolt_spread`), `sfx(2)` |
| bolts | `deflect(b)` | owner→`"p"`, irány `src` felé vagy negált, sebesség 2,5, `sfx(1)`, szikra |
| bolts | `upd_bolts()` | mozgás, kilépés, szikla, jedi-szabályok (spec 6.), katona-találat |
| bolts | `draw_bolts()` | |
| fx | `spawn_parts(x,y,n,c1,c2)`, `upd_parts()`, `draw_parts()` | |
| hud | `draw_hud()`, `draw_title()`, `draw_over()` | |

A suhintás/blokk kúp-tesztje: `dot(g.p.fx, g.p.fy, nx, ny) >= COS`, ahol `nx,ny = norm(target.x-g.p.x, target.y-g.p.y)`.

## .p8 fájlformátum jegyzet

```
pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
<kód; tabok között egy sor: -->8 >
__gfx__
<128 sor, soronként 128 hex karakter; 1 karakter = 1 pixel színe 0–f; a sor y, az oszlop x a 128×128 sprite-lapon>
__gff__
<2 sor × 256 hex — opcionális, elhagyható>
__sfx__
<64 sor × 168 karakter: 8 hex fejléc + 32 hang × 5 hex>
__music__
<64 sor: "FF AABBCCDD">
```

- **gfx**: a sprite `n` bal-felső pixele: sor `flr(n/16)*8`, oszlop `(n%16)*8`. Szín 0 = átlátszó `spr()`-nél.
- **sfx fejléc** (8 hex): `MM SS LS LE` = editor-mód (00), sebesség (01–ff, ~hang/tick; zenéhez 10–14, effektekhez 04–08), loop kezdet, loop vég (00 00 = nincs loop). **Hang** (5 hex): `PP W V E` = hangmagasság 00–3f (24 = C3 kb.), hullámforma 0 triangle / 1 tilted saw / 2 saw / 3 square / 4 pulse / 5 organ / 6 noise / 7 phaser, hangerő 0–7, effekt 0 none / 1 slide / 2 vibrato / 3 drop / 4 fade in / 5 fade out / 6 arp fast / 7 arp slow. Üres hang: `00000`. Példa blaster-lövés sor eleje: fejléc `00040000` (speed 4, nincs loop), majd hangok `2c371` `28371` `24371` `20371` `1c360` (lefelé lépkedő square, hangerő 7→6, effekt 1 = slide), a maradék 27 hang `00000`. **Ne használd a `t` nevet globális függvényként** (a PICO-8 beépített `t()` = `time()`).
- **music sor**: `FF` flagek (01 = loop kezdet, 02 = loop vég, 04 = stop), majd 4 sfx-index hexben; nem használt csatorna = `41`–`44` (a felső bit = kikapcsolva; a demókban `41 42 43 44` mintát látni), pl. `01 08094344` = 8-as és 9-es sfx a 0–1 csatornán, 2–3 kikapcsolva. Loop: első minta `01`, utolsó `02`.
- Példa a gyári `jelpi.p8`-ból: sfx sor `01100000240452400528000280452b0450c005280450000529042...` és music sor `01 01434144`.

## Megvalósítási sorrend táblázat

| Lépés | Érintett projekt | Feladat | Sub Agent |
|---|---|---|---|
| 1 | `carts/jedi` | Task 1: játékkód (`desert_strike.p8` `__lua__`), `test_ds.p8`, `run_tests.sh`; tesztek zölden | **A** (Build-csoport, párhuzamos) |
| 2 | `carts/jedi` | Task 2: sprite sheet `src/gfx.txt` + vizuális önellenőrzés preview PNG-vel | **B** (Build-csoport, párhuzamos) |
| 3 | `carts/jedi` | Task 3: `src/sfx.txt` + `src/music.txt` + formátum-ellenőrzés + headless lejátszás-teszt | **C** (Build-csoport, párhuzamos) |
| 4 | `carts/jedi` | Task 4: szekciók összefűzése `desert_strike.p8`-ba, `src/` törlése, `run_tests.sh` zöld | **D** (1–3 után) |
| 5a | `carts/jedi` | Task 5: `run_tests.sh` + shrinko8 riport | **E1** (Verify-csoport, párhuzamos) |
| 5b | `carts/jedi` | Task 5: headless képernyőképek (cím / játék / game over) + vizuális review a spec 8., 10., 15.3 ellen | **E2** |
| 5c | `carts/jedi` | Task 5: adverzáriális spec-megfelelés review (spec 3–7, 16) a kód olvasásával | **E3** |
| 5d | `carts/jedi` | Task 5: teszt-minőség + kód-review (lefedettség, token, lint, edge case-ek) | **E4** |
| 5e | `carts/jedi` | Task 5: bot-playtest headless (balansz: idle / blokkoló / rohamozó bot túlélési ideje) | **E5** |
| 6 | `carts/jedi` | Task 6: az E1–E5 🔴/🟡 találatainak javítása egy fájlban, tesztek zölden | **F** (5 után; majd vissza 5-re, max 3 kör) |
| 7 | `carts/jedi` | Task 7: `README.md` (irányítás, futtatás, `run_tests.sh` dokumentálva, TOC) | **G** (6 után) |
| 8 | `carts/jedi` | Záró: `run_tests.sh` zöld, `src/` és ideiglenes fájlok nincsenek, csak a 4 fájl + docs | **E1** újra |

---

## Task 1: Játékkód + teszt-harness (Agent A)

**Files:**
- Create: `carts/desert_strike/desert_strike.p8` (csak `__lua__` szekció; gfx/sfx/music később)
- Create: `carts/desert_strike/test_ds.p8`
- Create: `carts/desert_strike/run_tests.sh`

**Interfaces:**
- Consumes: a kanonikus kontrakt (sprite-indexek, sfx-slotok) — ezeket a kód **hívja**, a tartalom később jön.
- Produces: a kontrakt összes függvénye és a `g` tábla pontosan a fenti nevekkel.

- [ ] **Step 1: Teszt-harness váza** — `test_ds.p8`:

```lua
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
function _update() end
function _draw() end
function _init()
  cartdata("kepes_desert_jedi_test")
  -- ---- tests ----
  tcase("move right + clamp")
  fresh() local x0=g.p.x
  step(5,{[1]=true}) check(g.p.x>x0,"x should grow")
  step(200,{[1]=true}) check(g.p.x<=124,"x clamp 124: "..g.p.x)
  check(g.p.fx==1 and g.p.fy==0,"facing right")
  -- ... további tesztek a spec 12. listája szerint ...
  printh("TESTS DONE ok="..ok.." fail="..fail)
  extcmd("shutdown")
end
```

Sziklák a tesztekhez: `g.rocks={{x1=70,y1=60,x2=84,y2=71,big=true}}` kézzel beállítva `fresh()` után, hogy determinisztikus legyen. Katona kézzel: `add(g.troopers,{x=100,y=68,spd=0.5,stop=30,st="walk",t=0,shot_cd=0,flip=true,anim=0,stuck=0,side_t=0,side_dir=1})`. Lövedék kézzel: `add(g.bolts,{x=80,y=68,dx=-2,dy=0,owner="e"})`.

- [ ] **Step 2: `run_tests.sh`**:

```bash
#!/usr/bin/env bash
# Desert Jedi – headless tesztek + PICO-8 limit-ellenőrzés. Kilépőkód 0 = zöld.
set -u
cd "$(dirname "$0")"
P8="/Applications/PICO-8.app/Contents/MacOS/pico8"
SHRINKO=(uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8)
rc=0
echo "== headless tests =="
out=$(perl -e 'alarm 90; exec @ARGV' -- "$P8" -x test_ds.p8 2>&1); code=$?
echo "$out"
if [ $code -ne 0 ]; then echo "!! pico8 exit code $code (timeout = valószínűleg syntax error)"; rc=1; fi
echo "$out" | grep -qiE "syntax error|runtime error" && { echo "!! lua error"; rc=1; }
echo "$out" | grep -q "^FAIL:" && { echo "!! failing tests"; rc=1; }
echo "$out" | grep -q "TESTS DONE ok=[0-9]* fail=0$" || { echo "!! no clean TESTS DONE line"; rc=1; }
echo "== shrinko8 count =="
cnt=$("${SHRINKO[@]}" desert_strike.p8 --count 2>&1); echo "$cnt"
tok=$(echo "$cnt" | sed -n 's/^tokens: \([0-9]*\).*/\1/p')
[ -n "$tok" ] && [ "$tok" -gt 8192 ] && { echo "!! token limit exceeded"; rc=1; }
echo "== shrinko8 lint (nem blokkoló) =="
"${SHRINKO[@]}" desert_strike.p8 --lint 2>&1 | head -40
[ $rc -eq 0 ] && echo "ALL GREEN" || echo "RED"
exit $rc
```

- [ ] **Step 3: Futtasd** — `bash run_tests.sh` → várt: `FAIL`/`runtime error` (még nincs kód).
- [ ] **Step 4: `desert_strike.p8` main tab** — konstansok (spec 14.), `g`, segédek, `_init/_update/_draw`, `new_game`, `upd_play`, `elapsed`, `max_alive`.
- [ ] **Step 5: world tab** — `gen_rocks` (elutasításos mintavétel, spec 5.), `gen_decor`, `solid`, `in_rock`, `move_solid`, `draw_world`. Teszt: sziklák nem a 44..84×48..88 spawn-zónában, páronként ≥14 px hézag, `y1>=12`, szél 10 px szabad.
- [ ] **Step 6: player tab** — mozgás/fordulás/clamp, `move_solid`-dal; suhintás (`swing=8`, `cd=4`), `is_blocking`, `hurt_player`, dying → `g.state="over"` a 40 frame végén (+ `dset` ha rekord). Rajz: sprite-választás nézés+anim szerint, villogás `inv%2==1`-nél kihagy, `draw_saber`.
- [ ] **Step 7: troopers tab** — spawn (szél, `spd`, `stop` képletek), walk (tengelyenkénti mozgás, `stuck`/`side_t` kerülés, szétlökés), aim (telegráf `t`, `fire`, `stop-=6`, `shot_cd`), dead (`t=90` → `del`). `upd_troopers` elején spawn-logika: `if alive_count()<max_alive() and g.spawn_cd<=0 then spawn_trooper() g.spawn_cd=max(30,90-elapsed()*0.4) end g.spawn_cd-=1`. **Az első frame-en** (frames==0) azonnal spawnol (spawn_cd 0-ról indul).
- [ ] **Step 8: bolts tab** — `fire`, `deflect`, `upd_bolts` a spec 6. sorrendjével (suhintás-kúp → blokk-kúp → találat → inv-elnyelés), visszavert lövedék vs katona, szikla, képernyő-kilépés (−8..136).
- [ ] **Step 9: fx/hud tab** — részecskék (max 60, legrégebbi törlődik), `draw_hud` (szívek ♥ 8/5, idő mm:ss, score jobbra igazítva), `draw_title`, `draw_over`; képernyőrázás `camera()`.
- [ ] **Step 10: A spec 12. minden tesztesetét írd meg** (mind a 15 tételt; egy `tcase("...")` blokk / eset), futtasd `bash run_tests.sh` → `ALL GREEN`, token-szám a riportban.
- [ ] **Step 11: shrinko8 lint** figyelmeztetéseit nézd át; a valódi hibákat (nem használt/elgépelt globális) javítsd.

## Task 2: Sprite sheet (Agent B)

**Files:**
- Create: `carts/desert_strike/src/gfx.txt` — pontosan 128 sor × 128 hex kisbetűs karakter.
- Scratchpad: `gfx_preview.py`.

**Interfaces:** Produces a kanonikus sprite-indexeket (1–7, 16–19, 32–39). Consumes: PICO-8 paletta (0 fekete, 1 sötétkék, 2 sötétlila, 3 sötétzöld, 4 barna, 5 sötétszürke, 6 világosszürke, 7 fehér, 8 piros, 9 narancs, a sárga, b zöld, c kék, d indigó, e rózsaszín, f barack/homok).

- [ ] **Step 1: Preview-script** (scratchpad, `uv run --with pillow gfx_preview.py src/gfx.txt out.png`): beolvassa a 128 sort, a PICO-8 palettával 128×128 képet rajzol, **8×-os nagyítással**, 8 px-es rácsvonalakkal (szín 3 vagy 13 — a homok-háttér (f) mögé rajzolva, hogy az átlátszó 0 ne feketén látszódjon: a 0-t a homokszínnel jelenítsd meg), és kiírja a PNG-t. Csak a felső 64 sort (első 4 sprite-sort) nagyítsd külön képre, hogy jól látható legyen.
- [ ] **Step 2: Rajzold meg a sprite-okat** a kontrakt szerint. Iránymutatás: a 8×8-as figurák 7–8 px magasak, 5–6 px szélesek, középre igazítva; a jedi köpenye barna (4), belül világosabb (f arc, 9 öv); a katona fehér (7) sisak + páncél fekete (0) résekkel, a sisak-lencse 1; a blaster 5/0, a nézés irányában kinyúlva. Sziklák: 4 alap, 9 fény bal-felül, 2 árnyék jobb-alul, a kis szikla 7×6 px-es tömb; a nagy szikla 16×16-ból a felső ~5 sor kopár tető, az alsó 11 sor a „test" (a hitbox a spec szerint 14×11, alul).
- [ ] **Step 3: Nézd meg a preview PNG-t** (Read tool) és iterálj, amíg minden figura felismerhető és a spec 15.3 kritériumait hozza. Minimum 2 iteráció.
- [ ] **Step 4: Ellenőrzés**: `awk '{ if (length($0)!=128) print NR": "length($0) }' src/gfx.txt` üres; `wc -l` = 128; csak `[0-9a-f]` karakterek.

## Task 3: SFX + zene (Agent C)

**Files:**
- Create: `carts/desert_strike/src/sfx.txt` — 64 sor × 168 karakter.
- Create: `carts/desert_strike/src/music.txt` — 64 sor `FF AABBCCDD`.
- Scratchpad: `check_audio.py`, `play.p8`.

**Interfaces:** Produces a kanonikus sfx-slotokat 0–7 és a zene sfx 8–11-et, music pattern 0–1.

- [ ] **Step 1: Format-ellenőrző** (scratchpad Python): minden sfx-sor 168 hosszú, csak hex; minden hang: pitch ≤ 0x3f, waveform ≤ 0xf, vol ≤ 7, fx ≤ 7; music-sorok regex `^[0-9a-f]{2} [0-9a-f]{8}$`, 64 sor.
- [ ] **Step 2: Effektek** a spec 9. táblája szerint (slot 0–7), rövidek (≤ 12 hang, a maradék `00000`), speed 04–08.
- [ ] **Step 3: Zene**: 2 minta, ~100 BPM (speed ≈ 12–14 a 32 hangos mintához), **saját dallam** (D-moll vagy frígiai hangulat illik a sivataghoz; ne idézzen létező filmzenét), dallam (slot 8, 10 — pulse/organ, vol 4–5) + basszus (slot 9, 11 — triangle, vol 5), a music sorok: `01 08094344`, `02 0a0b4344`, a többi 62 sor `00 41424344`.
- [ ] **Step 4: Headless lejátszás-teszt**: `play.p8` egy minimál cart, amiben a `__sfx__`/`__music__` szekció a te fájljaid, `_init`-ben `music(0)` és `sfx(0..7)` egymás után, 60 frame után `printh("AUDIO OK")` + `extcmd("shutdown")`. Futtasd `pico8 -x play.p8` időkorláttal (`perl -e 'alarm 30; exec @ARGV' -- …`); ha `AUDIO OK` nincs, a formátum rossz.
- [ ] **Step 5:** Kottázd le a dallamot röviden (hangnevek) a visszatérő összefoglalóban, hogy a reviewer ellenőrizhesse a zeneiséget.

## Task 4: Összefűzés (Agent D)

**Files:** Modify `carts/desert_strike/desert_strike.p8`; delete `carts/desert_strike/src/`.

- [ ] **Step 1:** Python egysorossal: a `desert_strike.p8` `__lua__` szekcióját (a `__gfx__`/`__sfx__`/`__music__` fejlécig vagy a fájl végéig) megtartva írd újra a fájlt: `__lua__` + kód + `__gfx__` + `src/gfx.txt` + `__sfx__` + `src/sfx.txt` + `__music__` + `src/music.txt` (+ záró újsor).
- [ ] **Step 2:** `bash run_tests.sh` → `ALL GREEN`; `pico8 -x desert_strike.p8` időkorláttal (`alarm 10`) → csak `RUNNING:` sor, nincs `syntax error`/`runtime error` (a timeout miatti kilépés normális, mert a játék nem áll le magától).
- [ ] **Step 3:** `rm -r src/`.

## Task 5: Verifikáció (Agent E1–E5, párhuzamos)

Mind az öt agent **csak olvas/futtat** a `desert_strike/` mappában (E2/E5 saját segéd-cartja a scratchpadben: a `#include` **csak a cart mellé, relatív útvonalon** működik — abszolút út ellenőrzötten NEM megy —, ezért másold a `desert_strike.p8`-at a scratchpad-mappádba a segéd-cart mellé, és onnan `#include desert_strike.p8`). Kimenet: strukturált findings lista `{severity: high|medium|low, area, description, evidence, suggested_fix}` + rövid összefoglaló. **high** = spec-sértés, futásidejű hiba, tesztek pirosak, limit-túllépés, felismerhetetlen sprite; **medium** = hangolási/érzet-probléma, hiányzó teszteset, olvashatatlan HUD; **low** = kozmetika.

- **E1 (tesztek):** `bash run_tests.sh`; a kimenet alapján findings (piros teszt = high; token > 7000 = medium figyelmeztetés).
- **E2 (képernyőképek):** scratchpad `shots.p8`: `#include` a játék **és a `desert_strike.p8` `__gfx__`/`__sfx__`/`__music__` szekciói a segéd-cart végére másolva** (a `#include` csak kódot hoz; e nélkül üres a sprite-lap), stub `btn/btnp` mint a harnessben, `_init`: `srand(3) new_game()`; frame-vezérelt szkript a saját `_update`-jében: 1) `g.state="title"` → 3 frame → `extcmd("screen")`; 2) `g.state="play"`, majd 600 frame lépés úgy, hogy 2–3 katona legyen (`g.frames=1200`-ra állítva a `max_alive` miatt, spawn kikényszerítve `spawn_trooper()` ×3-mal), közben ❎ nyomva, a jedi jobbra néz → screen; 3) suhintás közben (🅾️ lenyomás után 3 frame) → screen; 4) `g.p.hp=1` + lövedék a jedibe → dying → 60 frame → game over → screen. Futtatás: `pico8 -desktop <scratch/shots> -x shots.p8`. A PNG-ket **nézd meg** (Read), és a spec 8., 10., 15.3 ellen értékelj: felismerhető jedi (barna+kék kard), katonák (fehér), sziklák, homok, HUD szívek/pontszám olvasható, cím szöveg középen, game over doboz.
- **E3 (spec-megfelelés, adverzáriális):** olvasd a spec 3–7. és 16. szakaszát, majd a `desert_strike.p8` kódot, és **keress eltérést** minden számszerű szabálynál (kúpok, távolságok, időzítők, `max_alive`, spawn, `stop` képlet, dead 90 frame, pontszám 10/20, blokk pozíció-alapú kúp, inv alatt blokk működik, katonák nem sebeznek érintéssel, lövedék sziklán megsemmisül). Minden eltérés = high, hivatkozott sorral.
- **E4 (teszt-minőség + kód):** a spec 12. 15 kötelező tesztesetének mindegyike létezik-e és valóban azt teszteli-e (nem csak „nem dob hibát"); shrinko8 lint; token-szám; halott kód; véletlen (`rnd`) tesztben determinizmus; harness `btnp` helyes; `_draw` is fut a lépésekben.
- **E5 (bot-playtest):** scratchpad `bot.p8`: 3 stratégia × 2 seed, mindegyik max 5400 frame (3 perc): **idle** (semmit nem nyom), **blocker** (mindig ❎, és a legközelebbi élő katona felé fordul a 4 főirány közül a nagyobb |dx|/|dy| komponens alapján, nem mozog), **hunter** (a legközelebbi katona felé mozog, 12 px-en belül 🅾️-t nyom, egyébként ❎). Mérd: túlélt frame, score, ölések. Elvárás (balansz, a hangolt konstansokkal mérve): idle **≥ 10 mp** (tipikusan 13–40 mp, seed-függő); blocker az 1–2 seeden az első 60 mp-et túléli, de 3 percen belül meghal; hunter score > blocker score az 1–2 seeden. Ha a blocker 3 percig sem hal meg → medium (túl könnyű); ha idle < 10 mp → medium (túl nehéz elején); runtime error → high.

## Task 6: Javítás (Agent F)

**Files:** Modify `desert_strike.p8`, `test_ds.p8`.

- [ ] **Step 1:** Olvasd a findings-listát (high + medium), a spec-et és a kódot.
- [ ] **Step 2:** Minden high és medium tételt javíts; ahol a találat tesztelhető, **előbb írj rá tesztet** a `test_ds.p8`-ba (piros → zöld).
- [ ] **Step 3:** `bash run_tests.sh` → `ALL GREEN`, token < 8192.
- [ ] **Step 4:** Rövid lista: mit javítottál, mit hagytál (low) és miért.

## Task 7: README (Agent G)

**Files:** Create `carts/desert_strike/README.md` (magyar).

- [ ] Tartalom: mi ez (2 mondat), **irányítás** táblázat, **futtatás** PICO-8-ban (`load desert_strike/desert_strike.p8` → `run`, vagy splore), **játékmenet** röviden (blokk-kúp, visszaverés, pontok 10/20, nehézség 20 mp-enként +1 katona), **tesztelés**: `bash run_tests.sh` — mit csinál (headless tesztek, shrinko8 token-limit, lint), előfeltételek (PICO-8 az `/Applications`-ben, `uv`), a `test_ds.p8` szerkezete (harness + `tcase()/check()/step()`), **fájlok** lista, hivatkozás a spec-re és a tervre. Ha > 3 H2 → tartalomjegyzék a bevezető után.

## Dispatch promptok

Minden prompt végén: „Return a summary of at most 120 words: files touched, key decisions, open issues. Do not narrate step by step." Minden agent megkapja a spec és a terv **abszolút útvonalát** és a saját Task-számát; **csak** a saját taskját hajtja végre.

Közös fejléc (minden promptban):

```
Project dir: /Users/kepes/Library/Application Support/pico-8/carts/jedi
Spec: <dir>/docs/specs/2026-09-16-desert-jedi-design.md
Plan: <dir>/docs/plans/2026-09-16-desert-jedi-plan.md
PICO-8 binary: /Applications/PICO-8.app/Contents/MacOS/pico8  (headless: `pico8 -x cart.p8`; screenshots: `pico8 -desktop <dir> -x cart.p8` + extcmd("screen"); ALWAYS wrap in `perl -e 'alarm N; exec @ARGV' -- ...` because a syntax error hangs the process; never launch PICO-8 with a window)
Scratchpad (throwaway files): /private/tmp/claude-501/-Users-kepes-Library-Application-Support-pico-8-carts/fac86f22-f64b-4c0a-b972-3764866f1a98/scratchpad/<agent>
Read the spec fully and your Task section in the plan (plus "Kanonikus kontrakt" and ".p8 fájlformátum jegyzet"). Do not re-derive the contract; use the exact names/indices/slots.
```

- **A:** „Execute Task 1 (Agent A) end to end: write desert_strike.p8 (`__lua__` only), test_ds.p8 with all 15 test cases from spec §12, run_tests.sh; iterate until `bash run_tests.sh` prints ALL GREEN. Keep tokens ≤ 6500 (shrinko8 --count). Draw calls must not error with an empty sprite sheet."
- **B:** „Execute Task 2 (Agent B): author src/gfx.txt (128×128 hex) for the canonical sprite indices, build the preview script in your scratchpad, view the PNG with the Read tool, iterate at least twice until every figure is recognizable; validate line lengths."
- **C:** „Execute Task 3 (Agent C): author src/sfx.txt and src/music.txt, validate format with a Python checker, prove loadability with a headless play.p8 run (AUDIO OK). Original melody only."
- **D:** „Execute Task 4 (Agent D): merge src/gfx.txt, src/sfx.txt, src/music.txt into desert_strike.p8 after the `__lua__` code, verify with run_tests.sh and a 10 s headless run of jedi.p8, then delete src/."
- **E1–E5:** a Task 5 megfelelő bekezdése + a findings-schema.
- **F:** „Execute Task 6 (Agent F) with this findings list: <JSON>. Fix all high and medium items; add tests first where testable; finish with ALL GREEN."
- **G:** „Execute Task 7 (Agent G): write README.md in Hungarian per the plan; document run_tests.sh usage; add a TOC if more than 3 H2 sections."

## Verification gate-ek

1. **Build → Assemble:** A ALL GREEN; B gfx.txt 128×128 validált + preview megnézve; C AUDIO OK.
2. **Assemble → Verify:** `run_tests.sh` ALL GREEN a teljes cart-on; `src/` törölve.
3. **Verify → Fix:** ha van high vagy medium finding → Fix, majd vissza Verify-ra (max 3 kör). Ha csak low → Docs.
4. **Docs → kész:** `run_tests.sh` ALL GREEN; a `desert_strike/` mappában csak `desert_strike.p8`, `test_ds.p8`, `run_tests.sh`, `README.md`, `docs/`.
