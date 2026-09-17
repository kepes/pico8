# Desert Strike v2.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. *(Ebben a sessionben a végrehajtás párhuzamos subagentekkel történik.)*

**Goal:** Címkép a poszterből, 3 terep-variáns, gyorsabb féreg, angol README-k/kommentek, licenc, fő README — tesztelve.

**Architecture:** A cart `__lua__` szekcióján egy kód-agent dolgozik (A1), a sprite-variánsok (B) és a címkép-tömörítés (T) párhuzamosan a `src/`-ba; a manual-átnézés (M) a skillt, a doksi-agent (R) a README-ket/LICENSE-t írja; az integráló agent (D) fűzi össze a cartot és teszi be a címkép-kódot; utána verifikáció és javítás.

**Spec:** `docs/specs/2026-09-17-desert-strike-v2.1-design.md` (+ v2 spec, v1 plan kontrakt és .p8 formátum; a `pico8-programming` skill kötelező olvasmány).

## Global Constraints

- PICO-8 0.2.7; limitek: 8192 token / 15360 byte tömörített; `#include` csak relatív; headless futtatás időkorláttal (skill).
- A v1/v2 sprite-ok pixelre változatlanok; új sprite csak a spec 3. slotjaiba.
- `archive/` érintetlen; `assets/` csak olvasható (forrásképek).
- Nincs Claude-attribúció; commit nincs (a fő session commitol).

## Megvalósítási sorrend táblázat

| Lépés | Érintett projekt | Feladat | Sub Agent |
|---|---|---|---|
| 1 | `desert_strike` | Task 1: variánsok a kódban, féreg-konstansok, angol kommentek, tesztek | **A1** (Build, párhuzamos) |
| 2 | `desert_strike` | Task 2: 18 variáns-sprite `src/gfx.txt`-be + preview | **B** (Build) |
| 3 | `desert_strike` | Task 3: címkép konverzió + px9 tömörítés → `src/map.txt`, `src/label.txt`, `src/title.lua` + proof-cart | **T** (Build) |
| 4 | `carts/.claude/skills` | Task 4: manual átnézése → `api-notes.md` + verzió a skillben | **M** (Build) |
| 5 | `carts` | Task 5: `carts/README.md`, `carts/LICENSE`, angol `desert_strike/README.md` | **R** (Build) |
| 6 | `desert_strike` | Task 6: összefűzés (gfx, map, label) + címkép-kód integrálása + tesztek zölden, `src/` törlés | **D** (1–3 után) |
| 7a–d | `desert_strike` | Task 7: E1 tesztek · E2 képernyőképek · E3 spec-megfelelés + nyelv-ellenőrzés · E5 féreg-bot | **E1–E5** (párhuzamos) |
| 8 | `desert_strike` | Task 8: javítás | **F** (max 2 kör) |
| 9 | `desert_strike` | Task 9: README-számok frissítése (tesztszám, token) | **G** |
| 10 | `carts` | Memória-jelentés + skill retrieval-teszt + commit | fő session |

## Task 1 (A1) — kód

- Konstansok/táblák a spec 6. szerint; `gen_rocks`/`gen_decor` variáns-sorsolás; `draw_world` `r.s`-t rajzol; `worm_after=20`, `worm_still=300`.
- Minden magyar komment angolra a cartban, `tests/*.p8`, `test_lib.lua`, `run_tests.sh` (a viselkedés nem változik).
- Tesztek: spec 7.1, 7.2 (a v2e cart 60 mp-es esetei átírva 20 mp-re), 7.5 grep; a variáns- és féreg-tesztek egy új `test_ds_v3.p8` cartba; a címkép-tesztet (7.3) D adja hozzá.
- `bash tests/run_tests.sh` ALL GREEN.

## Task 2 (B) — sprite-variánsok

- `src/gfx.txt` = a jelenlegi `__gfx__` + a spec 3. táblázat 18 új sprite-ja (8, 9, 12–15, 28–31, 10, 11, 20–23, 46, 47). Ugyanaz a színvilág (szikla 4/9/2, kavics 9/4, repedés 9, csont 7/6, bokor 4/9), más forma. Preview (skill `gfx_preview.py`), ≥ 2 iteráció; ellenőrzés: minden egyéb pixel változatlan.

## Task 3 (T) — címkép

