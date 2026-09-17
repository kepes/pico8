# PICO-8 carts — projekt-szabályok

Ez a mappa a PICO-8 cart-könyvtár (`~/Library/Application Support/pico-8/carts`), git repóként kezelve. A gyári `demos/` mappa `.gitignore`-ban van.

## Mappaszerkezet

```
carts/
  CLAUDE.md                     ez a fájl
  .claude/skills/pico8-programming/   PICO-8 fejlesztői tudás (headless futtatás, formátum, teszt-harness, buktatók)
  <játék>/
    <játék>.p8                  a cart — önálló (kód + gfx + sfx + music), nincs benne #include
    tests/                      test_lib.lua, test_*.p8 (#include ../<játék>.p8), run_tests.sh
    assets/                     külső assetek: referenciaképek, hang-/zeneforrások, generátor-scriptek — a cart nem tölti be
    docs/superpowers/specs/     design spec-ek (YYYY-MM-DD-<téma>-design.md)
    docs/superpowers/plans/     implementációs tervek
    archive/                    (opcionális) git előtti régi verziók; új verziót git-tel verziózunk, nem ide
  demos/                        gyári demók, nem verziózott
```

Jelenlegi játék: `jedi/` (Desert Jedi, v2). Új játék = új almappa ugyanezzel a szerkezettel.

## Fejlesztés

- **Cart-munka előtt töltsd be a `pico8-programming` skillt** (`.claude/skills/pico8-programming/SKILL.md`): headless futtatás időkorláttal, `#include` korlátok, 8192 tokenes limit, sprite-átlátszóság, teszt-harness. Ne fedezd fel újra.
- PICO-8 bináris: `/Applications/PICO-8.app/Contents/MacOS/pico8`. **Soha ne nyiss PICO-8 ablakot** automatizált munkában; `pico8 -x` headless módban fut.
- Bemenet a cartban kizárólag `btn()`/`btnp()` (a tesztek stubolják). Játékszövegek angolul, dokumentáció magyarul, a skill angolul.
- Sprite-részletekhez ne használd a pálya háttérszínét, és ne javíts `pal()`-lal futásidőben — a sprite-ba fesd a jó színt.

## Tesztelés és commit

- Tesztek: `bash <játék>/tests/run_tests.sh` (headless tesztek + shrinko8 token-limit + lint; 0 = zöld).
- Ha `.p8`/`.lua` változott → commit előtt a játék teszt-suite-ja fusson és legyen zöld. Csak doksi/asset változásnál nincs teszt.
- **Ebben a repóban a `main`-re közvetlen commit rendben van** (egyszemélyes hobbi-projekt; felülírja a globális „ne commitolj main-re" defaultot). Push továbbra is csak a felhasználó kezéből.
- Nincs CI: a PICO-8 bináris licencelt, nyilvános CI-ban nem futtatható; a lokális `run_tests.sh` az egyetlen védőháló.
- Commit message: tömör, a változásról; Claude-attribúció nélkül.
