# Desert Jedi

Görgetett, 512×512 pixeles sivatagi világban játszódó PICO-8 arcade túlélőjáték. Egy jedi lovagot irányítasz — fénykarddal suhintasz és blokkolsz, a kivédett lövés visszapattan és öl. Idővel drágakövek várnak begyűjtésre, minden 15. ölés után pedig felbukkan Darth Vader (3 kísérővel), és 1 percnél tovább egy helyben állva egy homokféreg is figyelmeztetés nélkül lecsaphat.

## Tartalomjegyzék

- [Irányítás](#irányítás)
- [Futtatás](#futtatás)
- [Görgetett világ és drágakövek](#görgetett-világ-és-drágakövek)
- [Játékmenet](#játékmenet)
- [Darth Vader](#darth-vader)
- [Homokféreg](#homokféreg)
- [Kardszínek és pontok](#kardszínek-és-pontok)
- [Zene és hang](#zene-és-hang)
- [Tesztelés](#tesztelés)
- [Fájlok](#fájlok)
- [Kapcsolódó dokumentumok](#kapcsolódó-dokumentumok)

## Irányítás

Változatlan a v1-hez képest.

| Gomb | Hatás |
|---|---|
| ⬅️➡️⬆️⬇️ (nyilak) | mozgás 8 irányban; a jedi a legutóbb lenyomott nyíl irányába fordul (4 nézési irány: fel/le/bal/jobb) |
| 🅾️ (Z) | kardsuhintás |
| ❎ (X) | blokk, amíg nyomva tartod |

## Futtatás

1. Nyisd meg PICO-8-ban: `load jedi/jedi.p8` (vagy Splore-ból a `jedi` cart), majd `run`.
2. Cím­képernyőn 🅾️-ra indul a menet, game over után 🅾️-ra újraindul.

Headless futtatáshoz (fejlesztéshez, teszteléshez), mivel egy Lua szintaxishiba a PICO-8-ot végtelenségig futva hagyja:

```bash
perl -e 'alarm 60; exec @ARGV' -- /Applications/PICO-8.app/Contents/MacOS/pico8 -x jedi.p8
```

## Görgetett világ és drágakövek

- A világ 512×512 px (4×4 képernyő), a jedi a közepén indul. A kamera követi a jedit és a világ szélén clampel — a jedi ilyenkor nem a képernyő közepén látszik.
- Sziklák és dekor véletlenszerűen generálódnak a világban (a kezdőpont körül szabad zóna, világszéli sáv, minimális hézag közöttük).
- **5 drágakő** (◆) van egyszerre a világban. Felvétel: **100 pont**. Amint mind az 5-öt begyűjtötted, 5 új kő jelenik meg — mindig a jelenlegi látómezőn kívül, sosem a szemed előtt. A HUD bal oldalán a `◆ n/5` számláló mutatja az állást.
- A katonák és a jedi tesztelt „képernyőn van" fogalma a világban a **látómezőre** (kamera + 128×128) vonatkozik, nem a teljes világra; a jeditől 200 px-nél messzebb lemaradt katonák szó nélkül eltűnnek.

## Játékmenet

- A katonák a látómezőn kívülről érkeznek, közelítenek a jedi felé, megállási távolságukon megállnak, telegráfolnak, majd lőnek.
- **Blokk:** amíg ❎ nyomva van (és nem suhintasz), a jedi a nézési irányába néző kúpban véd. A kúpot a lövedék **pozíciója** dönti el, nem a sebességvektora.
- **Suhintás (🅾️):** 8 frame hosszú, a 3.–7. frame-ben talál; a nézési irány előtti kúpban lévő katonákat (és Vadert) megöli, a lövedékeket is visszaveri.
- **Visszavert lövés szórása:** 30% eséllyel pontosan a lövő katona felé (vagy ha az már halott, a sebességvektor negáltja irányában) repül; a maradék 70%-nál ez az irány **pontosan ±10°**-kal el van forgatva (véletlen oldalra). A visszavert lövés bármely élő katonát megöl, Vadert nem (szikrázva megsemmisül rajta).
- **Nehézség:** az egyszerre élő katonák maximuma az első 20 másodpercben 1, majd 20 másodpercenként +1, legfeljebb 8-ig. A későbbi katonák közelebb állnak meg és gyorsabban mozognak.
- **Életerő:** 3 találat; találat után kb. 1,5 másodperc sérthetetlenség (villogással) — ez alatt a blokk továbbra is működik. A 3. találat után game over, a rekord `cartdata`-ban mentődik.

## Darth Vader

- `g.kills` (kard + visszavert lövéses ölések, a kísérők is beleszámítanak) minden **15.** elérésekor (15, 30, 45, …) — ha épp nincs élő Vader — felbukkan Darth Vader **3 kísérő katonával**, és a zene átvált a Vader-indulóra.
- Vader **lassabb** a jedinél (üldözhető/elfutható), közelharcban **piros kardot** használ. Megközelítve telegráfoz (~0,5 mp felemelt karddal), majd söpör.
- **Kivédhető blokkolással:** ha ❎ nyomva van és a jedi Vader felé néz, a csapás pattanás (parry) — szikra + hang, nincs sebzés. Blokk nélkül a csapás sebez.
- **5 kardtalálat** öli meg (mindegyik után ~1 mp tántorgás + sérthetetlenség, a jedi suhintása nem üt kétszer egy suhintásból). Lövedék (még a visszavert sem) nem sebzi.
- Legyőzve: **300 pont**, a zene visszavált a főtémára. Egyszerre csak egy Vader lehet a világban.
- HUD: amíg Vader él, a felső sáv alatt HP-pipek jelzik az életerejét.

## Homokféreg

- Csak a menet **60. másodperce** után „figyel": ha a jedi **20 másodpercnél tovább** egy kb. 40×40 px-es területen belül marad (nem mozdul ki belőle), **3 másodperces remegés** (talajrázás + porrészecskék) kezdődik.
- **Menekülés:** ha a remegés alatt a jedi ≥ 20 px-re elmozdul a kitörési ponttól, a féreg üresen bukkan fel, és nem történik semmi.
- Ha a jedi a kitörés pillanatában 20 px-en belül maradt, a féreg **azonnal megeszi** — ez **azonnali game over**, függetlenül az életerőtől. A game over képernyőn ilyenkor egy `EATEN BY A SANDWORM` sor jelenik meg.
- Nincs vizuális előjelzés a figyelmeztetésen (remegés) kívül — állva maradni kockázatos.

## Kardszínek és pontok

- **Jedi kardja:** zöld (11) külső vonal, fehér (7) mag. A blokk/visszaverés szikrái is 11/7 színűek.
- **Vader kardja:** piros (8) külső vonal, fehér (7) mag.

| Esemény | Pont |
|---|---|
| Suhintásos ölés (katona) | 10 |
| Visszavert lövéses ölés (katona) | 20 |
| Drágakő felvétele | 100 |
| Darth Vader legyőzése | 300 |

A pontszám 32000-nél telítődik (v1-ből változatlan).

## Zene és hang

- Két **saját** kompozíció készült Star Wars-stílusban — nem a filmek eredeti dallamainak átirata, hanem a stílus szerzői jogi aggály nélküli, saját feldolgozása:
  - **Főtéma** (music 0–3): hősies fanfár-jellegű dallam, szól a címképernyőn és a játék alatt (amíg Vader nincs jelen).
  - **Vader-induló** (music 4–7): sötét, moll hangulatú induló, Vader felbukkanásakor váltja a főtémát, és Vader legyőzésekor vissza is vált rá.
- A hangeffekt-készlet a v1 szettre épül, kiegészítve Vader (suhintás, kardösszecsapás, sérülés, halál), a homokféreg (földremegés, előbukkanás) és a drágakövek (felvétel, újratelepülés) hangjaival.

## Tesztelés

```bash
bash run_tests.sh
```

Ez három lépést futtat, kilépőkód `0` = minden zöld:

1. **Headless tesztek** — a script végigmegy az összes `test_jedi*.p8` carton (`pico8 -x <cart>` egy 90 másodperces `perl alarm` időkorláttal, mert egy szintaxishiba örökre lefagyasztaná a PICO-8 processzt), és a végén `TOTAL ok=N fail=M` sort ír. Bármelyik cart kimenetében `syntax error` / `runtime error` / `program too large` / `FAIL:` sor, vagy a `TESTS DONE ok=N fail=0` sor hiánya hibának számít. **Miért több cart?** Minden teszt-cart `#include`-dal behúzza a teljes játékkódot, és a PICO-8 8192 tokenes limitje cartonként érvényes — a játék + az összes teszt egy cartban nem fér el. Új tesztesetet a legkisebb cartba (vagy új `test_jedi_<x>.p8`-ba) érdemes tenni; a tesztkód cartonként kb. 900 token alatt maradjon.
2. **`shrinko8 <cart> --count`** — token- és tömörített méret kiírása; 8192 tokent meghaladva hibázik. Jelenleg a cart **~5040 token** (62%) és **~7215 byte** (46%) tömörítve.
3. **`shrinko8 <cart> --lint`** — figyelmeztetések kiírása (nem blokkoló).

**Előfeltételek:** a PICO-8 binárisnak a `/Applications/PICO-8.app/Contents/MacOS/pico8` úton kell lennie; a `shrinko8` futtatásához `uv`/`uvx` szükséges (`uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8 ...`).

### A teszt-cartok szerkezete (`test_lib.lua` + `test_jedi*.p8`)

Minden teszt-cart `#include jedi.p8`-tal húzza be a játék kódját, majd `#include test_lib.lua`-val a közös harnesst (relatív útvonalon, a cart mellől). A harness:

- felülírja a `btn`/`btnp` függvényeket egy `keys` táblából olvasó stubbal (a tesztek soha nem nyúlnak a valódi inputhoz), valamint a `music`/`sfx` függvényeket egy naplózó stubbal (`music_log`, `sfx_log` táblák — így a zene-váltás és a hangeffektek is ellenőrizhetők a tesztekben anélkül, hogy valódi hang szólna),
- definiál egy kis harnesst: `tcase(name)` jelöli az aktuális tesztesetet, `check(cond, msg)` gyűjti a PASS/FAIL-t (`printh("FAIL: ...")`-tal riportol hiba esetén), `step(n, keys)` `n` frame-et léptet (minden frame-ben `_update` **és** `_draw` is fut, hogy a rajzoló-kód futásidejű hibáit is elkapja), `fresh(seed)`/`arena()` determinisztikus új menetet indít (`srand`, sziklák/spawnok kikapcsolva), `mk_trooper`/`mk_bolt` kézzel tesz be entitásokat a `g` táblába,
- a cartok saját `_init()`-je futtatja a teszteseteket: `test_jedi.p8` … `test_jedi_e.p8` a v1 esetek (világkoordinátákra átírva: mozgás/fordulás/clamp 4..508, szikla-ütközés, spawn–közelítés–telegráf–lövés, találat/inv, blokk-kúp, suhintás-ölés, visszaverés, `max_alive` ramp, game over/retry, sziklagenerálás szabályai, lövedék-életciklus, pontszám-telítés stb.); `test_jedi_v2.p8`, `test_jedi_v2b.p8` a v2 alapesetek (kamera, világ/gem-generálás, `spawn_pos`, lemaradt katona, visszaverés-szórás, drágakövek, zene-napló); `test_jedi_v2c.p8`, `test_jedi_v2d.p8` a Vader-küszöb, kísérők, mozgás/telegráf/csapás/parry, sebzés/stagger/halál és lövedék-elnyelés esetei; `test_jedi_v2e.p8` a homokféreg 60 mp-es kapuja, 600 frame mozdulatlansága, remegés/előbukkanás/süllyedés, megevés → `EATEN BY A SANDWORM`, menekülés és harapási sugár esetei,
- a végén `finish()` írja ki a `TESTS DONE ok=... fail=...` sort és `extcmd("shutdown")`-nal zárja a futást.

Jelenleg **10 teszt-cart**, összesen **553 futó teszteset**, mind zöld.

## Fájlok

```
carts/jedi/
  jedi.p8          a játék (önálló cart: __lua__ + __gfx__ + __sfx__ + __music__)
  test_lib.lua     közös teszt-harness (#include-olva minden teszt-cartba)
  test_jedi.p8      v1 alapesetek
  test_jedi_b.p8    v1 esetek (folyt.)
  test_jedi_c.p8    v1 esetek (folyt.)
  test_jedi_d.p8    v1 esetek (folyt.)
  test_jedi_e.p8    v1 esetek (folyt.)
  test_jedi_v2.p8   v2: kamera, világgenerálás, spawn
  test_jedi_v2b.p8  v2: szórás, drágakövek, zene-napló
  test_jedi_v2c.p8  v2: Vader-küszöb, kísérők, mozgás/telegráf
  test_jedi_v2d.p8  v2: Vader sebzés/stagger/halál, lövedék-elnyelés
  test_jedi_v2e.p8  v2: homokféreg
  run_tests.sh      teszt + token-limit + lint futtató (végigmegy az összes test_jedi*.p8-on)
  README.md         ez a fájl
  archive/
    jedi-v1.p8         a v1 cart érintetlen mentése (ne módosítsd)
    test_jedi-v1.p8    a v1 teszt-cart érintetlen mentése (ne módosítsd)
  docs/superpowers/specs/2026-09-16-desert-jedi-design.md    v1 spec
  docs/superpowers/specs/2026-09-17-desert-jedi-v2-design.md v2 spec
  docs/superpowers/plans/2026-09-16-desert-jedi-plan.md      v1 implementációs terv
  docs/superpowers/plans/2026-09-17-desert-jedi-v2-plan.md   v2 implementációs terv
```

A `jedi.p8` kódja tabokra van bontva (`-->8` elválasztókkal): **main** (konstansok, `_init`/`_update`/`_draw`, `g` állapottábla), **world** (sziklák, dekoráció, ütközés, `spawn_pos`), **player** (a jedi, `upd_gems`), **troopers**, **vader** (Darth Vader állapotgépe), **bolts** (lövedékek, `deflect`), **worm** (homokféreg), **fx + hud**.

## Kapcsolódó dokumentumok

- v1 design spec: [`docs/superpowers/specs/2026-09-16-desert-jedi-design.md`](docs/superpowers/specs/2026-09-16-desert-jedi-design.md)
- v1 implementációs terv: [`docs/superpowers/plans/2026-09-16-desert-jedi-plan.md`](docs/superpowers/plans/2026-09-16-desert-jedi-plan.md)
- v2 design spec: [`docs/superpowers/specs/2026-09-17-desert-jedi-v2-design.md`](docs/superpowers/specs/2026-09-17-desert-jedi-v2-design.md)
- v2 implementációs terv: [`docs/superpowers/plans/2026-09-17-desert-jedi-v2-plan.md`](docs/superpowers/plans/2026-09-17-desert-jedi-v2-plan.md)
