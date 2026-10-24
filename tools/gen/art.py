"""Original pixel silhouettes, canonical material masks and padded atlases.

The drawing recipes are editable source, alongside direction.json. All image
operations author pixels from these recipes; no external image/font is loaded.
"""
from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw
from .common import record

COURIER_CLIPS = {"idle": 4, "run": 6, "jump_rise": 2, "fall": 2, "land": 2,
                 "slash": 4, "special": 4, "hurt": 2, "dash": 2, "downed": 2, "revive": 2}
TILE_IDS = ["solid_fill", "solid_top", "one_way_middle", "hazard_middle",
            "solid_fill_2", "solid_fill_3", "solid_fill_4", "solid_top_2", "solid_top_3", "solid_top_4",
            "solid_bottom", "solid_bottom_2", "solid_bottom_3", "solid_bottom_4",
            "solid_left", "solid_left_2", "solid_left_3", "solid_left_4",
            "solid_right", "solid_right_2", "solid_right_3", "solid_right_4",
            "corner_outer_tl", "corner_outer_tr", "corner_outer_bl", "corner_outer_br",
            "corner_inner_tl", "corner_inner_tr", "corner_inner_bl", "corner_inner_br",
            "one_way_left", "one_way_right", "one_way_single",
            "hazard_left", "hazard_right", "hazard_single",
            "bridge_left", "bridge_middle", "bridge_right", "bridge_single",
            "seam_horizontal", "seam_vertical", "seam_cross", "seam_knot",
            "background_stone", "background_brass", "background_root", "background_cloth"]
OUTLINE, SHADOW, BONE = "#293247", "#10141C", "#D5D2B8"


def courier(identity: str, state: str, step: int, colours: dict) -> Image.Image:
    image = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(image)
    hood, mantle, scarf, spool, glow = (colours[key] for key in ("hood", "mantle", "scarf", "spool", "glow"))
    if state == "downed":
        # A bundled mantle and upright loose thread distinguish recoverable defeat.
        d.ellipse((5, 31, 27, 42), fill=OUTLINE)
        d.ellipse((7, 32, 25, 40), fill=mantle)
        d.polygon([(8, 34), (16, 29), (23, 33), (21, 38)], fill=hood)
        d.line([(17, 32), (18, 26), (21, 24 - step)], fill=glow)
        d.ellipse((3, 35, 10, 41), fill=spool, outline=OUTLINE)
        d.line((6, 36, 6, 40), fill=BONE)
        return image
    bob = (step % 2) if state in ("idle", "run", "revive") else 0
    crouch = 3 if state == "land" else 0
    lean = 2 if state in ("dash", "slash") else (-1 if state == "hurt" else 0)
    oy = bob + crouch
    # Swing legs independently while keeping the foot reference fixed at y43.
    stride = [-3, -1, 2, 3, 1, -2][step % 6] if state == "run" else 0
    if state in ("jump_rise", "fall", "dash"):
        stride = 3 if step == 0 else 1
    d.line((13 + lean, 32 + oy, 12 - stride, 40), fill=OUTLINE, width=4)
    d.line((19 + lean, 32 + oy, 20 + stride, 40), fill=OUTLINE, width=4)
    d.line((10 - stride, 42, 15 - stride, 42), fill=BONE, width=2)
    d.line((18 + stride, 42, 23 + stride, 42), fill=BONE, width=2)
    # Spool silhouette: rectangular brass reel versus a rounded living spool.
    if identity == "tavi":
        d.rectangle((4 + lean, 20 + oy, 11 + lean, 32 + oy), fill=OUTLINE)
        d.rectangle((5 + lean, 21 + oy, 10 + lean, 31 + oy), fill=spool)
        d.line((6 + lean, 23 + oy, 9 + lean, 23 + oy), fill=BONE)
        d.line((6 + lean, 29 + oy, 9 + lean, 29 + oy), fill=BONE)
    else:
        d.ellipse((3 + lean, 23 + oy, 13 + lean, 34 + oy), fill=OUTLINE)
        d.ellipse((4 + lean, 24 + oy, 12 + lean, 33 + oy), fill=spool)
        d.arc((6 + lean, 26 + oy, 10 + lean, 31 + oy), 0, 300, fill=mantle)
    d.polygon([(11 + lean, 22 + oy), (20 + lean, 21 + oy), (25 + lean, 35 + oy),
               (19 + lean, 37 + oy), (8 + lean, 34 + oy)], fill=OUTLINE)
    d.polygon([(12 + lean, 23 + oy), (19 + lean, 23 + oy), (23 + lean, 34 + oy),
               (18 + lean, 34 + oy), (10 + lean, 32 + oy)], fill=mantle)
    d.line((12 + lean, 30 + oy, 21 + lean, 32 + oy), fill=scarf)
    for stitch in range(3):
        d.point((12 + lean + stitch * 3, 33 + oy), fill=BONE)
    if identity == "tavi":
        d.polygon([(9 + lean, 19 + oy), (10 + lean, 9 + oy), (16 + lean, 6 + oy),
                   (23 + lean, 13 + oy), (22 + lean, 23 + oy)], fill=OUTLINE)
        d.polygon([(11 + lean, 17 + oy), (12 + lean, 10 + oy), (16 + lean, 8 + oy),
                   (21 + lean, 14 + oy), (20 + lean, 22 + oy)], fill=hood)
    else:
        d.polygon([(8 + lean, 22 + oy), (9 + lean, 14 + oy), (12 + lean, 4 + oy),
                   (22 + lean, 11 + oy), (25 + lean, 21 + oy), (17 + lean, 25 + oy)], fill=OUTLINE)
        d.polygon([(10 + lean, 20 + oy), (11 + lean, 14 + oy), (13 + lean, 7 + oy),
                   (21 + lean, 13 + oy), (23 + lean, 20 + oy), (17 + lean, 23 + oy)], fill=hood)
        d.line((13 + lean, 9 + oy, 17 + lean, 17 + oy), fill=spool)
    d.rectangle((15 + lean, 15 + oy, 22 + lean, 20 + oy), fill=SHADOW)
    d.point((20 + lean, 17 + oy), fill=glow)
    d.line((11 + lean, 23 + oy, 22 + lean, 23 + oy), fill=scarf, width=2)
    if identity == "neri":
        d.polygon([(12 + lean, 24 + oy), (8, 27 + oy), (3, 25 + (step % 2)), (8, 30 + oy), (14 + lean, 26 + oy)], fill=scarf)
    hand_y = 27 + oy
    if state == "slash":
        hand_y -= [1, 7, 3, 0][step]
    if state == "special":
        hand_y -= [1, 3, 7, 4][step]
    d.line((20 + lean, 26 + oy, 25, hand_y), fill=hood, width=3)
    if identity == "tavi":
        d.line((25, hand_y, 29, hand_y - 5), fill=BONE, width=2)
        d.line((29, hand_y - 5, 26, hand_y - 5), fill=spool)
        d.rectangle((6 + lean, 32 + oy, 9 + lean, 37 + oy), fill=OUTLINE)
        d.rectangle((7 + lean, 33 + oy, 8 + lean, 36 + oy), fill=glow)
    else:
        d.line((24, hand_y, 30, hand_y - 7), fill=BONE)
        d.point((29, hand_y - 6), fill=glow)
    if state in ("special", "revive"):
        d.arc((22, hand_y - 9, 31, hand_y), 30 + step * 50, 210 + step * 20, fill=glow)
    if state == "hurt":
        d.line((8, 16, 5, 12 + step), fill="#F07865")
    return image


