#!/usr/bin/env python3
"""Draws assets/cover.png (630 by 500, the itch.io cover) from a rendered frame of the game:
the field at 2x under the title in Public Pixel (CC0). Make the frame first:
odin test src/game -collection:tggd=src -define:DUMP_PLAY=/tmp/frame.ppm
then: python3 -I tools/make_cover.py /tmp/frame.ppm"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
frame = Image.open(sys.argv[1]).convert('RGB')
field = frame.crop((10, 22, 10 + 196, 22 + 196)).resize((392, 392), Image.NEAREST)
cover = Image.new('RGB', (630, 500), (26, 28, 44))
cover.paste(field, ((630 - 392) // 2, 96))
d = ImageDraw.Draw(cover)
font = ImageFont.truetype(os.path.join(ROOT, 'tools/data/PublicPixel.ttf'), 32)
small = ImageFont.truetype(os.path.join(ROOT, 'tools/data/PublicPixel.ttf'), 16)
for text, f, y, color in (('FARMHANDS', font, 18, (255, 205, 117)), ('of SPLORR!!', small, 62, (148, 176, 194))):
    w = d.textlength(text, font=f)
    d.text(((630 - w) // 2, y), text, font=f, fill=color)
cover.save(os.path.join(ROOT, 'assets/cover.png'))
print('assets/cover.png', cover.size)
