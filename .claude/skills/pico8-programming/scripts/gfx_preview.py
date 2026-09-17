#!/usr/bin/env python3
"""Render the __gfx__ section of a .p8 cart (or a raw 128-line hex file) to a PNG.

Usage: uv run --with pillow gfx_preview.py cart.p8 out.png [--scale 8] [--bg N] [--transparent 0,3] [--rows 0-31] [--cols 0-127]
  --bg N            draw transparent colours as palette colour N (default: grey checkerboard)
  --transparent L   comma-separated colours treated as transparent (default 0)
  --rows / --cols   crop in sheet pixels (inclusive ranges), e.g. --rows 0-15 --cols 64-111
An 8-px grid marks sprite boundaries. View the PNG with the Read tool to judge the art.
"""
import argparse, sys
from PIL import Image, ImageDraw
PAL=[(0,0,0),(29,43,83),(126,37,83),(0,135,81),(171,82,54),(95,87,79),(194,195,199),(255,241,232),
     (255,0,77),(255,163,0),(255,236,39),(0,228,54),(41,173,255),(131,118,156),(255,119,168),(255,204,170)]
def rows_of(path):
    lines=[l.rstrip('\n') for l in open(path)]
    if any(l=='__gfx__' for l in lines):
        i=lines.index('__gfx__')+1; out=[]
        while i<len(lines) and not lines[i].startswith('__'): out.append(lines[i]); i+=1
        lines=out
    lines=[l for l in lines if l]
    return [l.ljust(128,'0')[:128] for l in lines]+['0'*128]*(128-len(lines))
def rng(s,mx): a,b=(s.split('-')+[None])[:2]; a=int(a); b=int(b) if b else a; return a,min(b,mx)
ap=argparse.ArgumentParser(); ap.add_argument('cart'); ap.add_argument('out'); ap.add_argument('--scale',type=int,default=8)
ap.add_argument('--bg',type=int); ap.add_argument('--transparent',default='0'); ap.add_argument('--rows',default='0-127'); ap.add_argument('--cols',default='0-127')
a=ap.parse_args(); rows=rows_of(a.cart); tr={int(c) for c in a.transparent.split(',') if c!=''}
r0,r1=rng(a.rows,127); c0,c1=rng(a.cols,127); S=a.scale; W=(c1-c0+1); H=(r1-r0+1)
img=Image.new('RGB',(W*S,H*S)); d=ImageDraw.Draw(img)
for y in range(r0,r1+1):
    for x in range(c0,c1+1):
        c=int(rows[y][x],16)
        if c in tr:
            col=PAL[a.bg] if a.bg is not None else ((150,150,150) if (x//4+y//4)%2 else (110,110,110))
        else: col=PAL[c]
        d.rectangle([(x-c0)*S,(y-r0)*S,(x-c0+1)*S-1,(y-r0+1)*S-1],fill=col)
for x in range(c0,c1+2):
    if x%8==0: d.line([((x-c0)*S,0),((x-c0)*S,H*S)],fill=(255,0,255),width=1)
for y in range(r0,r1+2):
    if y%8==0: d.line([(0,(y-r0)*S),(W*S,(y-r0)*S)],fill=(255,0,255),width=1)
img.save(a.out); print(f"wrote {a.out} ({W}x{H} sheet px at {S}x)")
