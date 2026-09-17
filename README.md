# PICO-8 Carts

A collection of PICO-8 game carts by Peter Kepes.

## Table of contents

- [Programs](#programs)
- [Running](#running)
- [Development notes](#development-notes)
- [License](#license)

## Programs

| Game | Description |
|---|---|
| [Desert Strike](desert_strike/README.md) | A scrolling desert-arcade survival game where you swing and block with a lightsaber, deflect blaster fire, collect gems, and watch out for Darth Vader and a sandworm. |

## Running

Requires PICO-8 0.2.7.

- In PICO-8: `load desert_strike/desert_strike.p8`, then `run`.
- Or browse and launch from Splore.

## Development notes

- Each game has its own headless test suite: `bash <game>/tests/run_tests.sh` (0 = all green).
- PICO-8 development knowledge (headless execution, `#include` limits, token budgets, test harness patterns) lives in the `pico8-programming` skill under `.claude/skills/`.
- Per-game layout:
  ```
  <game>/
    <game>.p8      the cart (self-contained: code + gfx + sfx + music)
    tests/         test_lib.lua, test_*.p8, run_tests.sh
    assets/        external assets (reference images, sound/music sources) — not loaded by the cart
    docs/specs/    design specs
    docs/plans/    implementation plans
    archive/       (optional) pre-git snapshots of older versions
  ```
- `demos/` holds PICO-8's factory demo carts and is not versioned (see `.gitignore`).

## License

This collection is licensed under [CC BY-NC-SA 4.0](LICENSE) (Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International), © Peter Kepes.

In short: you may share and adapt the material with attribution, but not for commercial purposes, and any derivatives must be shared under the same license.
