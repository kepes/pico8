# Desert Jedi — PICO-8 játék design spec

**Dátum:** 2026-09-16 · **Státusz:** jóváhagyott (a felhasználó kérdés-körben rögzítette a döntéseket), implementálva · **Cart:** `carts/desert_strike/desert_strike.p8`

> **Hangolási napló (2026-09-16, bot-playtest után):** a blokk-rádiusz 7 → **9 px**, a lövésszórás ±0,02 → **±0,04** fordulat. A spec eredeti értékeivel a tétlen jedi 6 seedből 4-en 10 mp alatt meghalt, a csak-blokkoló pedig 6-ból 5-ször 60 mp előtt — az alábbi számok már a hangolt értékek.

Felülnézetes, egyképernyős arcade túlélőjáték PICO-8-ra. A játékos egy jedi lovagot irányít egy sivatagi tájon, ahová a képernyő széleiről birodalmi katonák érkeznek, egyre többen. A katonák közelítenek, megállnak és lőnek; a jedi fénykarddal támad és blokkol, a kivédett lövés visszapattan és öl.

## Tartalomjegyzék

- [1. Célok és nem-célok](#1-célok-és-nem-célok)
- [2. Felhasználói döntések](#2-felhasználói-döntések)
- [3. Játékmenet](#3-játékmenet)
- [4. Entitások és állapotgépek](#4-entitások-és-állapotgépek)
- [5. Pálya: sivatag, kövek, sziklák](#5-pálya-sivatag-kövek-sziklák)
- [6. Ütközés és találat-szabályok](#6-ütközés-és-találat-szabályok)
- [7. Nehézségi görbe](#7-nehézségi-görbe)
- [8. Grafika](#8-grafika)
- [9. Hang](#9-hang)
- [10. HUD, címképernyő, game over](#10-hud-címképernyő-game-over)
- [11. Kód-architektúra](#11-kód-architektúra)
- [12. Tesztelés (headless)](#12-tesztelés-headless)
- [13. Fájlok és eszközök](#13-fájlok-és-eszközök)
- [14. Hangolható konstansok](#14-hangolható-konstansok)
- [15. Sikerkritériumok](#15-sikerkritériumok)
- [16. Edge case-ek](#16-edge-case-ek)

## 1. Célok és nem-célok

**Célok**

- Egyetlen, önálló `.p8` cart (kód + sprite + sfx + zene egy fájlban), ami a PICO-8-ban `load desert_strike/desert_strike.p8` → `run` után azonnal játszható.
- 30 fps (`_update`), 128×128, egy képernyő, nincs scroll.
- Headless módban futtatható automatikus tesztek (`pico8 -x`), ami a játéklogikát a rajzolás nélkül is ellenőrzi.
- Beleférés a PICO-8 limitekbe: ≤ 8192 token, ≤ 15360 byte tömörített méret.

**Nem-célok**

- Több pálya, szintek, boss, fejlesztések/power-upok.
- Többjátékos mód.
- Online ranglista (csak lokális rekord `cartdata`-val).
- Pályaszerkesztő, map-szekció használata (a pálya kódból generált).

## 2. Felhasználói döntések

| Kérdés | Döntés |
|---|---|
| Védekezés | **Nyomva tartott blokk, korlát nélkül**: amíg ❎ le van nyomva, a frontális kúpban véd, mozgás közben is. Nincs stamina, nincs időzítés. |
| Kivédett lövedék | **Visszapattan és öl**: a lövő felé repül vissza; bármelyik katonát megöli, amit eltalál. |
| Életerő | **3 találat**; találat után ~1,5 mp sérthetetlenség villogással. Game over → pontszám + rekord, gombra újraindul. |
| Hang | **SFX + háttérzene**. |

A „minél közelebb vannak, annál nehezebb kivédeni" követelmény a **konstans lövedék-sebességből** adódik: közelebbi katona lövése hamarabb ér oda, kevesebb idő marad odafordulni. Ezen felül a támadás (suhintás) alatt a blokk szünetel (ld. 4.1), ami közelharcnál kockázatot ad.

## 3. Játékmenet

- **Irányítás:** nyilak = mozgás 8 irányban (átlós: ×0,707 sebesség). A jedi **abba az irányba fordul, amerre utoljára nyomott nyíl mutat** (4 nézési irány: fel/le/bal/jobb; a bal a jobb tükrözése). Ha a jelenlegi nézési irány gombja még le van nyomva, az marad; különben az újonnan lenyomott lesz.
- **🅾️ (Z):** kardsuhintás. **❎ (X):** blokk, amíg nyomva.
- A jedi a képernyő belsejében mozoghat: x ∈ [4, 124], y ∈ [12, 124] (a felső 8 px HUD-sáv alatt), sziklákra nem léphet (csúszó ütközés).
- Katonák a képernyő szélén kívülről jönnek be, közelítenek, a saját megállási távolságukon megállnak és lőnek. Az idő múlásával több katona van egyszerre a pályán, és közelebb merészkednek.
- Ölés két módon: **suhintás** közvetlen közelről (elölről), vagy **visszavert lövés**. A megölt katona **összeesik** (fekvő sprite), **3 mp (90 frame) múlva eltűnik**.
- Végtelen túlélés: nincs „nyerés", a cél a pontszám. Pontok: suhintásos ölés **10**, visszavert lövéses ölés **20**.
- Game over: 3 találat után. Rekord `cartdata`-ban tárolva.

## 4. Entitások és állapotgépek

Minden entitás egy Lua tábla; a világ-koordináták a sprite **középpontját** jelentik (`x`, `y`), a hitboxok is ehhez képest értendők.

### 4.1 Jedi (`p`)

Mezők: `x, y, fx, fy` (nézési egységvektor, mindig a 4 főirány egyike), `hp` (0–3), `inv` (sérthetetlenség hátralévő frame), `swing` (suhintás hátralévő frame, 0 = nincs), `cd` (suhintás utáni cooldown frame), `blocking` (bool, számított), `anim` (járás-fázis), `dead`, `dying` (halál-animáció frame).

Állapotok és átmenetek:

- **idle/walk** → 🅾️ lenyomás (btnp) és `cd == 0` → **swing** (`swing = 8`).
- **swing**: 8 frame; alatta a jedi **mozoghat**, de nem blokkol. A suhintás **találati ablaka a 2.–6. frame** (`swing ∈ [3,7]`). Lejártakor `cd = 4`, vissza idle/walk.
- **blocking** = `btn(❎)` és `swing == 0` és nem halott. Nincs korlát, nincs mozgáslassítás.
- **hit**: ellenséges lövés találata, ha `inv == 0` → `hp -= 1`, `inv = 45`, képernyőrázás 6 frame, SFX. Ha `hp == 0` → **dying** (40 frame: kard kialszik, fekvő sprite), utána `state = "over"`.
- `inv > 0` alatt a jedi minden 2. frame-ben nem rajzolódik (villogás), és nem sebezhető, de **blokkolni tud** (a blokk sérthetetlenség alatt is visszaver).

Suhintás-kúp: a katona akkor esik el, ha `dist(p, tr) ≤ 13` és `dot(f, norm(tr - p)) ≥ 0,34` (±70°). Ugyanez a kúp a suhintás alatt a lövedékekre is érvényes (`dist ≤ 11`): a suhintás **visszaveri** a lövedéket (ugyanúgy, mint a blokk).

Blokk-kúp: a lövedék akkor van kivédve, ha `blocking` és `dist(p, bolt) ≤ 9` és `dot(f, norm(bolt - p)) ≥ 0,5` (±60°, összesen 120°). A kúp ellenőrzése **a lövedék pozíciója** alapján történik (nem a sebességvektor alapján) — így egy hátulról érkező lövés akkor sem védhető, ha a jedi épp elfordul, amíg a lövedék mögötte van.

### 4.2 Katona (`tr`, tábla: `troopers`)

Mezők: `x, y, spd, stop` (megállási távolság), `st` (`"walk" | "aim" | "dead"`), `t` (állapot-időzítő frame), `shot_cd` (következő lövésig frame), `flip` (bal/jobb nézés), `anim`, `stuck` (blokkolt frame-számláló), `side_t` (kerülő-manőver hátralévő frame), `side_dir` (±1).

- **Spawn:** véletlen szélről (0..3 = bal/jobb/fent/lent), a képernyőn kívül 6 px-re, a szél mentén véletlen pozíción (a HUD-sáv alá, y ≥ 14). `spd = 0,5 + min(0,3, elapsed/240)` (240 mp után max 0,8). `stop = max(20, 56 − elapsed·0,15) + rnd(12)`.
- **walk**: a jedi felé mozog. Tengelyenkénti mozgás sziklaütközéssel (ld. 6). Ha mindkét tengelyen blokkolt → `stuck += 1`; ha `stuck ≥ 6` → `side_t = 24`, `side_dir = ±1` véletlenül, `stuck = 0`. Amíg `side_t > 0`, a jedi-irányra **merőlegesen** mozog `side_dir` szerint. Katonák közti lágy szétlökés: ha két élő katona 8 px-nél közelebb van, mindkettő 0,3 px-t távolodik. Ha `dist ≤ stop` **és a katona a képernyőn, a HUD alatt van** (`0 ≤ x ≤ 128`, `12 ≤ y ≤ 128`) → **aim**, `t = 12` (célzás/telegráf). Képernyőn kívülről nem lő.
- **aim**: áll; `t` fogy. `t == 0`-nál **lő** (bolt a jedi aktuális pozíciója felé, ±0,04 fordulat véletlen szórással), majd `stop = max(16, stop − 6)`, `shot_cd = 45 + rnd(30)`, és `t = shot_cd`; a következő lövés előtt az utolsó 12 frame ismét telegráf (célzó sprite + torkolattűz-pixel). Ha `dist > stop + 8` (a jedi elment) vagy a katonát kitolták a képernyőről → vissza **walk**.
- **dead**: `t = 90`; nem ütközik, nem lő, alul rajzolódik (fekvő sprite), `t == 0` → törlés. Az élő katonák számába nem számít.
- A katonáknak **nincs érintéses sebzésük** és nem ütköznek a jedivel (csak lágy szétlökés a jeditől is, 6 px-en belül, hogy ne fedjék).
- A `flip` a mozgás/célzás x-irányából adódik (a jedi tőle balra → `flip = true`).

### 4.3 Lövedék (`b`, tábla: `bolts`)

Mezők: `x, y, dx, dy, owner` (`"e"` ellenséges / `"p"` visszavert), `src` (a kilövő katona referenciája, ha még él).

- Sebesség: ellenséges **2 px/frame**, visszavert **2,5 px/frame**.
- Képernyőn kívül (−8 .. 136) → törlés. Sziklába ütközve (pont-a-hitboxban) → szikra-részecskék + törlés.
- **Ellenséges** lövedék: a jedi ellen (ld. 6). Katonát nem sebez.
- **Visszavert** lövedék: bármely élő katonát megöl, ha `dist ≤ 5`; a jedit nem sebzi. Visszaveréskor az irány: ha `src` él → `norm(src − bolt)`; egyébként a sebességvektor negáltja. Színe piros (8) → kék (12).

### 4.4 Részecskék (`parts`)

`x, y, dx, dy, life, col`. Szikra (blokk: 12/7; sziklatalálat: 9/10), por (katona összeesés: 4/15). Max ~60 részecske; egyszerű élettartam-csökkentés.

## 5. Pálya: sivatag, kövek, sziklák

- Háttér: `cls(15)` (homok). Dekoráció: 12–18 db nem-ütköző díszsprite (kavics, repedés, csontváz-borda, száraz bokor) véletlen pozícióban, a HUD alatt.
- **Sziklák** (`rocks`): 5–8 db, két méret: **nagy** (16×16 sprite, hitbox 14×11, alsó részre igazítva) és **kicsi** (8×8 sprite, hitbox 7×5). Hitbox mező: `x1,y1,x2,y2` abszolút koordinátákban.
- Generálás elutasításos mintavétellel (max 300 próba): 
  - nem eshet a **spawn-zónába** (a (64, 68) középpont körüli 40×40 négyzet),
  - nem lóghat a HUD-sávba (`y1 ≥ 12`) és a képernyő szélén hagy **10 px** szabad sávot (a katonák be tudjanak jönni),
  - két szikla hitboxa között **≥ 14 px** hézag (a 8 px-es sprite-ok átférjenek).
- Rajzolás: sziklák a dekoráció után, az entitások előtt (a jedi/katonák a sziklák „előtt" haladnak el, mert a hitbox alá van igazítva; egyszerűsítés: nincs y-rendezés sziklákkal).

## 6. Ütközés és találat-szabályok

- **Mozgó entitás vs szikla:** az entitás hitboxa 6×6 (középpont ± 3). Tengelyenkénti mozgás: előbb x, ha ütközik → x visszaáll; aztán y ugyanígy → csúszás a szikla mentén. A jedi ezen felül a képernyő-határra clampelődik.
- **Ellenséges lövedék vs jedi** (frame-enként, minden ellenséges lövedékre, sorrendben):
  1. ha a jedi **suhint** (`swing ∈ [3,7]`) és a lövedék a suhintás-kúpban van (`dist ≤ 11`, ±70°) → **visszaverés**;
  2. különben ha **blokkol** és `dist ≤ 9` és a blokk-kúpban (±60°) → **visszaverés**;
  3. különben ha `dist ≤ 3,5` és `inv == 0` és nem halott → **találat**;
  4. különben ha `dist ≤ 3,5` és `inv > 0` → a lövedék **törlődik** sebzés nélkül (nem repül át a jedin).
- **Visszavert lövedék vs katona:** `dist ≤ 5` és `st ~= "dead"` → katona **dead**, +20 pont, lövedék törlődik.
- **Suhintás vs katona:** a találati ablak minden frame-jében minden élő katonára a suhintás-kúp szerint; egy suhintás **több katonát is** eltalálhat. +10 pont / katona.
- **Lövedék vs szikla:** pont-a-hitboxban teszt.

## 7. Nehézségi görbe

`elapsed` = a menet eltelt ideje másodpercben (`frames / 30`).

- **Egyszerre élő katonák maximuma:** `max_alive = min(8, 1 + flr(elapsed / 20))` — az első 20 mp-ben **egy**, utána 20 mp-enként eggyel több, max 8.
- **Spawn:** ha `élő katonák < max_alive` és `spawn_cd == 0` → spawn, `spawn_cd = max(30, 90 − elapsed·0,4)` frame. A menet 1. frame-jén azonnal spawnol egy katona.
- **Közelítés:** a `stop` képlet miatt a későbbi katonák közelebb állnak meg (56 → 20 px), és minden lövés után 6 px-t közelebb jönnek (min 16).
- **Sebesség:** katona 0,5 → 0,8 px/frame 4 perc alatt.
- Lövedék-sebesség konstans (2 px/frame): 56 px-ről ~28 frame (0,9 mp), 20 px-ről 10 frame (0,33 mp) a reakcióidő.

## 8. Grafika

Minden sprite 8×8 (a nagy szikla 16×16), kézzel rajzolt hex a `__gfx__` szekcióban. **0 = átlátszó** (`spr` alapértelmezés). Javasolt kiosztás (sprite-index):

| Index | Tartalom |
|---|---|
| 1–2 | jedi lefelé néz (idle, lépés) — barna köpeny (4), arc (14 rózsaszín — a 15-ös barack a homok színe, ezért nem használható; 2026-09-17-től a sprite-ban, nem futásidejű cserével), haj (4/0) |
| 3–4 | jedi felfelé néz (idle, lépés) |
| 5–6 | jedi oldalra néz (jobbra; balra `flip_x`) (idle, lépés) |
| 7 | jedi fekve (halál) |
| 16–17 | katona oldalnézet (lépés 2 fázis) — fehér páncél (7), fekete rések (0), szürke árnyék (6), sisak-lencse sötét (1) |
| 18 | katona célzó póz (blaster előre, torkolattűz pixel 10) |
| 19 | katona fekve (halál) |
| 32 | kis szikla (barna 4, világos él 9, árnyék 2/5) |
| 33–34 / 49–50 | nagy szikla 16×16 |
| 35–38 | dekor: kavicsok, repedés, csontborda, száraz bokor |

- **Fénykard:** kódból rajzolt, nem sprite. `line` a kéztől 6 px-re a nézési irányban, szín 12 (kék), 1 px-es 7 (fehér) mag: két `line` (12 majd egy rövidebb 7). Blokk közben a nézési irányra **merőlegesen** tartva (bal/jobb nézésnél függőleges, fel/le nézésnél vízszintes), a jedi előtt 3 px-re. Suhintás közben a szög a nézési irány körül −60° → +60° söpör a 8 frame alatt (`cos/sin` PICO-8 fordulat-egységben).
- **Árnyék:** minden álló entitás alatt 1 px-es sötét ellipszis (`ovalfill`, szín 4, 50%-os hatás helyett egyszerű).
- **Halott katona:** dead sprite a többi entitás **alatt**.
- Rajzolási sorrend: háttér → dekor → sziklák → halott katonák → élő entitások **y szerint rendezve** (jedi + katonák) → lövedékek → részecskék → HUD.
- Képernyőrázás: `camera(rnd(4)−2, rnd(4)−2)` amíg `shake > 0`, egyébként `camera()`. A HUD a rázás **után** `camera()`-val rajzolódik.

## 9. Hang

SFX-slotok (mind rövid, ≤ 16 hang):

| Slot | Esemény | Jelleg |
|---|---|---|
| 0 | suhintás | gyors lefelé csúszó zajos (noise 6) fütty |
| 1 | blokk/visszaverés | rövid, magas fémes „ping" (triangle/square) |
| 2 | blaster lövés | rövid lefelé csúszó square |
| 3 | katona összeesik | tompa, rövid lefelé zaj |
| 4 | jedi sérül | mély, rövid, kicsit zajos |
| 5 | jedi halál | hosszabb lefelé glissando |
| 6 | menü/start | 3 hangos felfelé arpeggio |
| 7 | visszavert lövés talál | ping + rövid zaj |

Zene: 8–11 slot, 2 minta (`__music__` 0–1, loop), dallam + basszus, kb. 100 BPM, sivatagi/hősies hangulat; **saját szerzemény** (nem idézhet létező filmzenét). Címképernyőn és játék közben szól (`music(0)`), game overkor leáll (`music(-1)`), az 5-ös SFX után.

## 10. HUD, címképernyő, game over

- **HUD** (y = 0..7, a rázástól függetlenül): bal oldalon 3 szív (`print("♥")`, tele: 8, üres: 5), középen `elapsed` mm:ss, jobb oldalon `score` (jobbra igazítva, `#tostr(score)·4`).
- **Cím:** „DESERT JEDI" nagy szöveg középen (dupla méretű hatás: `print` 2× eltolva, vagy `?`-vel árnyék), alatta „⬅️➡️⬆️⬇️ MOVE  🅾️ ATTACK  ❎ BLOCK", „PRESS 🅾️ TO START", „BEST: n". Háttér: a generált pálya (sziklákkal), a jedi középen áll, kard ég — élő demó nélkül.
- **Game over:** a pálya kimerevítve (entitások maradnak, nem frissülnek), középen sötét doboz: „GAME OVER", „SCORE n", „BEST n" (NEW! ha rekord), „PRESS 🅾️ TO RETRY". 🅾️ → új menet (új sziklák).
- Állapotok: `state ∈ {"title", "play", "over"}`; `_update`/`_draw` ez alapján diszpécsel.

## 11. Kód-architektúra

Egyetlen `__lua__` szekció, tab-olva (`-->8` elválasztókkal) a PICO-8 szerkesztő kedvéért:

1. **main**: konstansok, `_init` (cartdata, `srand`, `state="title"`, `new_game()`), `_update`, `_draw` diszpécser, globális `g` tábla (állapot).
2. **world**: `gen_rocks()`, `gen_decor()`, `solid(x,y)` (hitbox-teszt), `move_solid(e,dx,dy)` (csúszó mozgás).
3. **player**: `new_player()`, `upd_player()`, `draw_player()`, `draw_saber()`.
4. **troopers**: `spawn_trooper()`, `upd_troopers()`, `draw_trooper()`.
5. **bolts**: `fire(tr)`, `upd_bolts()`, `deflect(b)`, `draw_bolts()`.
6. **fx/hud**: részecskék, `shake`, `draw_hud()`, `draw_title()`, `draw_over()`.

Globális állapot: `g = {state, p, troopers, bolts, rocks, decor, parts, frames, score, best, spawn_cd, shake}`. `new_game()` teljesen újraépíti `g`-t (kivéve `best`).

Elvek: nincs OOP/metatábla (token-takarékos); a segédfüggvények (`dist`, `norm`, `dot`, `clamp`) egy helyen. Minden számszerű paraméter a **main** tab tetején konstansként.

Hívási sorrend `upd_play()`-ben: `upd_player` → `upd_troopers` (spawn is) → `upd_bolts` (ütközések) → `upd_parts` → `frames += 1`.

## 12. Tesztelés (headless)

- `carts/desert_strike/test_ds.p8`: `#include desert_strike.p8` (csak a kódot húzza be; a PICO-8 ezt támogatja — ellenőrizve), majd **felülírja** `btn`/`btnp`-t egy `keys` táblából olvasó stubbal, és saját `_init`-et definiál, ami lefuttatja az összes tesztet, `printh`-val riportol (`PASS: ...` / `FAIL: ...`), a végén `printh("TESTS DONE ok=N fail=M")` és `extcmd("shutdown")`.
- A tesztek a játék `_update`/`_draw` függvényeit hívják közvetlenül (`step(n, keys)` segéddel), `srand(1)` determinizmussal, és a `g` táblát vizsgálják. A `_draw` is meghívódik minden lépésben, hogy a rajzoló-kód futásidejű hibáit is elkapja.
- Kötelező tesztesetek: mozgás + clamp; fordulás; szikla-ütközés (csúszás); spawn + közelítés + megállás + telegráf + lövés; találat → hp−1 + inv; blokk kúpban → visszaverés (hp változatlan, owner=`"p"`); blokk háton kívül → hp−1; visszavert lövés öl (+20, dead, 90 frame után törlés); suhintás elöl öl (+10), hátul nem; `max_alive` ramp (0 s: 1, 20 s: 2, 200 s: 8); game over hp=0 → `state="over"`, 🅾️ → új menet, `score=0`, `hp=3`; sziklák nem lógnak a spawn-zónába és nem érnek össze; lövedék sziklában törlődik; lövedék képernyőn kívül törlődik.
- `carts/desert_strike/run_tests.sh`: (1) `pico8 -x test_ds.p8` időkorláttal (`perl -e 'alarm 60; exec @ARGV'`), a kimenetben `syntax error` / `runtime error` / `FAIL:` → hiba; `TESTS DONE ... fail=0` → siker; (2) `shrinko8 desert_strike.p8 --count` token/tömörített méret kiírása, 8192 token felett hiba; (3) `shrinko8 --lint` figyelmeztetések kiírása (nem blokkoló). Kilépőkód 0 = zöld.
- Vizuális ellenőrzés: `pico8 -desktop <dir> -x shots.p8` ahol egy kis cart `extcmd("screen")`-nel ment képernyőképet a cím-, játék- és game-over képernyőről (ellenőrizve: headless módban működik, PNG a `-desktop` mappába). **Fontos:** a `#include` csak a Lua-kódot húzza be, ezért a képernyőképes segéd-cartba a `desert_strike.p8` `__gfx__`/`__sfx__`/`__music__` szekcióit is át kell másolni (`sed -n '/^__gfx__$/,$p' desert_strike.p8 >> shots.p8`), különben üres sprite-lappal rajzol.

## 13. Fájlok és eszközök

```
carts/desert_strike/
  desert_strike.p8              a játék (önálló cart)
  test_ds.p8         headless tesztek (#include desert_strike.p8)
  run_tests.sh         teszt + token-limit + lint futtató
  README.md            játék leírása, irányítás, futtatás, tesztelés
  docs/specs/2026-09-16-desert-jedi-design.md   (ez a doksi)
  docs/plans/2026-09-16-desert-jedi-plan.md     (implementációs terv)
```

Eszközök: `/Applications/PICO-8.app/Contents/MacOS/pico8` (`-x` headless, `-desktop` screenshot-mappa), `uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8 <cart> --count|--lint`.

## 14. Hangolható konstansok

| Név | Érték | Jelentés |
|---|---|---|
| `P_SPD` | 1.5 | jedi sebesség px/frame |
| `SWING_T` | 8 | suhintás hossza frame |
| `SWING_R` | 13 | suhintás hatótáv px (katona) |
| `SWING_BR` | 11 | suhintás hatótáv px (lövedék) |
| `SWING_COS` | 0.34 | suhintás-kúp (±70°) |
| `BLOCK_R` | 9 | blokk hatótáv px (hangolt, eredetileg 7) |
| `BLOCK_COS` | 0.5 | blokk-kúp (±60°) |
| `HIT_R` | 3.5 | jedi test-találat px |
| `INV_T` | 45 | sérthetetlenség frame |
| `MAX_HP` | 3 | életerő |
| `T_SPD0` | 0.5 | katona alapsebesség |
| `BOLT_SPD` | 2 | ellenséges lövedék px/frame |
| `BOLT_SPREAD` | 0.04 | lövés szórása ± fordulat (hangolt, eredetileg 0.02) |
| `RBOLT_SPD` | 2.5 | visszavert lövedék px/frame |
| `DEAD_T` | 90 | hulla eltűnés frame (3 mp) |
| `AIM_T` | 12 | telegráf frame |
| `RAMP_S` | 20 | mp-enként +1 max katona |
| `MAX_ALIVE_CAP` | 8 | felső korlát |
| `N_ROCKS` | 5–8 | sziklák száma |

## 15. Sikerkritériumok

1. `run_tests.sh` zöld (minden teszteset PASS, nincs runtime/syntax error, ≤ 8192 token).
2. A cart PICO-8-ban `load desert_strike/desert_strike.p8` → `run` után a címképernyővel indul, 🅾️-ra játszható.
3. Headless képernyőképeken (cím, játék közben 2+ katonával, game over) a sprite-ok felismerhetők: jedi barna köpeny + kék kard, katona fehér páncél, sziklák barnák a homokon, HUD olvasható.
4. Az első 20 mp-ben soha nincs egynél több élő katona; 200 mp-nél 8.
5. Megölt katona pontosan 90 frame-ig fekszik, aztán eltűnik.
6. Sziklára sem a jedi, sem katona nem tud rálépni; a katonák nem ragadnak be tartósan (a kerülő-manőver 24 frame-en belül elindul).

## 16. Edge case-ek

- **Lövő katona már halott a visszaveréskor** → a lövedék a sebességvektor negáltjával repül vissza.
- **Egy frame-ben több lövedék a blokk-kúpban** → mind visszaverődik.
- **Jedi a szikla mögött**: az ellenséges lövedék a sziklán megsemmisül; a katona tovább lő (nincs LoS-tudat) — szándékos, taktikai elem.
- **Katona spawnja a képernyőn kívül, szikla a 10 px-es szélsávban nincs** → mindig be tud lépni.
- **8-nál több lövedék / 60-nál több részecske** → a részecskéknél a legrégebbi törlődik; lövedékeknél nincs cap (max_alive·~2 realisztikusan).
- **Game over közben** a katonák és lövedékek nem frissülnek (kimerevítés), a zene leáll.
- **Cartdata headless módban** is működik; a rekord `dget(0)`-ból jön, mentés csak ha `score > best`.
- **Átlós fordulás:** két nyíl egyszerre → az előbb lenyomott marad a nézési irány, amíg tartják.
- **Képernyőn kívüli katona** sosem lő: a spawn utáni első lövés csak a belépés után jöhet; ha egy célzó katonát a szétlökés kitol a képernyőről, walk-ra vált.
