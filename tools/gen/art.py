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

TILE_IDS = [
    'floor_path_1', 'floor_path_2', 'floor_grass_1', 'floor_grass_2',
    'wall_fill_1', 'wall_fill_2', 'wall_fill_3', 'wall_fill_4',
    'wall_edge_north', 'wall_edge_east', 'wall_edge_south', 'wall_edge_west',
    'wall_corner_outer_ne', 'wall_corner_outer_se', 'wall_corner_outer_sw', 'wall_corner_outer_nw',
    'wall_corner_inner_ne', 'wall_corner_inner_se', 'wall_corner_inner_sw', 'wall_corner_inner_nw',
    'water_fill_1', 'water_fill_2', 'water_fill_3', 'water_fill_4',
    'water_edge_north', 'water_edge_east', 'water_edge_south', 'water_edge_west',
    'water_corner_ne', 'water_corner_se', 'water_corner_sw', 'water_corner_nw',
    'bridge_plank_1', 'bridge_plank_2', 'bridge_rail_north', 'bridge_rail_south',
    'seam_rune_1', 'seam_rune_2', 'seam_rune_3', 'seam_rune_4',
    'background_earth_1', 'background_earth_2', 'background_roots_1', 'background_roots_2',
    'hazard_glass_1', 'hazard_glass_2', 'hazard_thread_1', 'hazard_thread_2',
]
OUTLINE, SHADOW, BONE = "#293247", "#10141C", "#D5D2B8"


# Four authored camera-facing banks; sprites are never rotated into a new view.
COURIER_DIRECTIONS = ("down", "left", "right", "up")
COURIER_STATE_COUNTS = {"idle": 4, "run": 6, "slash": 5, "special": 5,
                        "roll": 4, "dash": 2, "hurt": 2, "downed": 2, "revive": 2}
COURIER_CLIPS = {f"{state}_{direction}": count for direction in COURIER_DIRECTIONS
                 for state, count in COURIER_STATE_COUNTS.items()}
# Presentation durations only. Runtime owns hit windows, invulnerability and moves.
COURIER_TICKS = {"idle": [10, 10, 10, 10], "run": [5] * 6,
                 "slash": [3, 3, 3, 3, 6], "special": [4, 4, 3, 4, 7],
                 "roll": [3, 3, 3, 3], "dash": [6, 6], "hurt": [5, 7],
                 "downed": [18, 18], "revive": [6, 10]}


def _courier_weapon(d: ImageDraw.ImageDraw, identity: str, hand: tuple[int, int],
                    angle: float, colours: dict, charged: bool = False) -> None:
    """A hollow cleaving shuttle or needle spindle, drawn in the ground plane."""
    ux, uy = math.cos(angle), math.sin(angle)
    nx, ny = -uy, ux
    def point(length, side=0):
        return (round(hand[0] + ux * length * 7 / 9 + nx * side),
                round(hand[1] + uy * length * 7 / 9 + ny * side))
    if identity == "tavi":
        d.line([point(-2), point(2)], fill=OUTLINE, width=3)
        d.polygon([point(1, -2), point(6, -3), point(9, -1), point(7, 3),
                   point(3, 3), point(4, 1), point(1, 1)], fill=OUTLINE)
        d.polygon([point(2, -1), point(6, -2), point(8), point(6, 2), point(4, 2)],
                  fill=colours["spool"])
        d.line([point(3, -1), point(6, -1)], fill=SHADOW)
        d.line([point(6, -2), point(8), point(6, 2)], fill=colours["glow"] if charged else BONE)
    else:
        d.line([point(-2), point(8)], fill=OUTLINE, width=3)
        d.line([point(-1), point(8)], fill=BONE)
        d.polygon([point(1, -2), point(4, -2), point(5), point(3, 2), point(1, 2)],
                  fill=colours["spool"])
        d.line([point(2, -1), point(4, 1)], fill=colours["mantle"])
        d.point(point(8), fill=colours["glow"])


