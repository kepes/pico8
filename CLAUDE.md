# PICO-8 carts — project rules

This folder is the PICO-8 cart directory (`~/Library/Application Support/pico-8/carts`), managed as a git repository. The factory `demos/` folder is in `.gitignore`.

## Directory layout

```
carts/
  CLAUDE.md                     this file
  README.md, LICENSE            collection overview (English) and the CC BY-NC-SA 4.0 license
  .claude/skills/pico8-programming/   PICO-8 development know-how (headless runs, cart format, test harness, gotchas)
  <game>/
    <game>.p8                   the cart — self-contained (code + gfx + sfx + music), no #include inside
    tests/                      test_lib.lua, test_*.p8 (#include ../<game>.p8), run_tests.sh
    assets/                     external assets: reference images, sound/music sources, generator scripts — never loaded by the cart
    docs/specs/                 design specs (YYYY-MM-DD-<topic>-design.md)
    docs/plans/                 implementation plans
    archive/                    (optional) pre-git versions; new versions are versioned with git, not here
  demos/                        factory demos, not versioned
```

Current game: `desert_strike/` (Desert Strike, formerly Desert Jedi; v2.1). A new game = a new subfolder with the same layout.

## Development

- **Load the `pico8-programming` skill before any cart work** (`.claude/skills/pico8-programming/SKILL.md`): headless runs with a timeout, `#include` limits, the 8192-token limit, sprite transparency, test harness. Do not rediscover these.
- PICO-8 binary: `/Applications/PICO-8.app/Contents/MacOS/pico8`. **Never open a PICO-8 window** during automated work; `pico8 -x` runs headless.
- Input in the cart only through `btn()`/`btnp()` (the tests stub them).
- **Language:** every `README.md`, all code comments (cart, tests, scripts), this file and the skill are in **English**; `docs/specs` and `docs/plans` are in Hungarian; in-game text is English.
- **Spec/plan paths (project override):** `docs/specs/` and `docs/plans/` — not `docs/superpowers/...`.
- **License:** CC BY-NC-SA 4.0 (`LICENSE` in the root, author Peter Kepes); every program's README gets a license line.
- Do not use the playfield background colour for sprite details, and do not patch colours with `pal()` at draw time — paint the right colour into the sprite.

## Testing and commits

- Tests: `bash <game>/tests/run_tests.sh` (headless tests + shrinko8 token limit + lint; exit 0 = green).
- If a `.p8`/`.lua` file changed, run the game's test suite before committing and require green. Docs/asset-only changes need no test run.
- **Committing directly to `main` is fine in this repository** (single-developer hobby project; overrides the global "do not commit to main" default). Pushing stays in the user's hands.
- No CI: the PICO-8 binary is licensed and cannot run on public CI; the local `run_tests.sh` is the only safety net.
- Commit messages: concise, about the change; no Claude attribution.
