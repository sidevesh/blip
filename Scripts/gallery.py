"""Builds the README images from banner captures.

usage: gallery.py CAPTURES_DIR OUT_DIR MODE

CAPTURES_DIR holds NN-name.png screen captures of the top-right corner (as Scripts/screenshots.sh
takes them, at 2x). Each is cropped to its banner and laid out on a canvas:
  OUT_DIR/banners-MODE.png  a few representative banners
  OUT_DIR/all-MODE.png      every banner
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

source, target, mode = sys.argv[1], sys.argv[2], sys.argv[3]
# The banner sits 20 pt in and 16 pt down in the capture; keep 12 pt of wallpaper around it.
CROP = (62, 14, 62 + 636, 14 + 164)
HERO = ["01-volume", "10-low-battery", "04-brightness", "14-accessory", "09-all-microphones", "26-play-pause",
        "05-keyboard", "11-charging", "19-wifi", "29-dpi", "35-success", "41-slider"]
BACKGROUND = (14, 15, 22) if mode == "dark" else (238, 239, 244)

paths = sorted(glob.glob(os.path.join(source, "[0-9][0-9]-*.png")))
tiles = {os.path.basename(p)[:-4]: Image.open(p).convert("RGB").crop(CROP) for p in paths}


def sheet(names, columns, out):
    w, h = CROP[2] - CROP[0], CROP[3] - CROP[1]
    gap, pad, radius = 20, 32, 28
    rows = -(-len(names) // columns)
    canvas = Image.new("RGB", (pad * 2 + columns * w + (columns - 1) * gap, pad * 2 + rows * h + (rows - 1) * gap), BACKGROUND)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    for index, name in enumerate(names):
        x = pad + (index % columns) * (w + gap)
        y = pad + (index // columns) * (h + gap)
        canvas.paste(tiles[name], (x, y), mask)
    canvas.save(out, optimize=True)
    print("wrote", out)


sheet([n for n in HERO if n in tiles], 3, os.path.join(target, f"banners-{mode}.png"))
sheet(sorted(tiles), 3, os.path.join(target, f"all-{mode}.png"))
