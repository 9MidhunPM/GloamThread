"""Editable original pixel designs and three deterministic cutout rigs.

All masks and animation poses are local authored data. Generated parts may use
these same templates; they never supply gameplay timing or collision geometry.
"""
from __future__ import annotations
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageColor

RIG_PARTS={
 'upright':['torso','head','arm_back','arm_front','leg_back','leg_front'],
 'quadruped':['torso','head','leg_back_left','leg_back_right','leg_front_left','leg_front_right','tail'],
 'floating':['torso','arm_back','arm_front'],
}
PIVOTS={
 'upright':{'torso':(32,36),'head':(33,23),'arm_back':(27,31),'arm_front':(38,31),'leg_back':(28,43),'leg_front':(36,43)},
 'quadruped':{'torso':(30,36),'head':(45,33),'leg_back_left':(19,39),'leg_back_right':(24,39),'leg_front_left':(37,39),'leg_front_right':(42,39),'tail':(16,33)},
 'floating':{'torso':(32,34),'arm_back':(20,34),'arm_front':(43,34)},
}
FRAME_STATES=[('idle',4),('run',6),('rise',2),('fall',2),('land',2),('slash',4),('special',4),('hurt',2),('dash',2),('downed',2),('revive',2)]
OUT='#111622'; BONE='#ffe9ba'



def normalize_palette(palette:list[str])->list[str]:
    """Derive highlight swatches locally; keep the accepted proposal unchanged."""
    result=list(palette[:6])
    while len(result)<6:
        rgb=ImageColor.getrgb(result[-1]);amount=.34 if len(result)==4 else .55
        result.append('#'+''.join(f'{round(channel+(255-channel)*amount):02x}' for channel in rgb))
    return result


