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
    shift = variant % 4
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
        corner = tile_id.rsplit("_", 1)[1]
        x, y = (0 if corner[1] == "l" else 15), (0 if corner[0] == "t" else 15)
        dx, dy = (1 if x == 0 else -1), (1 if y == 0 else -1)
        d.line((x, y, x + dx * 7, y), fill=bone)
        d.line((x, y, x, y + dy * 7), fill=bone)
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
          source_files: list[str] | None = None, **metadata: object) -> dict:
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
    sources = ["assets/source/art/direction.json", "tools/gen/art.py"] + (source_files or [])
    return record(root, asset_id, kind, path, sources,
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


PROP_IDS = ["anchor", "anchor_latched", "loom", "loom_lit", "bell", "bell_broken",
            "lantern", "lantern_lit", "sign", "checkpoint", "checkpoint_lit", "spindle",
            "cloth", "root", "glass", "home_bridge", "bobbin", "bench", "banner", "arch", "boat"]
LOGICAL_PROPS = ["anchor", "loom", "bell", "lantern", "sign", "checkpoint", "spindle", "cloth",
                 "root", "glass", "home_bridge", "bobbin", "bench", "banner", "arch", "boat"]
UI_IDS = ["heart_full", "heart_empty", "heart_half", "interact", "jump", "slash", "special", "dash",
          "map", "pause", "partner_up", "partner_downed", "anchor", "bridge", "checkpoint", "boss",
          "secret", "loom", "sound", "home"]
EFFECT_IDS = ["slash", "ember_arc", "spore_impact", "dash", "hit", "weave", "revive", "restoration"]


def prop_image(name: str) -> Image.Image:
    image = Image.new("RGBA", (48, 64))
    d = ImageDraw.Draw(image)
    brass, gold, root, glow = "#845044", "#E3AD6A", "#3E6B51", "#F5CC83"
    lit = name.endswith(("lit", "latched"))
    if name.startswith("anchor"):
        d.polygon([(12, 58), (17, 50), (18, 29), (30, 29), (31, 50), (36, 58)], fill=OUTLINE)
        d.rectangle((20, 30, 28, 54), fill=brass)
        d.ellipse((15, 17, 33, 35), fill=OUTLINE)
        d.ellipse((18, 20, 30, 32), fill=gold)
        d.ellipse((21, 23, 27, 29), fill=glow if lit else SHADOW)
        d.line((14, 57, 34, 57), fill=BONE)
        if lit:
            d.line([(24, 25), (35, 21), (45, 23)], fill=glow)
    elif name.startswith("loom"):
        d.polygon([(3, 58), (8, 8), (39, 8), (44, 58), (35, 58), (33, 18), (14, 18), (12, 58)], fill=OUTLINE)
        d.line((10, 10, 6, 56), fill=gold, width=2)
        d.line((37, 10, 41, 56), fill=gold, width=2)
        d.rectangle((10, 11, 37, 17), fill=brass)
        for x in range(16, 34, 3):
            d.line((x, 18, x, 49), fill=glow if lit else "#41465A")
        for y in range(27, 46, 4):
            d.line((15, y, 34, y), fill="#73965D" if lit else brass)
        d.polygon([(23, 21), (32, 32), (23, 43), (15, 32)], outline=BONE)
        d.rectangle((8, 52, 39, 57), fill=brass)
    elif name.startswith("bell"):
        d.line((24, 3, 24, 16), fill=brass, width=3)
        d.arc((13, 9, 35, 29), 180, 360, fill=gold, width=2)
        d.polygon([(15, 19), (33, 19), (36, 42), (42, 48), (6, 48), (12, 42)], fill=OUTLINE)
        d.polygon([(17, 21), (31, 21), (34, 41), (38, 45), (10, 45), (14, 41)], fill=brass)
        d.line((11, 44, 37, 44), fill=gold, width=2)
        d.ellipse((20, 48, 28, 55), fill=gold)
        if name.endswith("broken"):
            d.line([(27, 21), (21, 29), (27, 34), (22, 44)], fill=SHADOW, width=3)
            d.polygon([(31, 48), (40, 52), (35, 58)], fill=gold)
    elif name.startswith("lantern"):
        d.arc((17, 10, 31, 28), 180, 360, fill=brass, width=2)
        d.rectangle((16, 25, 32, 47), fill=OUTLINE)
        d.polygon([(14, 24), (24, 18), (34, 24)], fill=brass)
        d.rectangle((19, 28, 29, 42), fill=glow if lit else "#41465A")
        d.line((24, 27, 24, 44), fill=brass)
        d.rectangle((16, 45, 32, 49), fill=gold)
    elif name == "sign":
        d.rectangle((22, 27, 25, 58), fill=brass)
        d.polygon([(7, 16), (33, 16), (41, 24), (33, 32), (7, 32)], fill=OUTLINE)
        d.polygon([(9, 18), (32, 18), (37, 24), (32, 29), (9, 29)], fill=gold)
        d.line([(15, 24), (28, 24), (24, 21)], fill=brass, width=2)
    elif name.startswith("checkpoint"):
        d.polygon([(7, 58), (11, 51), (16, 51), (16, 37), (32, 37), (32, 51), (37, 51), (41, 58)], fill=OUTLINE)
        d.rectangle((18, 39, 30, 54), fill=brass)
        d.ellipse((11, 17, 37, 40), fill=OUTLINE)
        d.ellipse((14, 20, 34, 36), fill=glow if lit else "#41465A")
        d.polygon([(24, 22), (31, 29), (24, 35), (17, 29)], outline=gold)
        d.line((24, 11, 24, 20), fill=BONE)
        d.line((14, 57, 34, 57), fill=gold)
    elif name == "spindle":
        d.line((24, 8, 24, 57), fill=gold, width=3)
        d.polygon([(24, 8), (18, 18), (30, 18)], fill=BONE)
        d.ellipse((9, 23, 39, 50), fill=OUTLINE)
        d.ellipse((12, 26, 36, 47), fill=brass)
        d.arc((16, 28, 32, 43), 0, 330, fill=gold, width=2)
    elif name in ("cloth", "banner"):
        d.line((6, 8, 42, 8), fill=brass, width=3)
        d.polygon([(10, 10), (37, 10), (36, 46), (28, 55), (23, 47), (16, 53), (12, 44)], fill="#644258")
        d.polygon([(13, 11), (21, 11), (20, 46), (16, 50)], fill="#A26671")
        d.line((33, 13, 32, 44), fill=BONE)
        if name == "banner":
            d.polygon([(25, 20), (32, 29), (25, 38), (18, 29)], outline=gold)
    elif name == "root":
        for points, width in (([(2, 59), (15, 49), (20, 34), (31, 26), (41, 9)], 5),
                              ([(18, 49), (30, 44), (39, 49), (46, 47)], 3),
                              ([(20, 34), (10, 28), (7, 18)], 3)):
            d.line(points, fill=OUTLINE, width=width + 2)
            d.line(points, fill=root, width=width)
        d.polygon([(29, 27), (27, 15), (36, 18)], fill="#73965D")
        d.polygon([(10, 29), (1, 24), (3, 33)], fill="#73965D")
    elif name == "glass":
        for points in ([(4, 56), (14, 29), (18, 57)], [(19, 56), (30, 14), (32, 53)], [(32, 57), (42, 37), (46, 58)]):
            d.polygon(points, fill="#3C6570", outline=OUTLINE)
            d.line([points[0], points[1]], fill="#6BA49B")
    elif name == "home_bridge":
        d.arc((-4, 15, 52, 74), 190, 350, fill=brass, width=5)
        d.line((0, 38, 47, 38), fill=OUTLINE, width=5)
        for x in range(2, 47, 6):
            d.line((x, 31, x, 45), fill=brass, width=2)
        d.line((0, 31, 47, 31), fill=gold)
    elif name == "bobbin":
        d.ellipse((9, 39, 39, 58), fill=OUTLINE)
        d.rectangle((15, 35, 33, 51), fill="#3C6570")
        d.ellipse((9, 27, 39, 42), fill=brass, outline=gold)
        d.ellipse((21, 31, 27, 36), fill=SHADOW)
        for y in range(40, 51, 3):
            d.line((16, y, 32, y), fill=BONE)
    elif name == "bench":
        d.line((11, 43, 9, 58), fill=brass, width=3)
        d.line((36, 43, 39, 58), fill=brass, width=3)
        d.polygon([(4, 39), (39, 39), (44, 44), (7, 44)], fill=OUTLINE)
        d.line((7, 40, 39, 40), fill=gold, width=2)
    elif name == "arch":
        d.arc((2, 4, 46, 54), 180, 360, fill=OUTLINE, width=8)
        d.arc((5, 7, 43, 51), 180, 360, fill=brass, width=3)
        d.rectangle((2, 28, 8, 58), fill=OUTLINE)
        d.rectangle((40, 28, 46, 58), fill=OUTLINE)
        d.line((7, 29, 7, 57), fill=gold)
        d.line((41, 29, 41, 57), fill=gold)
    elif name == "boat":
        d.polygon([(3, 43), (44, 43), (35, 58), (13, 58)], fill=OUTLINE)
        d.line([(6, 45), (14, 54), (34, 54), (41, 45)], fill=brass, width=2)
        d.line((24, 8, 24, 43), fill=gold)
        d.polygon([(26, 11), (26, 35), (42, 35)], fill="#3C6570")
    return image


def background(theme: str, layer: str, palette: list[str], seed: int) -> Image.Image:
    image = Image.new("RGBA", (480, 360))
    d = ImageDraw.Draw(image)
    recess, outline, stone = palette[:3]
    if layer == "far":
        d.rectangle((0, 0, 479, 359), fill=recess)
        d.polygon([(0, 205), (59, 183), (124, 204), (209, 170), (300, 205), (410, 181), (479, 197), (479, 359), (0, 359)], fill=palette[11])
        # Distant looms are broad, quiet shapes rather than repeated foreground blocks.
        for x, y, width in ((38, 106, 44), (170, 68, 57), (347, 111, 65)):
            d.polygon([(x, 240), (x + 4, y + 24), (x + width // 2, y), (x + width - 5, y + 24), (x + width, 240)], fill=outline)
            d.rectangle((x + 12, y + 35, x + width - 12, 231), fill=recess)
            d.line((x + 5, y + 27, x + width - 5, y + 27), fill=palette[11])
        d.ellipse((374, 24, 410, 60), fill=outline)
        d.ellipse((381, 21, 414, 53), fill=recess)
        for x in (17, 92, 145, 263, 319, 451):
            d.point(((x + seed % 7) % 480, 24 + x % 75), fill=stone)
        for y in range(270, 360, 19):
            d.line((0, y, 479, y), fill=outline)
    elif layer == "middle":
        d.polygon([(0, 286), (30, 271), (65, 279), (97, 248), (159, 266), (188, 250), (231, 273), (279, 258), (339, 276), (395, 246), (447, 263), (479, 245), (479, 359), (0, 359)], fill=outline)
        d.arc((47, 102, 205, 344), 185, 355, fill=stone, width=9)
        d.arc((53, 109, 199, 340), 185, 355, fill=palette[11], width=3)
        d.line((66, 208, 66, 303), fill=stone, width=9)
        d.line((186, 208, 186, 292), fill=stone, width=9)
        d.line([(242, 0), (246, 143), (232, 205), (250, 264)], fill=outline, width=6)
        d.polygon([(251, 77), (310, 79), (303, 195), (278, 212), (253, 190)], fill=palette[11])
        d.line((260, 84, 262, 183), fill=outline, width=3)
        if theme == "moss":
            d.line([(479, 80), (426, 146), (437, 214), (396, 280)], fill=stone, width=8)
            for x, y in ((430, 142), (436, 205), (408, 255)):
                d.polygon([(x, y), (x - 22, y - 24), (x - 3, y - 29)], fill=palette[11])
        else:
            d.line((373, 0, 373, 204), fill=outline, width=3)
            d.polygon([(355, 203), (361, 174), (384, 174), (392, 203)], fill=stone)
            d.line((353, 205, 394, 205), fill=outline, width=4)
    else:
        # Frame the upper corners; do not paint opaque clutter across play surfaces.
        d.polygon([(0, 0), (113, 0), (95, 10), (59, 15), (33, 8), (0, 18)], fill=outline)
        d.polygon([(480, 0), (438, 0), (449, 70), (467, 87), (480, 69)], fill=outline)
        d.line([(0, 0), (12, 72), (5, 115)], fill=palette[11], width=5)
        d.line([(480, 359), (452, 344), (424, 352), (390, 344)], fill=outline, width=7)
        d.line([(0, 359), (31, 344), (67, 351)], fill=outline, width=7)
        d.line((45, 0, 49, 31), fill=stone)
        d.polygon([(44, 30), (54, 30), (58, 46), (40, 46)], fill=palette[11])
    return image


def effect_image(name: str, step: int) -> Image.Image:
    size = 64 if name == "restoration" else 32
    image = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(image)
    centre = size // 2
    glow = "#B5E5B4" if name in ("spore_impact", "revive") else "#F5CC83"
    if name in ("slash", "ember_arc"):
        radius = 6 + step * 2
        d.arc((16 - radius, 16 - radius, 16 + radius, 16 + radius), 280, 430, fill=glow, width=max(1, 4 - step // 2))
        d.arc((17 - radius, 17 - radius, 15 + radius, 15 + radius), 300, 400, fill="#D5D2B8")
        if name == "ember_arc":
            d.line([(14, 12), (23, 6 + step), (21, 14), (30, 17)], fill="#F07865", width=2)
    elif name == "dash":
        for y, length in ((10, 20), (16, 27), (23, 18)):
            x = step * 3
            d.line((max(0, x - length + 12), y, min(31, x + 12), y - 2), fill=glow)
        d.polygon([(17 + step, 11), (26, 16), (17 + step, 23), (20, 16)], outline=BONE)
    elif name in ("spore_impact", "hit"):
        radius = 3 + step * 2
        for index in range(6):
            angle = index * math.pi / 3 + (0.2 if name == "hit" else 0)
            x, y = 16 + round(math.cos(angle) * radius), 16 + round(math.sin(angle) * radius)
            d.line((16 + round(math.cos(angle) * (radius - 3)), 16 + round(math.sin(angle) * (radius - 3)), x, y), fill=glow, width=2)
            if name == "spore_impact":
                d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=glow)
    elif name == "weave":
        for offset, colour in ((-3, "#E3AD6A"), (3, "#B5E5B4")):
            points = [(x, 16 + round(math.sin((x + step * 3) / 5) * (5 - step // 2)) + offset) for x in range(2, 30)]
            d.line(points, fill=colour)
        d.polygon([(16, 9), (22, 16), (16, 23), (10, 16)], outline=BONE)
    elif name == "revive":
        d.arc((3, 3 + step, 29, 29), 180 + step * 22, 420 + step * 22, fill=glow, width=2)
        d.line((16, 9, 16, 23), fill=BONE, width=2)
        d.line((10, 16, 22, 16), fill=BONE, width=2)
    else:
        radius = 7 + step * 4
        d.ellipse((centre - radius, centre - radius, centre + radius, centre + radius), outline=glow, width=2)
        d.polygon([(centre, centre - radius), (centre + radius, centre), (centre, centre + radius), (centre - radius, centre)], outline="#B5E5B4")
        d.line((centre - 4, centre, centre + 4, centre), fill=BONE)
        d.line((centre, centre - 4, centre, centre + 4), fill=BONE)
    return image


def icon_image(name: str) -> Image.Image:
    image = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(image)
    gold, green, danger = "#F5CC83", "#B5E5B4", "#F07865"
    if name.startswith("heart"):
        shape = [(2, 5), (4, 2), (7, 3), (8, 5), (10, 2), (13, 2), (15, 5), (14, 8), (8, 14), (2, 8)]
        d.polygon(shape, fill=danger if name == "heart_full" else OUTLINE, outline=BONE)
        if name == "heart_half":
            d.polygon([(3, 5), (5, 3), (7, 4), (8, 6), (8, 12), (3, 7)], fill=danger)
    elif name in ("interact", "partner_up", "partner_downed"):
        d.ellipse((5, 1, 10, 6), outline=gold)
        d.line((8, 7, 8, 11), fill=gold, width=2)
        d.line((3, 9, 12, 9), fill=gold)
        d.line([(4, 14), (8, 11), (12, 14)], fill=gold)
        if name == "interact":
            d.line((12, 1, 12, 5), fill=green)
            d.line((10, 3, 14, 3), fill=green)
        if name == "partner_downed":
            image = image.transpose(Image.Transpose.ROTATE_90)
    elif name == "jump":
        d.line([(2, 13), (8, 4), (14, 13)], fill=gold, width=2)
        d.line((8, 3, 8, 10), fill=BONE)
    elif name == "slash":
        d.line((3, 13, 12, 3), fill=BONE, width=2)
        d.line((3, 8, 8, 13), fill=gold)
    elif name == "special":
        d.polygon([(8, 1), (10, 6), (15, 8), (10, 10), (8, 15), (6, 10), (1, 8), (6, 6)], fill=green)
    elif name == "dash":
        d.line((1, 5, 9, 5), fill=gold)
        d.line((0, 10, 8, 10), fill=gold)
        d.line([(8, 2), (14, 7), (8, 13)], fill=BONE, width=2)
    elif name == "map":
        d.polygon([(1, 3), (5, 1), (10, 3), (14, 1), (14, 12), (10, 14), (5, 12), (1, 14)], outline=BONE)
        d.line((5, 2, 5, 11), fill=gold)
        d.line((10, 4, 10, 13), fill=gold)
    elif name == "pause":
        d.rectangle((3, 3, 5, 13), fill=BONE)
        d.rectangle((10, 3, 12, 13), fill=BONE)
    elif name in ("anchor", "checkpoint"):
        d.ellipse((3, 1, 12, 10), outline=gold)
        d.line((8, 6, 8, 14), fill=BONE, width=2)
        d.line((3, 14, 13, 14), fill=gold)
        if name == "checkpoint":
            d.point((8, 5), fill=green)
    elif name == "bridge":
        d.line((1, 9, 14, 9), fill=BONE, width=2)
        for x in (2, 6, 10, 14):
            d.line((x, 6, x, 13), fill=gold)
    elif name == "boss":
        d.ellipse((2, 2, 13, 13), outline=danger, width=2)
        d.line((4, 5, 11, 10), fill=gold)
        d.line((11, 5, 4, 10), fill=gold)
    elif name == "secret":
        d.polygon([(8, 1), (14, 7), (8, 14), (2, 7)], outline=gold)
        d.ellipse((5, 4, 10, 9), fill=green)
    elif name == "loom":
        d.rectangle((2, 2, 13, 14), outline=gold)
        for x in (5, 8, 11):
            d.line((x, 3, x, 13), fill=green)
        d.line((3, 8, 12, 8), fill=BONE)
    elif name == "sound":
        d.polygon([(1, 6), (5, 6), (9, 2), (9, 14), (5, 10), (1, 10)], fill=BONE)
        d.arc((6, 3, 14, 13), 280, 80, fill=gold)
    elif name == "home":
        d.polygon([(1, 7), (8, 1), (15, 7)], outline=gold)
        d.rectangle((3, 7, 12, 14), outline=BONE)
        d.rectangle((7, 10, 9, 14), fill=green)
    return image


def production(root: Path, seed: int) -> list[dict]:
    direction = json.loads((root / "assets/source/art/direction.json").read_text())
    records = []
    for name in ("tavi", "neri"):
        frames = [courier(name, state, step, direction["couriers"][name])
                  for state, count in COURIER_CLIPS.items() for step in range(count)]
        records.append(atlas(root, f"fixed_{name}_v1", frames, (32, 48), 8, 4, (16, 43), COURIER_CLIPS))
    for theme in ("ember", "moss"):
        frames = [tile_image(name, direction[theme], index) for index, name in enumerate(TILE_IDS)]
        records.append(atlas(root, f"terrain_{theme}_v1", frames, (16, 16), 8, 6, (0, 0), tile_ids=TILE_IDS))
        for layer in ("far", "middle", "near"):
            image = background(theme, layer, direction[theme], seed)
            path = root / f"assets/generated/backgrounds/{theme}_{layer}.png"
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path)
            records.append(record(root, f"background_{theme}_{layer}_v1", "image", path,
                                  ["assets/source/art/direction.json", "tools/gen/art.py"], size=[480, 360], extent="finite"))
    records.append(atlas(root, "props_v1", [prop_image(name) for name in PROP_IDS], (48, 64), 4, 6, (24, 59),
                         prop_ids=PROP_IDS, logical_props=LOGICAL_PROPS))
    records.append(atlas(root, "ui_v1", [icon_image(name) for name in UI_IDS], (16, 16), 5, 4, (8, 8), icon_ids=UI_IDS))
    for name in EFFECT_IDS:
        size = 64 if name == "restoration" else 32
        records.append(atlas(root, f"effect_{name}_v1", [effect_image(name, step) for step in range(6)],
                             (size, size), 6, 1, (size // 2, size // 2), {"play": 6}))
    return records
