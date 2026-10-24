"""Original enemy/boss pixel silhouettes and telegraphed16-frame poses."""
from __future__ import annotations
from pathlib import Path
import math
from PIL import Image,ImageDraw
from .rigs import write_json
from .validation import sha256,require
import json
import hashlib

ROLES=('swarm','chaser','charger','shooter','flyer','heavy')
BOSSES=('warden','artillery','tempest','loom')
OUT='#141726';DARK='#34364c';MID='#756579';EDGE='#bc8b87';EYE='#f3dca9';WARN='#ffba73';ACTIVE='#fff0c2'


def _ordinary(role:str,frame:int)->Image.Image:
    im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
    state='walk' if frame<4 else 'windup' if frame<8 else 'active' if frame<12 else 'recovery' if frame<14 else 'defeat'
    stride=[-2,0,2,0][frame%4] if state=='walk' else 0;bob=frame%2 if state=='walk' else 2 if state=='windup' else 0
    glow=ACTIVE if state=='active' else WARN if state=='windup' else EYE
    if role=='swarm':
      for x in (9,15,21):
        d.line([(x,20+bob),(x-4,24),(x-5+stride,28)],fill=OUT,width=3);d.line([(x+1,20+bob),(x+5,25),(x+6-stride,28)],fill=OUT,width=3)
        d.point((x-5+stride,28),fill=EDGE);d.point((x+6-stride,28),fill=EDGE)
      d.ellipse((5,10+bob,25,24+bob),fill=OUT);d.ellipse((7,11+bob,23,22+bob),fill=MID)
      d.polygon([(8,15+bob),(12,11+bob),(16,14+bob),(20,11+bob),(23,15+bob),(19,21+bob),(12,21+bob)],fill=DARK)
      d.line((10,16+bob,20,16+bob),fill=EDGE);d.ellipse((13,14+bob,17,19+bob),fill=glow)
      d.polygon([(23,16+bob),(29,13+bob),(28,19+bob),(25,23+bob)],fill=OUT);d.point((27,17+bob),fill=glow)
      if state=='active':d.line((27,17,31,13),fill=ACTIVE,width=2)
    elif role=='chaser':
      for x,dx in ((11,stride),(18,-stride)):
        d.line([(x,21),(x+dx,26),(x+dx+2,28)],fill=OUT,width=4);d.line((x+dx,27,x+dx+3,27),fill=MID)
      d.polygon([(11,12+bob),(18,11+bob),(23,23),(17,24),(12,22),(6,24),(8,18)],fill=OUT);d.polygon([(12,14+bob),(17,13+bob),(20,21),(15,19),(9,21)],fill='#88566b')
      d.polygon([(8,13+bob),(9,6+bob),(14,2+bob),(22,8+bob),(20,15+bob)],fill=OUT);d.polygon([(12,7+bob),(16,6+bob),(20,10+bob),(18,13+bob),(12,12+bob)],fill=MID);d.line((16,10+bob,20,10+bob),fill=glow)
      hand=(23,18) if state!='windup' else (20,11)
      d.line([(18,16+bob),hand],fill=OUT,width=4);d.line((hand[0],hand[1],29,9 if state=='windup' else 16),fill=EDGE,width=2)
      d.line((29,9 if state=='windup' else 16,31,12 if state=='windup' else 11),fill=glow,width=2)
      if state=='active':d.arc((16,7,32,25),270,85,fill=ACTIVE,width=2)
    elif role=='charger':
      for x,dx in ((9,stride),(21,-stride)):
        d.line([(x,20+bob),(x+dx,26),(x+dx+3,28)],fill=OUT,width=4);d.point((x+dx+3,28),fill=EDGE)
      d.ellipse((3,11+bob,26,24+bob),fill=OUT);d.polygon([(6,14+bob),(11,9+bob),(20,10+bob),(25,17+bob),(21,22+bob),(7,21+bob)],fill=MID)
      d.line((9,12+bob,10,20+bob),fill=DARK,width=2);d.line((16,11+bob,17,20+bob),fill=DARK,width=2)
      d.polygon([(22,14+bob),(28,12+bob),(30,16+bob),(28,24+bob),(23,23+bob)],fill=OUT);d.line((27,16+bob,29,16+bob),fill=glow)
      d.arc((18,5+bob,30,16+bob),170,25,fill=EDGE,width=3);d.point((28,7+bob),fill=EYE)
      if state=='windup':d.line((3,24,10,25),fill=WARN,width=2)
    elif role=='shooter':
      for x,dx in ((11,stride),(20,-stride)):
        d.line([(16,20),(x+dx,27),(x+dx+3,28)],fill=OUT,width=3);d.point((x+dx+3,28),fill=EDGE)
      d.polygon([(11,11+bob),(20,11+bob),(22,20),(16,24),(9,20)],fill=OUT);d.polygon([(13,13+bob),(18,13+bob),(19,20),(14,21)],fill=MID);d.ellipse((13,15,18,20),fill=EDGE)
      d.ellipse((9,3+bob,23,15+bob),fill=OUT);d.polygon([(12,6+bob),(19,5+bob),(21,9+bob),(18,12+bob),(11,11+bob)],fill=DARK);d.rectangle((17,7+bob,21,9+bob),fill=glow)
      d.line((20,17,29,14),fill=OUT,width=5);d.line((21,17,29,15),fill=EDGE,width=2);d.ellipse((26,12,31,17),fill=OUT);d.ellipse((28,13,30,15),fill=glow)
      d.line((6,12+bob,4,4+bob),fill=MID,width=2);d.point((4,3+bob),fill=EYE)
      if state=='active':d.line((29,14,31,14),fill=ACTIVE,width=3)
    elif role=='flyer':
      fold=5 if state=='windup' else [0,4,7,3][frame%4];y=15+bob
      d.polygon([(14,y-1),(8,4+fold),(1,7+fold),(3,18),(9,20),(14,y+4)],fill=OUT)
      d.polygon([(18,y-1),(24,4+fold),(31,7+fold),(29,18),(23,20),(18,y+4)],fill=OUT)
      d.line([(3,9+fold),(8,9+fold),(12,y)],fill=MID,width=2);d.line([(29,9+fold),(24,9+fold),(20,y)],fill=MID,width=2)
      d.ellipse((11,y-6,21,y+7),fill=OUT);d.ellipse((13,y-3,19,y+4),fill=EDGE);d.line((15,y-1,19,y-1),fill=glow)
      d.line((14,y+6,11,y+10),fill=DARK,width=2);d.line((18,y+6,21,y+10),fill=DARK,width=2)
      if state=='active':d.line((22,y,31,y+3),fill=ACTIVE,width=2)
    else:
      for x,dx in ((8,stride),(21,-stride)):
        d.rectangle((x+dx,22,x+dx+6,28),fill=OUT);d.line((x+dx+1,26,x+dx+5,26),fill=MID)
      d.polygon([(5,10+bob),(10,5+bob),(23,5+bob),(28,11+bob),(26,25),(6,25)],fill=OUT)
      d.polygon([(8,12+bob),(11,8+bob),(22,8+bob),(25,13+bob),(23,23),(9,23)],fill=DARK);d.line((10,10+bob,10,21),fill=EDGE,width=2);d.line((22,10+bob,22,21),fill=EDGE,width=2)
      d.ellipse((12,11+bob,21,21+bob),fill=OUT);d.ellipse((14,13+bob,19,19+bob),fill=glow);d.line((16,12+bob,16,20+bob),fill=MID,width=2)
      d.line((5,15+bob,2,23 if state!='windup' else 7),fill=OUT,width=5);d.line((27,15+bob,30,23 if state!='windup' else 7),fill=OUT,width=5)
      d.rectangle((12,2+bob,22,6+bob),fill=OUT);d.line((15,4+bob,21,4+bob),fill=glow)
      if state=='active':d.line((1,27,31,27),fill=ACTIVE,width=2)
    if state=='windup':d.line((11,0,14,3),fill=WARN);d.line((22,0,19,3),fill=WARN)
    if state=='defeat':
      flat=im.resize((30,10 if frame==14 else 6),Image.Resampling.NEAREST);im=Image.new('RGBA',(32,32));im.alpha_composite(flat,(1,28-flat.height))
      d=ImageDraw.Draw(im);d.line([(3,28),(8,26),(12,29),(20,27),(27,29)],fill=EDGE)
    return im


