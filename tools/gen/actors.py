"""Original pixel recipes for Oru, two ordinary enemies and the Spoolwarden.

Palette and per-frame poses are retained in actors.json. These are presentation
poses only: no hitbox, attack timing or gameplay tuning comes from this module.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

from .art import atlas, OUTLINE, SHADOW, BONE


CLIPS = {
    "oru": {"idle": 4, "talk": 2, "acknowledge": 2},
    "spoolmite": {"idle": 2, "walk": 4, "anticipation": 2, "charge": 2, "recovery": 2, "defeat": 4},
    "wickwing": {"flap": 4, "anticipation": 2, "dive": 2, "recovery": 2, "defeat": 4},
    "spoolwarden": {
        "idle": 4, "sweep_anticipation": 2, "sweep_active": 2, "sweep_recovery": 2,
        "strike_anticipation": 2, "strike_active": 2, "strike_recovery": 2,
        "charge_anticipation": 2, "charge_active": 2, "charge_recovery": 2,
        "stagger": 4, "defeat": 6,
    },
}
GEOMETRY = {
    "oru": ((32, 48), (16, 43), 1),
    "spoolmite": ((32, 32), (16, 28), 2),
    "wickwing": ((32, 32), (16, 28), 2),
    "spoolwarden": ((64, 64), (32, 59), 4),
}
SOURCES = ["tools/gen/actors.py", "assets/source/art/actors.json"]


def _oru(state: str, pose: dict, p: dict) -> Image.Image:
    image = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(image)
    bob, hem, sway = pose["bob"], pose["hem"], pose["lantern_sway"]
    lift = pose["staff_lift"]
    # Broad, weighted rain cape and little boots anchor this keeper at the feet.
    d.rounded_rectangle((8, 38, 15, 42), radius=1, fill=OUTLINE)
    d.rounded_rectangle((18, 38, 24, 42), radius=1, fill=OUTLINE)
    d.line((9, 41, 14, 41), fill=p["brass"])
    d.line((19, 41, 23, 41), fill=p["brass"])
    d.polygon([(10, 19 + bob), (20, 18 + bob), (25, 24 + bob), (28, 38),
               (21, 41 - hem), (14, 39), (6, 41), (2, 37), (6, 25 + bob)], fill=OUTLINE)
    d.polygon([(10, 21 + bob), (19, 20 + bob), (23, 26 + bob), (25, 37),
               (19, 38 - hem), (12, 36), (5, 38), (7, 27 + bob)], fill=p["cape"])
    d.polygon([(10, 23 + bob), (14, 27 + bob), (13, 36), (5, 38), (7, 29 + bob)], fill=p["cape_dark"])
    d.line([(20, 23 + bob), (20, 30 + bob), (23, 35)], fill=p["cape_light"])
    d.line([(6, 34), (13, 33 + bob), (21, 35), (25, 34)], fill=p["cape_dark"])
    for x, y in ((6, 36), (9, 36), (12, 35), (16, 36), (20, 37), (23, 36)):
        d.line((x, y, x + 1, y), fill=BONE)
    # A patched woven hood, copper spectacles and a warm face, looking right.
    d.polygon([(8, 19 + bob), (7, 10 + bob), (11, 6 + bob), (19, 6 + bob),
               (24, 12 + bob), (24, 20 + bob), (15, 23 + bob)], fill=OUTLINE)
    d.polygon([(9, 17 + bob), (9, 11 + bob), (12, 8 + bob), (18, 8 + bob),
               (22, 12 + bob), (20, 21 + bob), (13, 20 + bob)], fill=p["cape_dark"])
    d.polygon([(15, 12 + bob), (22, 12 + bob), (24, 16 + bob), (21, 20 + bob),
               (15, 19 + bob)], fill=p["face"])
    d.line((10, 11 + bob, 13, 9 + bob), fill=p["cape_light"])
    d.rectangle((13, 13 + bob, 17, 16 + bob), outline=p["brass"])
    d.rectangle((19, 13 + bob, 23, 16 + bob), outline=p["brass"])
    d.line((17, 14 + bob, 19, 14 + bob), fill=p["brass"])
    for x in (16, 22):
        d.point((x, 15 + bob), fill=SHADOW)
    mouth_y = 18 + bob
    if state == "talk":
        d.rectangle((19, mouth_y, 21, mouth_y + pose["mouth"]), fill=SHADOW)
    else:
        d.line((19, mouth_y, 21, mouth_y), fill=p["cape_dark"])
    # A hand at the centre, the other holding a tall staff with a crooked lamp.
    hand_y = 28 + pose["hand"]
    d.line([(20, 24 + bob), (22, hand_y), (27, hand_y - 1)], fill=OUTLINE, width=4)
    d.line((22, hand_y, 26, hand_y - 1), fill=p["face"], width=2)
    d.line([(28, 42), (27, 27), (28, 12 - lift)], fill=OUTLINE, width=3)
    d.line([(28, 41), (28, 28), (29, 13 - lift)], fill=p["wood"])
    d.line([(28, 12 - lift), (25 + sway, 10 - lift), (23 + sway, 12 - lift)], fill=p["brass"])
    lamp_x, lamp_y = 22 + sway, 13 - lift
    d.rectangle((lamp_x, lamp_y, lamp_x + 5, lamp_y + 8), fill=OUTLINE)
    d.rectangle((lamp_x + 1, lamp_y + 2, lamp_x + 4, lamp_y + 6), fill=p["glow"])
    d.line((lamp_x + 2, lamp_y + 1, lamp_x + 2, lamp_y + 7), fill=p["brass"])
    d.point((lamp_x + 4, lamp_y + 2), fill=BONE)
    if state == "acknowledge":
        d.line([(8, 27 + bob), (5, 24 - pose["hand"]), (8, 21 - pose["hand"])], fill=p["face"], width=2)
        d.point((18, 9 + bob), fill=BONE)
    return image


def _spoolmite(state: str, pose: dict, p: dict) -> Image.Image:
    image = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(image)
    cx, cy = 15 + pose["dx"], 18 + pose["bob"]
    stride, crouch = pose["stride"], pose["crouch"]
    cy += crouch
    if state == "defeat":
        spread = pose["unwind"]
        d.line([(cx - 8, 25), (cx - 12, 27), (cx - 5, 28), (cx + 2, 26),
                (cx + 7 + spread, 28 - spread % 2)], fill=p["thread"])
        d.ellipse((cx - 7, 23 - spread, cx + 7, 28), fill=OUTLINE)
        d.ellipse((cx - 5, 24 - spread, cx + 5, 27), fill=p["wood"])
        d.arc((cx - 5, 22 - spread, cx + 5, 27), 190 + spread * 20, 530 - spread * 10, fill=p["brass"])
        d.line((cx + 6, 24, cx + 10 + spread, 25 - spread), fill=p["wood_light"], width=2)
        d.point((cx - 9 - spread, 26 - spread), fill=p["brass"])
        return image
    # Six jointed feet carry a wound wooden reel, rather than a generic blob.
    for side, direction in ((-1, -1), (1, 1)):
        for leg in range(3):
            hip_x = cx + side * (2 + leg * 3)
            knee_x = hip_x + direction * 4
            foot_x = max(1, min(30, knee_x + (stride if leg % 2 == 0 else -stride)))
            knee_y = 23 + (leg % 2) + crouch // 2
            d.line([(hip_x, cy + 2), (knee_x, knee_y), (foot_x, 27 - (abs(stride) if leg == 1 else 0))], fill=OUTLINE, width=3)
            d.line((hip_x, cy + 2, knee_x, knee_y), fill=p["wood_light"])
    d.ellipse((cx - 9, cy - 7, cx + 9, cy + 7), fill=OUTLINE)
    d.ellipse((cx - 7, cy - 6, cx + 7, cy + 5), fill=p["wood"])
    d.ellipse((cx - 5, cy - 5, cx + 5, cy + 4), fill=p["thread"])
    d.arc((cx - 4, cy - 4, cx + 4, cy + 3), 60 + pose["coil"], 340 + pose["coil"], fill=p["brass"], width=2)
    d.ellipse((cx - 1, cy - 1, cx + 1, cy + 1), fill=SHADOW)
    d.line((cx - 7, cy - 3, cx - 7, cy + 3), fill=p["wood_light"])
    d.polygon([(cx + 5, cy - 5), (cx + 10, cy - 3), (cx + 11, cy + 1), (cx + 6, cy + 3)], fill=OUTLINE)
    d.line((cx + 7, cy - 3, cx + 9, cy - 3), fill=p["danger"] if state == "anticipation" else p["glow"])
    claw_y = pose["claw_y"]
    d.line([(cx + 7, cy + 3), (27, claw_y + 2), (30, claw_y)], fill=OUTLINE, width=3)
    d.line((27, claw_y + 2, 30, claw_y), fill=p["brass"])
    d.point((29, claw_y + 1), fill=BONE)
    if state == "anticipation":
        d.line([(cx - 5, cy - 7), (cx, cy - 9), (cx + 6, cy - 7)], fill=p["danger"])
    if state == "charge":
        d.line((1, 17 + pose["coil"] % 3, 5, 18 + pose["coil"] % 3), fill=p["thread"])
        d.line((2, 23, 5, 22), fill=p["wood_light"])
    return image


def _wickwing(state: str, pose: dict, p: dict) -> Image.Image:
    image = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(image)
    cy, fold, tip = pose["body_y"], pose["fold"], pose["tip_y"]
    if state == "defeat":
        drop = pose["drop"]
        d.polygon([(11, 20 + drop), (17, 18 + drop), (23, 24 + drop), (14, 26 + drop)], fill=OUTLINE)
        d.line([(12, 21 + drop), (17, 20 + drop), (20, 24 + drop)], fill=p["glass"])
        d.polygon([(5 - drop, 18), (10, 20 + drop), (8, 24 + drop)], fill=p["glass_dark"])
        d.line([(15, 24 + drop), (12, 27), (18 + drop, 28)], fill=p["thread"])
        d.line((25 + drop, 16 + drop, 27 + drop, 20 + drop), fill=p["rim"])
        return image
    if state == "dive":
        # Folded glass vanes make a clear arrow silhouette, facing right.
        d.polygon([(13, cy), (5, tip), (3, tip - 4), (18, cy - 5), (22, cy + 1)], fill=OUTLINE)
        d.polygon([(13, cy - 2), (7, tip - 1), (17, cy - 4), (20, cy)], fill=p["glass_dark"])
        d.line((7, tip - 2, 18, cy - 4), fill=p["rim"])
        d.polygon([(13, cy + 1), (3, cy + 6), (5, cy + 9), (21, cy + 4)], fill=OUTLINE)
        d.line((7, cy + 6, 18, cy + 3), fill=p["glass"])
        d.polygon([(13, cy - 2), (21, cy - 3), (28, cy + 1), (20, cy + 6), (12, cy + 4)], fill=OUTLINE)
        d.polygon([(15, cy - 1), (21, cy - 1), (25, cy + 1), (20, cy + 4), (14, cy + 3)], fill=p["bell"])
        d.point((24, cy + 1), fill=p["danger"])
        d.line((27, cy + 1, 30, cy + 1), fill=BONE)
    else:
        # Two unequal folded glass wings and their metal veins are readable at 1x.
        d.polygon([(14, cy), (3 + fold, tip), (1 + fold, tip + 5), (7 + fold, cy + 5), (16, cy + 4)], fill=OUTLINE)
        d.polygon([(13, cy), (4 + fold, tip + 2), (4 + fold, tip + 5), (9 + fold, cy + 3)], fill=p["glass_dark"])
        d.line([(4 + fold, tip + 2), (8 + fold, cy), (14, cy + 2)], fill=p["glass"])
        d.line((4 + fold, tip + 4, 10 + fold, cy + 2), fill=p["rim"])
        d.polygon([(16, cy), (25 - fold, tip - 1), (29 - fold, tip + 4), (25 - fold, cy + 5), (17, cy + 6)], fill=OUTLINE)
        d.polygon([(18, cy + 1), (25 - fold, tip + 1), (27 - fold, tip + 4), (23 - fold, cy + 3)], fill=p["glass"])
        d.line((20, cy + 2, 26 - fold, tip + 3), fill=p["rim"])
        d.polygon([(13, cy - 4), (18, cy - 5), (22, cy - 2), (23, cy + 5), (20, cy + 8), (12, cy + 6)], fill=OUTLINE)
        d.polygon([(14, cy - 3), (18, cy - 3), (20, cy - 1), (21, cy + 4), (19, cy + 6), (14, cy + 5)], fill=p["bell"])
        d.line((15, cy - 2, 15, cy + 4), fill=p["rim"])
        d.line((13, cy + 5, 21, cy + 5), fill=p["glass_dark"])
        d.point((20, cy), fill=p["danger"] if state == "anticipation" else p["glow"])
        d.line((22, cy + 1, 25, cy), fill=p["rim"])
        d.line([(16, cy + 7), (15 + pose["tail"], cy + 10), (18 + pose["tail"], cy + 12)], fill=p["thread"])
    if state == "anticipation":
        d.line([(12, cy - 5), (16, cy - 7), (20, cy - 5)], fill=p["danger"])
    return image


def _shuttle(d: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], p: dict, width: int = 4) -> None:
    # A hollow weaving shuttle with a pointed nose, not a sword silhouette.
    sx, sy = start
    ex, ey = end
    length = math.hypot(ex - sx, ey - sy)
    if length < 1:
        return
    ux, uy = (ex - sx) / length, (ey - sy) / length
    nx, ny = -uy, ux
    def point(t: float, side: float = 0) -> tuple[int, int]:
        return round(sx + ux * t + nx * side), round(sy + uy * t + ny * side)
    d.polygon([point(-2), point(3, width), point(length - 4, width), point(length),
               point(length - 4, -width), point(3, -width)], fill=OUTLINE)
    d.polygon([point(0), point(4, width - 1), point(length - 5, width - 1), point(length - 2),
               point(length - 5, -width + 1), point(4, -width + 1)], fill=p["wood_light"])
    d.line([point(4), point(max(5, length - 6))], fill=SHADOW, width=2)
    d.line([point(4, -width + 1), point(length - 5, -width + 1)], fill=p["brass"])


def _spoolwarden(state: str, pose: dict, p: dict) -> Image.Image:
    image = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(image)
    dx, bob, stance = pose["dx"], pose["bob"], pose["stance"]
    collapse = pose.get("collapse", 0)
    torso_y = 24 + bob + collapse
    # Legs are bent wood struts with visible joints; feet reference stays y59.
    for hip_x, knee_x, foot_x in ((25 + dx, 21 + dx - stance, 17 - stance),
                                 (39 + dx, 43 + dx + stance, 45 + stance)):
        d.line([(hip_x, torso_y + 17), (knee_x, min(53, torso_y + 25)), (foot_x, 56)], fill=OUTLINE, width=6)
        d.line([(hip_x, torso_y + 17), (knee_x, min(53, torso_y + 25)), (foot_x, 56)], fill=p["wood"], width=3)
        d.ellipse((knee_x - 2, min(52, torso_y + 23), knee_x + 2, min(56, torso_y + 27)), fill=p["brass"])
        d.polygon([(foot_x - 4, 55), (foot_x + 5, 55), (foot_x + 7, 58), (foot_x - 5, 58)], fill=OUTLINE)
        d.line((foot_x - 3, 56, foot_x + 4, 56), fill=p["wood_light"])
    # Side reel and its wound thread remain asymmetrical when the actor mirrors.
    reel_x, reel_y = 11 + dx, min(46, torso_y + 7)
    d.line((22 + dx, torso_y + 3, reel_x + 1, reel_y + 2), fill=OUTLINE, width=5)
    d.ellipse((reel_x - 6, reel_y - 8, reel_x + 6, reel_y + 7), fill=OUTLINE)
    d.ellipse((reel_x - 4, reel_y - 6, reel_x + 4, reel_y + 5), fill=p["wood_light"])
    d.rectangle((reel_x - 2, reel_y - 6, reel_x + 2, reel_y + 5), fill=p["thread_dark"])
    for y in range(reel_y - 4, reel_y + 5, 3):
        d.line((reel_x - 2, y, reel_x + 2, y), fill=p["thread"])
    # Open loom torso: frame bars and strings, leaving recognisable dark gaps.
    top = [(20 + dx, torso_y), (42 + dx, torso_y - 1), (46 + dx, torso_y + 20), (18 + dx, torso_y + 20)]
    d.polygon(top, fill=OUTLINE)
    d.polygon([(24 + dx, torso_y + 4), (38 + dx, torso_y + 3), (40 + dx, torso_y + 16), (23 + dx, torso_y + 16)], fill=SHADOW)
    d.line([(21 + dx, torso_y + 1), (20 + dx, torso_y + 18), (43 + dx, torso_y + 18)], fill=p["wood"], width=3)
    d.line([(22 + dx, torso_y + 1), (41 + dx, torso_y), (44 + dx, torso_y + 18)], fill=p["wood_light"], width=2)
    seam = p["glow"] if state == "stagger" else p["thread"]
    if state == "defeat":
        seam = p["thread_dark"]
    for index, x in enumerate((27, 31, 35, 39)):
        y_end = torso_y + 15 - (pose["thread"] + index) % 3
        d.line([(x + dx, torso_y + 4), (x + dx + (index % 2), y_end)], fill=seam)
        if state == "stagger":
            d.point((x + dx + 1, torso_y + 8 + pose["thread"] % 3), fill=BONE)
    d.line((23 + dx, torso_y + 15, 41 + dx, torso_y + 12), fill=p["brass"])
    for x in (21, 42):
        for y in (torso_y + 2, torso_y + 17):
            d.point((x + dx, y), fill=BONE)
    # A cracked bell hood, irregular rim, and an off-centre slit looking right.
    head_x, head_y = 31 + dx + pose["tilt"], 7 + bob + collapse
    d.arc((head_x - 3, head_y - 3, head_x + 4, head_y + 3), 175, 365, fill=OUTLINE, width=2)
    d.polygon([(head_x - 6, head_y + 1), (head_x + 5, head_y), (head_x + 9, head_y + 5),
               (head_x + 11, head_y + 13), (head_x + 14, head_y + 17), (head_x - 12, head_y + 18),
               (head_x - 9, head_y + 12)], fill=OUTLINE)
    d.polygon([(head_x - 5, head_y + 3), (head_x + 4, head_y + 2), (head_x + 7, head_y + 6),
               (head_x + 9, head_y + 14), (head_x - 9, head_y + 15), (head_x - 7, head_y + 11)], fill=p["brass"])
    d.polygon([(head_x - 5, head_y + 3), (head_x - 1, head_y + 4), (head_x - 2, head_y + 13),
               (head_x - 8, head_y + 15)], fill=p["brass_dark"])
    d.line((head_x - 8, head_y + 15, head_x + 10, head_y + 14), fill=p["wood_light"])
    d.line([(head_x + 1, head_y + 2), (head_x - 1, head_y + 7), (head_x + 3, head_y + 9),
            (head_x, head_y + 14)], fill=SHADOW)
    eye = p["danger"] if state.endswith("anticipation") else p["glow"]
    if state == "defeat":
        eye = p["brass_dark"]
    d.line((head_x + 4, head_y + 10, head_x + 8, head_y + 10), fill=SHADOW, width=2)
    d.point((head_x + 7, head_y + 10), fill=eye)
    # The source table supplies the arm/weapon pose for every attack phase.
    arm = pose["arm"]
    d.line([(42 + dx, torso_y + 5), (arm[0], arm[1])], fill=OUTLINE, width=6)
    d.line([(42 + dx, torso_y + 5), (arm[0], arm[1])], fill=p["wood"], width=3)
    d.ellipse((arm[0] - 2, arm[1] - 2, arm[0] + 2, arm[1] + 2), fill=p["brass"])
    weapon = pose["weapon"]
    _shuttle(d, (weapon[0], weapon[1]), (weapon[2], weapon[3]), p)
    if state.endswith("anticipation"):
        if state.startswith("sweep"):
            d.line((5, 20 + pose["thread"], 14, 18 + pose["thread"]), fill=p["danger"])
        elif state.startswith("strike"):
            d.line((47, 3, 51, 2 + pose["thread"]), fill=p["danger"])
        else:
            d.line([(50, 21), (54, 25 + pose["thread"]), (50, 29)], fill=p["danger"])
    if state == "stagger":
        # The central exposed stitch changes shape/brightness, not merely colour.
        x, y = 33 + dx, torso_y + 9
        d.polygon([(x, y - 5), (x + 4, y), (x, y + 5), (x - 4, y)], outline=BONE)
        d.line((x - 2, y, x + 2, y), fill=p["glow"])
    if state == "defeat":
        loosen = pose["thread"]
        d.line([(26 + dx, min(56, torso_y + 16)), (25 - loosen, 56), (31, 58), (36 + loosen, 56)], fill=p["thread_dark"])
        d.line((8 - min(loosen, 3), 57, 13, 58), fill=p["wood_light"])
    return image


DRAW = {"oru": _oru, "spoolmite": _spoolmite, "wickwing": _wickwing, "spoolwarden": _spoolwarden}


def generate(root: Path) -> list[dict]:
    """Author the four required atlases from their editable palette/pose tables."""
    root = Path(root)
    path = root / "assets/source/art/actors.json"
    source = json.loads(path.read_text(encoding="utf-8"))
    if source.get("schema_version") != 1 or set(source.get("actors", {})) != set(CLIPS):
        raise ValueError(f"{path}: expected schema 1 and the four fixed actor definitions")
    records = []
    for name, required in CLIPS.items():
        definition = source["actors"][name]
        clips = definition["clips"]
        if set(clips) != set(required):
            raise ValueError(f"{path}: {name} animation states do not match the fixed contract")
        images = []
        for state, count in required.items():
            data = clips[state]
            if len(data["poses"]) != count or len(data["ticks"]) != count:
                raise ValueError(f"{path}: {name}.{state} needs {count} poses and presentation tick lengths")
            if any(type(value) is not int or value <= 0 for value in data["ticks"]):
                raise ValueError(f"{path}: {name}.{state} ticks must be positive integers")
            images.extend(DRAW[name](state, pose, definition["palette"]) for pose in data["poses"])
        cell, origin, rows = GEOMETRY[name]
        record = atlas(root, f"{name}_v1", images, cell, 8, rows, origin, required, source_files=SOURCES)
        for state, data in clips.items():
            record["animations"][state]["ticks"] = data["ticks"]
            record["animations"][state]["loop"] = data["loop"]
        records.append(record)
    return records
