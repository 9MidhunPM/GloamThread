"""Whole-illustration cutout animation; no limb substitution or provider calls.

The original full-resolution source stays in the job. The canonical editable
64px master is sampled once, then each gameplay state uses an authored whole-
body transform. This is intentionally a cutout performance, not limb animation.
"""
from __future__ import annotations
import math
from PIL import Image, ImageChops

VERSION = 'illustrated-master-v1'
# angle, horizontal/vertical scale, horizontal/vertical offset;32 authored poses.
POSES = {
    'idle': [(0,1,1,0,0),(1,1,1,0,-1),(0,1,1,0,-2),(-1,1,1,0,-1)],
    'run': [(-5,1,.98,-1,0),(-2,.98,1.02,0,-2),(4,1,1,1,-1),
            (6,1,.98,1,0),(2,.98,1.02,0,-2),(-3,1,1,-1,-1)],
    'rise': [(-7,.98,1.03,0,-3),(-3,1,1.02,1,-2)],
    'fall': [(6,1.02,.98,1,-1),(3,1,1,0,0)],
    'land': [(0,1.08,.88,0,2),(-1,1.03,.96,0,1)],
    'slash': [(-11,.99,1,-2,0),(5,1.03,.98,1,-1),
              (14,1.04,.96,3,0),(-2,1,1,0,1)],
    'special': [(-6,.96,1.02,-1,1),(-2,1,1.04,0,-3),
                (8,1.04,.98,2,-2),(2,1,1,0,-1)],
    'hurt': [(-9,.98,.97,-3,1),(-4,1,1,-1,0)],
    'dash': [(13,1.06,.94,3,-2),(10,1.03,.97,2,-1)],
    'downed': [(78,1,.94,-1,0),(83,1,.92,-2,0)],
    'revive': [(42,.98,.98,-1,-1),(12,1,1,0,-2)],
}


def prepare_master(image: Image.Image) -> Image.Image:
    """Preserve the entire silhouette/aspect; fit one canonical editable part."""
    bounds=image.getchannel('A').getbbox()
    if bounds is None: raise ValueError('Illustrated master is blank.')
    cutout=image.crop(bounds)
    scale=min(48/cutout.width,50/cutout.height)
    cutout=cutout.resize((max(1,round(cutout.width*scale)),max(1,round(cutout.height*scale))),Image.Resampling.NEAREST)
    result=Image.new('RGBA',(64,64))
    result.alpha_composite(cutout,((64-cutout.width)//2,56-cutout.height))
    return result


def render_frame(parts: dict,rig: dict,state: str,index: int,count: int,masks: dict|None=None) -> Image.Image:
    # Import lazily: validation imports the original art rig vocabulary.
    from .validation import require
    require(state in POSES and count==len(POSES[state]) and 0<=index<count,
            'Illustrated animation state/count differs from its authored recipe.')
    image=parts['master'].copy()
    if masks and 'master' in masks:
        image.putalpha(ImageChops.multiply(image.getchannel('A'),masks['master']))
    box=image.getchannel('A').getbbox()
    require(box is not None,'The illustrated master mask removes the entire character.')
    record=rig['parts'][0]
    angle,sx,sy,dx,dy=POSES[state][index]
    image=image.crop(box)
    pivot=((record['pivot'][0]-box[0])*sx,(record['pivot'][1]-box[1])*sy)
    image=image.resize((max(1,round(image.width*sx)),max(1,round(image.height*sy))),Image.Resampling.NEAREST)
    centre=(image.width/2,image.height/2)
    image=image.rotate(angle,resample=Image.Resampling.NEAREST,expand=True)
    radians=math.radians(angle);c=math.cos(radians);s=math.sin(radians)
    px,py=pivot[0]-centre[0],pivot[1]-centre[1]
    pivot=(image.width/2+c*px+s*py,image.height/2-s*px+c*py)
    rotated_box=image.getchannel('A').getbbox()
    require(rotated_box is not None,'Illustrated pose is empty.')
    image=image.crop(rotated_box)
    pivot=(pivot[0]-rotated_box[0],pivot[1]-rotated_box[1])
    # Whole-body rotations may need a small uniform fit. Never clip the hat,
    # face, staff or feet, and never stretch them into an authored limb envelope.
    floor=56+dy
    scale=min(1,60/image.width,(floor-2)/image.height)
    if scale<1:
        before=image.size
        image=image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))),Image.Resampling.NEAREST)
        pivot=(pivot[0]*image.width/before[0],pivot[1]*image.height/before[1])
    x=round(record['anchor'][0]+dx-pivot[0]);y=round(record['anchor'][1]+dy-pivot[1])
    x=max(2,min(62-image.width,x));y=max(2,min(floor-image.height,y))
    result=Image.new('RGBA',(64,64));result.alpha_composite(image,(x,y))
    return result
