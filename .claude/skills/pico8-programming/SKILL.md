---
name: pico8-programming
description: Use when creating, editing, testing or debugging PICO-8 carts (.p8 files, PICO-8 Lua, sprite sheets, sfx/music data), including running a cart without a window, taking screenshots, writing a test harness, hitting "program too large" or token limits, or editing the __gfx__/__sfx__/__music__ sections by hand.
---

# PICO-8 programming

## Overview

PICO-8 carts can be built and verified entirely from the shell: `pico8 -x` runs a cart headlessly (no window), `printh` is stdout, `extcmd("screen")` writes PNGs, and a test cart can `#include` the game and stub its inputs. Everything below was learned the hard way; follow it instead of rediscovering it.

Binary on this machine: `/Applications/PICO-8.app/Contents/MacOS/pico8`. Never start PICO-8 with a window during automated work: bare `pico8`, `-run`, and **any unknown flag such as `-h`/`--help` open the GUI** (there is no help flag). The only safe invocation is `pico8 [-desktop DIR] -x cart.p8` inside a timeout. For API questions read the manual text file if present (`~/Downloads/pico-8/pico-8_manual.txt`) instead of probing flags.

## Quick reference

| Need | Do |
|---|---|
| Run a cart headless | `scripts/p8run.sh cart.p8` (wraps `pico8 -x` with a timeout and error grep) |
| Screenshot from a headless run | `scripts/p8run.sh -d shots/ cart.p8` and call `extcmd("screen")` in Lua → `shots/<cart>_N.png`; view with the Read tool. Do not use the "current folder" variant `extcmd("screen",scale,1)`: it writes into the PICO-8 carts root, not next to the cart |
| Exit a headless run | `extcmd("shutdown")` from Lua; without it the run lasts until the timeout (exit 142 = normal for a smoke run) |
| Exact token / char / compressed counts, lint | `uvx --from git+https://github.com/thisismypassport/shrinko8 shrinko8 cart.p8 --count` (`--lint`); shrinko8 is not on PyPI. There is no runtime API for the token count (`info()` only draws it on screen) |
| Preview the sprite sheet as an image | `uv run --with pillow scripts/gfx_preview.py cart.p8 out.png` |
| Test harness, runner, multi-cart split | [testing-harness.md](testing-harness.md) |
| Cart file format (`__gfx__`, `__sfx__`, `__music__`) | [p8-format.md](p8-format.md) |

## Gotchas that cost time

| Symptom | Cause | Fix |
|---|---|---|
| `pico8 -x` never returns | A Lua **syntax error** hangs the process; there is no exit | Always run through a timeout (`perl -e 'alarm 60; exec @ARGV' -- pico8 -x cart.p8`; macOS has no `timeout`). Treat `syntax error` in the output as failure |
| Run exits 0 but the test did nothing | **Runtime errors** print `runtime error line N` and exit 0 | grep the output for `runtime error` |
| `could not #include file` | `#include` accepts only paths **relative to the cart** (`../game.p8` works, absolute paths do not) | Keep helper carts next to the game or one directory below |
| Helper cart renders sand but no sprites | `#include` pulls **Lua code only**; gfx/sfx/music stay in the source cart | `sed -n '/^__gfx__$/,$p' game.p8 >> helper.p8` after writing the helper's code |
| `program too large` in a test cart | The **8192-token limit** counts included code; game + many tests overflow | Split tests into several carts sharing one `test_lib.lua` (see testing-harness.md) |
| Black sprite has holes / shows the floor | Colour **0 is transparent** in `spr()` | Paint the sprite background with an unused colour (e.g. 3) and draw with `palt(0,false) palt(3,true) spr(...) palt()`; the editor shows that colour as a background, which is expected |
| A sprite detail is invisible in game | Its colour equals the **playfield background** (e.g. face 15 on sand 15) | Pick another palette colour **in the sprite**; do not patch it with `pal()` at draw time |
| Helper named `t` breaks timing code | `t()` is a **built-in** (`time()`), as are `add`, `del`, `all`, `stat`, `count` | Never define globals with built-in names |
| Distances wrong on large maps, scores stuck | Numbers are **16.16 fixed point**, max 32767 | Pre-scale before squaring (`dx/8`), saturate scores with `min(v,32000)` |
| `cartdata` error in tests | `cartdata()` may be called **once per run** | Call it once in the test `_init` with a test-only key so tests never touch the real save |
| Music cannot be checked headless | `-x` does not tick the audio mixer | Verify format and loadability only; judge musicality by reading the note data |
| `#include`d `_init` runs instead of the test's | Later definitions win, but only if the test file defines them **after** the include | Put the include first, then override `_init`, `_update`, `_draw`, `btn`, `btnp`, `music`, `sfx` |

## Project layout (repo convention)

```
carts/<game>/<game>.p8      the cart (self-contained: code + gfx + sfx + music)
carts/<game>/tests/         test_lib.lua, test_*.p8 (#include ../<game>.p8), run_tests.sh
carts/<game>/assets/        external assets: reference images, tracker/wav sources, generator scripts — never loaded by the cart
carts/<game>/docs/          specs and plans
```

Keep the cart self-contained (no `#include` inside the shipped cart) so it loads from splore and exports cleanly.

## Common mistakes

- Reading `stat()` for input: tests stub `btn`/`btnp`, so route all input through those two.
- Running the whole suite in `_update` frames: run tests inside `_init` (loops of the game's own `_update`/`_draw`), print `PASS:`/`FAIL:` lines and a final `TESTS DONE ok=N fail=M`, then `extcmd("shutdown")`.
- Forgetting `srand(seed)` in tests: `rnd()` differs per run otherwise.
- Trusting a screenshot from a cart that only `#include`s the game: it has an empty sprite sheet (see gotchas).
- Copying the whole game into a test cart instead of `#include ../game.p8`: it works once, then the copy silently drifts from the game.
- Editing `__gfx__` rows by hand without checking lengths: every row is exactly 128 hex chars; run `awk 'length($0)!=128' ` over the section.
