# PICO-8 API notes (less-known / shell-relevant)

Source: `pico-8_manual.txt`, **PICO-8 v0.2.7** (cart format `version 30`), local copy at `~/Downloads/pico-8/pico-8_manual.txt`. This file only covers material useful for building/testing carts from the shell that is **not** already in `SKILL.md`, `p8-format.md` or `testing-harness.md` — do not duplicate those.

## `extcmd(cmd_str, [p1, p2])`

| Command | Parameters | Use |
|---|---|---|
| `"screen"` | p1: scale override (int); p2 > 0: save to cart's folder instead of desktop | Screenshot; used by the harness already, but note the folder-override footgun in SKILL.md gotchas is p2, not a separate call |
| `"video"` | p1: scale override; p2 > 0: save to cart's folder | Save the rolling gif buffer (same as ctrl-9) |
| `"rec"` | none | Set video (gif) start point, normal mode (same as ctrl-8) |
| `"rec_frames"` | none | Set video start point in **frames mode**: records exactly one gif frame per `flip()` regardless of real framerate — use for deterministic headless gif capture |
| `"set_filename"` | string, may include `%d` | Override the default `cartname_%d` filename for the next screenshot/video/audio_rec; without `%d` it always overwrites |
| `"set_title"` | string | Set the host window title (also works headless/exported) |
| `"folder"` | none | Open the cart's working folder in the OS file browser (also usable from BBS/exported carts) |
| `"pause"` | none | Request the pause menu open |
| `"reset"` | none | Request a cart reset |
| `"go_back"` | none | Return to the previous cart (the one that `load()`ed this one), if any |
| `"label"` | none | Set the cart label image to the current screen contents |
| `"audio_rec"` | none | Start recording audio to a buffer |
| `"audio_end"` | p1 > 0: save to cart folder instead of desktop | Flush the audio buffer to a `.wav` on disk (not supported on web) |
| `"shutdown"` | none | Quit the cartridge; the only clean way to end a headless `-x` run before the timeout |

Default output filename is `cartname_N` (auto-incrementing); `set_filename` overrides it. `extcmd("folder")` opens `{cart dir}` normally, or `{pico-8 appdata}/appdata/appname` for exported binaries.

## Command-line switches