def courier(identity: str, state: str, step: int, colours: dict) -> Image.Image:
    """Original overhead courier: fixed ground anchor, four explicitly drawn views.

    Bare logical states use down-facing for the diagnostic packet. Source poses
    use no imported character art, image rotation or side-view mirroring.
    """
    direction = "down"
    for candidate in COURIER_DIRECTIONS:
        if state.endswith("_" + candidate):
            state, direction = state[:-(len(candidate) + 1)], candidate
            break
    if identity not in ("tavi", "neri") or state not in COURIER_STATE_COUNTS:
        raise ValueError(f"unknown courier pose: {identity}/{state}/{direction}")
    if not 0 <= step < COURIER_STATE_COUNTS[state]:
        raise ValueError(f"pose index outside clip: {state}/{step}")
    image = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(image)
    hood, mantle, scarf, spool, glow = (colours[k] for k in ("hood", "mantle", "scarf", "spool", "glow"))
    fx, fy = {"down": (0, 1), "left": (-1, 0), "right": (1, 0), "up": (0, -1)}[direction]
    rx, ry = -fy, fx
    # A compact ground contact, never an alpha shadow or collision silhouette.
    if state not in ("roll", "downed"):
        d.ellipse((9, 39, 23, 44), fill=SHADOW)
    if state == "downed":
        # Face and discarded tools remain recoverable, with a loose living thread.
        cx, cy = 16 + fx, 37 + fy
        d.ellipse((cx - 9, cy - 5, cx + 9, cy + 6), fill=OUTLINE)
        d.ellipse((cx - 7, cy - 4, cx + 7, cy + 4), fill=mantle)
        hx, hy = cx + fx * 5, cy + fy * 4 - 2
        d.ellipse((hx - 5, hy - 5, hx + 5, hy + 3), fill=hood, outline=OUTLINE)
        d.line((cx - 6, cy + 1, cx + 5, cy + 4), fill=scarf, width=2)
        if direction != "up":
            d.line((hx - 2 + fx, hy + 1, hx + 1 + fx, hy + 1), fill=SHADOW)
        d.ellipse((cx - rx * 6 - 2, cy - ry * 3 - 2, cx - rx * 6 + 2, cy - ry * 3 + 2), fill=spool)
        d.line([(cx, cy - 5), (cx - 1, cy - 10), (cx + 2 + step, cy - 12 - step)], fill=glow)
        d.point((cx + 2 + step, cy - 13 - step), fill=BONE)
        _courier_weapon(d, identity, (16 - fx * 5, 37 - fy * 3), math.atan2(fy, fx) + 1.2, colours)
        return image
    if state == "roll":
        # Visible somersault phases, not a rotated standing sprite. The spool is
        # the persistent identity cue while hood, soles and cloth exchange depth.
        cx, cy = 16 + fx * (-1, 0, 1, 0)[step], 35 + fy * (-1, 0, 1, 0)[step]
        width, height = ((8, 7), (7, 9), (9, 6), (8, 8))[step]
        d.ellipse((cx - width, cy - height, cx + width, cy + height), fill=OUTLINE)
        d.ellipse((cx - width + 2, cy - height + 1, cx + width - 1, cy + height - 2), fill=hood if step in (0, 3) else mantle)
        d.arc((cx - 6, cy - 6, cx + 6, cy + 6), 35 + step * 85, 230 + step * 85, fill=scarf, width=3)
        sx, sy = cx - fx * 3 + rx * 3, cy - fy * 3 + ry * 2
        d.ellipse((sx - 3, sy - 3, sx + 3, sy + 3), fill=spool, outline=OUTLINE)
        d.line((sx - 1, sy - 2, sx - 1, sy + 2), fill=BONE)
        if step in (1, 2):
            for side in (-1, 1):
                bx, by = cx + rx * side * 4, cy + ry * side * 3 - 5
                d.line((bx, by, bx + fx * 3, by + fy * 3), fill=BONE, width=2)
        else:
            d.point((cx + fx * 3, cy + fy * 4), fill=glow)
        d.line([(cx - fx * 8, cy - fy * 7), (cx - fx * 10 + rx * 2, cy - fy * 10 + ry * 2)], fill=scarf)
        return image

    bob = {"idle": (0, 0, 1, 0), "run": (0, -1, 0, 1, -1, 0),
           "revive": (4, 1), "hurt": (1, 0), "dash": (2, 1)}.get(state, (0,) * COURIER_STATE_COUNTS[state])[step]
    recoil = (-2, -3, 1, 2, 0)[step] if state == "special" else 0
    lean = (0, -1, 2, 2, 1)[step] if state == "slash" else (3 if state == "dash" else recoil)
    cx, cy = 16 + fx * lean, 31 + bob + fy * lean
    # Cloth falls behind movement; each view keeps its own backpack/face layering.
    tail = (-2, -1, 1, 3, 1, -1)[step] if state == "run" else (step % 3 - 1)
    if state in ("dash", "slash", "special"):
        tail += 3
    tx, ty = cx - fx * (9 if state == "dash" else 6), cy - fy * 4 + 4
    d.polygon([(cx - 3, cy - 3), (tx + rx * 4, ty + ry * 3),
               (tx + rx * (6 + tail), ty + ry * 4 + 3), (tx - rx * 2, ty + 1), (cx + 3, cy)],
              fill=OUTLINE)
    d.line([(cx - 2, cy - 2), (tx + rx * 3, ty + ry * 2), (tx + rx * (5 + tail), ty + ry * 3 + 2)], fill=scarf, width=2)
    # Six independent steps around a fixed foot origin, including diagonal-view gait.
    stride = (-3, -1, 2, 3, 1, -2)[step] if state == "run" else (2 if state == "dash" else 0)
    for side in (-1, 1):
        hip = (cx + side * 4, cy + 5)
        bx = 16 + side * 4 + fx * stride * side
        by = 41 + fy * stride * side // 2 - (1 if state == "run" and stride * side < 0 else 0)
        if state == "revive" and step == 0:
            by, bx = 42, 16 + side * 6
        d.line([hip, (bx, by)], fill=OUTLINE, width=4)
        d.line((bx - 2, by, bx + 2, by), fill=BONE, width=2)
    # Short shoulder cape, foreshortened hem and visible belt give a ground-plane view.
    d.polygon([(cx - 6, cy - 7), (cx + 6, cy - 7), (cx + 9, cy + 4),
               (cx + 5, cy + 9), (cx - 6, cy + 8), (cx - 9, cy + 3)], fill=OUTLINE)
    d.polygon([(cx - 5, cy - 5), (cx + 5, cy - 5), (cx + 7, cy + 3),
               (cx + 3, cy + 6), (cx - 6, cy + 5)], fill=mantle)
    d.line([(cx - 6, cy + 4), (cx, cy + 6), (cx + 5, cy + 4)], fill=scarf)
    for x in (-4, 0, 4):
        d.point((cx + x, cy + 5), fill=BONE)
    pack_x = cx - fx * 4 - rx * 5
    pack_y = cy - fy * 3 + 1
    # Rectangular brass reel / living circular spool are deliberately different.
    if identity == "tavi":
        d.rounded_rectangle((pack_x - 3, pack_y - 5, pack_x + 3, pack_y + 4), radius=1, fill=OUTLINE)
        d.rectangle((pack_x - 2, pack_y - 4, pack_x + 2, pack_y + 3), fill=spool)
        d.line((pack_x - 2, pack_y - 3, pack_x + 2, pack_y - 3), fill=BONE)
        d.line((pack_x - 2, pack_y + 2, pack_x + 2, pack_y + 2), fill=BONE)
    else:
        d.ellipse((pack_x - 4, pack_y - 4, pack_x + 4, pack_y + 4), fill=OUTLINE)
        d.ellipse((pack_x - 3, pack_y - 3, pack_x + 3, pack_y + 3), fill=spool)
        d.arc((pack_x - 2, pack_y - 2, pack_x + 2, pack_y + 2), 0, 290, fill=mantle)
    # Large visible crown with a small face plane: the overhead projection is
    # authored per direction, rather than four rotations of a side-view head.
    hx, hy = cx + fx, cy - 10
    if identity == "tavi":
        d.polygon([(hx - 8, hy + 3), (hx - 8, hy - 4), (hx - 4, hy - 8),
                   (hx + 4, hy - 8), (hx + 8, hy - 4), (hx + 8, hy + 4), (hx, hy + 7)], fill=OUTLINE)
        d.polygon([(hx - 6, hy + 2), (hx - 6, hy - 3), (hx - 3, hy - 6),
                   (hx + 4, hy - 6), (hx + 6, hy - 2), (hx + 6, hy + 3), (hx, hy + 5)], fill=hood)
        d.line([(hx - 4, hy - 4), (hx, hy - 5), (hx + 3, hy - 3)], fill=BONE)
    else:
        d.polygon([(hx - 8, hy + 4), (hx - 9, hy - 2), (hx - 6, hy - 8),
                   (hx - 2, hy - 6), (hx + 2, hy - 10), (hx + 5, hy - 6),
                   (hx + 9, hy - 4), (hx + 8, hy + 4), (hx, hy + 7)], fill=OUTLINE)
        d.polygon([(hx - 6, hy + 2), (hx - 7, hy - 2), (hx - 5, hy - 6),
                   (hx - 1, hy - 4), (hx + 2, hy - 8), (hx + 4, hy - 4),
                   (hx + 7, hy - 2), (hx + 6, hy + 3), (hx, hy + 5)], fill=hood)
        d.line([(hx + 2, hy - 7), (hx, hy - 1), (hx + 3, hy + 3)], fill=spool)
        d.line((hx - 5, hy - 5, hx - 2, hy - 1), fill=mantle)
    if direction == "down":
        d.polygon([(hx - 5, hy + 1), (hx + 5, hy + 1), (hx + 4, hy + 5), (hx - 3, hy + 5)], fill=SHADOW)
        for x in (-3, 3):
            d.point((hx + x, hy + 3), fill=glow)
    elif direction in ("left", "right"):
        d.polygon([(hx + fx * 3, hy - 1), (hx + fx * 7, hy),
                   (hx + fx * 8, hy + 3), (hx + fx * 3, hy + 5)], fill=SHADOW)
        d.point((hx + fx * 6, hy + 1), fill=glow)
        d.line((hx - fx * 4, hy - 2, hx - fx * 3, hy + 3), fill=scarf)
    else:
        # Back-facing seam and fastener; never paint eyes on the rear crown.
        d.line([(hx - 3, hy - 5), (hx - 1, hy), (hx, hy + 5)], fill=mantle)
        d.rectangle((hx - 2, hy + 4, hx + 2, hy + 5), fill=scarf)
        d.point((hx, hy + 4), fill=BONE)
    d.line((cx - 5, cy - 3, cx + 5, cy - 3), fill=scarf, width=2)
    if identity == "tavi":
        lx, ly = cx + rx * 6 + fx * 2, cy + ry * 3 + 4
        d.rectangle((lx - 2, ly - 2, lx + 2, ly + 3), fill=OUTLINE)
        d.rectangle((lx - 1, ly - 1, lx + 1, ly + 1), fill=glow)
        d.point((lx, ly - 1), fill=BONE)
    # Weapons have a genuine backswing, two active poses and held follow-through.
    base_angle = math.atan2(fy, fx)
    arm_angle = base_angle + (-.45 if identity == "tavi" else .35)
    if state == "run":
        arm_angle += (-.28, -.1, .18, .32, .1, -.18)[step]
    if state == "slash":
        arm_angle = base_angle + (-1.9, -1.25, -.2, .85, 1.2)[step]
    elif state == "special":
        arm_angle = base_angle + ((-1.3, -1.65, -.2, .65, .9)[step] if identity == "tavi" else (-.6, -.3, 0, .2, .5)[step])
    elif state in ("dash", "hurt"):
        arm_angle = base_angle + 1.7 + step * .2
    arm_center = (cx, cy - (5 if direction == "up" else 0))
    hand = (round(arm_center[0] + math.cos(arm_angle) * 4), round(arm_center[1] + math.sin(arm_angle) * 4))
    d.line([arm_center, hand], fill=OUTLINE, width=4)
    d.line([arm_center, hand], fill=hood, width=2)
    _courier_weapon(d, identity, hand, arm_angle, colours, state == "special" and step in (1, 2, 3))
    if state in ("slash", "special") and step in (2, 3):
        # Embedded small arc complements, but cannot replace, the runtime effect.
        points = [(round(cx + math.cos(base_angle + angle) * 11), round(cy + math.sin(base_angle + angle) * 10))
                  for angle in (-.75, -.35, 0, .35, .65)]
        d.line(points, fill=glow, width=2 if identity == "tavi" else 1)
    if state == "special" and identity == "neri":
        # Spore cast gathers a seed, opens a fan, then recoils with trailing cloth.
        sx, sy = round(cx + fx * (7 + min(step, 2))), round(cy + fy * (7 + min(step, 2)))
        radius = (1, 3, 4, 2, 1)[step]
        d.ellipse((sx - radius, sy - radius, sx + radius, sy + radius), fill=mantle, outline=glow)
        d.line((sx, sy - radius, sx, sy + radius), fill=spool)
        for offset in (-1, 1):
            d.point((sx + rx * (radius + 2) * offset, sy + ry * (radius + 2) * offset), fill=BONE)
    if state == "hurt":
        d.line((cx - 9, cy - 10, cx - 11, cy - 13 + step), fill="#F07865")
        d.line((cx + 7, cy - 14, cx + 10, cy - 16 + step), fill=BONE)
    if state == "revive":
        for side in (-1, 1):
            x = cx + side * (7 + step)
            d.line((x, 38, x, 33 - step * 5), fill=glow)
            d.point((x, 31 - step * 5), fill=BONE)
    # Idle cloth and lantern breathe without moving the world/foot origin.
    if state == "idle":
        d.line((cx - 3, cy + 6, cx - 1 + step, cy + 7), fill=scarf)
    return image



