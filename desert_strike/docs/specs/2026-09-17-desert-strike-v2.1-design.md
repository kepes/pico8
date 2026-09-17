# Desert Strike v2.1 — címkép, terep-variánsok, féreg-időzítés, angol doksik

**Dátum:** 2026-09-17 · **Státusz:** jóváhagyott · **Alap:** a v2 spec (`2026-09-17-desert-jedi-v2-design.md`) marad érvényben, ez a doksi felülír/kiegészít. **Cart:** `carts/desert_strike/desert_strike.p8` (PICO-8 0.2.7). A játék neve mostantól **Desert Strike**.

## Tartalomjegyzék

- [1. Változások](#1-változások)
- [2. Címkép](#2-címkép)
- [3. Terep-variánsok](#3-terep-variánsok)
- [4. Homokféreg időzítés](#4-homokféreg-időzítés)
- [5. Nyelv és licenc](#5-nyelv-és-licenc)
- [6. Kontrakt-delta](#6-kontrakt-delta)
- [7. Tesztek](#7-tesztek)
- [8. Sikerkritériumok](#8-sikerkritériumok)

## 1. Változások

| # | Kérés | Megvalósítás |
|---|---|---|
| 1 | Indító képernyő a poszterből | `assets/desert_strike_frontpage_01.jpg` → 128×128, PICO-8 paletta, px9-tömörítve a map felső felében; a címképernyő a képet mutatja, a játék nevét nem írja ki (rajta van) |
| 2 | 3 variáns minden tereptárgyhoz | kis szikla, nagy szikla, kavics, repedés, csont, bokor: 3-3 sprite-változat, generáláskor véletlen választás |
| 3 | Féreg: legkorábban 30 mp, 10 mp mozdulatlanság | `WORM_AFTER = 20` s, `WORM_STILL = 300` frame → első lehetséges kitörés 30 s + 3 s remegés |
| 4 | README-k és kommentek angolul | a cart, a tesztek, a `run_tests.sh` kommentjei és a `README.md` angolul; a spec/plan doksik magyarok maradnak |
| 5 | Licenc | CC BY-NC-SA 4.0 a gyűjteményre (`carts/LICENSE`), a README-kben hivatkozva |
| 6 | Fő README | `carts/README.md` angolul: mi a gyűjtemény, programok, szerző (Peter Kepes), licenc |

## 2. Címkép

- **Forrás:** `assets/desert_strike_frontpage_01.jpg` (1024×1024). Konverzió: LANCZOS kicsinyítés 128×128-ra, majd kvantálás a 16 PICO-8 színre **Floyd–Steinberg ditherrel, 40%-os hibaterjesztéssel** (saját, maszkolható implementáció), és egy második réteg az **arc-régióra** (ellipszis kb. (68,76) középponttal, 16×19 sugárral, 4 px-es lágy széllel): ott kontraszt ×1,5, fényerő ×1,1, unsharp-élesítés és **dither nélkül**, hogy a szem/orr/száj 16 színnel is olvasható maradjon. (2026-09-17-i módosítás: a dither nélküli első változat elvesztette az árnyalatokat.)
- **Tárolás:** px9 formátumban (zep `px9_comp`/`px9_decomp`, BBS #34058, CC BY-NC-SA — kompatibilis), **4388 byte** a `0x1000..0x2123` folytonos tartományban: a sprite-lap üres alsó fele (`__gfx__` 64–127. sor = `__map__` 32–63. sor, ugyanaz a memória) plusz a map felső felének eleje (`__map__` 0–2. sor). A 128–255-ös sprite-ok tehát adatot tartalmaznak, rajzolni tilos őket. (Eredetileg 3213 byte a `0x2000..0x2fff`-ben; a dither miatt nőtt.) Ha a px9 forrás nem szerezhető meg, saját, azonos elven működő tömörítő/kitömörítő pár (bal/felső szomszéd-predikció + futamhossz) is elfogadható, amíg a kitömörített kép **pixelre azonos** és ≤ 4096 byte.
- **Betöltés:** `_init` végén `load_title()`: kitömörítés a képernyőre (`px9_decomp(0,0,0x1000,pget,pset)`), majd `memcpy(0x8000,0x6000,0x2000)` (a 0x8000–0x9fff bővített memória a cache). `draw_title()`: `memcpy(0x6000,0x8000,0x2000)`, majd overlay: sötét sáv `rectfill(0,114,127,127,0)`, villogó `press 🅾️ to start` (y=116, szín 7), `best n` (y=122, szín 9). **Nincs „DESERT STRIKE" felirat** kódból, nincs világ-rajz a cím alatt.
- **Label:** ugyanez a kép a `__label__` szekcióban (128 sor × 128 hex), hogy a splore is ezt mutassa.
- A `sfx(6)` indításkor marad; a `music(0)` a címképernyőn marad.

## 3. Terep-variánsok

Sprite-slotok (a sprite-lap felső felének szabad helyei; a v1/v2 sprite-ok nem változnak):

| Tereptárgy | v1 (meglévő) | v2 | v3 |
|---|---|---|---|
| kis szikla (8×8) | 32 | 8 | 9 |
| nagy szikla (16×16, bal-felső index; +1 jobbra, +16 alatta) | 33 | 12 | 14 |
| kavicsok | 35 | 10 | 11 |
| repedés | 36 | 20 | 21 |
| csont | 37 | 22 | 23 |
| száraz bokor | 38 | 46 | 47 |

- Kód: `rock_small_s={32,8,9}`, `rock_big_s={33,12,14}`, `decor_s={{35,10,11},{36,20,21},{37,22,23},{38,46,47}}`. `gen_rocks()` minden sziklához variánst sorsol és a rock táblába `s` (sprite-index) mezőt tesz; `gen_decor()` a típus után variánst is sorsol. A hitboxok változatlanok (a variánsok ugyanazt a 7×5 / 14×11-es testet töltik ki, csak a forma/árnyalat más).
- Rajzolás: `spr(r.s, …)` ill. `spr(r.s, x, y, 2, 2)`.

## 4. Homokféreg időzítés

`WORM_AFTER = 20` (mp), `WORM_STILL = 300` (frame, 10 mp). Minden más (horgony 20 px, remegés 90, evés 20 px, menekülés) változatlan. Legkorábbi remegés: 30,0 s; legkorábbi harapás: 33,3 s.

## 5. Nyelv és licenc

- **Angol:** `carts/README.md`, `desert_strike/README.md`, minden kód-komment a cartban, a tesztcartokban, a `test_lib.lua`-ban és a `run_tests.sh`-ban. Játékszövegek angolok maradnak.
- **Magyar marad:** `carts/CLAUDE.md`, `docs/specs`, `docs/plans`.
- **Licenc:** CC BY-NC-SA 4.0; a `carts/LICENSE` a hivatalos legal code (creativecommons.org), a README-k fejlécében rövid hivatkozás + szerző: Peter Kepes.

## 6. Kontrakt-delta

| Elem | Név |
|---|---|
| konstansok | `worm_after=20`, `worm_still=300`, `rock_small_s`, `rock_big_s`, `decor_s` |
| rock mező | `s` (sprite index, kis szikla: 8×8 index; nagy: bal-felső) |
| decor mező | `s` (már létezik; most a variáns-táblából) |
| címkép | `load_title()`, `draw_title()`; px9 dekóder függvények (`px9_decomp` + segédei) egy külön `title` tabban |
| map | `__map__` 0–31. sor = px9 adat; a map-API (`mget/map`) nem használt |
| label | `__label__` szekció = a címkép |

## 7. Tesztek

1. **Variánsok:** 3 különböző seeddel generálva a sziklák `s` mezője csak a megengedett indexekből kerül ki, és mindhárom kis-szikla- és mindhárom nagy-szikla-variáns előfordul legalább egyszer 100 szikla között; dekor ugyanígy.
2. **Féreg:** `frames=30·19` + 320 frame állás → nincs tremor; `frames=30·20` + 300 frame → `tremor`; a v2 „60 mp" tesztek átírva.
3. **Címkép:** `load_title()` után `peek(0x8000+k)` nem csupa nulla (legalább 8 különböző byte-érték az első 1024 byte-ban); `draw_title()` nem dob hibát; a képernyő (0x6000) első sora egyezik a 0x8000-es cache első sorával a `draw_title()` után.
4. **px9 kerek-út (fejlesztési bizonyíték, nem a suite része):** a T-agent proof-cartja kitömörít és pixelenként hasonlít a várt képhez → `PASS`.
5. **Nyelv:** `grep -nP '[áéíóöőúüű]' desert_strike.p8 tests/*` üres (nincs magyar komment).

## 8. Sikerkritériumok

1. `run_tests.sh` ALL GREEN, ≤ 8192 token (cél ≤ 6500), tömörített ≤ 15360.
2. Címképernyő headless képernyőképe: a poszter felismerhető (cím, alak, féreg), alul a start-sor és a rekord olvasható.
3. Játék közbeni képernyőképen legalább 2 különböző kis-szikla- és nagy-szikla-forma látszik.
4. Bot: álló játékos `cause=="worm"` 33–40 s között.
5. `carts/README.md`, `LICENSE`, angol `desert_strike/README.md` léteznek; nincs magyar komment a kódban.
6. Memória-jelentés a következő pályához: szabad sprite-slotok, token, tömörített byte, szabad map/sfx.
