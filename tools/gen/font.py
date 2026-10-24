"""Export the retained original glyph matrix as PNG and text BMFont."""
import json
from pathlib import Path
from PIL import Image
from .common import record


def generate(root: Path) -> list[dict]:
    glyphs = json.loads((root / "assets/source/art/glyphs.json").read_text())["glyphs"]
    codepoints = list(range(32, 127)) + [65533]
    image = Image.new("RGBA", (96, 48))
    lines = ['info face="Weft Hand" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
             'common lineHeight=8 base=7 scaleW=96 scaleH=48 pages=1 packed=0',
             'page id=0 file="weft_5x7.png"', 'chars count=96']
    for index, codepoint in enumerate(codepoints):
        x, y = index % 16 * 6, index // 16 * 8
        rows = glyphs[chr(codepoint)].split("/")
        if len(rows) != 7 or any(len(row) != 5 or set(row) - {"0", "1"} for row in rows):
            raise ValueError(f"Malformed original glyph {codepoint}")
        for gy, row in enumerate(rows):
            for gx, pixel in enumerate(row):
                if pixel == "1":
                    image.putpixel((x + gx, y + gy), (213, 210, 184, 255))
        lines.append(f"char id={codepoint} x={x} y={y} width=5 height=7 xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15")
    directory = root / "assets/generated/font"
    directory.mkdir(parents=True, exist_ok=True)
    texture, font = directory / "weft_5x7.png", directory / "weft_5x7.fnt"
    image.save(texture)
    font.write_text("\n".join(lines) + "\n", encoding="utf-8")
    sources = ["assets/source/art/glyphs.json", "tools/gen/font.py"]
    return [record(root, "font_texture_v1", "image", texture, sources, size=[96, 48]),
            record(root, "font_v1", "font", font, sources, texture_id="font_texture_v1", glyphs=codepoints)]
