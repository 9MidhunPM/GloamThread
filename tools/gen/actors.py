"""Original actor pixel recipes and their separate ground-plane warning.

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
    bob, phase = pose["bob"], pose["phase"]
    d.ellipse((5, 37, 27, 44), fill=SHADOW)
    for x in (11, 21):
        d.rectangle((x - 2, 38, x + 2, 42), fill=OUTLINE)
        d.line((x - 2, 42, x + 2, 42), fill=p["wood"])
    d.polygon([(8, 27 + bob), (23, 27 + bob), (27, 38), (24, 41),
               (17, 39), (10, 42), (4, 39)], fill=OUTLINE)
    d.polygon([(9, 28 + bob), (22, 28 + bob), (25, 37), (21, 39),
               (17, 37), (10, 39), (6, 38)], fill=p["cape"])
    d.polygon([(9, 29), (14, 31 + bob), (12, 37), (7, 38)], fill=p["cape_dark"])
    d.line([(19, 30 + bob), (20, 35), (23, 37)], fill=p["cape_light"])
    for x,y in ((8,37),(11,38),(16,36),(21,38)):
        d.line((x,y,x+1,y), fill=BONE)
    # The wide hood is seen from above; spectacles sit on its lower front plane.
    d.ellipse((6, 14 + bob, 25, 31 + bob), fill=OUTLINE)
    d.ellipse((8, 15 + bob, 23, 28 + bob), fill=p["cape_dark"])
    d.polygon([(10,17+bob),(17,15+bob),(22,19+bob),(18,23+bob),(9,22+bob)], fill=p["cape"])
    d.line([(10,18+bob),(14,17+bob),(16,19+bob)], fill=p["cape_light"])
    d.polygon([(9,23+bob),(23,23+bob),(21,29+bob),(12,30+bob)], fill=p["face"])
    for x in (12,20):
        d.rectangle((x-3,23+bob,x+2,27+bob), outline=p["brass"])
        d.point((x,25+bob), fill=SHADOW)
    d.line((14,25+bob,17,25+bob), fill=p["brass"])
    d.line((15,29+bob,18,29+bob), fill=p["cape_dark"])
    if state == "talk":
        d.rectangle((15,28+bob,18,29+bob+pose["mouth"]), fill=SHADOW)
    hand_y = 31 - pose["hand"]
    d.line([(9,30+bob),(5,hand_y),(7,hand_y-2)], fill=OUTLINE,width=4)
    d.line((5,hand_y,7,hand_y-2), fill=p["face"],width=2)
    d.line([(24,30+bob),(27,33),(28,27)], fill=p["cape_dark"],width=3)
    d.line([(28,43),(27,29),(28,14-pose["staff_lift"])], fill=OUTLINE,width=3)
    d.line((28,41,28,15-pose["staff_lift"]), fill=p["wood"])
    lx,ly=23+pose["lantern_sway"],17-pose["staff_lift"]
    d.line([(28,ly-2),(lx+2,ly-4),(lx,ly)], fill=p["brass"])
    d.rectangle((lx-1,ly,lx+4,ly+7), fill=OUTLINE)
    d.rectangle((lx,ly+2,lx+3,ly+5), fill=p["glow"])
    d.line((lx+1,ly+1,lx+1,ly+6), fill=p["brass"])
    if state == "acknowledge":
        d.line((5,hand_y-4,5,hand_y-7-phase), fill=p["glow"])
    return image


def _spoolmite(state: str, pose: dict, p: dict) -> Image.Image:
    image=Image.new("RGBA",(32,32)); d=ImageDraw.Draw(image)
    phase, bob, stride=pose["phase"],pose["bob"],pose["stride"]
    cx,cy=16,18+bob
    if state == "defeat":
        spread=phase+1
        d.ellipse((7,20,25,28),fill=SHADOW)
        d.polygon([(10,19+phase),(16,16+phase),(22,20+phase),(20,27),(11,26)],fill=OUTLINE)
        d.arc((10,18+phase,22,27),180+phase*25,480,fill=p["wood_light"],width=3)
        d.line([(4,25),(8,23),(13,27),(19,25),(25+spread,28-spread)],fill=p["thread"])
        for side in (-1,1):
            d.line((16+side*8,22,16+side*(10+spread),20-spread),fill=p["wood"],width=2)
        return image
    d.ellipse((5,23,27,29),fill=SHADOW)
    for side in (-1,1):
        for leg in range(3):
            y=cy-5+leg*5
            dy=stride if leg%2 else -stride
            d.line([(cx+side*5,y),(cx+side*11,y-2),(cx+side*13,y+2+dy)],fill=OUTLINE,width=3)
            d.line([(cx+side*5,y),(cx+side*10,y-2),(cx+side*12,y+1+dy)],fill=p["wood_light"])
    radius=8 if state != "anticipation" else 9
    d.ellipse((cx-radius,cy-9,cx+radius,cy+7),fill=OUTLINE)
    d.ellipse((cx-radius+1,cy-8,cx+radius-1,cy+5),fill=p["wood"])
    d.ellipse((cx-6,cy-7,cx+6,cy+4),fill=p["thread"])
    # Overhead reel top, nested wound thread, central square axle.
    for radius,start in ((5,phase*23),(3,90+phase*23)):
        d.arc((cx-radius,cy-radius-1,cx+radius,cy+radius-1),start,start+280,fill=p["brass"])
    d.rectangle((cx-1,cy-2,cx+1,cy),fill=SHADOW)
    d.line((cx-6,cy-6,cx-3,cy-7),fill=p["wood_light"])
    # Radial rim rivets avoid implying a fixed attack direction. Heading and
    # the charge lane belong to the separate runtime telegraph.
    for x,y in ((cx-6,cy),(cx+6,cy),(cx,cy-6),(cx,cy+5)):
        d.point((x,y),fill=p["danger"] if state=="anticipation" else p["glow"])
    reach=2 if state=="charge" else 0
    for side in (-1,1):
        d.line([(cx+side*7,cy),(cx+side*(11+reach),cy+2),(cx+side*(9+reach),cy+4)],fill=p["brass"],width=2)
    if state=="anticipation":
        d.line([(10,cy-10),(16,cy-12-phase),(22,cy-10)],fill=p["danger"])
    if state=="charge":
        for side in (-1,1):
            d.line((16+side*5,4+phase,16+side*6,8),fill=p["thread"])
    return image


def _wickwing(state: str, pose: dict, p: dict) -> Image.Image:
    image=Image.new("RGBA",(32,32));d=ImageDraw.Draw(image)
    phase,fold,bob=pose["phase"],pose["fold"],pose["bob"]
    cy=17+bob
    if state=="defeat":
        d.ellipse((8,23,24,28),fill=SHADOW)
        d.polygon([(11,21+phase),(16,18+phase),(22,24),(18,28),(12,27)],fill=OUTLINE)
        d.line([(12,22+phase),(17,21+phase),(20,25)],fill=p["glass"])
        for side in (-1,1):
            d.polygon([(16+side*6,22),(16+side*(10+phase),18+phase),(16+side*9,26)],fill=p["glass_dark"])
            d.line((16+side*9,21,16+side*(12+phase),23),fill=p["rim"])
        d.line([(16,26),(12,29),(22+phase,28)],fill=p["thread"])
        return image
    # Bell dome and two ribbed glass fans are viewed from above, flying down.
    for side in (-1,1):
        tip=16+side*(14-fold)
        top=7+fold+bob if state!="dive" else 8+bob
        wing=[(16+side*3,cy-1),(tip,top),(tip-side,top+7),(16+side*9,cy+5),(16+side*3,cy+5)]
        d.polygon(wing,fill=OUTLINE)
        inner=[(16+side*4,cy),(tip-side*2,top+2),(tip-side*2,top+6),(16+side*6,cy+3)]
        d.polygon(inner,fill=p["glass_dark"] if side<0 else p["glass"])
        d.line([(16+side*4,cy),(tip-side*2,top+2),(16+side*7,cy+3)],fill=p["rim"])
        d.line((16+side*4,cy+2,tip-side*3,top+6),fill=p["glass"])
    d.ellipse((10,cy-7,22,cy+8),fill=OUTLINE)
    d.ellipse((11,cy-6,21,cy+5),fill=p["bell"])
    d.ellipse((13,cy-5,19,cy),fill=p["rim"])
    d.line((12,cy+4,20,cy+4),fill=p["glass_dark"])
    d.arc((11,cy-5,21,cy+5),200,290,fill=BONE)
    for x in (14,18):
        d.point((x,cy+3),fill=p["danger"] if state=="anticipation" else p["glow"])
    if state=="dive":
        # A closed rim and folded fans show acceleration without a baked arrow.
        d.arc((11,cy-5,21,cy+7),0,355,fill=p["rim"],width=2)
    else:
        d.line([(16,cy+7),(14+pose["tail"],cy+10),(17+pose["tail"],cy+11)],fill=p["thread"])
    if state=="anticipation":
        d.line([(10,cy-8),(16,cy-10-phase),(22,cy-8)],fill=p["danger"])
    return image


def _shuttle(d: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], p: dict, width: int = 4) -> None:
    sx,sy=start;ex,ey=end
    length=math.hypot(ex-sx,ey-sy)
    if length<1:return
    ux,uy=(ex-sx)/length,(ey-sy)/length;nx,ny=-uy,ux
    def point(t,side=0):return round(sx+ux*t+nx*side),round(sy+uy*t+ny*side)
    d.polygon([point(-2),point(3,width),point(length-4,width),point(length),point(length-4,-width),point(3,-width)],fill=OUTLINE)
    d.polygon([point(0),point(4,width-1),point(length-5,width-1),point(length-2),point(length-5,-width+1),point(4,-width+1)],fill=p["wood_light"])
    d.line([point(4),point(max(5,length-6))],fill=SHADOW,width=2)
    d.line([point(4,-width+1),point(length-5,-width+1)],fill=p["brass"])


def _spoolwarden(state: str, pose: dict, p: dict) -> Image.Image:
    """A radial loom chassis seen from overhead; attack heading is external.

    This body never draws a target-sector warning. The runtime owns its directed
    shuttle/telegraph. Here a rotating mechanism, lifted spindle and braced coil
    distinguish sweep, strike and charge without inventing a cardinal bank.
    """
    image=Image.new("RGBA",(64,64));d=ImageDraw.Draw(image)
    phase=pose["phase"]; collapse=pose["collapse"]
    cx,cy=32+pose["dx"],36+pose["bob"]+collapse//2
    stance=pose["stance"]
    d.ellipse((8,45,56,61),fill=SHADOW)
    # Four splayed struts read as an overhead footprint, never a humanoid side view.
    for sx,sy in ((-1,-1),(1,-1),(-1,1),(1,1)):
        hip=(cx+sx*10,cy+sy*7)
        knee=(cx+sx*(17+stance//2),cy+sy*12)
        foot=(32+sx*(23+stance//2),36+sy*21)
        d.line([hip,knee,foot],fill=OUTLINE,width=6)
        d.line([hip,knee,foot],fill=p["wood"],width=3)
        d.ellipse((knee[0]-2,knee[1]-2,knee[0]+2,knee[1]+2),fill=p["brass"])
        d.polygon([(foot[0]-4,foot[1]-2),(foot[0]+3,foot[1]-3),(foot[0]+4,foot[1]+2),(foot[0]-3,foot[1]+3)],fill=OUTLINE)
        d.line((foot[0]-2,foot[1]-1,foot[0]+2,foot[1]-1),fill=p["wood_light"])
    spread=pose["open_seam"]
    corners=[(cx-13-spread,cy-12),(cx+12+spread,cy-12),(cx+18+spread,cy+2),
             (cx+11+spread,cy+16),(cx-12-spread,cy+16),(cx-18-spread,cy+2)]
    d.polygon(corners,fill=OUTLINE)
    d.polygon([(cx-12,cy-10),(cx+10,cy-10),(cx+15,cy+2),(cx+9,cy+12),(cx-10,cy+12),(cx-15,cy+2)],fill=p["wood"])
    d.line([corners[0],corners[1],corners[2]],fill=p["wood_light"],width=3)
    d.line([corners[3],corners[4],corners[5]],fill=p["wood_light"],width=3)
    # Receding open loom bed: skewed top surface and warp/weft under the dome.
    d.polygon([(cx-11,cy-6),(cx+10,cy-7),(cx+12,cy+8),(cx-10,cy+10)],fill=SHADOW)
    seam=p["glow"] if state=="stagger" else p["thread"]
    if state=="defeat":seam=p["thread_dark"]
    for i in range(5):
        x=cx-8+i*4
        d.line([(x,cy-5),(x+(phase+i)%2,cy+2),(x+1,cy+8)],fill=seam)
    for y in (-2,3,7):d.line((cx-9,cy+y,cx+10,cy+y-2),fill=p["brass_dark"])
    for x,y in corners:
        d.rectangle((x-1,y-1,x+1,y+1),fill=p["brass"])
        d.point((x,y-1),fill=BONE)
    # Two winding reels and central bell crown have visible concentric top faces.
    for side in (-1,1):
        x,y=cx+side*16,cy-5
        d.ellipse((x-5,y-6,x+5,y+5),fill=OUTLINE)
        d.ellipse((x-4,y-5,x+4,y+3),fill=p["wood_light"])
        d.ellipse((x-2,y-3,x+2,y+1),fill=p["thread_dark"])
        d.arc((x-3,y-4,x+3,y+2),phase*27,phase*27+290,fill=p["thread"])
    hx,hy=cx+pose["tilt"],cy-10-pose["weapon_lift"]//2
    d.ellipse((hx-11,hy-9,hx+11,hy+6),fill=OUTLINE)
    d.ellipse((hx-9,hy-8,hx+9,hy+3),fill=p["brass_dark"])
    d.ellipse((hx-8,hy-7,hx+8,hy+1),fill=p["brass"])
    d.arc((hx-6,hy-6,hx+6,hy),195,300,fill=p["wood_light"],width=2)
    d.ellipse((hx-3,hy-5,hx+3,hy-1),fill=OUTLINE)
    d.line([(hx,hy-1),(hx-2,hy+1),(hx+1,hy+3),(hx,hy+5)],fill=SHADOW)
    d.line((hx-8,hy+3,hx+8,hy+3),fill=p["wood_light"],width=2)
    signal=p["danger"] if state.endswith("anticipation") else p["glow"]
    if state=="defeat":signal=p["brass_dark"]
    # Four status rivets provide no false facing/target direction.
    for x,y in ((cx-11,cy+3),(cx+11,cy+3),(cx,cy-5),(cx,cy+10)):
        d.point((x,y),fill=signal)
    angle=math.radians(pose["orbit_angle"])
    arm=(round(cx+math.cos(angle)*17),round(cy+math.sin(angle)*12)-pose["weapon_lift"])
    end=(round(cx+math.cos(angle)*25),round(cy+math.sin(angle)*19)-pose["weapon_lift"])
    d.line([(cx+9,cy-2),arm],fill=OUTLINE,width=5)
    d.line([(cx+9,cy-2),arm],fill=p["wood"],width=2)
    _shuttle(d,arm,end,p,width=3)
    if state.startswith("sweep"):
        # Wound circular mechanism, not a baked world-space hit sector.
        colour=p["danger"] if state.endswith("anticipation") else p["glow"]
        if not state.endswith("recovery"):
            d.ellipse((cx-10,cy-4,cx+10,cy+10),outline=colour)
            d.line((cx-7+phase*2,cy+2,cx+7,cy+2),fill=colour)
    elif state=="strike_anticipation":
        d.line((hx-2,hy-11,hx-2,hy-14),fill=p["danger"])
        d.line((hx+3,hy-10,hx+5,hy-13),fill=BONE)
    elif state=="strike_active":
        d.polygon([(cx,cy-4),(cx+7,cy+2),(cx,cy+10),(cx-7,cy+2)],outline=p["glow"])
    elif state=="charge_anticipation":
        for side in (-1,1):
            d.line([(cx+side*12,cy+6),(cx+side*9,cy+9),(cx+side*6,cy+6)],fill=p["danger"],width=2)
    elif state=="charge_active":
        d.ellipse((cx-8,cy-2,cx+8,cy+9),outline=p["glow"],width=2)
    if state=="stagger":
        y=cy+2
        d.polygon([(cx,y-6),(cx+6,y),(cx,y+8),(cx-6,y)],fill=p["thread_dark"],outline=BONE)
        d.line((cx-3,y,cx+3,y),fill=p["glow"],width=2)
        d.line((cx,y-3,cx,y+5),fill=p["glow"],width=2)
        d.point((cx-8+phase,y-2),fill=BONE)
    if state=="defeat":
        for side in (-1,1):
            d.line((cx+side*10,cy+9,cx+side*(15+phase),56-phase),fill=p["wood_light"],width=2)
        d.line([(cx-8,cy+10),(cx-12-phase,59),(cx,60),(cx+10+phase,56)],fill=p["thread_dark"])
    return image


DRAW = {"oru": _oru, "spoolmite": _spoolmite, "wickwing": _wickwing, "spoolwarden": _spoolwarden}


def enemy_warning_image(pose: dict, palette: dict) -> Image.Image:
    """A steady hollow arrow points +X; a small stitch advances during windup.

    The complete warning is visible in every frame, including the first and
    held last frame. Straight edges and an inset tail distinguish it from the
    curved slash effects. The empty centre leaves the ground readable.
    """
    image = Image.new("RGBA", (32, 32))
    draw = ImageDraw.Draw(image)
    edge = [(18, 8), (29, 16), (18, 24), (20, 16), (18, 8)]
    draw.line(edge, fill=palette["outline"], width=3, joint="curve")
    draw.line(edge, fill=palette["danger"], width=2)
    draw.line([(18, 7), (30, 16), (18, 25)], fill=palette["light"], width=1)
    # This tiny forward stitch moves once, never blinks or erases the rim.
    x = pose["stitch_x"]
    draw.line((x, 16, x + 1, 16), fill=palette["light"])
    return image


def generate(root: Path) -> list[dict]:
    """Author the four actors and dedicated warning from editable source tables."""
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
    warning = source["effects"]["enemy_warning"]
    if len(warning["poses"]) != 6 or len(warning["ticks"]) != 6:
        raise ValueError(f"{path}: enemy_warning needs six poses and tick lengths")
    if any(type(value) is not int or value <= 0 for value in warning["ticks"]):
        raise ValueError(f"{path}: enemy_warning ticks must be positive integers")
    if any(type(pose.get("stitch_x")) is not int or not 21 <= pose["stitch_x"] <= 26
           for pose in warning["poses"]):
        raise ValueError(f"{path}: enemy_warning stitch_x must stay inside the arrow")
    images = [enemy_warning_image(pose, warning["palette"]) for pose in warning["poses"]]
    record = atlas(root, "effect_enemy_warning_v1", images, (32, 32), 6, 1,
                   (16, 16), {"play": 6}, source_files=SOURCES)
    record["animations"]["play"]["ticks"] = warning["ticks"]
    records.append(record)
    return records
