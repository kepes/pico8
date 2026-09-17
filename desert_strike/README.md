# Desert Strike

A scrolling, 512×512 pixel desert-arcade survival game for PICO-8 (formerly called Desert Jedi). You play a Jedi knight — swing and block with a lightsaber, and deflected shots bounce back and kill. Gems are scattered around to collect, every 15th kill summons Darth Vader (with 3 escorts), and standing still for too long draws the attention of a sandworm that can strike without warning.

## Table of contents

- [Controls](#controls)
- [Running](#running)
- [Scrolling world and gems](#scrolling-world-and-gems)
- [Gameplay](#gameplay)
- [Darth Vader](#darth-vader)
- [Sandworm](#sandworm)
- [Sword colors and points](#sword-colors-and-points)
- [Music and sound](#music-and-sound)
- [Testing](#testing)
- [Files](#files)
- [Related documents](#related-documents)
- [License](#license)

## Controls

Unchanged since v1.

| Button | Effect |
|---|---|
| ⬅️➡️⬆️⬇️ (arrows) | move in 8 directions; the Jedi faces the last-pressed arrow direction (4 facings: up/down/left/right) |
| 🅾️ (Z) | sword swing |
| ❎ (X) | block, while held |

## Running

1. In PICO-8: `load desert_strike/desert_strike.p8` (or the `desert_strike` cart from Splore), then `run`.
2. On the title screen, 🅾️ starts the run; after game over, 🅾️ restarts.

The title screen shows the poster art from `assets/desert_strike_frontpage_01.jpg`, converted to 128×128 with Floyd–Steinberg dithering (40 % strength) and a separately contrast-boosted, undithered face region so the facial features survive at 16 colours, then px9-compressed and stored in the cart itself (4388 bytes at 0x1000, i.e. the unused lower half of the sprite sheet plus the top of map memory) — the game title is not drawn by code (it's already on the poster). `assets/title_dither_compare.png` shows the dithering variants that were considered.

Headless run (for development/testing), since a Lua syntax error would leave PICO-8 running forever:

```bash
perl -e 'alarm 60; exec @ARGV' -- /Applications/PICO-8.app/Contents/MacOS/pico8 -x desert_strike.p8
```

## Scrolling world and gems

- The world is 512×512 px (4×4 screens); the Jedi starts at the center. The camera follows the Jedi and clamps at the world edges — the Jedi is then no longer centered on screen.
- Rocks and decoration spawn randomly across the world (with a clear zone around the start point, a border strip, and minimum spacing between them). Each terrain object type — small rock, big rock, pebbles, crack, bones, dry bush — has 3 sprite variants, chosen at random when generated, so the world doesn't look uniformly tiled.
- **5 gems** (◆) exist in the world at any time. Picking one up is worth **100 points**. Once all 5 are collected, 5 new ones appear — always outside the current view, never right in front of you. The HUD's left side shows a `◆ n/5` counter.
- The "on screen" test for troopers and the Jedi refers to the **viewport** (camera + 128×128), not the whole world; troopers left more than 200 px behind the Jedi disappear silently.

## Gameplay

- Troopers arrive from outside the viewport, approach the Jedi, stop at their standoff distance, telegraph, then fire.
- **Block:** while ❎ is held (and you're not swinging), the Jedi defends in a cone facing their look direction. The cone is decided by the shot's **position**, not its velocity vector.
- **Swing (🅾️):** 8 frames long, connects on frames 3–7; it kills troopers (and Vader) in the cone ahead of the look direction, and also deflects shots.
- **Deflected shot spread:** 30% chance it flies exactly toward the trooper who fired it (or, if that trooper is already dead, in the negated direction of its velocity); the remaining 70% is rotated **exactly ±10°** off that (random side). A deflected shot kills any living trooper, but not Vader (it sparks and is destroyed on contact).
- **Difficulty:** the maximum number of troopers alive at once is 1 for the first 20 seconds, then +1 every 20 seconds, up to 8. Later troopers stand closer and move faster.
- **Health:** 3 hits; after a hit, about 1.5 seconds of invincibility (with flashing) — blocking still works during this window. The 3rd hit ends the run; the high score is saved to `cartdata`.

## Darth Vader

- Every 15th kill (`g.kills` — sword and deflected-shot kills, escorts included) — 15, 30, 45, … — if no Vader is currently alive, Darth Vader appears with **3 escort troopers**, and the music switches to the Vader march.
- Vader is **slower** than the Jedi (can be outrun or chased down), uses a **red saber** in melee. When close, he telegraphs (~0.5 s with the saber raised), then sweeps.
- **Parryable:** if ❎ is held and the Jedi faces Vader, the strike is parried — a spark and sound, no damage. Without blocking, the strike hits.
- **5 saber hits** kill him (each followed by ~1 s of stagger + invincibility; the Jedi's swing doesn't hit twice from one swing). Shots (even deflected ones) don't damage him.
- Defeated: **300 points**, music switches back to the main theme. Only one Vader can exist in the world at a time.
- HUD: while Vader is alive, HP pips below the top bar show his remaining health.

## Sandworm

- The worm only starts watching after **20 seconds** into the run. If the Jedi stays within a roughly 40×40 px area (without moving out of it) for **10 seconds**, a **3-second tremor** begins (ground shake + dust particles). Earliest possible tremor: 30.0 s; earliest possible bite: ~33.3 s.
- **Escape:** if the Jedi moves ≥ 20 px away from the strike point during the tremor, the worm surfaces empty and nothing happens.
- If the Jedi is still within 20 px of the strike point at the moment it surfaces, the worm **eats immediately** — an instant game over regardless of remaining health. The game-over screen then shows an `EATEN BY A SANDWORM` line.
- There's no visual warning besides the tremor itself — standing still for too long is risky.

## Sword colors and points

- **Jedi's sword:** green (11) outline, white (7) core. Block/deflect sparks use the same 11/7 colors.
- **Vader's sword:** red (8) outline, white (7) core.

| Event | Points |
|---|---|
| Sword kill (trooper) | 10 |
| Deflected-shot kill (trooper) | 20 |
| Gem pickup | 100 |
| Defeating Darth Vader | 300 |

The score caps at 32000 (unchanged since v1).

## Music and sound

- Two **original** compositions were written in a Star Wars-adjacent style — not transcriptions of the films' themes, but an original take on the style, free of copyright concerns:
  - **Main theme** (music 0–3): a heroic fanfare-style melody, plays on the title screen and during play (whenever Vader isn't present).
  - **Vader march** (music 4–7): a dark, minor-key march that replaces the main theme when Vader appears, and switches back when he's defeated.
- The sound effect set builds on the v1 set, adding Vader (swing, saber clash, hit, death), the sandworm (ground rumble, surfacing), and gems (pickup, respawn) sounds.

## Testing

```bash
bash tests/run_tests.sh        # from the desert_strike/ folder (or from anywhere: bash desert_strike/tests/run_tests.sh)
```

This runs three steps, exit code `0` = all green:

1. **Headless tests** — the script runs every `test_ds*.p8` cart (`pico8 -x <cart>` under a 90-second `perl alarm`, since a syntax error would freeze the PICO-8 process forever), then prints a `TOTAL ok=N fail=M` line. Any `syntax error` / `runtime error` / `program too large` / `FAIL:` line in a cart's output, or a missing `TESTS DONE ok=N fail=0` line, counts as a failure. Add new test cases to the smallest cart (or a new `test_ds_<x>.p8`); keep each test cart's code under roughly 900 tokens.
2. **`shrinko8 <cart> --count`** — prints token and compressed size; fails above 8192 tokens.
3. **`shrinko8 <cart> --lint`** — prints warnings (non-blocking).

Currently **11 test carts**, totalling **566 test cases**, all green; the cart itself is **~5280 tokens** (64%) and **~7970 bytes** (52%) compressed.

**Prerequisites:** the PICO-8 binary must be at `/Applications/PICO-8.app/Contents/MacOS/pico8`; running `shrinko8` requires `uv`/`uvx` (`uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8 ...`).

### Test cart structure (`test_lib.lua` + `test_ds*.p8`)

The test carts live in `tests/`; each `#include`s `../desert_strike.p8` to pull in the game code (`#include` paths are relative to the cart file), then `#include test_lib.lua` for the shared harness. The harness:

- overrides `btn`/`btnp` with a stub reading from a `keys` table (tests never touch real input), and overrides `music`/`sfx` with logging stubs (`music_log`, `sfx_log` tables — so music switches and sound effects can be asserted on without any sound actually playing),
- defines a small harness: `tcase(name)` marks the current test case, `check(cond, msg)` collects PASS/FAIL (reporting failures via `printh("FAIL: ...")`), `step(n, keys)` advances `n` frames (running both `_update` and `_draw` each frame, so drawing-code runtime errors are also caught), `fresh(seed)`/`arena()` starts a deterministic fresh run (`srand`, rocks/spawns disabled), `mk_trooper`/`mk_bolt` manually insert entities into the `g` table,
- each cart's own `_init()` runs its test cases: `test_ds.p8` … `test_ds_e.p8` are the v1 cases (rewritten for world coordinates: movement/turning/clamp 4..508, rock collision, spawn–approach–telegraph–fire, hit/invincibility, block cone, sword kill, deflection, `max_alive` ramp, game over/retry, rock generation rules, shot lifecycle, score cap, etc.); `test_ds_v2.p8`, `test_ds_v2b.p8` cover the v2 base cases (camera, world/gem generation, `spawn_pos`, left-behind troopers, deflection spread, gems, music log); `test_ds_v2c.p8`, `test_ds_v2d.p8` cover the Vader threshold, escorts, movement/telegraph/strike/parry, damage/stagger/death, and shot-absorption cases; `test_ds_v2e.p8` covers the sandworm's gating, stillness window, tremor/surface/sink, being eaten (`EATEN BY A SANDWORM`), escaping, and bite radius; `test_ds_v3.p8` covers the v2.1 cases (terrain sprite variants, the 20 s + 10 s worm timing, and the title image cache),
- at the end, `finish()` prints the `TESTS DONE ok=... fail=...` line and calls `extcmd("shutdown")` to end the run.

## Files

```
carts/desert_strike/
  desert_strike.p8       the game (self-contained cart: __lua__ + __gfx__ + __sfx__ + __music__)
  README.md              this file
  tests/
    run_tests.sh         test + token-limit + lint runner (runs every test_ds*.p8)
    test_lib.lua         shared test harness (#include-d by every test cart)
    test_ds.p8           v1 base cases
    test_ds_b.p8         v1 cases (cont.)
    test_ds_c.p8         v1 cases (cont.)
    test_ds_d.p8         v1 cases (cont.)
    test_ds_e.p8         v1 cases (cont.)
    test_ds_v2.p8        v2: camera, world generation, spawning
    test_ds_v2b.p8       v2: deflection spread, gems, music log
    test_ds_v2c.p8       v2: Vader threshold, escorts, movement/telegraph
    test_ds_v2d.p8       v2: Vader damage/stagger/death, shot absorption
    test_ds_v2e.p8       v2: sandworm
    test_ds_v3.p8        v2.1: terrain variants, worm timing, title image
  assets/                external assets (reference images, poster art, etc.) — not loaded by the cart
  archive/
    jedi-v1.p8           untouched snapshot of the v1 cart (do not modify)
    test_jedi-v1.p8      untouched snapshot of the v1 test cart (do not modify)
  docs/specs/2026-09-16-desert-jedi-design.md         v1 design spec
  docs/specs/2026-09-17-desert-jedi-v2-design.md      v2 design spec
  docs/specs/2026-09-17-desert-strike-v2.1-design.md  v2.1 design spec
  docs/plans/2026-09-16-desert-jedi-plan.md           v1 implementation plan
  docs/plans/2026-09-17-desert-jedi-v2-plan.md        v2 implementation plan
  docs/plans/2026-09-17-desert-strike-v2.1-plan.md    v2.1 implementation plan
```

`desert_strike.p8`'s code is split into tabs (`-->8` separators): **main** (constants, `_init`/`_update`/`_draw`, the `g` state table), **world** (rocks, decoration, collision, `spawn_pos`), **player** (the Jedi, `upd_gems`), **troopers**, **vader** (Darth Vader's state machine), **bolts** (shots, `deflect`), **worm** (the sandworm), **fx + hud**.

## Related documents

- v1 design spec: [`docs/specs/2026-09-16-desert-jedi-design.md`](docs/specs/2026-09-16-desert-jedi-design.md)
- v1 implementation plan: [`docs/plans/2026-09-16-desert-jedi-plan.md`](docs/plans/2026-09-16-desert-jedi-plan.md)
- v2 design spec: [`docs/specs/2026-09-17-desert-jedi-v2-design.md`](docs/specs/2026-09-17-desert-jedi-v2-design.md)
- v2 implementation plan: [`docs/plans/2026-09-17-desert-jedi-v2-plan.md`](docs/plans/2026-09-17-desert-jedi-v2-plan.md)
- v2.1 design spec: [`docs/specs/2026-09-17-desert-strike-v2.1-design.md`](docs/specs/2026-09-17-desert-strike-v2.1-design.md)
- v2.1 implementation plan: [`docs/plans/2026-09-17-desert-strike-v2.1-plan.md`](docs/plans/2026-09-17-desert-strike-v2.1-plan.md)

## License

CC BY-NC-SA 4.0, © Peter Kepes — see [`../LICENSE`](../LICENSE).