def tile_image(tile_id: str, palette: list[str], variant: int = 0) -> Image.Image:
    """Opaque overhead material tiles; geometry and collision remain room data.

    Edges/corners separate two opaque ground materials inside a complete cell.
    No old side-view one-way/transparent terrain semantics survive this recipe.
    """
    if tile_id not in TILE_IDS:
        raise ValueError(f"unknown overhead terrain slot: {tile_id}")
    dark,edge,stone,light,bone,danger,danger_light,deep,mid,bright,gold=palette[:11]
    water_dark,water_mid,water_light,reflection=palette[11:15]
    image=Image.new("RGBA",(16,16),edge);d=ImageDraw.Draw(image)
    n=int(tile_id[-1])-1 if tile_id[-1].isdigit() else variant%4

    def path_floor():
        d.rectangle((0,0,15,15),fill=edge)
        d.polygon([(0,1),(8,0),(15,3),(14,14),(6,15),(0,12)],fill=stone)
        if n%2:
            d.line([(0,8),(6,8),(8,15)],fill=edge)
            d.line([(9,0),(9,6),(15,7)],fill=edge)
            d.line((1,2,5,2),fill=light)
        else:
            d.line([(0,6),(8,5),(10,0)],fill=edge)
            d.line([(8,5),(9,12),(15,12)],fill=edge)
            d.line((2,9,5,10),fill=light)

    def wall():
        d.rectangle((0,0,15,15),fill=deep)
        # Broad cap stones with a regular, deliberately staggered mortar seam.
        split=5+n%3
        d.rectangle((0,0,15,6),fill=mid)
        d.rectangle((0,8,split,15),fill=bright)
        d.rectangle((split+2,8,15,15),fill=mid)
        d.line((0,0,15,0),fill=gold)
        d.line((0,8,split,8),fill=gold)
        d.line((split+2,9,15,9),fill=bright)
        d.line((2+n,2,6+n,2),fill=bright)
        d.point((12-n,12),fill=gold)

    def water():
        d.rectangle((0,0,15,15),fill=water_dark)
        d.polygon([(0,3),(5,2),(9,5),(15,4),(15,12),(8,14),(0,11)],fill=water_mid)
        y=4+n%3
        d.line([(1,y),(4,y-1),(7,y),(10,y-1)],fill=water_light)
        d.line([(7,10+n%2),(10,9+n%2),(14,10+n%2)],fill=water_light)
        d.line((2+n,12,4+n,12),fill=reflection)

    if tile_id.startswith("floor_path"):
        path_floor()
    elif tile_id.startswith("floor_grass"):
        d.rectangle((0,0,15,15),fill=deep)
        d.polygon([(0,2),(7,0),(14,3),(15,9),(10,14),(2,15),(0,10)],fill=mid)
        # Three designed tufts and a quiet worn centre; never per-pixel noise.
        for x,y in ((3+n*2,4),(11-n,8),(5+n,13)):
            d.line([(x-2,y-1),(x,y+1),(x+1,y-3)],fill=bright)
        d.line((8,3,10,3),fill=gold)
    elif tile_id.startswith("wall_fill"):
        wall()
    elif tile_id.startswith("wall_edge"):
        wall(); side=tile_id.rsplit("_",1)[1]
        if side=="north":
            d.rectangle((0,0,15,3),fill=stone);d.line((0,4,15,4),fill=bone);d.line((0,5,15,5),fill=gold)
        elif side=="east":
            d.rectangle((12,0,15,15),fill=stone);d.line((11,0,11,15),fill=bone);d.line((10,0,10,15),fill=gold)
        elif side=="south":
            d.rectangle((0,12,15,15),fill=stone);d.line((0,11,15,11),fill=dark);d.line((0,10,15,10),fill=gold)
        else:
            d.rectangle((0,0,3,15),fill=stone);d.line((4,0,4,15),fill=bone);d.line((5,0,5,15),fill=gold)
    elif tile_id.startswith("wall_corner"):
        wall();corner=tile_id.rsplit("_",1)[1]
        east,north="e" in corner,"n" in corner
        def corner_point(x,y):return (15-x if east else x,y if north else 15-y)
        if "outer" in tile_id:
            shape=[corner_point(x,y) for x,y in ((0,0),(15,0),(15,3),(6,3),(3,6),(3,15),(0,15))]
            d.polygon(shape,fill=stone)
            d.line([corner_point(x,y) for x,y in ((15,4),(6,4),(4,6),(4,15))],fill=bone,width=1)
        else:
            d.polygon([corner_point(x,y) for x,y in ((0,0),(6,0),(6,4),(4,6),(0,6))],fill=stone)
            d.line([corner_point(x,y) for x,y in ((7,0),(7,4),(4,7),(0,7))],fill=bone)
    elif tile_id.startswith("water_fill"):
        water()
    elif tile_id.startswith("water_edge"):
        water();side=tile_id.rsplit("_",1)[1]
        if side=="north":
            d.rectangle((0,0,15,3),fill=stone);d.line([(0,4),(4,4),(6,5),(11,4),(15,4)],fill=reflection)
        elif side=="east":
            d.rectangle((12,0,15,15),fill=stone);d.line([(11,0),(11,5),(10,7),(11,12),(11,15)],fill=reflection)
        elif side=="south":
            d.rectangle((0,12,15,15),fill=stone);d.line([(0,11),(5,11),(7,10),(12,11),(15,11)],fill=reflection)
        else:
            d.rectangle((0,0,3,15),fill=stone);d.line([(4,0),(4,4),(5,6),(4,11),(4,15)],fill=reflection)
    elif tile_id.startswith("water_corner"):
        water();corner=tile_id.rsplit("_",1)[1]
        east,north="e" in corner,"n" in corner
        def corner_point(x,y):return (15-x if east else x,y if north else 15-y)
        d.polygon([corner_point(x,y) for x,y in ((0,0),(15,0),(15,3),(7,3),(3,7),(3,15),(0,15))],fill=stone)
        d.line([corner_point(x,y) for x,y in ((15,4),(7,4),(4,7),(4,15))],fill=reflection)
    elif tile_id.startswith("bridge_"):
        d.rectangle((0,0,15,15),fill=deep)
        for y in (0,8):
            d.rectangle((0,y,15,y+6),fill=mid)
            d.line((0,y,15,y),fill=gold)
            d.line((2+n%2,y+3,8+n%3,y+3),fill=bright)
            d.line((11,y+4,14,y+4),fill=deep)
            for x in (1,14):d.point((x,y+2),fill=bone)
        if "rail" in tile_id:
            y=1 if tile_id.endswith("north") else 11
            d.rectangle((0,y,15,y+3),fill=edge)
            d.line((0,y,15,y),fill=bone)
            d.line((0,y+1,15,y+1),fill=gold)
            for x in (3,12):d.rectangle((x,y-1,x+1,y+4),fill=bright)
    elif tile_id.startswith("seam_rune"):
        path_floor()
        runes=[[(4,3),(11,3),(11,11),(5,11),(5,6),(8,6)],
               [(3,5),(8,2),(12,6),(8,12),(4,9),(7,6)],
               [(3,3),(12,12),(12,4),(4,12)],
               [(3,8),(8,3),(12,8),(8,12),(8,5)]]
        points=runes[n%4]
        d.line(points,fill=deep,width=3)
        d.line(points,fill=gold)
        d.point(points[0],fill=bone)
    elif tile_id.startswith("background_earth"):
        d.rectangle((0,0,15,15),fill=dark)
        d.polygon([(0,2),(6,1+n),(14,4),(15,12),(7,14),(1,11)],fill=deep)
        d.line([(1,8),(5,7),(9,9),(14,8)],fill=edge)
        d.line((3+n,3,6+n,4),fill=mid)
    elif tile_id.startswith("background_roots"):
        d.rectangle((0,0,15,15),fill=dark)
        d.polygon([(0,3),(7,1),(15,5),(15,14),(3,15)],fill=deep)
        roots=[[(2+n,0),(5,5),(4,10),(8,15)],[(15,3+n),(9,6),(7,11),(0,13)]]
        for points in roots:
            d.line(points,fill=mid,width=3);d.line(points,fill=bright)
        d.line((5,5,1,7+n),fill=mid)
    elif tile_id.startswith("hazard_glass"):
        d.rectangle((0,0,15,15),fill=dark)
        d.ellipse((1,5,14,14),fill=edge)
        for x,y,h in ((4+n,10,7),(10,12,10-n)):
            d.polygon([(x-3,y),(x,y-h),(x+3,y-2),(x,y+2)],fill=danger,outline=edge)
            d.line((x,y-h+1,x+1,y-1),fill=danger_light)
            d.point((x,y-h),fill=bone)
        d.line((1,14,5,14),fill=danger)
    else:  # hazard_thread: taut barbed fibres have a shared danger contour.
        d.rectangle((0,0,15,15),fill=dark)
        d.polygon([(0,3),(7,0),(15,4),(15,13),(5,15),(0,11)],fill=edge)
        points=[(0,12-n),(5,5),(10,10),(15,2+n)]
        d.line(points,fill=danger,width=2)
        for x,y in ((5,5),(10,10)):
            d.line((x-2,y-2,x+2,y+2),fill=danger_light)
            d.line((x-2,y+1,x+1,y-2),fill=danger_light)
            d.point((x,y),fill=bone)
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
                             "ticks": list(COURIER_TICKS[state.rsplit("_", 1)[0]]) if state in COURIER_CLIPS else [8 if state == "idle" else 5] * count,
                             "loop": state.rsplit("_", 1)[0] in ("idle", "run", "downed") if state in COURIER_CLIPS else state in ("idle", "run", "walk", "flap", "downed")}
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
    """Six-frame ground-plane effects; directional art points along local +X."""
    if name not in EFFECT_IDS or not 0 <= step < 6:
        raise ValueError(f"unknown effect frame: {name}/{step}")
    size=64 if name=="restoration" else 32
    image=Image.new("RGBA",(size,size));d=ImageDraw.Draw(image)
    gold,green,danger="#F5CC83","#B5E5B4","#F07865"
    if name in ("slash","ember_arc"):
        radius=(6,10,13,14,13,12)[step]
        width=(2,4,5,4,2,1)[step]
        span=(.35,.7,1.1,1.0,.7,.4)[step]
        def arc_points(r):
            return [(round(15+math.cos(a)*r),round(16+math.sin(a)*r))
                    for a in [-span+i*span/6 for i in range(13)]]
        outer=arc_points(radius);inner=arc_points(radius-width)
        d.polygon(outer+list(reversed(inner)),fill=danger if name=="ember_arc" else gold)
        d.line(outer,fill=gold if name=="ember_arc" else BONE,width=1)
        if name=="ember_arc":
            # A cleaved seam and hot cinders, never a stationary lightning zigzag.
            d.line(inner,fill="#E3AD6A")
            for side in (-1,1):
                x,y=19+step,16+side*(5+step)
                d.polygon([(x-2,y),(x,y-side*2),(x+3,y-side),(x+1,y+side)],fill=gold)
        if step in (1,2,3):d.line((18,16,23+step,16),fill=BONE)
    elif name=="dash":
        # Three separate woven ribbons trail behind the local +X burst.
        head=(18,23,27,27,24,20)[step]
        for lane,colour in ((-6,gold),(0,BONE),(6,"#6BA49B")):
            start=2+step*2
            d.line([(start,16+lane),(max(start+2,head-8),15+lane),(head,16+lane//2)],fill=colour,width=2 if step<4 else 1)
        d.polygon([(head-4,10),(head+2,16),(head-4,22),(head-1,16)],outline=gold)
    elif name=="spore_impact":
        radius=(2,5,8,11,12,13)[step]
        pod=(2,3,3,2,1,1)[step]
        for i in range(6):
            angle=i*math.pi/3+.12*step
            x,y=16+round(math.cos(angle)*radius),16+round(math.sin(angle)*radius)
            d.ellipse((x-pod,y-pod,x+pod,y+pod),fill="#3E6B51",outline=green)
            d.point((x,y-1),fill=BONE)
        if step<4:
            d.polygon([(16,11-step),(20+step,16),(16,21+step),(12-step,16)],outline="#BCD184")
    elif name=="hit":
        radius=(4,8,12,13,10,6)[step]
        inner=(2,3,4,3,2,1)[step]
        points=[]
        for i in range(16):
            angle=i*math.pi/8
            r=radius if i%4==0 else (radius*.65 if i%2==0 else inner)
            points.append((16+round(math.cos(angle)*r),16+round(math.sin(angle)*r)))
        d.polygon(points,fill=gold if step<3 else danger)
        d.line((16-inner,16,16+inner,16),fill=BONE)
        d.line((16,16-inner,16,16+inner),fill=BONE)
    elif name=="weave":
        for offset,colour in ((-2,gold),(2,green)):
            points=[(x,16+round(math.sin((x+step*3)/5)*(5-step//2))+offset) for x in range(2,30)]
            d.line(points,fill=colour,width=2 if step in (2,3) else 1)
        radius=(6,7,8,7,6,5)[step]
        d.polygon([(16,16-radius),(16+radius,16),(16,16+radius),(16-radius,16)],outline=BONE)
        d.point((16+step-2,16),fill=gold)
    elif name=="revive":
        # Returning threads climb to a compact living knot over the ground ring.
        lift=(0,2,4,6,8,10)[step]
        d.arc((3,12,29,29),190+step*20,470+step*20,fill=green,width=2)
        for side in (-1,1):
            d.line([(16+side*8,23),(16+side*5,19-lift//2),(16+side*2,16-lift)],fill=green)
        y=17-lift
        d.polygon([(16,y-3),(19,y),(16,y+4),(13,y)],fill="#3E6B51",outline=BONE)
    else:
        radius=(7,11,16,21,26,29)[step]
        d.ellipse((32-radius,32-radius//2,32+radius,32+radius//2),outline=gold,width=2)
        for i in range(8):
            angle=i*math.pi/4
            x,y=32+round(math.cos(angle)*radius),32+round(math.sin(angle)*radius)
            d.line((32+round(math.cos(angle)*(radius-5)),32+round(math.sin(angle)*(radius-5)),x,y),fill=green if i%2 else gold)
        knot=5+step//2
        d.polygon([(32,32-knot),(32+knot,32),(32,32+knot),(32-knot,32)],outline=BONE,width=2)
        d.line((32-knot,32,32+knot,32),fill=gold)
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
        records.append(atlas(root, f"fixed_{name}_v1", frames, (32, 48), 8, 16, (16, 43), COURIER_CLIPS))
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