def _boss(name:str,frame:int)->Image.Image:
    im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
    phase='walk' if frame<4 else 'windup' if frame<8 else 'active' if frame<12 else 'recover' if frame<14 else 'defeat'
    bob=frame%2 if phase=='walk' else 2 if phase=='windup' else 0
    stride=[-2,0,2,0][frame%4] if phase=='walk' else 0;glow=ACTIVE if phase=='active' else WARN if phase=='windup' else EYE
    accent={'warden':'#b67b5d','artillery':'#8799ad','tempest':'#9b83b5','loom':'#b5a579'}[name]
    for x,dx in ((20,stride),(39,-stride)):
        d.line([(x,45),(x+dx-2,55),(x+dx+7,59)],fill=OUT,width=8);d.line((x+dx-1,55,x+dx+5,57),fill=accent,width=3)
    if name=='tempest':
      fold=9 if phase=='windup' else [0,3,7,2][frame%4]
      d.polygon([(28,24),(12,6+fold),(2,11+fold),(5,35),(18,43),(28,37)],fill=OUT);d.polygon([(36,24),(52,6+fold),(62,11+fold),(59,35),(46,43),(36,37)],fill=OUT)
      for side in (-1,1):
        d.line([(32+side*8,29),(32+side*21,14+fold),(32+side*25,28)],fill=accent,width=2)
        d.ellipse((32+side*18-3,21+fold,32+side*18+3,27+fold),outline=glow,width=2)
    if name=='artillery':
      d.polygon([(14,28),(8,35),(6,50),(12,54),(18,47),(22,36)],fill=OUT);d.polygon([(47,27),(55,34),(59,49),(53,53),(47,45),(43,36)],fill=OUT)
      d.line((12,36,10,48),fill=accent,width=3);d.line((53,36,55,47),fill=accent,width=3)
    d.polygon([(22,18+bob),(41,18+bob),(48,30+bob),(45,46),(37,51),(23,48),(16,39)],fill=OUT)
    d.polygon([(24,22+bob),(38,22+bob),(44,31+bob),(41,44),(34,47),(25,44),(21,37)],fill=DARK)
    d.line((24,26+bob,24,40),fill=accent,width=3);d.line((39,25+bob,40,39),fill=accent,width=3)
    d.ellipse((25,28+bob,40,43+bob),fill=OUT);d.ellipse((28,31+bob,37,40+bob),fill=accent);d.ellipse((30,33+bob,35,38+bob),fill=glow)
    d.line((32,29+bob,32,41+bob),fill=OUT);d.line((27,35+bob,38,35+bob),fill=OUT)
    if name=='loom':
      for side in (-1,1):
        d.line([(32+side*10,26),(32+side*21,20),(32+side*27,9 if phase=='windup' else 26)],fill=OUT,width=6)
        d.line([(32+side*11,39),(32+side*21,43),(32+side*28,36 if phase=='active' else 51)],fill=OUT,width=6)
        d.line((32+side*20,22,32+side*25,14 if phase=='windup' else 26),fill=accent,width=2)
      d.line([(6,13),(17,18),(25,14),(37,18),(48,14),(57,20)],fill=accent)
    elif name!='tempest':
      for x,side in ((17,-1),(47,1)):
        end=(x+side*9,24 if phase=='windup' else 41)
        d.line([(x,28+bob),(x+side*4,34),end],fill=OUT,width=8);d.line((x+side*3,34,end[0],end[1]),fill=accent,width=3)
    # Different crowns and weapon tells give each encounter a distinct silhouette.
    d.polygon([(23,18+bob),(24,8+bob),(31,4+bob),(41,8+bob),(43,19+bob),(34,24+bob)],fill=OUT)
    d.polygon([(27,11+bob),(32,8+bob),(38,11+bob),(39,17+bob),(33,20+bob),(27,17+bob)],fill=accent);d.line((32,13+bob,39,13+bob),fill=glow,width=2)
    if name=='warden':
      d.line((49,39,58,19 if phase=='windup' else 44),fill=OUT,width=5);d.line((50,38,57,21 if phase=='windup' else 43),fill=accent,width=2)
      d.polygon([(52,18 if phase=='windup' else 40),(61,15 if phase=='windup' else 38),(61,25 if phase=='windup' else 48),(55,27 if phase=='windup' else 49)],fill=OUT)
      d.line((56,20 if phase=='windup' else 42,59,20 if phase=='windup' else 42),fill=glow,width=2)
    elif name=='artillery':
      d.rectangle((38,21+bob,61,29+bob),fill=OUT);d.rectangle((40,23+bob,59,27+bob),fill=accent);d.rectangle((57,21+bob,62,30+bob),fill=OUT);d.line((60,24+bob,62,24+bob),fill=glow,width=2)
      d.rectangle((26,1+bob,35,8+bob),fill=OUT);d.point((30,3+bob),fill=glow)
    elif name=='tempest':
      d.line([(24,11+bob),(22,3),(29,7),(33,0),(36,7),(44,3),(42,11+bob)],fill=accent,width=2)
    else:
      d.line([(24,12+bob),(18,4),(29,8),(32,1),(37,9),(47,4),(41,14+bob)],fill=accent,width=3)
    if phase=='active':d.arc((6,5,62,60),270,80,fill=ACTIVE,width=2)
    if phase=='windup':d.line((17,1,20,6),fill=WARN,width=2);d.line((49,1,46,6),fill=WARN,width=2)
    if phase=='defeat':
      flat=im.resize((60,22 if frame==14 else 13),Image.Resampling.NEAREST);im=Image.new('RGBA',(64,64));im.alpha_composite(flat,(2,59-flat.height))
      d=ImageDraw.Draw(im);d.line([(3,59),(14,55),(25,60),(38,56),(48,60),(61,57)],fill=accent,width=2)
    return im