def tile_image(tile_id: str, palette: list[str], variant: int = 0) -> Image.Image:
    image = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(image)
    dark, edge, stone, light, bone, danger, danger_light, deep, mid, bright, gold = palette[:11]
    if tile_id.startswith("one_way") or tile_id.startswith("bridge"):
        left = 2 if tile_id.endswith(("left", "single")) else 0
        right = 13 if tile_id.endswith(("right", "single")) else 15
        d.rectangle((left, 1, right, 4), fill=edge)
        d.line((left, 1, right, 1), fill=bone)
        d.line((left, 3, right, 3), fill=bright)
        d.line((left + 2, 5, right - 2, 5), fill=deep)
        if tile_id.startswith("bridge"):
            for x in range(left + 2, right, 4):
                d.point((x, 2), fill=gold)
        return image
    if tile_id.startswith("hazard"):
        # Shared hooked chevron contour in both material interpretations.
        for x in (0, 8):
            d.polygon([(x, 15), (x + 3, 4), (x + 5, 11), (x + 7, 15)], fill=edge)
            d.line([(x + 1, 13), (x + 3, 6), (x + 5, 13)], fill=danger)
            d.point((x + 3, 6), fill=danger_light)
        return image
    d.rectangle((0, 0, 15, 15), fill=deep if not tile_id.startswith("background") else dark)
    d.polygon([(0, 1), (8, 0), (15, 5), (15, 13), (7, 15), (0, 9)], fill=mid)
    d.polygon([(1, 2), (7, 1), (13, 5), (6, 7), (1, 6)], fill=bright)
    d.line([(0, 9), (6, 7), (15, 9)], fill=deep)
    # Sparse stitched seams, rather than stochastic texture noise.
    shift = variant % 3
    for x in range(2 + shift, 15, 5):
        d.line((x, 11, x + 1, 12), fill=gold)
    if "top" in tile_id:
        d.line((0, 0, 15, 0), fill=bone)
        d.line((0, 1, 15, 1), fill=gold)
    if "bottom" in tile_id:
        d.line((0, 15, 15, 15), fill=edge)
    if "left" in tile_id:
        d.line((0, 0, 0, 15), fill=bone)
    if "right" in tile_id:
        d.line((15, 0, 15, 15), fill=bone)
    if tile_id.startswith("corner_outer"):
        corner = tile_id.rsplit("_", 1)[1]
        cut = [(0, 0), (3, 0), (0, 3)]
        if corner[0] == "b":
            cut = [(x, 15 - y) for x, y in cut]
        if corner[1] == "r":
            cut = [(15 - x, y) for x, y in cut]
        d.polygon(cut, fill=(0, 0, 0, 0))
    if tile_id.startswith("corner_inner"):
        d.line((0, 0, 7, 0), fill=bone)
        d.line((0, 0, 0, 7), fill=bone)
    if tile_id.startswith("seam"):
        if tile_id.endswith(("horizontal", "cross", "knot")):
            d.line((0, 8, 15, 8), fill=bone)
        if tile_id.endswith(("vertical", "cross", "knot")):
            d.line((8, 0, 8, 15), fill=bone)
        if tile_id.endswith("knot"):
            d.polygon([(8, 4), (12, 8), (8, 12), (4, 8)], outline=gold)
    return image


