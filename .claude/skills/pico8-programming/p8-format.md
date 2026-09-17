# .p8 cart file format (text)

```
pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
<code; tabs separated by a line containing only -->8 >
__gfx__
<128 rows x 128 hex chars; one char per pixel, row = y, column = x on the 128x128 sheet>
__gff__          (optional) 2 rows x 256 hex — sprite flags
__map__          (optional)
__sfx__
<64 rows x 168 chars>
__music__
<64 rows "FF AABBCCDD">
```

A cart with only `__lua__` is valid; PICO-8 fills missing sections with zeros. Sections can be extracted with `awk '/^__gfx__/{f=1;next}/^__/{f=0}f' cart.p8` and replaced by concatenating `header + code + "__gfx__" + rows + ...`.

## Sprites

- Sprite `n` occupies columns `(n%16)*8..+7` and rows `flr(n/16)*8..+7`; `spr(n, x, y, w, h, flip_x)` draws `w x h` sprites (`spr(n,x,y,1,2)` = an 8x16 figure using `n` and `n+16`).
- Colour digits: 0 black (transparent by default), 1 dark blue, 2 dark purple, 3 dark green, 4 brown, 5 dark grey, 6 light grey, 7 white, 8 red, 9 orange, a yellow, b green, c blue, d indigo, e pink, f peach.
- Big objects (16x16, 32x32) are just adjacent sprites drawn with `w,h > 1`.

## SFX rows (168 chars)

`MM SS LS LE` (8 hex): editor mode (00), speed (01–ff; 04–08 for effects, 10–14 for music at ~100 BPM with a 32-note 16th grid), loop start, loop end (00 00 = none). Then 32 notes x 5 hex: `PP W V E` = pitch 00–3f (24 ≈ C3), waveform 0 triangle / 1 tilted saw / 2 saw / 3 square / 4 pulse / 5 organ / 6 noise / 7 phaser, volume 0–7, effect 0 none / 1 slide / 2 vibrato / 3 drop / 4 fade in / 5 fade out / 6 arp fast / 7 arp slow. Silent note: `00000`.

Example blaster shot: header `00040000`, notes `2c371 28371 24371 20371 1c360`, remaining 27 notes `00000`.

## Music rows

`FF AABBCCDD`: flags (01 loop start, 02 loop end, 04 stop), then four sfx indices in hex, one per channel; an unused channel is `41`–`44` (high bit = off). Example loop of two patterns using sfx 16–18 and 19–21 on three channels: `01 10111244`, `02 13141544`; unused rows `00 41424344`.

## Limits

8192 tokens, 65535 chars, 15360 bytes compressed per cart; `shrinko8 --count` reports all three. Headless `-x` obeys the same limits, and `#include`d code counts.