def rebuild(root:Path)->dict:
    destination=root/'assets/arena/enemies';destination.mkdir(parents=True,exist_ok=True)
    records={}
    for key in (*ROLES,*BOSSES):
        size=64 if key in BOSSES else 32;atlas=Image.new('RGBA',(size*4,size*4))
        for frame in range(16):atlas.alpha_composite((_boss if size==64 else _ordinary)(key,frame),((frame%4)*size,(frame//4)*size))
        path=destination/f'{key}.png';atlas.save(path)
        records[key]={'file':path.name,'cell_size':[size,size],'origin':[size//2,size-4],'frames':16,'columns':4,'sha256':sha256(path)}
    value={'schema_version':1,'layout':'walk0-3, windup4-7, active8-11, recovery12-13, defeat14-15','assets':records,
           'provenance':{'method':'original authored pixel silhouettes and poses','source':'tools/forge/enemies.py','source_sha256':sha256(Path(__file__)),'provider_calls':0}}
    write_json(destination/'index.json',value);return value


def validate(root:Path)->dict:
    folder=root/'assets/arena/enemies';index=json.loads((folder/'index.json').read_text())
    require(type(index.get('schema_version')) is int and index['schema_version']==1,'Enemy asset index version is invalid.')
    require(isinstance(index.get('assets'),dict) and set(index['assets'])==set(ROLES+BOSSES),'Enemy role atlas set differs.')
    for key,record in index['assets'].items():
        n=64 if key in BOSSES else 32
        require(record.get('file')==key+'.png' and record.get('cell_size')==[n,n] and record.get('frames')==16 and record.get('columns')==4,'Enemy atlas metadata is invalid.')
        file=folder/record['file'];require(file.is_file() and not file.is_symlink() and sha256(file)==record.get('sha256'),'Enemy atlas hash/path is invalid.')
        with Image.open(file) as im:
            require(im.format=='PNG' and im.size==(n*4,n*4),'Enemy atlas dimensions are invalid.')
            frames=[im.crop(((f%4)*n,(f//4)*n,(f%4+1)*n,(f//4+1)*n)).convert('RGBA') for f in range(16)]
            require(all(frame.getchannel('A').getbbox() is not None for frame in frames),'Enemy atlas contains an empty pose.')
            require(len({hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames})>=6,'Enemy atlas lacks animation/tell states.')
    return index