def authored_parts(rig_id:str, palette:list[str]) -> dict[str,Image.Image]:
    p=normalize_palette(palette); parts={name:Image.new('RGBA',(64,64)) for name in RIG_PARTS[rig_id]}
    def draw(name): return ImageDraw.Draw(parts[name])
    if rig_id=='upright':
      # A long-eared kiln keeper with a copper mask, split apron and coal-glass heart.
      for name,x in [('leg_back',25),('leg_front',34)]:
        d=draw(name); d.polygon([(x,41),(x+6,41),(x+6,51),(x+9,53),(x+8,56),(x-1,56)],fill=OUT)
        d.rectangle((x+1,43,x+4,52),fill=p[2]); d.line((x+1,54,x+7,54),fill=p[3])
      d=draw('torso'); d.polygon([(25,25),(39,25),(44,39),(41,48),(33,46),(24,48),(20,39)],fill=OUT)
      d.polygon([(25,28),(38,27),(41,38),(38,44),(32,42),(25,45),(23,37)],fill=p[3]); d.polygon([(25,30),(29,29),(29,43),(25,45),(23,36)],fill=p[1])
      d.line([(32,29),(32,41),(38,44)],fill=p[4],width=2); d.rectangle((24,37,40,40),fill=OUT); d.line((25,38,39,38),fill=p[2])
      d.ellipse((29,30,36,37),fill=OUT); d.ellipse((31,31,34,35),fill=p[5]); d.point((32,32),fill='#ffffff')
      d=draw('head'); d.polygon([(21,20),(21,8),(26,11),(29,18),(35,17),(40,6),(44,8),(43,24),(48,26),(43,31),(28,30)],fill=OUT)
      d.polygon([(23,12),(25,14),(28,21),(37,20),(41,11),(41,24),(45,26),(41,28),(28,27),(24,23)],fill=p[3]);d.polygon([(24,15),(25,18),(26,21),(24,21)],fill=p[4])
      d.polygon([(31,21),(42,21),(42,25),(46,26),(40,28),(30,26)],fill=p[2]);d.line((34,22,36,22),fill=p[5],width=2);d.point((44,26),fill=OUT)
      d.line((23,24,29,29),fill=p[4],width=2); d.line((27,28,37,30),fill=p[5]);d.rectangle((35,28,39,31),fill=p[4])
      for name,x in [('arm_back',23),('arm_front',39)]:
        d=draw(name);d.line([(x,30),(x-2 if x<30 else x+3,37),(x+1 if x<30 else x+4,42)],fill=OUT,width=7)
        d.line([(x,31),(x-2 if x<30 else x+3,37)],fill=p[2],width=4);d.ellipse((x-2,39,x+4,44),fill=p[3])
      d=draw('arm_front'); d.line((45,38,54,23),fill=OUT,width=5);d.line((46,37,53,25),fill=p[5],width=2);d.polygon([(50,25),(53,18),(57,19),(55,27)],fill=OUT);d.line((53,21,54,24),fill=p[4],width=2)
    elif rig_id=='quadruped':
      # A small bark-plated seed beast, with branch antlers and a luminous seed.
      for name,x in [('leg_back_left',17),('leg_back_right',23),('leg_front_left',36),('leg_front_right',42)]:
        d=draw(name);d.polygon([(x,37),(x+5,38),(x+5,48),(x+8,53),(x+6,56),(x-1,55),(x,46)],fill=OUT);d.line([(x+2,40),(x+2,49),(x+5,53)],fill=p[2],width=3);d.line((x,54,x+5,54),fill=p[4])
      d=draw('tail');d.line([(17,34),(10,29),(7,22),(11,19)],fill=OUT,width=5);d.line([(17,33),(11,28),(9,22)],fill=p[2],width=3);d.polygon([(8,22),(4,18),(6,13),(11,17),(13,12),(15,17),(12,23)],fill=OUT);d.polygon([(9,20),(7,17),(8,16),(11,19),(13,16),(12,21)],fill=p[4])
      d=draw('torso');d.ellipse((13,25,45,45),fill=OUT);d.ellipse((16,27,43,42),fill=p[2]);d.polygon([(17,30),(23,26),(28,28),(33,25),(39,29),(41,37),(34,39),(29,36),(23,39),(17,36)],fill=p[3]);
      for x,y in [(21,30),(29,29),(36,31)]: d.line((x,y,x+2,y+6),fill=p[1],width=2)
      d.ellipse((25,30,34,39),fill=OUT);d.ellipse((27,32,32,37),fill=p[4]);d.line((29,32,30,36),fill=p[5])
      d=draw('head');d.polygon([(35,30),(39,22),(48,21),(53,28),(57,31),(55,39),(44,40),(37,36)],fill=OUT);d.polygon([(39,29),(42,24),(48,24),(51,30),(54,32),(52,36),(44,37),(39,34)],fill=p[3]);d.rectangle((45,28,48,30),fill=p[5]);d.point((55,32),fill=p[1]);d.line((48,35,52,35),fill=p[1])
      for x in (40,47):
        d.line([(x,24),(x-2,18),(x-5,15)],fill=OUT,width=4);d.line([(x,23),(x-2,18),(x-5,15)],fill=p[4],width=2);d.line((x-2,18,x+1,15),fill=p[4],width=2)
      d.polygon([(38,29),(33,23),(38,24),(42,29)],fill=p[4])
    else:
      # A lantern-manta: readable floating body with long stitched fins.
      d=draw('torso');d.polygon([(18,31),(21,20),(29,15),(38,17),(46,25),(47,38),(40,47),(34,43),(27,49),(20,43)],fill=OUT)
      d.polygon([(21,31),(24,22),(30,19),(37,21),(43,27),(43,37),(38,42),(33,39),(27,44),(23,40)],fill=p[2]);d.polygon([(23,31),(29,25),(38,25),(41,32),(36,38),(29,38)],fill=p[3]);d.rectangle((28,28,30,30),fill=p[5]);d.rectangle((36,28,38,30),fill=p[5]);d.line((30,34,35,34),fill=OUT)
      d.line([(27,43),(25,50),(29,54)],fill=p[4],width=2);d.line([(37,43),(40,49),(36,54)],fill=p[4],width=2)
      for name,left in [('arm_back',True),('arm_front',False)]:
        d=draw(name);pts=[(23,29),(13,28),(7,35),(13,44),(22,39)] if left else [(41,29),(51,27),(59,34),(53,44),(43,39)]
        d.polygon(pts,fill=OUT);d.line(pts[1:4],fill=p[3],width=3);d.line((pts[0][0],32,pts[2][0],35),fill=p[4],width=2)
    return parts