1. Konverzió a spec 2. szerint → `src/title.png` (128×128 előnézet 3×) és a 128 soros hex (`src/label.txt`).
2. px9 forrás: `https://www.lexaloffle.com/bbs/?tid=34058` (zep). Ha nem elérhető: saját tömörítő (Python) + kitömörítő (Lua) azonos elven. A kitömörítő Lua kódja → `src/title.lua` (`px9_decomp` + segédek + `load_title()` + `draw_title()` a spec 2. szerint), ≤ 400 token.
3. Tömörítés: a képet egy temp cart `__gfx__`-ébe írva PICO-8 headless futtatja a `px9_comp`-ot (`printh`-val hex kimenet), vagy Python-implementáció — a lényeg a kerek-út: proof-cart (`__map__` = adat, `__lua__` = dekóder), kitömörít a képernyőre, `pget`-tel összeveti a `label.txt`-vel → `printh("PASS")`, plusz screenshot (`-desktop`), amit a T megnéz.
4. Kimenet: `src/map.txt` (32 sor × 256 hex; a maradék 32 sor csupa 0), méret jelentése byte-ban.

## Task 4 (M) — manual → skill

- Olvasd végig `/Users/kepes/Downloads/pico-8/pico-8_manual.txt` (v0.2.7). Írj `carts/.claude/skills/pico8-programming/api-notes.md`-t: tömör, táblázatos, **csak** a cart-fejlesztésnél hasznos, kevésbé ismert dolgok (extcmd változatok, parancssori kapcsolók, stat() kódok, memóriatérkép 0x8000-ig, poke-olható rajz-állapot, P8SCII vezérlőkódok printben, printh fájlba, tline/fillp/pal-tábla/palt, sspr/map, menuitem, cstore/reload, split/tostr/tonum flagek, btnp ismétlés, `\` egészosztás, `%`, 16.16 határok, cocreate/yield, serial, _update60, mouse/keyboard stat, `-p` paraméter, `#include` szabályai). Minden tétel 1–2 sor + mikor hasznos. Ne ismételd a SKILL.md-ben már meglévőt.
- SKILL.md: az Overview első sorába „Applies to PICO-8 0.2.7 (cart format version 30)"; a Quick reference kap egy sort az `api-notes.md`-re.

## Task 5 (R) — README-k, licenc

- `carts/LICENSE`: CC BY-NC-SA 4.0 legal code (`https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.txt`) változtatás nélkül.
- `carts/README.md` (angol): mi ez a gyűjtemény (PICO-8 carts, Peter Kepes), programok táblázata (Desert Strike: 1 mondat + link), hogyan futtatható (PICO-8, `load desert_strike/desert_strike.p8`), fejlesztés (tesztek, skill), licenc + szerző, a `demos/` nincs verziózva.
- `desert_strike/README.md` (angol újraírás a jelenlegi magyar alapján): Desert Strike név, a spec 1–4 változásaival (címkép a poszterből, variánsok, féreg 30 s), licenc-sor. A tesztszámot/tokent a G frissíti.

## Task 6 (D) — integrálás

- `desert_strike.p8`: `__lua__` (A1 állapot) + `src/title.lua` új `title` tabként (a régi `draw_title` törlése), `_init` végén `load_title()`; `__gfx__` ← `src/gfx.txt`; `__label__` ← `src/label.txt`; `__map__` ← `src/map.txt`; `__sfx__`/`__music__` változatlan. Szekció-sorrend: `__lua__`, `__gfx__`, `__label__`, `__gff__`(ha volt), `__map__`, `__sfx__`, `__music__`.
- Címkép-teszt (spec 7.3) a `test_ds_v3.p8`-ba. `bash tests/run_tests.sh` ALL GREEN; headless screenshot a címről; `rm -r src/`.

## Task 7 (E1–E5) — verifikáció

- E1: tesztek + token; E2: cím (kép + overlay, nincs kódból írt cím), játék közben variánsok, féreg-jelenet; E3: spec 2–5 szabályai a kód ellen + `grep` magyar ékezetekre a kódban/kommentekben + README-k angolok; E5: álló bot → `cause=="worm"` 33–40 s között, mozgó bot nem; `stat(1)` a címképernyőn < 0,5.

## Task 8 (F), Task 9 (G)

Mint a v2 tervben: F javít (max 2 kör), G a README-számokat frissíti (angolul).
