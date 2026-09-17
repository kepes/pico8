# Desert Jedi v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. *(Ebben a sessionben a végrehajtás a Workflow tool-lal történik a lenti Sub Agent csoportok szerint.)*

**Goal:** A v1 cartot görgetett 512×512-es világgá bővíteni Darth Vader főellenséggel, homokféreggel, drágakövekkel, új zenével, módosított visszaverés-szórással és új kardszínekkel — tesztelve, a PICO-8 limiteken belül.

**Architecture:** A meglévő `jedi.p8` kódja marad a váz (tab-ok, `g` tábla, kontrakt-nevek); a világkoordináták + kamera bevezetése átvág mindenen, ezért az első kód-agent ezt csinálja, a további kettő ráépít (Vader, féreg). A sprite- és hang-agent a `src/` fájlokba dolgozik párhuzamosan, az összefűzés a v1 recept szerint.

**Tech Stack:** PICO-8 0.2.x, shrinko8 (`uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8`), Python 3 + Pillow (`uv run --with pillow`).

**Spec:** `docs/superpowers/specs/2026-09-17-desert-jedi-v2-design.md` (+ a v1 spec és v1 plan a kontraktért, harnessért és a .p8 formátumért: `2026-09-16-desert-jedi-design.md`, `2026-09-16-desert-jedi-plan.md`).

## Tartalomjegyzék