def atlas(root: Path, asset_id: str, images: list[Image.Image], cell: tuple[int, int],
          columns: int, rows: int, origin: tuple[int, int], clips: dict[str, int] | None = None,
          *, filename: str | None = None, diagnostic: bool = False, tile_ids: list[str] | None = None,
          **metadata: object) -> dict:
    width, height = cell
    image = Image.new("RGBA", (columns * (width + 4), rows * (height + 4)))
    rectangles = []
    for index, frame in enumerate(images):
        x, y = index % columns * (width + 4) + 2, index // columns * (height + 4) + 2
        image.paste(frame, (x, y))
        rectangles.append([x, y, width, height])
    animations, index = {}, 0
    for state, count in (clips or {}).items():
        animations[state] = {"frames": list(range(index, index + count)),
                             "ticks": [8 if state == "idle" else 5] * count,
                             "loop": state in ("idle", "run", "walk", "flap", "downed")}
        index += count
    path = root / "assets/generated" / (filename or f"sprites/{asset_id}.png")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    kind = "tile_atlas" if tile_ids is not None else "sprite_atlas"
    extra = {"tile_ids": tile_ids} if tile_ids is not None else {}
    return record(root, asset_id, kind, path, ["assets/source/art/direction.json", "tools/gen/art.py"],
                  diagnostic, size=list(image.size), cell_size=list(cell), origin=list(origin),
                  frames=rectangles, animations=animations, **extra, **metadata)


def diagnostic(root: Path) -> list[dict]:
    direction = json.loads((root / "assets/source/art/direction.json").read_text())
    tiles = [tile_image(name, direction["ember"], index) for index, name in enumerate(TILE_IDS)]
    records = [atlas(root, "diagnostic_terrain_v1", tiles, (16, 16), 8, 6, (0, 0),
                     filename="diagnostic/tiles_diag.png", diagnostic=True, tile_ids=TILE_IDS)]
    for name in ("tavi", "neri"):
        path = root / f"assets/generated/diagnostic/courier_{name}_diag.png"
        courier(name, "idle", 0, direction["couriers"][name]).save(path)
        records.append(record(root, f"fixed_{name}_v1", "sprite_atlas", path,
                              ["assets/source/art/direction.json", "tools/gen/art.py"], True,
                              size=[32, 48], cell_size=[32, 48], origin=[16, 43], frames=[[0, 0, 32, 48]],
                              animations={state: {"frames": [0], "ticks": [8], "loop": True} for state in COURIER_CLIPS}))
    mover = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(mover)
    d.ellipse((3, 10, 28, 28), fill=OUTLINE)
    d.ellipse((5, 11, 26, 26), fill="#BC7852")
    d.arc((9, 13, 23, 25), 10, 320, fill=BONE, width=2)
    d.line((6, 25, 3, 28), fill=BONE)
    d.line((25, 25, 29, 28), fill=BONE)
    path = root / "assets/generated/diagnostic/mover_diag.png"
    mover.save(path)
    records.append(record(root, "diagnostic_mover_v1", "sprite_atlas", path,
                          ["tools/gen/art.py"], True, size=[32, 32], cell_size=[32, 32], origin=[16, 28],
                          frames=[[0, 0, 32, 32]], animations={"idle": {"frames": [0], "ticks": [8], "loop": True}}))
    return records
