#!/usr/bin/env python3
"""Build the website display font from Gloamthread's original bitmap glyphs.

Authoring-only dependencies: fonttools and brotli. The reproducible WOFF2 is
committed so public/Docker builds do not need a font toolchain.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = Path(__file__).resolve().parents[1]


def build(output: Path) -> None:
    source = json.loads((ROOT / "assets/source/art/glyphs.json").read_text())
    glyphs = source["glyphs"]
    names = {char: f"uni{ord(char):04X}" for char in glyphs}
    order = [".notdef", *names.values()]
    builder = FontBuilder(1000, isTTF=True)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap({ord(char): name for char, name in names.items()})
    outlines = {}
    metrics = {}
    for char, name in [("\ufffd", ".notdef"), *names.items()]:
        pen = TTGlyphPen(None)
        for row, cells in enumerate(glyphs[char].split("/")):
            # Adjacent pixels form horizontal runs, avoiding shared contour edges.
            col = 0
            while col < len(cells):
                if cells[col] != "1":
                    col += 1
                    continue
                end = col + 1
                while end < len(cells) and cells[end] == "1":
                    end += 1
                left, right = col * 100 + 30, end * 100 + 30
                bottom, top = (6 - row) * 100, (7 - row) * 100
                pen.moveTo((left, bottom))
                pen.lineTo((left, top))
                pen.lineTo((right, top))
                pen.lineTo((right, bottom))
                pen.closePath()
                col = end
        outlines[name] = pen.glyph()
        metrics[name] = (600, 30 if char != " " else 0)
    builder.setupGlyf(outlines)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=800, descent=-200)
    builder.setupNameTable({
        "familyName": "Gloamthread Display",
        "styleName": "Regular",
        "uniqueFontIdentifier": "GloamthreadDisplay-Regular-1.0",
        "fullName": "Gloamthread Display Regular",
        "psName": "GloamthreadDisplay-Regular",
        "version": "Version 1.0",
        "copyright": "Original Gloamthread project glyphs. Copyright Midhun P M. MIT License.",
    })
    builder.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200, usWeightClass=400)
    builder.setupPost()
    builder.setupMaxp()
    font = builder.font
    font.recalcTimestamp = False
    font["head"].created = font["head"].modified = 2082844800
    font.flavor = "woff2"
    output.parent.mkdir(parents=True, exist_ok=True)
    font.save(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "web/assets/display.woff2")
    build(parser.parse_args().output)
