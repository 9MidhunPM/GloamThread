"""Six original recognizable drawings for creator/rig acceptance.

These retain known separated parts and expected features for local conversion.
They do not establish provider recognition or arbitrary-drawing segmentation.
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image,ImageDraw
from .art import authored_parts,make_rig
from .rigs import write_json
from .validation import sha256

PALETTE=['#111925','#263b50','#567d8c','#87b8b6','#d7c996','#fff0bd']
DESIGNS={
 'upright_fox':('upright','Kiln Fox','ember',['long pointed ears','copper mask','glowing chest core']),
 'upright_bucket':('upright','Bucket Knight','stone',['square helmet','three short helmet studs','blue chest plate']),
 'quadruped_seed':('quadruped','Seed Stag','nature',['branch antlers','four thin legs','luminous seed in flank']),
 'quadruped_pebble':('quadruped','Pebbleback','stone',['low lizard head','triangular back plates','paddle tail']),
 'floating_manta':('floating','Lantern Manta','storm',['two wide angular fins','stitched face','two trailing ribbons']),
 'floating_orb':('floating','Clock Orb','frost',['round clock body','one large central eye','two curly ribbons']),
}


def parts_for(identifier:str)->dict:
    rig=DESIGNS[identifier][0];parts=authored_parts(rig,PALETTE)
    if identifier=='upright_bucket':
        parts['head']=Image.new('RGBA',(64,64));d=ImageDraw.Draw(parts['head'])
        d.rectangle((21,13,44,29),fill=PALETTE[0]);d.rectangle((23,15,42,27),fill=PALETTE[2]);d.rectangle((26,19,41,23),fill=PALETTE[0]);d.line((28,20,38,20),fill=PALETTE[5])
        for x in (25,32,39):d.rectangle((x,9,x+2,14),fill=PALETTE[3])
        d.line((23,26,41,26),fill=PALETTE[4]);d.line((39,15,39,25),fill=PALETTE[1])
        d=ImageDraw.Draw(parts['torso']);d.polygon([(24,27),(40,27),(41,38),(33,43),(23,38)],fill=PALETTE[2]);d.line((25,29,38,29),fill=PALETTE[3],width=2);d.rectangle((30,32,35,37),fill=PALETTE[4])
    elif identifier=='quadruped_pebble':
        parts['head']=Image.new('RGBA',(64,64));d=ImageDraw.Draw(parts['head']);d.polygon([(37,29),(48,27),(57,31),(56,38),(44,40),(37,35)],fill=PALETTE[0]);d.polygon([(40,30),(47,30),(54,33),(53,36),(44,37)],fill=PALETTE[2]);d.rectangle((48,31,51,33),fill=PALETTE[5]);d.line((50,36,55,36),fill=PALETTE[0])
        d=ImageDraw.Draw(parts['torso']);d.ellipse((15,28,43,44),fill=PALETTE[2])
        for x in (17,25,33):d.polygon([(x,29),(x+3,21),(x+8,29)],fill=PALETTE[0]);d.polygon([(x+2,28),(x+3,24),(x+5,28)],fill=PALETTE[4])
        parts['tail']=Image.new('RGBA',(64,64));d=ImageDraw.Draw(parts['tail']);d.polygon([(18,32),(9,30),(3,33),(3,38),(12,39),(18,36)],fill=PALETTE[0]);d.line((5,35,17,34),fill=PALETTE[3],width=3)
    elif identifier=='floating_orb':
        parts['torso']=Image.new('RGBA',(64,64));d=ImageDraw.Draw(parts['torso']);d.ellipse((17,18,48,49),fill=PALETTE[0]);d.ellipse((20,21,45,46),fill=PALETTE[2]);d.ellipse((23,24,42,43),outline=PALETTE[4],width=2);d.ellipse((26,27,39,40),fill=PALETTE[0]);d.ellipse((30,29,36,37),fill=PALETTE[5]);d.ellipse((33,31,36,35),fill=PALETTE[1])
        for x,y in ((31,18),(17,32),(46,32),(31,47)):d.rectangle((x-1,y-1,x+2,y+2),fill=PALETTE[4])
        for name,side in [('arm_back',-1),('arm_front',1)]:
            parts[name]=Image.new('RGBA',(64,64));d=ImageDraw.Draw(parts[name]);d.line([(32+side*13,33),(32+side*23,34),(32+side*25,43),(32+side*19,47),(32+side*17,42)],fill=PALETTE[0],width=5);d.line([(32+side*14,33),(32+side*22,35),(32+side*23,42),(32+side*19,45)],fill=PALETTE[3],width=2)
    return parts


def board_for(identifier:str)->Image.Image:
    parts=parts_for(identifier);board=Image.new('RGBA',(1024,1024));assembled=Image.new('RGBA',(64,64))
    for n,part in enumerate(parts.values()):
        assembled.alpha_composite(part);crop=part.crop(part.getbbox());crop=crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST)
        x0,x1=(n%3)*1024//3,((n%3)+1)*1024//3;y0,y1=(n//3)*1024//3,((n//3)+1)*1024//3
        board.alpha_composite(crop,(x0+(x1-x0-crop.width)//2,y0+(y1-y0-crop.height)//2))
    master=assembled.crop(assembled.getbbox());master=master.resize((master.width*4,master.height*4),Image.Resampling.NEAREST)
    board.alpha_composite(master,(682+(342-master.width)//2,682+(342-master.height)//2));return board


def rebuild(root:Path)->dict:
    folder=root/'assets/arena/source/fixtures';folder.mkdir(parents=True,exist_ok=True);records=[]
    for identifier,(rig,name,kit,features) in DESIGNS.items():
        parts=parts_for(identifier);master=Image.new('RGBA',(64,64))
        target=folder/identifier;target.mkdir(parents=True,exist_ok=True);(target/'parts').mkdir(exist_ok=True)
        for part_name,part in parts.items():master.alpha_composite(part);part.save(target/f'parts/{part_name}.png')
        # A larger retained drawing is readable in the creator input canvas.
        master.resize((256,256),Image.Resampling.NEAREST).save(target/'drawing.png')
        write_json(target/'rig.json',make_rig(rig))
        records.append({'id':identifier,'name':name,'rig_id':rig,'kit_id':kit,'expected_features':features,'file':f'{identifier}/drawing.png','sha256':sha256(target/'drawing.png')})
    index={'schema_version':1,'notice':'Original local creator/rig fixtures, not provider recognition evidence.','drawings':records,'source':'tools/forge/fixtures.py','source_sha256':sha256(Path(__file__))}
    write_json(folder/'index.json',index);return index