def pose(rig:str,state:str,index:int,count:int) -> dict:
    phase=index/max(count,1)*math.tau
    run=math.sin(phase); bob=-round(abs(run)) if state=='run' else -(index%2) if state=='idle' else 0
    result={'bob':bob,'lean':0,'parts':{}}
    for name in RIG_PARTS[rig]:
      angle=0;dx=0;dy=0
      if state=='run':
        if 'leg' in name: angle=(22 if ('front' in name or name.endswith('right')) else -22)*run
        elif 'arm' in name: angle=(-16 if 'front' in name else 16)*run
        elif name=='tail': angle=12*run
      if state in ('rise','fall') and ('leg' in name or 'arm' in name): angle=(15 if state=='rise' else -10)*(1 if 'front' in name else -1)
      if state=='slash' and ('arm_front'==name or (rig=='quadruped' and name=='head')): angle=[24,-20,-65,-12][index];dx=[-1,3,4,0][index]
      if state=='special':
        if 'arm' in name: angle=(-1 if 'back' in name else 1)*[20,45,35,10][index]
        if name=='head':dy=[2,-1,-2,0][index]
      if state=='dash':angle=10 if 'leg' in name else -8; dx=-2
      if state=='hurt':dx=-2+index*2
      result['parts'][name]={'angle':angle,'dx':dx,'dy':dy}
    if state=='land':result['bob']=2-index
    if rig=='floating': result['bob']+=round(math.sin(phase)*2) if state in ('idle','run') else 0
    return result


def render_frame(parts:dict,rig:dict,state:str,index:int,count:int,masks:dict|None=None) -> Image.Image:
    if rig.get('source_kind')=='illustrated-master':
      from .illustrated import render_frame as render_illustrated
      return render_illustrated(parts,rig,state,index,count,masks)
    canvas=Image.new('RGBA',(64,64));p=pose(rig['rig_id'],state,index,count)
    order={'upright':['arm_back','leg_back','leg_front','torso','head','arm_front'],
      'quadruped':['tail','leg_back_left','leg_front_left','torso','leg_back_right','leg_front_right','head'],
      'floating':['arm_back','torso','arm_front']}[rig['rig_id']]
    records={x['id']:x for x in rig['parts']}
    for name in order:
      image=parts[name].copy()
      if masks and name in masks:
        from PIL import ImageChops
        image.putalpha(ImageChops.multiply(image.getchannel('A'),masks[name]))
      record=records[name];pivot=tuple(record['pivot']);anchor=record.get('anchor',pivot);motion=p['parts'][name]
      image=image.rotate(motion['angle'],resample=Image.Resampling.NEAREST,center=pivot)
      canvas.alpha_composite(image,(int(anchor[0]-pivot[0]+motion['dx']),int(anchor[1]-pivot[1]+motion['dy']+p['bob'])))
    if state=='downed':
      down=canvas.resize((52,25),Image.Resampling.NEAREST);canvas=Image.new('RGBA',(64,64));canvas.alpha_composite(down,(6,31))
    elif state=='revive':
      canvas=ImageEnhance.Brightness(canvas).enhance(1.1+index*.15)
    return canvas


def make_rig(rig_id:str) -> dict:
    return {'schema_version':1,'rig_id':rig_id,'parts':[{'id':name,'file':f'parts/{name}.png','pivot':list(PIVOTS[rig_id][name]),'anchor':list(PIVOTS[rig_id][name])} for name in RIG_PARTS[rig_id]]}