- [Global Constraints](#global-constraints)
- [Fájlstruktúra](#fájlstruktúra)
- [Megvalósítási sorrend táblázat](#megvalósítási-sorrend-táblázat)
- [Task 1: Világ + kamera + drágakövek + szórás + kardszín (A1)](#task-1-világ--kamera--drágakövek--szórás--kardszín-a1)
- [Task 2: Darth Vader + zene-váltás (A2)](#task-2-darth-vader--zene-váltás-a2)
- [Task 3: Homokféreg (A3)](#task-3-homokféreg-a3)
- [Task 4: Sprite-kiegészítés (B)](#task-4-sprite-kiegészítés-b)
- [Task 5: SFX + zene v2 (C)](#task-5-sfx--zene-v2-c)
- [Task 6: Összefűzés (D)](#task-6-összefűzés-d)
- [Task 7: Verifikáció (E1–E5)](#task-7-verifikáció-e1e5)
- [Task 8: Javítás (F)](#task-8-javítás-f)
- [Task 9: README frissítés (G)](#task-9-readme-frissítés-g)
- [Dispatch promptok](#dispatch-promptok)
- [Verification gate-ek](#verification-gate-ek)

## Global Constraints

- ≤ 8192 token (cél ≤ 6500), ≤ 15360 byte tömörített; 30 fps `_update`; input csak `btn/btnp`.
- A v1 kontrakt nevei megmaradnak (`g`, `new_game`, `upd_play`, `move_solid`, `in_rock`, `solid`, `in_cone`, `hurt_player`, `is_blocking`, `spawn_trooper`, `kill_trooper`, `fire`, `deflect`, `upd_bolts`, `spawn_parts`, `draw_hud`, `draw_title`, `draw_over`); a v2 spec 12. új nevei pontosan úgy.
- Sprite-indexek és sfx/music slotok a v2 spec 9. és 11. szerint. A v1 sprite-ok (1–7, 16–19, 32–38, 49–50) pixelre változatlanok.
- A tesztek a `music`/`sfx` függvényeket stubolják és naplózzák (`music_log`, `sfx_log` táblák).
- `archive/` tartalma (v1 cart + teszt) érintetlen marad.
- Nincs Claude-attribúció; nincs git.

## Fájlstruktúra

| Fájl | Változás | Ki |
|---|---|---|
| `jedi.p8` `__lua__` | világ/kamera/gem/szórás/kardszín → Vader/zene → féreg | A1 → A2 → A3, később F |
| `test_lib.lua` + `test_jedi.p8`, `test_jedi_b..e.p8`, `test_jedi_v2.p8`, `test_jedi_v2b..e.p8` | közös harness + v1 tesztek világkoordinátákra + v2 esetek, cartonként ≤ ~900 token teszt-kód (a játék + tesztek együtt nem férnek egy cartba) | A1, A2, A3, F |
| `run_tests.sh` | változatlan (max. a tokenszám-kiírás) | – |
| `src/gfx.txt` | a jelenlegi `__gfx__` 128 sora + új sprite-ok | B |
| `src/sfx.txt`, `src/music.txt` | teljes csere: sfx 0–7 v1, 8–15 új, 16–39 zene | C |
| `README.md` | v2 szekciók | G |
| `docs/superpowers/…` | v2 spec/plan (kész) | – |

## Megvalósítási sorrend táblázat

| Lépés | Érintett projekt | Feladat | Sub Agent |
|---|---|---|---|
| 1 | `carts/jedi` | Task 1: világ, kamera, kövek, szórás, kardszín + tesztek zölden | **A1** (Build-csoport, párhuzamos B-vel és C-vel) |
| 2 | `carts/jedi` | Task 2: Vader + kísérők + zene-váltás + HP-pipek + tesztek | **A2** (A1 után, szekvenciális) |
| 3 | `carts/jedi` | Task 3: homokféreg + game over ok + tesztek | **A3** (A2 után) |
| 4 | `carts/jedi` | Task 4: `src/gfx.txt` (v1 sorok + Vader, gem, féreg) + preview | **B** (Build-csoport) |
| 5 | `carts/jedi` | Task 5: `src/sfx.txt` + `src/music.txt` (új SFX, 2 saját téma) + headless lejátszás | **C** (Build-csoport) |
| 6 | `carts/jedi` | Task 6: összefűzés, `src/` törlése, tesztek zölden | **D** (1–5 után) |
| 7a–e | `carts/jedi` | Task 7: E1 tesztek · E2 képernyőképek · E3 spec-megfelelés · E4 teszt-minőség · E5 bot-playtest (féreg, Vader, fps) | **E1–E5** (párhuzamos) |
| 8 | `carts/jedi` | Task 8: high+medium javítása, tesztek zölden | **F** (majd vissza 7-re, max 3 kör) |
| 9 | `carts/jedi` | Task 9: README v2 | **G** |
| 10 | `carts/jedi` | Záró kapu: tesztek, fájllista (`archive/` megengedett) | **E1** |

---

## Task 1: Világ + kamera + drágakövek + szórás + kardszín (A1)

**Files:** Modify `jedi.p8` (`__lua__`), `test_jedi.p8`.

**Interfaces:** Produces `world_w/world_h`, `g.cam_x/cam_y`, `upd_cam()`, `in_view(x,y,m)`, `spawn_pos()`, `spawn_trooper_at(x,y)`, `gen_gems(n,outside)`, `upd_gems()`, `g.kills` (számláló – A2 használja), `g.gems`, `g.gems_got`, `draw_saber(x,y,fx,fy,col,mode)`-szerű újrafelhasználható kard-rajz (A2 Vader kardjához), `sfx_log`/`music_log` stub a harnessben.

- [ ] **Step 1 (harness):** a `test_jedi.p8`-ban a `#include` után: `music_log,sfx_log={},{}` és `function music(n) add(music_log,n) end function sfx(n) add(sfx_log,n) end` (a játék hívásai így naplózódnak). `fresh()` marad, de a jedi a világ közepén indul.
- [ ] **Step 2 (piros tesztek):** v2 spec 13. 1–6. és 11–12. esetei `tcase` blokkokban; a v1 esetek átírása: clamp `508`, „képernyő" → `in_view`; a 12. v1-teszt (sziklák) a v2 számokkal (80–120 db, 40×40 a (256,256) körül, 10 px szélsáv).
- [ ] **Step 3 (kód):** `world_w=512 world_h=512`; `g.cam_x,cam_y`; `upd_cam()`; `_draw`-ban `camera(g.cam_x+sx, g.cam_y+sy)` a világ rajzolásához, `camera()` a HUD előtt; culling `in_view(x,y,16)` dekorra, sziklára, hullára, gemre; `solid/in_rock` elején olcsó távolság-szűrő; `gen_rocks/gen_decor` v2 darabszámokkal; `spawn_pos()`; `spawn_trooper` → `spawn_pos`; `spawn_trooper_at`; `despawn_far` az `upd_troopers`-ben; katona `vis` = `in_view(tr.x,tr.y,0)`; lövedék-törlés `not in_view(b.x,b.y,16) or világon kívül`; `gen_gems`, `upd_gems`, gem rajz (44/45), HUD `◆ n/5`; `deflect` 30/70 szórás (`DEFL_EXACT`, `DEFL_DEV`); kardszín 11 + szikrák 11/7; cím felirat 11; `g.kills` növelése `kill_trooper`-ben.
- [ ] **Step 4:** `bash run_tests.sh` → ALL GREEN; tokenszám a riportba.

## Task 2: Darth Vader + zene-váltás (A2)

**Files:** Modify `jedi.p8`, `test_jedi.p8`.

**Interfaces:** Consumes A1 neveit. Produces `g.vader`, `g.next_vader`, `spawn_vader()`, `upd_vader()`, `hit_vader()`, `draw_vader()`, HUD-pipek, `music(4)`/`music(0)` váltás.

- [ ] **Step 1 (piros tesztek):** v2 spec 13. 7–9. esetei. Vader kézzel: `g.vader={x=…,y=…,hp=5,st="walk",t=0,flip=false,anim=0,stuck=0,side_t=0,side_dir=1,cd=0}`. A suhintás-teszthez a stagger kivárása `step(31)`.
- [ ] **Step 2 (kód):** új `vader` tab a `troopers` és `bolts` között (`-->8`); a v2 spec 7. állapotgépe; `hit_vader` hívása az `upd_bolts`/suhintás-találat ágban (ahol a katonákat vizsgálja a suhintás, Vadert is); visszavert lövedék vs Vader az `upd_bolts`-ban; Vader küszöb-ellenőrzés az `upd_play`-ben; rajz 8×16 `palt(0,false) palt(3,true)`; piros kard a közös kard-rajzolóval; HP-pipek a `draw_hud`-ban; `music(4)` spawnkor, `music(0)` dying kezdetén.
- [ ] **Step 3:** `bash run_tests.sh` → ALL GREEN.

## Task 3: Homokféreg (A3)

**Files:** Modify `jedi.p8`, `test_jedi.p8`.

**Interfaces:** Produces `g.worm`, `upd_worm()`, `draw_worm()`, `g.cause`, `p.eaten`, game over sor.

- [ ] **Step 1 (piros tesztek):** v2 spec 13. 10. esete (nem indul 60 mp előtt; tremor 90; emerge; evés → over; menekülés). A `frames` beállítása: `g.frames=30*60`.
- [ ] **Step 2 (kód):** új `worm` tab a `bolts` után; állapotgép a v2 spec 8. szerint; `upd_worm` az `upd_bolts` után; `draw_worm` az entitások után, a részecskék előtt (`spr(64,ex-16,ey-24,4,4)` A / `spr(68,…)` B; sink: `clip` a `ey+8` vonalig a kamera figyelembevételével); `draw_over` `EATEN BY A SANDWORM` sor; a jedi nem rajzolódik, ha `p.eaten`.
- [ ] **Step 3:** `bash run_tests.sh` → ALL GREEN; tokenszám ≤ 6500 ellenőrzése.

## Task 4: Sprite-kiegészítés (B)

**Files:** Create `src/gfx.txt` (128 × 128 hex). Scratchpad: `gfx_preview.py`.

- [ ] **Step 1:** a jelenlegi `__gfx__` szekció kiemelése: `awk '/^__gfx__/{f=1;next}/^__sfx__/{f=0}f' jedi.p8 > src/gfx.txt` — ez a kiindulás; a v1 sorok **pixelre** változatlanok maradnak.
- [ ] **Step 2:** új sprite-ok a v2 spec 11. szerint: Vader 24–27 (felső) + 40–43 (alsó), 8×16, **háttér 3-as szín** (nem 0!), fekete test; gem 44/45; féreg A/B 32×32 a 4–7. sprite-sorokban (64–67/80–83/96–99/112–115 és 68–71/84–87/100–103/116–119).
- [ ] **Step 3:** preview PNG (v1 recept: 8× nagyítás, 0 = homok, rács; **Vadernél a 3-as színt is homokként** rajzold, hogy a fekete test látszódjon), Read-del megnézve, ≥ 2 iteráció; ellenőrzés: 128 sor × 128 hex, és `diff <(awk '/^__gfx__/{f=1;next}/^__sfx__/{f=0}f' jedi.p8 | head -32) <(head -32 src/gfx.txt)` **üres** (a v1 sorok 0–31 érintetlenek) — kivéve a 24–27/40–43-as sprite-ok oszlopai (192–223 px) a 8–23. sorokban és a 44–45 (352–367 px) a 16–23. sorokban: csak ezeken a téglalapokon változhat valami.

## Task 5: SFX + zene v2 (C)

**Files:** Create `src/sfx.txt` (64 × 168), `src/music.txt` (64 sor). Scratchpad: `check_audio.py`, `play.p8`.

- [ ] **Step 1:** a jelenlegi `__sfx__` 0–7 sorainak kiemelése és megtartása (`awk '/^__sfx__/{f=1;next}/^__music__/{f=0}f' jedi.p8 | head -8`).
- [ ] **Step 2:** új SFX 8–15 a v2 spec 9. szerint.
- [ ] **Step 3:** **Főtéma** 16–27 (minta 0–3, 3 csatorna: dallam / ellenszólam / basszus+ütős) és **Vader-induló** 28–39 (minta 4–7) — mindkettő **saját** dallam a spec 9. stílusleírásával; a `__music__` 8 sora pontosan a spec szerint (`01 10111244` … `02 25262744`), a többi `00 41424344`. A 8–11 v1 zene-slotok tartalma felülírható (nem használt többé).
- [ ] **Step 4:** `check_audio.py` + `play.p8` (`music(0)` 60 frame, `music(4)` 60 frame, `sfx(8..15)`), headless `AUDIO OK`. Az összefoglalóban mindkét téma dallama hangnevekkel, és egy mondat arról, hogy miben tér el az eredeti Williams-témáktól (nem idézi).

## Task 6: Összefűzés (D)

Mint v1 Task 4: `__lua__` kód megtartása + `src/gfx.txt` + `src/sfx.txt` + `src/music.txt` → `jedi.p8`; számok ellenőrzése (128/64/64); `bash run_tests.sh` ALL GREEN; 10 mp headless futás; `rm -r src/`.

## Task 7: Verifikáció (E1–E5)

Mint v1 Task 5, v2 tartalommal. Findings-formátum azonos (high/medium/low + evidence + suggested_fix). **Segéd-cart szabály:** a `jedi.p8` másolata a scratchpadbe, `#include jedi.p8`, **és** a `__gfx__`-től a fájl végéig terjedő szekciók a segéd-cart végére másolva (`sed -n '/^__gfx__$/,$p' jedi.p8 >> helper.p8`), különben üres a sprite-lap.

- **E1:** `run_tests.sh`; token > 7000 medium; `archive/` létezik és érintetlen (md5 azonos a `archive/jedi-v1.p8`-ra a futás előtt/után — az archívumot senki nem írhatja).
- **E2:** képernyőképek a v2 spec 15.2 (a)–(g) listája szerint: cím; görgetés (jedi a világ sarkában, `cam` clampel); Vader + 3 kísérő + piros kard + HP-pipek (Vader kézzel: `spawn_vader()` után `g.vader.x,y` a jedi mellé 20 px-re); windup póz; remegés (`g.worm.st="tremor"`); féreg B-frame; gem a látómezőben + `◆` számláló; game over `EATEN BY A SANDWORM`. Értékelés: Vader fekete, sisak/fény felismerhető, nem lyukas (a 3-as háttér átlátszó, a 0 nem); féreg gyűrűs, fogak; gem csillog; kardszínek zöld/piros.
- **E3:** a v2 spec 3–8. és 16. minden számszerű szabálya a kód ellen (kamera clamp, 512, spawn kívül/belül, 200 px despawn, 30/70 és pontosan 10°, gem 100 / respawn kívül / ≥ 40 px, kills küszöb 15·n, egy Vader, V_SPD 1.1, reach 12, windup 15, strike ablak [3,7], parry feltétel, stagger 30 + sérthetetlen, 5 hp, 300 pont, `music(4)/(0)`, lövedék nem sebzi, féreg 60 mp + 600 frame + 90 + evés a 10. frame-ben 20 px, menekülés, sink, `cause`), plus a v1 szabályok regressziója (blokk 9 px, szórás ±0,04, dead 90, max_alive).
- **E4:** a v2 spec 13. 1–12. esetei léteznek és valódi állítások; v1 tesztek átírva, nem törölve (25 → ≥ 36 eset); harness `music/sfx` naplózás; lint; token; halott kód (pl. v1 `spawn` régi ágai).
- **E5:** bot.p8 (segéd-cart szabály): (1) **álló blokkoló** — várt: 80–110 mp között `cause=="worm"`; (2) **mozgó blokkoló** — 20 mp-enként (600 frame) 40 px-t odébb megy, majd blokkol — várt: nincs féreg 3 percen belül (halál más okból lehet); (3) **vadász** — a legközelebbi katona felé, 12 px-en belül 🅾️, egyébként ❎ — várt: `g.kills` eléri a 15-öt < 120 mp és Vader spawnol, a napló tartalmaz `music 4`-et; (4) **menekülő** — Vader spawn után mindig Vadertől el (a világhatárt is figyelembe véve: ha sarokba szorul, oldalra) — várt: 30 mp-ig nincs `hp` csökkenés Vader-csapástól (a lövéseket blokkolja ❎-szel; ha lövés talál, az nem számít). (5) **teljesítmény:** 8 katona + Vader + 60 részecske mellett `stat(1)` átlag < 0,8 (printh). Minden futás runtime error nélkül.

## Task 8: Javítás (F)

Mint v1 Task 6: high + medium javítása tesztekkel, `ALL GREEN`, token ≤ 8192; a spec-től való szándékos eltérést (hangolás) indokolni, hogy a docs szinkronizálható legyen.

## Task 9: README frissítés (G)

`README.md` v2: új játékelemek (görgetett világ, Vader szabályai, féreg-figyelmeztetés, drágakövek, pontok 10/20/100/300, zene), irányítás változatlan, tesztelés szekció (tesztszám, `music/sfx` stub), fájlok (`archive/`), a v2 spec/plan linkje. TOC frissítése.

## Dispatch promptok

Közös fejléc mint v1 (útvonalak, headless-recept, alarm-wrapper, `#include` relatív, scratchpad, shrinko8), plusz: „Read the v2 spec fully, then the v1 spec §4–§8 and the v1 plan's 'Kanonikus kontrakt' + '.p8 fájlformátum jegyzet'. Read jedi.p8 and test_jedi.p8 before editing." Minden prompt végén ≤ 120 szavas összefoglaló kérés.

- **A1:** „Execute Task 1 (A1). Start with the harness change and the red tests, then implement. Keep every existing test (rewritten to world coordinates), finish ALL GREEN, report tokens."
- **A2:** „Execute Task 2 (A2) on top of A1's code (read the current jedi.p8 first). Red tests first. ALL GREEN."
- **A3:** „Execute Task 3 (A3). Red tests first. ALL GREEN, tokens ≤ 6500 (if above, shorten without changing behaviour and report)."
- **B / C / D / E1–E5 / F / G:** a Task-szekciók szerint.

## Verification gate-ek

1. **Build → Assemble:** A3 ALL GREEN; B `src/gfx.txt` validált + v1 sorok érintetlenek; C `AUDIO OK`.
2. **Assemble → Verify:** `run_tests.sh` ALL GREEN a teljes carton; `src/` törölve.
3. **Verify → Fix:** high/medium → Fix → Verify (max 3 kör).
4. **Kész:** ALL GREEN; a mappában `jedi.p8`, `test_lib.lua`, `test_jedi*.p8` (10 cart), `run_tests.sh`, `README.md`, `docs/`, `archive/` (2 fájl) — más semmi.
