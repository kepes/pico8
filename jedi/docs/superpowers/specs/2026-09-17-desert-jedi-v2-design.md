# Desert Jedi v2 — görgetett világ, Vader, homokféreg, drágakövek

**Dátum:** 2026-09-17 · **Státusz:** jóváhagyott (a felhasználó kérdés-körben rögzítette), implementálva 2026-09-17 · **Alap:** a v1 spec (`2026-09-16-desert-jedi-design.md`) minden szabálya érvényben marad, kivéve ahol ez a doksi felülírja. **Cart:** `carts/jedi/jedi.p8` (a v1 archívuma: `carts/jedi/archive/jedi-v1.p8`).

A v1 egyképernyős arcade játékot 4×4 képernyős, görgetett sivataggá bővítjük, új ellenféllel (Darth Vader főellenség kísérőkkel), környezeti veszéllyel (homokféreg), gyűjthető drágakövekkel, új zenével és módosított visszaverés-szórással.

## Tartalomjegyzék

- [1. Változások összefoglalója](#1-változások-összefoglalója)
- [2. Felhasználói döntések](#2-felhasználói-döntések)
- [3. Görgetett világ](#3-görgetett-világ)
- [4. Visszavert lövedék szórása](#4-visszavert-lövedék-szórása)
- [5. Kardszínek](#5-kardszínek)
- [6. Drágakövek](#6-drágakövek)
- [7. Darth Vader (főellenség)](#7-darth-vader-főellenség)
- [8. Homokféreg](#8-homokféreg)
- [9. Zene és hang v2](#9-zene-és-hang-v2)
- [10. HUD és képernyők](#10-hud-és-képernyők)
- [11. Grafika-kiegészítés](#11-grafika-kiegészítés)
- [12. Állapot- és függvény-kontrakt (v2 delta)](#12-állapot--és-függvény-kontrakt-v2-delta)
- [13. Tesztelés v2](#13-tesztelés-v2)
- [14. Hangolható konstansok (új)](#14-hangolható-konstansok-új)
- [15. Sikerkritériumok](#15-sikerkritériumok)
- [16. Edge case-ek](#16-edge-case-ek)

## 1. Változások összefoglalója

| # | Kérés | Megvalósítás röviden |
|---|---|---|
| 1 | Visszavert lövedék 30% pontos, 70% ±10° | `deflect()`: 30% a lövő felé, 70% pontosan 10°-kal balra vagy jobbra (véletlen előjel) |
| 2 | Nagyobb, görgetett, random terület | 512×512 px világ (4×4 képernyő), kamera követi a jedit, világhatáron clampel; sziklák/dekor/kövek random |
| 3 | Star Wars-osabb zene | **Saját** hősies fanfár-főtéma (4 minta, 3 csatorna) + saját sötét induló Vaderhez (4 minta); az eredeti Williams-dallamok nem kerülnek átírásra |
| 4 | 15 kill után Vader + 3 katona | `g.kills` számláló; küszöb 15, 30, 45…; egyszerre egy Vader; lassabb a jedinél, közelharc piros karddal, 5 kardtalálat, 300 pont, zene-váltás |
| 5 | Homokféreg | 60 mp után, ha a jedi 20 mp-nél tovább egy 40×40 px-es területen marad → 3 mp remegés → féreg; ha a jedi 20 px-en belül maradt, bekapja (azonnali game over) |
| 6 | Kardszínek | jedi kard zöld (11), Vader kardja piros (8), mindkettő fehér (7) maggal |
| 7 | 5 drágakő, 100 pont | 5 kő a világban; mind begyűjtve → 5 új a látómezőn kívül; HUD számláló |
| 8 | Vader 300 pont | `kill_vader()` → +300 |

## 2. Felhasználói döntések

| Kérdés | Döntés |
|---|---|
| Pálya mérete | **4×4 képernyő = 512×512 px**, fix; az elrendezés random |
| Drágakő-jelzés | **Nincs** iránymutató; csak a HUD számláló (`◆ n/5`) |
| Vader csapása | **Blokkolva kivédhető**: ❎ tartva Vader felé nézve a kardok összecsapnak (szikra + hang), nincs sebzés; a csapást 0,5 mp telegráf előzi meg |
| Homokféreg | **El lehet futni**: a 3 mp remegés alatt ≥ 20 px-re eltávolodva a kitörési ponttól a féreg üresen bukkan fel |
| Zene | Saját kompozíció Star Wars-stílusban (szerzői jog miatt nem az eredeti dallamok) |

Kérdés nélkül eldöntött részletek: a visszavert lövés 70%-a **pontosan** 10°-kal tér el; egyszerre csak egy Vader; Vadert lövedék nem sebzi (a visszavert lövés rajta szikrázva megsemmisül), minden kardtalálat után 1 mp tántorgás + sérthetetlenség; a jeditől 200 px-nél messzebb lemaradt katonák csendben eltűnnek; a féreg azonnali game over az életerőtől függetlenül.

## 3. Görgetett világ

- **Méret:** `W = 512`, `H = 512` px. Világkoordináták minden entitásra; a jedi kezdőpontja a világ közepe `(256, 256)`.
- **Kamera:** `cam_x = clamp(p.x − 64, 0, W − 128)`, `cam_y = clamp(p.y − 64, 0, H − 128)`; rajzoláskor `camera(cam_x + rázás, cam_y + rázás)`. A HUD `camera()` visszaállítás után, a felső 8 px-es fekete sávban.
- **Látómező (view):** `[cam_x, cam_x+128] × [cam_y, cam_y+128]`. Az „on screen" fogalom mindenhol (katona `vis`, spawn, lövedék-törlés, gem-respawn) erre vonatkozik.
- **Jedi határ:** `x ∈ [4, W−4]`, `y ∈ [12, H−4]` (a világ felső 12 px sávja tiltott, mint v1-ben a HUD alatt).
- **Világszél rajzolása:** a világon kívüli terület sötétebb homok (`cls(9)` helyett: a világ téglalapját `rectfill`-lel 15-ös színnel, körülötte 9 marad) — a kamera clampje miatt legfeljebb a HUD-sáv alatt látszik 0 px kívüli terület, de a rajz legyen robusztus.
- **Generálás:** sziklák száma `N_ROCKS = 96 + flr(rnd(24))` (≈ 6–7 / képernyő), a v1 szabályaival (spawn-zóna a kezdőpont körüli 40×40; szélsáv 10 px a világhatárnál; páronként ≥ 14 px hézag; max 3000 próba, ha elfogy, kevesebb szikla is elfogadható). Dekor `N_DECOR = 200 + flr(rnd(60))`.
- **Culling:** dekor/szikla/gem/hulla csak akkor rajzolódik, ha a látómező ±16 px-en belül van. Ütközéstesztnél (`solid`, `in_rock`) csak azok a sziklák vizsgálandók, amelyek hitboxa 16 px-en belül van a ponthoz — a v1 lineáris keresés marad, de az első ellenőrzés egy olcsó távolság-szűrő.
- **Katona-spawn:** a látómezőn kívül 6 px-re, véletlen oldalon, a világon belül (≥ 4 px a széltől). Ha a választott oldal a világon kívülre esne, másik oldal (max 4 próba); ha egyik sem jó (elméleti eset), a jeditől 90 px-re véletlen irányban, világon belülre clampelve.
- **Lemaradt katonák:** ha egy élő katona a jeditől > 200 px-re van → törlés (nem kill, nem pont, nem esemény). Vaderre nem vonatkozik.
- **Lövedék-törlés:** a látómezőn kívül > 16 px-re, vagy a világon kívül.
- **Katona `vis`:** a látómezőben van (v1 „képernyőn van" szabály kamerához igazítva). Csak látható katona vált `aim`-re.
- **Sebességek, nehézségi görbe:** változatlan (v1 §7).

## 4. Visszavert lövedék szórása

`deflect(b)`: a célirány `a0` = a lövő (`src`, ha él) felé mutató szög, különben a sebességvektor negáltja (v1). Ezután:

- `rnd() < 0.3` → **pontosan** `a0`;
- különben `a0 ± 10°` = `a0 + (rnd()<0.5 and −1 or 1) · (10/360)` fordulat (PICO-8 szögegység: 1 fordulat = 1.0).

A sebesség marad `RBOLT_SPD = 2.5`. A visszavert lövés továbbra is bármely élő katonát megöli (+20), Vadert nem (ld. 7.).

## 5. Kardszínek

- Jedi kard: **11 (zöld)** külső vonal + 7 mag. Blokk/visszaverés szikrái 11/7. A cím „DESERT JEDI" felirat is 11-es színű, árnyék 3.
- Vader kardja: **8 (piros)** + 7 mag; Vader szikrái (lövedék-megsemmisítés, parry) 8/7.

## 6. Drágakövek

- **Elhelyezés:** `g.gems` = 5 elem `{x, y}`; feltételek: nem sziklában (`in_rock(x,y,6)` hamis), a jedi kezdőpontjától ≥ 40 px, egymástól ≥ 40 px, világszéltől ≥ 8 px; max 500 próba/kő.
- **Rajz:** sprite 44/45 váltakozva 8 frame-enként (csillogás), `y` szerint rendezve az entitásokkal, alatta kis árnyék.
- **Felvétel:** `dist(p, gem) ≤ 6` → `score += 100`, `g.gems_got += 1`, `sfx(14)`, 8 részecske (12/7), a kő törlődik.
- **Újratelepítés:** amikor `#g.gems == 0` → 5 új kő a **látómezőn kívül** (`x < cam_x−8 or x > cam_x+136 or y < cam_y−8 or y > cam_y+136`), a többi feltétel mint fent; `g.gems_got = 0`, `sfx(15)`.
- **HUD:** `◆ n/5` a szívek után (szín 12).

## 7. Darth Vader (főellenség)

### 7.1 Megjelenés

- `g.kills` = megölt katonák száma (kard + visszavert lövés; Vader kísérői is számítanak). `g.next_vader = 15` induláskor.
- Minden frame-ben (play): ha `g.vader == nil` és `g.kills >= g.next_vader` **és a jedi nem halott** (`not g.p.dead`, hogy a haldoklás alatt ne induljon Vader és ne írja felül a `music(-1)`-et) → `spawn_vader()`, `g.next_vader += 15`, `music(4)`.
- `spawn_vader()`: pozíció mint a katona-spawn (látómezőn kívül, világon belül). Mellé **3 katona** (`spawn_trooper_at(x±12, y±12)` — a v1 spawn mezőivel, `stop` és `spd` az aktuális `elapsed` szerint), függetlenül a `max_alive` korláttól.
- Vader tábla: `g.vader = {x, y, hp=5, st="walk"|"windup"|"strike"|"stagger"|"dying", t, flip, anim, stuck, side_t, side_dir, cd}`.

### 7.2 Viselkedés

- **walk:** a jedi felé `V_SPD = 1.1` px/frame (jedi 1,5 → elfutható), tengelyenkénti mozgás sziklaütközéssel és a v1 katona-kerülő manőverrel (`stuck`/`side_t`). Nincs szétlökés a katonákkal (átmegy rajtuk). Ha `dist ≤ V_REACH = 12` és `cd == 0` → **windup**, `t = 15` (0,5 mp telegráf: kard felemelve, sprite 26/42).
- **windup:** áll, `t` fogy; `t == 0` → **strike**, `t = 8`, `sfx(8)`.
- **strike:** a kard −60° → +60° söpör a nézési irány (a jedi felé mutató, 4 főirányra kerekített `fx,fy`) körül. A `t ∈ [3,7]` ablakban, ha a jedi a kúpban (`dist ≤ 13`, `dot ≥ 0.34`):
  - ha a jedi **blokkol** (`is_blocking()`) és Vader a jedi blokk-kúpjában van (`in_cone(vader.x, vader.y, 14, BLOCK_COS)`) → **parry**: `sfx(9)`, 10 szikra 11/8 vegyesen, a jedi **nem** sérül; ez frame-enként legfeljebb egyszer, a strike-ra egyszer (`hit_done` flag);
  - különben `hurt_player()` (v1 szabály: `inv` alatt nem sebez), `hit_done`.
  - A jedi **suhintása** Vader strike-ját nem szakítja meg.
  - `t == 0` → **walk**, `cd = 30`.
- **stagger** (kardtalálat után): `t = 30`; visszalökés 8 px a jeditől távolodva (3 frame alatt, sziklába nem), villog (páros frame-eken `pal(…,7)`), **sérthetetlen** (újabb suhintás nem számít); `t == 0` → walk.
- **dying:** `t = 60`: kard kialszik, fekvő sprite (27/43 használható fekve: `spr` 90°-os forgatás nincs — a 27/43 legyen eleve összeesett/térdelő póz), villog; `t == 0` → `g.vader = nil`. A pont és a zene **a dying kezdetén**: `score += 300`, `sfx(11)`, `music(0)`.
- **Sebzés Vadernek:** a jedi suhintás-kúpja (`SWING_R = 13`, `SWING_COS`) és találati ablaka a v1 szerint; ha Vader `st` ∈ {walk, windup, strike} → `hp −= 1`, `sfx(10)`, 6 szikra 8/7, `st = "stagger"`; `hp == 0` → dying. Egy suhintás Vadert legfeljebb egyszer találja el (a stagger ezt garantálja).
- **Lövedék vs Vader:** visszavert (`owner == "p"`) lövedék `dist ≤ 6` → a lövedék törlődik, 4 szikra 8/7, Vader nem sérül. Ellenséges lövedék átmegy rajta.
- **Vader vs jedi test:** nincs érintéses sebzés, nincs szétlökés.
- **Lemaradás:** Vader sosem despawnol és nem teleportál; a világ véges, ezért előbb-utóbb odaér, ha a jedi megáll.

### 7.3 Rajz

- 8×16-os sprite: felső 24–27, alsó 40–43 (`spr(24+f, x−4, y−12, 1, 2, flip)`): 24/40 járás A, 25/41 járás B, 26/42 windup (kard fent), 27/43 összeesett. **Átlátszó szín: 3** (a sprite fekete pixeleket használ): `palt(0,false) palt(3,true) spr(...) palt()`.
- Kard: piros, v1 `draw_saber` logikával paraméterezve (szín 8), walk közben a nézési irányban előre, windup alatt felfelé/előre emelve, strike alatt söpör.
- Y-rendezés a többi entitással (a lábak `y`-a).
- **HP-csík:** HUD, `y = 9..11`, középen: 5 pip (4×3 px, 8-as szín tele, 2-es üres), csak amíg `g.vader ~= nil`.

## 8. Homokféreg

- `g.worm = {st="idle"|"tremor"|"emerge"|"sink", t, ax, ay, still, ex, ey}`; `ax,ay` horgony, `still` = frame-számláló.
- **Figyelés** (csak `play`, csak ha `elapsed() ≥ 60`): ha `dist(p, (ax,ay)) > 20` → `ax,ay = p.x,p.y`, `still = 0`; különben `still += 1`. (60 mp előtt a horgony követi a jedit, `still` marad 0 → a legkorábbi kitörés 60 + 20 = 80 mp-nél.)
- **tremor:** `still ≥ 600` és `st == "idle"` → `st = "tremor"`, `t = 90`, `ex,ey = p.x,p.y`. Minden frame-ben: `g.shake = max(g.shake, 2)`, 2 porrészecske (4/9 — a 15 a homok színe, láthatatlan lenne) `ex±8, ey±8` körül, `sfx(12)` 30 frame-enként. `t == 0` → **emerge**.
- **emerge:** `t = 60`, `sfx(13)`. A **10. frame-ben** (`t == 50`): ha `dist(p, (ex,ey)) ≤ 20` → a jedi megevése: `p.dead = true`, `p.hp = 0`, `p.eaten = true` (nem rajzolódik), `g.cause = "worm"`, `p.dying = 40` → 40 frame múlva `state = "over"` (v1 dying-logika), `music(-1)`. Rajz: `t ≥ 45` A-frame (fej, csukott száj), `t < 45` B-frame (nyitott száj, fogak); a sprite közepe `(ex, ey − 8)`. `t == 0` → **sink**.
- **sink:** `t = 30`, a féreg 1 px/frame-mel süllyed (clip-pel levágva a `ey+8` vonal alatt), majd `st = "idle"`, `still = 0`, `ax,ay = p.x,p.y`.
- A féreg **nem** sebzi a katonákat/Vadert (nem kért), nem ütközik.
- Rajzolási sorrend: a féreg minden entitás **fölött** (a jedi elé), a részecskék alatt.
- Game over képernyőn ha `g.cause == "worm"`: extra sor `EATEN BY A SANDWORM` (szín 9) a `SCORE` fölött.

## 9. Zene és hang v2

**Szerzői jog:** az eredeti Star Wars-dallamok nem kerülnek átírásra. Két saját kompozíció készül „a stílusban":

- **Főtéma** (music 0–3, loop): hősies fanfár — B♭-dúr/C-dúr, felütéses kvart–kvint ugrások (pl. 5→1→5→3 kontúr), pontozott ritmus, 3 csatorna: dallam (pulse/square, vol 5), ellenszólam/akkordtörés (organ/triangle, vol 3), basszus+ütős (triangle basszus + noise pergő az 1. és 3. ütésen, vol 4). ~110 BPM (speed ≈ 16 a 32 hangos, 16-od rácsú mintához).
- **Vader-induló** (music 4–7, loop): sötét, moll induló (G-moll), **pontozott „tá–tá–tá, ti-tá, ti-tá" ritmus**, kis tercek és kis szekundok, dallam square vol 5, kvint-orgonapont triangle vol 4, noise nagydob a negyedeken. ~100 BPM. Nem idézi a Birodalmi induló hangsorát.
- **Váltás:** `music(0)` cím és játék; Vader spawn → `music(4)`; Vader dying kezdete → `music(0)`; game over → `music(-1)`; új menet → `music(0)`.

**SFX-slotok:** 0–7 v1 (jedi hurt/death, blaster, stb.), új: **8** Vader suhintás (mély, zajos „vúm"), **9** kardok összecsapása (fémes, magas, rövid, 2 hang), **10** Vader sérül, **11** Vader halál (hosszabb ereszkedés), **12** földremegés (mély noise, 30 frame), **13** féreg előbukkanás/ordítás, **14** drágakő felvétel (gyors felfelé arpeggio), **15** kövek újratelepülése (3 hangos csengés). **Zene-sfx:** főtéma 16–27 (minta 0: 16,17,18; 1: 19,20,21; 2: 22,23,24; 3: 25,26,27), induló 28–39 (minta 4: 28,29,30; 5: 31,32,33; 6: 34,35,36; 7: 37,38,39). `__music__` sorok: `01 10111244`, `00 13141544`, `00 16171844`, `02 191a1b44`, `01 1c1d1e44`, `00 1f202144`, `00 22232444`, `02 25262744`, a többi 56 sor `00 41424344`.

## 10. HUD és képernyők

- Felső fekete sáv (0..7): balra `♥♥♥` (8/5) majd `◆ n/5` (12), középen idő `mm:ss`, jobbra pontszám.
- `y = 9..11`: Vader HP-pipek, csak ha Vader él.
- Cím: mint v1, a felirat zöld (11), a kezdő területet mutatja a jedivel; a szöveg alá kerül egy sor: `◆ 100  VADER 300` (szín 6), a `BEST` fölé.
- Game over: v1 doboz + opcionális `EATEN BY A SANDWORM` sor.

## 11. Grafika-kiegészítés

| Index | Tartalom |
|---|---|
| 24–27 / 40–43 | Vader 8×16 (felső/alsó): járás A, járás B, windup (kard fent — a kardot kód rajzolja, a sprite csak a kart emeli), összeesett. Fekete (0) test, sötétszürke (5) részletek, sisak fénye 6, mellkasi panel 8/11/12 pixelek; **háttér 3 (átlátszó)**. |
| 44, 45 | drágakő 8×8, két csillogás-frame (12 test, 7 fény, 1 árnyék) |
| 64–67 / 80–83 / 96–99 / 112–115 | homokféreg A (32×32): homokból kiemelkedő, gyűrűs test (4/9/15), csukott száj (2) |
| 68–71 / 84–87 / 100–103 / 116–119 | homokféreg B: nyitott száj (1/2), fogak (7), gyűrűk |
| 39 | (v1 szív, marad, nem használt) |

A v1 sprite-ok (1–7, 16–19, 32–38, 33/34/49/50) változatlanok. A jedi kardja nem sprite (kód, 11-es szín).

## 12. Állapot- és függvény-kontrakt (v2 delta)

Új `g` mezők: `cam_x, cam_y, kills, next_vader, vader (nil|tábla), worm (tábla), gems (tábla), gems_got, cause (nil|"worm")`. Új `p` mező: `eaten`. Új konstansok a main tab tetején (14.).

| Tab | Függvény | Szerződés |
|---|---|---|
| main | `upd_cam()` | `g.cam_x/cam_y` számítása a jedi pozíciójából, clamp `[0, W−128]` |
| main | `in_view(x,y,m)` | `x ≥ cam_x−m and x ≤ cam_x+128+m and y ≥ cam_y−m and y ≤ cam_y+128+m` |
| world | `gen_rocks()`, `gen_decor()` | v2 darabszámokkal, világméretre |
| world | `gen_gems(n, outside_view)` | `n` kő elhelyezése a 6. szabályaival; `outside_view=true` → látómezőn kívül |
| world | `spawn_pos()` | látómezőn kívüli, világon belüli spawn-pozíció `x,y` (katona és Vader használja) |
| player | `upd_gems()` | felvétel + újratelepítés |
| troopers | `spawn_trooper()` → `spawn_pos()`; új: `spawn_trooper_at(x,y)` | |
| troopers | `despawn_far()` | `dist > 200` → `del` (az `upd_troopers` része) |
| vader | `spawn_vader()`, `upd_vader()`, `hit_vader()` (suhintás-találat), `draw_vader()` | 7. szerint; `upd_vader` az `upd_troopers` után, az `upd_bolts` előtt fut |
| bolts | `deflect(b)` | 4. szerint; Vader-ütközés az `upd_bolts`-ban |
| worm | `upd_worm()`, `draw_worm()` | 8. szerint; `upd_worm` az `upd_parts` előtt |
| hud | `draw_hud()` | gem-számláló + Vader-pipek; `draw_over()` a `cause` sorral |

Hívási sorrend `upd_play()`: `upd_player` → `upd_gems` → `upd_troopers` (spawn, despawn, állapotgép) → Vader-küszöb ellenőrzés + `upd_vader` → `upd_bolts` → `upd_worm` → `upd_parts` → `upd_cam` → `frames += 1`.

## 13. Tesztelés v2

A v1 harness marad, de **több teszt-cartra bontva**: egy cart a játékkal (`#include jedi.p8`) plusz az összes teszttel túllépné a 8192 tokenes cart-limitet („program too large"), ezért a harness a közös `test_lib.lua`-ba került, és a tesztesetek `test_jedi.p8`, `test_jedi_b..e.p8` (v1 esetek) és `test_jedi_v2.p8`, `test_jedi_v2b..e.p8` (v2 esetek) cartokba; a `run_tests.sh` a `test_jedi*.p8` mintára fut végig és összesít (`TOTAL ok=N fail=M`). A `music` és `sfx` függvényeket a harness **stubolja és naplózza** (`music_log`, `sfx_log`), hogy a zene-váltás tesztelhető legyen. Új/módosított kötelező esetek:

1. **Kamera:** a jedi a világ közepén → `cam = (192,192)`; a jedi a (10, 20)-ban → `cam = (0,0)`; a jedi (500, 500)-ban → `cam = (384,384)`; a jedi világhatárra clampel (`x ≤ 508`, `y ≥ 12`).
2. **Világgenerálás:** `#g.rocks ∈ [80, 120]`, egyik sem a kezdő 40×40-ben, páronként ≥ 14 px hézag, 10 px szélsáv; `#g.gems == 5`, egyik sem sziklában, páronként ≥ 40 px.
3. **Spawn a látómezőn kívül:** 20 spawn `spawn_pos()`-szal → mind `not in_view(x,y,0)` és világon belül; a jedi a világ sarkában → spawn még mindig érvényes.
4. **Lemaradt katona:** katona 250 px-re → egy frame után törölve, `kills` változatlan.
5. **Szórás:** 200 visszaverés `srand(1)`-gyel; a pontos találatok aránya 20–40% (`|Δszög| < 0.001`), a többi `|Δszög| − 10/360| < 0.0005`.
6. **Drágakő:** felvétel +100, `gems_got` 1; 5 felvétel után 5 új kő, mind `not in_view(x,y,8)`, `gems_got == 0`.
7. **Vader-küszöb:** `kills = 14` + egy ölés → `g.vader ~= nil`, 3 új katona, `next_vader == 30`, `music_log` utolsó = 4; `kills = 30` Vader életében → nincs második; Vader halála után a következő frame-ben spawn.
8. **Vader mozgás/támadás:** Vader 60 px-re → sebessége < 1.5 (mért elmozdulás/frame ≈ 1.1); 12 px-en belül → windup 15 frame → strike; jedi blokkol felé nézve → `hp` változatlan és `music/sfx_log` tartalmaz `sfx(9)`; jedi nem blokkol → `hp − 1`.
9. **Vader sebzés:** 5 külön suhintás (stagger kivárásával) → `hp` 5→0, `+300`, `music_log` utolsó = 0, 60 frame múlva `g.vader == nil`; két suhintás a stagger alatt → `hp` csak 1-gyel csökken; visszavert lövedék Vadernél → törlődik, `hp` változatlan.
10. **Féreg:** `frames = 30·59`, jedi áll 700 frame-ig → `worm.st == "idle"` (60 mp előtt nem indul a számláló); `frames = 30·60`, áll 600 frame → `tremor`, `t == 90`; +90 frame → `emerge`; +10 frame → `p.dead`, `cause == "worm"`, +40 → `state == "over"`. Menekülés: tremor alatt 30 px-re elmozdulva → emerge után `p.dead == false`, a sink végén `st == "idle"`.
11. **Zene-váltás:** új menet → `music(0)`; game over → `music(-1)` (a naplóból).
12. A v1 tesztek átírva a világ-koordinátákra (clamp 124 → 508; „képernyő" → látómező), mind zöld.

## 14. Hangolható konstansok (új)

| Név | Érték | Jelentés |
|---|---|---|
| `WORLD_W`, `WORLD_H` | 512 | világméret px |
| `N_ROCKS_MIN/MAX` | 96 / 119 | sziklák |
| `N_DECOR_MIN/MAX` | 200 / 259 | dekor |
| `DESPAWN_D` | 200 | katona lemaradási távolság |
| `DEFL_EXACT` | 0.3 | pontos visszaverés aránya |
| `DEFL_DEV` | 10/360 | eltérés fordulatban |
| `GEM_N` | 5 | kövek száma |
| `GEM_PTS` | 100 | pont/kő |
| `VADER_EVERY` | 15 | ölés-küszöb |
| `V_SPD` | 1.1 | Vader sebesség |
| `V_HP` | 5 | Vader életerő |
| `V_REACH` | 12 | Vader támadási táv |
| `V_WINDUP` | 15 | telegráf frame |
| `V_STAGGER` | 30 | tántorgás frame |
| `V_PTS` | 300 | pont |
| `WORM_AFTER` | 60 | mp, ettől figyel |
| `WORM_STILL` | 600 | frame egy helyben (20 mp) |
| `WORM_AREA` | 20 | horgony-sugár px (40×40) |
| `WORM_TREMOR` | 90 | remegés frame |
| `WORM_BITE_R` | 20 | evési sugár px |
| `SABER_COL`, `V_SABER_COL` | 11, 8 | kardszínek |

## 15. Sikerkritériumok

1. `run_tests.sh` ALL GREEN (v1 + v2 esetek), ≤ 8192 token (cél ≤ 6500).
2. Headless képernyőképek: (a) cím zöld felirattal; (b) játék közben görgetve, a jedi nem a képernyő közepén, mert a kamera világhatáron clampel; (c) Vader + 3 kísérő + piros kard + HP-pipek; (d) remegés porral; (e) féreg nyitott szájjal; (f) drágakő a látómezőben és `◆` számláló; (g) game over `EATEN BY A SANDWORM` sorral.
3. Bot-playtest: „álló blokkoló" bot 80–110 mp között a féreg áldozata lesz; „mozgó blokkoló" (20 mp-enként 40 px-t odébb megy) nem; 15 ölés után Vader jön, és a „menekülő" bot (mindig Vadertől el) 30 mp-ig nem kap Vader-csapást.
4. A 30 fps tartható: `stat(1)` < 0,8 játék közben 8 katonával + Vaderrel (a bot-teszt méri, `printh`).

## 16. Edge case-ek

- **Vader küszöbe Vader életében:** `next_vader` már nőtt; új Vader csak a jelenlegi halála után, a következő frame-ben.
- **Vader spawnja sziklába:** `spawn_pos()` elutasítja a sziklás pozíciót (`in_rock(x,y,6)` → újrapróbál, max 20).
- **Gem sziklába/kamera alá:** elhelyezés elutasításos; ha 500 próba után sincs hely, a kő a jeditől 100 px-re, világon belül, sziklán kívüli első találatra kerül.
- **Féreg tremor közben game over (lövés által):** a féreg állapota lefagy a többi entitással együtt.
- **Féreg és Vader egyszerre:** függetlenek; a jedi megevése esetén Vader HP-csíkja eltűnik a game over képernyőn (a HUD a `state == "over"`-ben is rajzolódik? — igen, a v1 szerint a HUD marad, a pipek csak ha `g.vader`).
- **`still` számláló és sérthetetlenség:** a találat utáni visszalökés (nincs v1-ben) nem befolyásolja; a blokkolás egy helyben állva igenis számít mozdulatlanságnak — ez a féreg lényege.
- **Score plafon:** 32000 marad (v1), a 100/300 pontos tételekkel is.
- **Kamera a világ szélén:** a jedi nem középen látszik; a spawn ilyenkor a látómező belső oldalain történik.