def bake_atlas(parts:dict,rig:dict,masks:dict|None=None) -> tuple[Image.Image,Image.Image]:
    atlas=Image.new('RGBA',(544,272));frame=0;portrait=None
    for state,count in FRAME_STATES:
      for i in range(count):
        cell=render_frame(parts,rig,state,i,count,masks)
        if portrait is None:portrait=cell
        atlas.alpha_composite(cell,((frame%8)*68+2,(frame//8)*68+2));frame+=1
    return atlas,portrait.resize((128,128),Image.Resampling.NEAREST)


def background(theme:dict) -> Image.Image:
    p=normalize_palette(theme['palette']);image=Image.new('RGB',(640,360),p[0]);d=ImageDraw.Draw(image)
    # Tall kiln/glasshouse windows, distant tiers and quiet central combat space.
    d.rectangle((0,198,639,319),fill=p[1]);d.polygon([(0,196),(48,158),(89,179),(137,135),(181,174),(231,141),(287,179),(344,130),(399,170),(448,139),(498,173),(553,132),(606,167),(639,153),(639,319),(0,319)],fill=p[1])
    for x in (40,168,296,424,552):
      d.rectangle((x,54,x+48,236),fill=p[2]);d.ellipse((x,30,x+48,81),fill=p[2]);d.rectangle((x+5,57,x+43,234),fill=p[0]);d.ellipse((x+5,36,x+43,80),fill=p[0]);d.rectangle((x+7,62,x+41,228),fill=p[1]);d.line((x+24,46,x+24,229),fill=p[2],width=2)
      d.line((x+7,111,x+41,111),fill=p[2],width=2);d.line((x+7,166,x+41,166),fill=p[2],width=2)
      # Hand-authored glass diamonds and hanging lanterns.
      d.polygon([(x+24,69),(x+35,87),(x+24,103),(x+13,87)],outline=p[3]);d.line((x+24,0,x+24,48),fill=p[2]);d.ellipse((x+18,48,x+30,62),fill=p[3]);d.rectangle((x+21,51,x+27,58),fill=p[5])
    for y in (244,276,308):
      d.rectangle((0,y,639,y+4),fill=p[0]);d.line((0,y+5,639,y+5),fill=p[2])
      for x in range(16 if y==276 else 0,640,64):d.line((x,y+7,x,y+29),fill=p[0])
    for x in (8,620):
      d.line([(x,319),(x+4,258),(x-3,209),(x+6,162),(x,108)],fill=p[0],width=8)
      for y,dx in ((260,24),(210,-20),(166,19)):
        d.line([(x,y),(x+dx,y-20),(x+dx*2,y-25)],fill=p[2],width=3)
    # A moon/heart-like emblem centres the stage without hiding projectiles.
    d.ellipse((302,14,338,50),outline=p[3],width=2);d.ellipse((310,22,330,42),outline=p[4]);d.line((320,18,320,46),fill=p[2])
    d.rectangle((0,320,639,359),fill=p[0]);d.line((0,320,639,320),fill=p[3],width=2)
    return image.convert('RGBA')


def materials(theme:dict) -> Image.Image:
    p=normalize_palette(theme['palette']);image=Image.new('RGBA',(256,256),p[1]);d=ImageDraw.Draw(image)
    for row in range(4):
      for col in range(4):
        x,y=col*64,row*64; d.rectangle((x,y,x+63,y+63),fill=p[1 if row%2==0 else 2]);d.line((x,y,x+63,y),fill=p[3]);d.line((x,y,x,y+63),fill=p[0])
        if row==0:
          for yy in (20,42):d.line((x, y+yy, x+63,y+yy),fill=p[0])
          for xx,yy in ((20,0),(43,20),(16,42)):d.line((x+xx,y+yy,x+xx,y+yy+20),fill=p[0])
          d.line((x+3,y+3,x+18,y+3),fill=p[2])
        elif row==1:
          d.rectangle((x+5,y+5,x+58,y+58),outline=p[3]);d.line((x+10,y+32,x+54,y+32),fill=p[0],width=2)
          for xx,yy in ((9,9),(54,9),(9,54),(54,54)):d.ellipse((x+xx-1,y+yy-1,x+xx+1,y+yy+1),fill=p[5])
        elif row==2:
          for off in (8,25,42):d.line([(x+off,y+63),(x+off+7,y+41),(x+off,y+22),(x+off+12,y)],fill=p[3],width=4)
          d.line([(x+12,y+63),(x+18,y+43),(x+10,y+23),(x+21,y)],fill=p[4],width=2)
        else:
          for yy in range(4,64,8):d.line((x+2,y+yy,x+61,y+yy),fill=p[3])
          for xx in range(4,64,8):d.line((x+xx,y+2,x+xx,y+61),fill=p[1])
    return image