| Switch | Effect |
|---|---|
| `-x filename` | Run headless then quit (already used by the harness) |
| `-run filename` | Load and run — **opens a window**, never use in automation |
| `-p param_str` | Pass a parameter string, readable in-cart via `stat(6)` |
| `-export param_str` | Run the `EXPORT` command headlessly with the given param string, then exit; paths are relative to the shell's cwd, not PICO-8's virtual drive |
| `-desktop path` | Where screenshots/gifs/audio land (already used by `p8run.sh -d`) |
| `-screenshot_scale n` | Screenshot scale, default 3 (368x368) |
| `-gif_scale n` / `-gif_len n` | Gif capture scale (default 2) / max length in seconds (1..120) |
| `-timeout n` | Seconds before a network download times out (default 30) — irrelevant to local headless runs |
| `-home path` | Where `config.txt` and other user data live (use to sandbox a test run's settings) |
| `-root_path path` | Where cartridge files are looked up from |
| `-splore` | Boot into splore — never use in automation (opens UI) |
| `-global_api 1` | Leaves API functions in global scope; useful only for interactive debugging, irrelevant headless |
| `-accept_future 1` | Allow loading carts saved by a newer PICO-8 than this binary |
| `-width n` / `-height n` / `-windowed n` / `-display n` / `-draw_rect x,y,w,h` | Window geometry — irrelevant headless |
| `-volume n` / `-joystick n` / `-pixel_perfect n` / `-preblit_scale n` / `-software_blit n` | Playback/rendering tuning — irrelevant headless |
| `-foreground_sleep_ms n` / `-background_sleep_ms n` | Frame sleep delay; could matter if a headless run seems slower than expected |
| `-i filename` / `-o filename` | Bind host stdin/stdout-like files to `serial()` channels `0x806`/`0x807` — lets a cart read/write a file via `serial()` without `printh` |

`export`'s own switches (`-x`, `-y`, `-s` for import; `-i`, `-s`, `-c`, `-e` for `.bin` icon/extra files; `-f`, `-w`, `-p` for html) are console-only, not `pico8` binary switches — see the Exporters section of the manual if a build pipeline needs them.

## `stat()` codes worth knowing

| Code | Meaning |
|---|---|
| `0` | Memory usage 0..2048 (triggers GC; use `stat(99)` for the raw value without GC) |
| `1` | CPU used since last flip (1.0 = 100%); cheap way to check a bot-playtest isn't blowing the budget |
| `6` | Parameter string passed via `-p` / `load()`'s 3rd arg |
| `7` | Current framerate |
| `4` | Clipboard contents (only populated after the user pressed ctrl-V — not usable non-interactively) |
| `30`/`31` | Keypress available (bool) / character (devkit keyboard, needs `poke(0x5f2d,...)` below) |
| `32`/`33`/`34`/`36` | Mouse x/y/buttons bitfield/wheel delta (devkit mouse) |
| `38`/`39` | Relative mouse movement in host pixels (needs pointer-lock flag `0x4`) |
| `46..49` | Currently playing sfx index per channel 0..3 (high-resolution; `16..26` is the legacy/coarser version) |
| `50..53` | Current note (0..31) per channel |
| `54`/`55`/`56` | Current pattern index / total patterns played / ticks played on current pattern |
| `57` | true while music is playing |
| `80..85` | UTC year, month, day, hour, minute, second |
| `90..95` | Same, local time |
| `100` | Current breadcrumb label, or nil |
| `101`/`102` | BBS cart id / hostname (web only) |
| `110` | true while in frame-by-frame (`.`) mode |
| `120`/`121` | true when a dropped file / dropped image is available on `serial()` channel `0x800`/`0x802` |
| `124` | Current working directory (only meaningful for local/non-BBS runs) |

## Memory map (base RAM, up to 0x8000)

| Range | Contents |
|---|---|
| `0x0000` | GFX (sprite sheet, bank 1) |
| `0x1000` | GFX2 / MAP2 (shared — bottom half of sprite sheet overlaps top-shared map rows, see SKILL.md gotcha) |
| `0x2000` | MAP |
| `0x3000` | Sprite flags (gff) |
| `0x3100` | Song data |
| `0x3200` | SFX data |
| `0x4300` | User data start (code is stored >= here in cart ROM and is **not** readable via `reload()`) |
| `0x5600` | Custom font, if defined (2048 bytes) |
| `0x5e00` | Persistent cart data (256 bytes, mirrors `dget`/`dset`, only active after `cartdata()`) |
| `0x5f00` | Draw state |
| `0x5f40` | Hardware state |
| `0x5f80` | GPIO pins (128 bytes) |
| `0x6000` | Screen (8K) |
| `0x8000` | User data (general purpose) |

`peek`/`poke` docs say "max 8192" values per call, but the 0.2.5 changelog raised this to 32767 (and the current manual text still says 8192 in the API section) — treat 8192 as the safe assumption unless verified live with `poke(0,0,...)` of length > 8192.

## Pokeable draw-state / hardware addresses

The manual does **not** document `0x5f2c` as a "screen mode" register in 0.2.7 (an old changelog entry refers to a since-removed secondary-palette-enable bit there); the actually-documented pokeable addresses are:

| Address | Bits / value | Effect |
|---|---|---|
| `0x5f2d` | `0x1` enable devkit input, `0x2` mouse buttons trigger `btn(4)..btn(6)`, `0x4` pointer lock (enables `stat(38..39)`) | Enable mouse/keyboard |
| `0x5f2e` | `0x20` | Preserve fill pattern across program-suspend (default: cleared) |
| `0x5f36` | `0x8` sprite-0 opaque in `map()`/`tline()`; `0x10` custom out-of-range return value for `pget`/`sget`/`mget`; `0x20` disable lpf on legacy `0x808` serial audio; `0x40` disable console auto-scroll on `print()`; `0x80` enable character wrap by default | Misc draw/print/map behaviour bitfield |
| `0x5f37` | `1` | Disable automatic cart-ROM → base-RAM `reload()` on cart load/run/editor-exit |
| `0x5f38`/`0x5f39` | width/height (power of 2) | `tline()` sample-loop mask, in tiles |
| `0x5f3a`/`0x5f3b` | offset x/y | `tline()` sample offset, in tiles |
| `0x5f54`..`0x5f57` | see manual | Remap GFX/SCREEN/MAP memory regions (e.g. GFX at `0x60`=use screen mem as sprite sheet) |
| `0x5f58`..`0x5f5b` | bitfield + nibbles | Default P8SCII print attributes (wide/tall/invert/solid-bg/custom-font, char size, tab width, offsets) |
| `0x5f59`/`0x5f5a`/`0x5f5b` | custom value | Out-of-range return values for `sget`/`mget`/`pget` respectively (needs `0x5f36` bit `0x10` set first) |
| `0x5f5c`/`0x5f5d` | delay in frames @30fps, `255`=never, `0`=default (15/4) | `btnp()` initial repeat delay / repeat interval |
| `0x5f5e` | high nibble = read mask, low nibble = write mask | Bitplane colour read/write mask |

"Hardware extension bit" (mentioned in some older material) is obsolete since 0.2.4: 64k base RAM is now standard and no longer needs enabling.

## P8SCII control codes (inside strings printed with `print`/`?`)

One-letter escapes: `\0` terminate, `\*` repeat next char P0 times, `\#` solid background colour P0, `\-`/`\|`/`\+` shift cursor x / y / x,y by P0(-16) px, `\^` special command (below), `\a` audio, `\b` backspace, `\t` tab, `\n` newline, `\v` decorate previous char, `\f` set foreground colour, `\r` carriage return, `\014`/`\015` switch to custom font (0x5600) / default font.

`\^` special commands (`\^c1` = cls to colour 1): `1..9` skip N frames, `c` cls+home, `d` per-char delay, `g`/`h` goto/set home, `j` jump to pixel P0*4,P1*4, `r` set right-wrap column, `s` tab stop width, `u` underline, `x`/`y` char width/height. Rendering toggles (prefix `-` to disable): `w` wide, `t` tall, `=` stripey, `p` pinball (=w+t+=), `i` invert, `b` border, `#` solid bg. Raw memory write: `\^@addrnnnn[bytes]` pokes nnnn bytes at addr; `\^!addr[bytes]` pokes all remaining chars. One-off inline glyphs: `\^.`/`\^:` (raw binary / 16 hex chars = 8x8 bitmap, ignores padding) and `\^,`/`\^;` (same, respects padding). Outline: `\^oXYZ` where X=colour (or `$`/`!`), YZ=8-bit neighbour bitfield. Inline sfx: `\a` alone = beep, `\aNN` = play sfx NN, or `\a` + `s`/`l` (speed/loop) + note letters `a..g[#-]octave` (`.` = rest) + `i`/`v`/`x` (instrument/volume/effect) to synthesize a sound inline, e.g. `"\ACE-G"`.

`?` is shorthand for `print()` with no parens, usable mid-line: `if (true) ?"yes"`.

## `printh` to a file

`printh(str, [filename], [overwrite], [save_to_desktop])` — with `filename` it appends to that file in the cart's current folder (view with `folder`/`extcmd("folder")`); `overwrite=true` truncates instead of appending; `save_to_desktop=true` writes to the desktop path instead. Filename `"@clip"` writes to the host clipboard. Rate limits: 10MB of log writes and 64 distinct files per minute.

## Graphics detail: `tline`/`fillp`/`pal` table/`palt`/`sspr`/`map`/`clip`/`camera`

| Function | Detail |
|---|---|
| `pal(tbl, [p])` | First arg a table remaps many colours at once: `pal({[12]=9,[14]=8})`; table indices start at 1, so colour 0's remap goes at the end: `pal({1,1,5,...}, 1)` |
| `palt(c)` | Single-arg form treats `c` as a 16-bit bitfield setting all colours' transparency at once (bit 15 = colour 0) |
| `fillp(p)` | 16-bit pattern bitfield (reading order, MSB first) observed by `circ/circfill/rect/rectfill/oval/ovalfill/pset/line`; extra bits `0b0.100` transparency, `0b0.010` apply pattern to sprites via secondary palette, `0b0.001` apply secondary palette globally to non-sprite draws too. Can also be set via the high 16 bits of any colour parameter if `poke(0x5f34,1)` is set (bit `0x1000.0000` must be set in the colour value) |
| `sspr(sx,sy,sw,sh, dx,dy,[dw,dh],[flip_x,flip_y])` | Stretch-blit a spritesheet rect to an arbitrary screen rect; `dw,dh` default to `sw,sh` |
| `map(tile_x,tile_y,[sx,sy],[tile_w,tile_h],[layers])` | `layers` is a flag bitfield: only sprites whose gff flags match are drawn; sprite 0 = "empty" (skipped) unless `poke(0x5f36,0x8)` |
| `tline(x0,y0,x1,y1, mx,my,[mdx,mdy],[layers])` | Samples colour from the map at tile coords `mx,my` (fractional = inside the 8x8 sprite); precision/loop/offset controlled via `0x5f38/39/3a/3b` above; call `tline(16)` once (single arg) to switch mx/my/mdx/mdy units from tiles to pixels |
| `clip(x,y,w,h,[clip_previous])` | `clip_previous=true` intersects the new rect with the old one instead of replacing it; `clip()` alone returns/resets |
| `camera([x,y])` | Offsets all drawing by `-x,-y`; commonly `camera(pl.x-64, pl.y-64)` then `map()` to center on a player |

## `menuitem`

`menuitem(index, [label], [callback])` adds/updates a pause-menu entry. `index` 1..5 orders it; OR in `0xff00` bits as a button mask to ignore L/R/X presses for that item (e.g. `menuitem(2 | 0x300, ...)` ignores L/R). Callback receives a button-press bitfield and returning `true` keeps the menu open (useful for toggles that update their own label via `menuitem(nil, "new label")`). Omitting label/callback removes the item.

## `cstore`/`reload`/multi-cart

`cstore(dest,src,len,[filename])` writes base-RAM → cart ROM (or to another cart file on disk if `filename` given — up to 64 extra cartridges per session); `cstore()` alone == `cstore(0,0,0x4300)`. `reload(dest,src,len,[filename])` is the inverse (cart ROM/another cart → base RAM); the code section (`>= 0x4300`) can never be read this way. Bundling: `export mygame.html dat1.p8 dat2.p8` packs up to 32 carts; at runtime `reload(0,0,0x2000,"dat1.p8")` or `load("game2.p8")` accesses the bundled files as if they were local. Exported multicarts cannot `load("#bbs_id")`.

## Strings / numbers

| Function | Notes |
|---|---|
| `split(str,[sep],[convert_numbers])` | default `sep` is `","`; `sep` as a number `n` splits into n-char groups instead of by delimiter; `convert_numbers` defaults **true**; empty fields become `""` |
| `tostr(val,[flags])` | `0x1` raw hex (`"0x0011.0000"`), `0x2` treat as signed 32-bit int shifted left 16 (`"1114112"`); `tostr(nil)`→`"[nil]"`, `tostr()`→`""` |
| `tonum(val,[flags])` | `0x1` parse as unsigned hex without `0x` prefix; `0x2` parse as signed 32-bit int, shift right 16; `0x4` return 0 instead of no-value on failure |
| `tonum("0x1f")`, `tonum("0b101")` | Prefixed hex/binary strings parse without flags (→ 31, 5); returns `nil` for non-numbers | Reading hex from data strings |
| `chr(v0,v1,...)` | Multiple ordinals → one string: `chr(104,101,108,108,111)` = `"hello"` |
| `ord(str,[index],[num_results])` | With `num_results`, returns that many ordinals starting at `index` (like a multi-`peek` over a string) |
| `sub(str,pos0,[pos1])` | `pos1` non-numeric-but-given (e.g. `true`) returns the single char at `pos0`; `str[pos]` is sugar for a single character |

Strings accept `[[ ]]` multi-line literals; joining a number with `..` auto-converts it; using a string in arithmetic auto-converts it (`2+"3"` == `5`).

## Integer division, modulo, fixed point

`\` is integer division (`9\2` == `4`, == `flr(9/2)`); `%` is modulo (`x%0` gives `0`, not an error). All numbers are 16.16 fixed point, range **-32768.0 .. 32767.99999**, minimum step ~0.00002; a plain frame counter incremented by 1 overflows after ~18 minutes. Divide-by-zero gives `±0x7fff.ffff`. Hex literals with fractional part: `0x11.4000` == `17.25`; view the raw bits with `tostr(val,true)`.

## Coroutines

`cocreate(f)` makes a coroutine; `cocreate(f)` + `coresume(c,[p0,...])` runs/resumes it (returns `true` on success, or `false, err` — wrap in `assert(coresume(c))` since **errors inside a coroutine don't stop the program**); `costatus(c)` returns `"running"`/`"suspended"`/`"dead"`; `yield()` suspends. Useful for scripted bot-playtest sequences that need to pause mid-script without restructuring `_update`.

## Serial / GPIO

`serial(channel, address, length)`: channel `0x000..0x0fe` = a GPIO pin (`0x00`/`0xff` = LOW/HIGH), `0x0ff` = delay of `length` microseconds, `0x400..0x401` = ws281x LED string. Host bytestream channels (local runs and exported binaries only, not BBS): `0x800` dropped file, `0x802` dropped image (`stat(120)`/`stat(121)` signal availability; image bytestream = 2x `peek2`-style width/height header then 1 byte/pixel), `0x804` stdin, `0x805` stdout, `0x806`/`0x807` files bound via `pico8 -i`/`-o`. Max transfer 64k/sec, blocks CPU. GPIO pins live at `0x5f80..0x5fff` (poke to output, peek to read); meaning is host-specific (CHIP, Pocket CHIP, Raspberry Pi wiringPi pins).

## `_update60`

Define `_update60()` instead of `_update()` to run at 60fps (both it and `_draw()` called at 60fps, half the per-frame CPU budget before PICO-8 drops to 30fps). Slower hosts may still call it twice per `_draw()`, same as the 15fps fallback for `_update()`.

## Custom fonts

Defined at `0x5600`: 8 bytes/char x 256 chars = 2048 bytes, each char an 8x8 1-bit bitmap (bit 0 = leftmost pixel of each row byte). First 128 bytes (chars 0..15, never drawn) are font-wide attributes: `0x5600` width, `0x5601` width for char >=128, `0x5602` height, `0x5603`/`0x5604` draw offset x/y, `0x5605` flags (`0x1` apply size adjustments, `0x2` tabs relative to cursor home), `0x5606` tab width. Remaining bytes give per-character width/vertical-offset nibble adjustments for chars 16..255. Switch to it mid-string with P8SCII `\014` (back to default with `\015`), or globally via `0x5f58` bit `0x80`.

## Mouse/keyboard input

Experimental "devkit" input: `poke(0x5f2d, flags)` with `0x1` enable, `0x2` mouse buttons map to `btn(4)..btn(6)`, `0x4` pointer lock (then read deltas via `stat(38)`/`stat(39)`). Read state via `stat(30)` (keypress available), `stat(31)` (character), `stat(32..34)` (mouse x/y/buttons), `stat(36)` (wheel). When enabled, BBS players see a warning that the cart expects non-standard input — keep it optional/off by default for shared carts. For test harnesses this is mostly irrelevant since tests stub `btn`/`btnp` directly.

## `#include` rules

`#include filename` (only at cartridge boot, not at runtime) accepts a plaintext `.lua` file, one tab from another cart (`#include other.p8:1`), or all tabs (`#include other.p8`). Filenames are relative to the **current cartridge's saved location** (so save before using it). Includes are **not recursive** (an included file's own `#include` lines are not processed) and still count toward the normal token/char limits. When exported or saved as `.p8.png`/binary, included files are flattened into the cartridge so there is no external dependency at distribution time.

## Cartridge data (persistent save)

`cartdata(id)` opens a 256-byte (64-number) persistent slot named `id` (a..z, 0..9, `_`, max 64 chars); returns `true` if existing data was loaded. `dget(i)`/`dset(i,v)` read/write index `0..63`. Data auto-flushes to disk — no explicit save call needed, including when poking `0x5e00..0x5eff` directly. As of 0.2.6, a cart can switch between up to 4 different cartdata ids per session (older versions: once per run — the harness's "call once per test run" caution in SKILL.md is still the safe default for tests).

## Audio memory / low-level

Song (pattern) data lives at base RAM `0x3100`, SFX (note) data at `0x3200` — same 168-byte-per-sfx / pattern-row layout described for the `.p8` text format in `p8-format.md`, just in binary in RAM. There is no headless audio mixer tick under `-x` (per SKILL.md gotcha); these addresses are useful for a script that wants to `peek`/diff sfx/song data rather than trying to "hear" it.
