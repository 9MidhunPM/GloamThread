"""Original scrolling-world pixel scenery:24props,fourlandmarks,fourparallaxlayers."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
from PIL import Image,ImageDraw
from .rigs import write_json
from .validation import require,sha256

ROOT=Path(__file__).resolve().parents[2]
PROPS=['lantern_pole','kiln_brazier','thread_spool','root_arch','glass_fern','hanging_bell','broken_column','ivy_pillar','iron_gate','seed_pod','crystal_cluster','woven_banner','stone_stack','hollow_log','little_shrine','water_pipe','copper_cogs','thorn_bush','blue_mushrooms','tomb_marker','rope_coil','wind_chimes','cave_lantern','old_crate']
LANDMARKS=['bell_oak','glass_gate','spool_tower','crown_loom']
P={'outline':'#101a26','deep':'#1d3540','stone':'#3d5963','edge':'#6f9290','wood':'#62554b','wood_light':'#a18361','copper':'#bc8857','gold':'#e9c58c','glow':'#f9e7af','leaf':'#548a76','leaf_light':'#91b996','blue':'#8ec9cc','violet':'#8d7a98'}


def prop(name:str)->Image.Image:
    im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im);o=P['outline'];c=P['copper'];g=P['gold'];e=P['edge'];s=P['stone'];w=P['wood'];l=P['leaf'];b=P['blue']
    if name=='lantern_pole':
        d.line([(24,56),(24,13),(38,8),(47,13)],fill=o,width=5);d.line([(25,55),(25,15),(38,11),(44,14)],fill=w,width=2);d.rectangle((39,14,51,32),fill=o);d.polygon([(41,17),(48,16),(49,27),(42,29)],fill=g);d.line((45,17,45,29),fill=c);d.polygon([(17,56),(28,51),(32,56)],fill=o)
    elif name=='kiln_brazier':
        d.polygon([(17,56),(20,44),(44,44),(48,56)],fill=o);d.ellipse((14,33,50,49),fill=o);d.ellipse((18,35,46,44),fill=c);d.polygon([(23,38),(20,27),(29,30),(31,17),(38,28),(44,25),(41,38)],fill=c);d.polygon([(27,38),(27,30),(33,26),(38,36)],fill=P['glow']);d.line((20,48,44,48),fill=e,width=2)
    elif name=='thread_spool':
        d.ellipse((13,18,49,54),fill=o);d.ellipse((16,21,46,51),fill=w);d.ellipse((22,24,41,47),fill=c);d.ellipse((25,28,38,43),fill=g);d.ellipse((29,32,34,38),fill=o)
        for y in range(26,46,4):d.line((23,y,40,y),fill=P['wood_light'])
        d.line([(38,43),(50,47),(46,54),(56,56)],fill=g,width=2)
    elif name=='root_arch':
        d.arc((7,9,57,75),182,356,fill=o,width=12);d.arc((9,12,55,73),183,355,fill=w,width=7);d.arc((11,15,53,71),186,350,fill=P['wood_light'],width=2)
        for x,y in ((11,34),(16,21),(38,16),(48,30)):
            d.polygon([(x,y),(x-8,y-6),(x-5,y-11),(x+2,y-5)],fill=l)
        d.line([(12,46),(6,51),(4,56)],fill=w,width=4);d.line([(51,44),(57,52),(60,56)],fill=w,width=4)
    elif name=='glass_fern':
        d.line([(32,56),(29,32),(35,10)],fill=o,width=4);d.line((32,54,33,17),fill=e,width=2)
        for y,side in ((20,-1),(28,1),(36,-1),(44,1)):
            x=32+side*18;d.polygon([(32,y+7),(x,y-3),(x+side*4,y-12),(32,y)],fill=o);d.line((33,y+2,x,y-8),fill=b,width=3)
    elif name=='hanging_bell':
        d.line((32,5,32,28),fill=w,width=3);d.polygon([(22,28),(24,21),(39,21),(42,29),(44,43),(49,48),(15,48),(20,42)],fill=o);d.polygon([(26,25),(36,24),(39,40),(42,44),(22,44),(25,38)],fill=c);d.line((28,27,28,41),fill=g,width=2);d.ellipse((28,45,36,53),fill=o);d.point((32,49),fill=g)
    elif name=='broken_column':
        d.rectangle((15,49,49,56),fill=o);d.rectangle((19,25,44,49),fill=o);d.polygon([(19,25),(22,14),(29,18),(34,11),(44,19),(44,29)],fill=s);d.rectangle((22,27,41,47),fill=s);d.line((26,28,26,46),fill=e,width=2);d.line((36,22,36,44),fill=P['deep'],width=2);d.line((18,51,46,51),fill=e,width=2)
    elif name=='ivy_pillar':
        d.rectangle((24,7,41,56),fill=o);d.rectangle((27,9,38,54),fill=s);d.line((29,10,29,52),fill=e);d.line([(21,56),(32,44),(24,33),(38,22),(32,7)],fill=l,width=4)
        for x,y in ((25,44),(29,33),(33,22),(33,12)):d.polygon([(x,y),(x-10,y-5),(x-8,y-11),(x+1,y-4)],fill=P['leaf_light'])
    elif name=='iron_gate':
        d.arc((8,4,56,54),180,360,fill=o,width=7);d.line((11,28,11,56),fill=o,width=6);d.line((53,28,53,56),fill=o,width=6)
        for x in (21,31,42):d.line((x,15 if x==31 else 22,x,55),fill=s,width=3);d.point((x,52),fill=c)
        d.line((14,36,50,36),fill=e,width=2);d.line((14,48,50,48),fill=e,width=2)
    elif name=='seed_pod':
        d.line((31,56,29,44),fill=w,width=3);d.ellipse((16,17,47,50),fill=o);d.polygon([(19,34),(23,22),(32,17),(42,25),(44,39),(34,47),(25,43)],fill=l);d.ellipse((26,26,37,41),fill=P['deep']);d.ellipse((29,28,35,37),fill=g);d.line((32,15,38,9),fill=P['leaf_light'],width=2)
    elif name=='crystal_cluster':
        for x,y,h in ((13,42,17),(25,28,30),(38,35,23)):
            d.polygon([(x,y),(x+5,y-h),(x+13,y-4),(x+10,56),(x+2,56)],fill=o);d.polygon([(x+3,y),(x+6,y-h+5),(x+9,y-3),(x+7,52)],fill=b);d.line((x+6,y-h+5,x+6,50),fill=P['edge'])
    elif name=='woven_banner':
        d.line((18,56,18,7),fill=o,width=5);d.line((19,9,48,9),fill=c,width=3);d.polygon([(23,12),(46,12),(46,44),(35,39),(23,47)],fill=o);d.polygon([(26,15),(43,15),(43,38),(35,34),(26,41)],fill=P['violet']);d.line((29,18,29,35),fill=g);d.line((39,18,39,35),fill=g);d.line((27,25,42,25),fill=w)
    elif name=='stone_stack':
        for box in ((9,44,55,56),(15,31,49,46),(23,21,43,33)):
            x,y,x1,y1=box;d.polygon([(x,y+3),(x+5,y),(x1-4,y),(x1,y+5),(x1-2,y1),(x+3,y1)],fill=o);d.line((x+6,y+3,x1-5,y+3),fill=e,width=3);d.line((x+5,y+7,x1-4,y+7),fill=s,width=3)
    elif name=='hollow_log':
        d.rounded_rectangle((9,31,53,55),radius=9,fill=o);d.rectangle((18,33,45,51),fill=w);d.ellipse((7,32,28,55),fill=o);d.ellipse((11,36,24,51),fill=P['wood_light']);d.ellipse((14,39,22,49),fill=P['deep']);d.line((29,37,49,37),fill=P['wood_light']);d.line((31,45,50,46),fill=o);d.polygon([(22,32),(32,27),(43,30),(49,27),(51,33)],fill=l)
    elif name=='little_shrine':
        d.rectangle((13,51,51,56),fill=o);d.rectangle((19,24,45,51),fill=o);d.polygon([(11,25),(31,9),(53,25)],fill=o);d.line([(16,23),(31,13),(47,23)],fill=c,width=3);d.rectangle((23,27,41,47),fill=s);d.ellipse((27,30,37,40),fill=g);d.rectangle((28,42,36,47),fill=P['deep'])
    elif name=='water_pipe':
        d.line([(8,56),(8,31),(16,23),(45,23),(53,32),(53,56)],fill=o,width=10);d.line([(9,55),(9,32),(17,26),(44,26),(50,32),(50,55)],fill=s,width=5);d.ellipse((25,18,39,32),fill=o);d.ellipse((28,21,36,29),outline=c,width=2);d.line((32,18,32,31),fill=c);d.point((52,47),fill=b)
    elif name=='copper_cogs':
        for cx,cy,r in ((25,37,17),(44,25,11)):
            pts=[]
            for n in range(32):
                angle=n*math.tau/32;radius=r if n%4 in (0,1) else r-4;pts.append((round(cx+math.cos(angle)*radius),round(cy+math.sin(angle)*radius)))
            d.polygon(pts,fill=o);d.ellipse((cx-r+5,cy-r+5,cx+r-5,cy+r-5),outline=c,width=3);d.ellipse((cx-4,cy-4,cx+4,cy+4),fill=g)
    elif name=='thorn_bush':
        for points in ([(30,56),(27,35),(12,24),(7,12)],[(29,48),(43,34),(51,16)],[(26,35),(34,17),(31,6)]):d.line(points,fill=o,width=5);d.line(points,fill=P['violet'],width=2)
        for x,y in ((15,27),(39,37),(32,21)):d.polygon([(x,y),(x-6,y-8),(x+3,y-4)],fill=P['violet'])
    elif name=='blue_mushrooms':
        for x,y,r in ((17,41,12),(36,30,14),(49,45,9)):
            d.line((x,y,x+1,56),fill=o,width=5);d.line((x,y+2,x,53),fill=e,width=2);d.pieslice((x-r,y-r,x+r,y+r),180,360,fill=o);d.arc((x-r+3,y-r+3,x+r-3,y+r-2),190,350,fill=b,width=3);d.point((x-2,y-6),fill=g)
    elif name=='tomb_marker':
        d.rectangle((17,50,48,56),fill=o);d.rounded_rectangle((20,17,45,52),radius=10,fill=o);d.rounded_rectangle((23,20,42,48),radius=7,fill=s);d.ellipse((28,26,37,35),outline=e,width=2);d.line((27,39,38,39),fill=e);d.line((29,43,36,43),fill=P['deep'])
    elif name=='rope_coil':
        for y in (46,41,36):d.ellipse((12,y-6,48,y+8),outline=o,width=5);d.arc((14,y-4,46,y+6),10,345,fill=P['wood_light'],width=2)
        d.line([(39,48),(50,50),(52,55),(59,55)],fill=c,width=3)
    elif name=='wind_chimes':
        d.line((32,3,32,13),fill=w,width=2);d.line((15,14,50,14),fill=c,width=3)
        for x,y in ((19,31),(31,43),(44,35)):
            d.line((x,15,x,y),fill=e);d.rectangle((x-3,y,x+4,y+12),fill=o);d.line((x-1,y+2,x-1,y+9),fill=g,width=2)
    elif name=='cave_lantern':
        d.rectangle((17,49,47,56),fill=o);d.line((22,47,22,26),fill=o,width=3);d.line((43,47,43,26),fill=o,width=3);d.arc((21,14,44,37),180,360,fill=c,width=3);d.rectangle((25,28,40,46),fill=o);d.rectangle((28,31,37,42),fill=b);d.line((32,31,32,43),fill=e)
    else:
        d.rectangle((12,24,52,56),fill=o);d.rectangle((15,27,49,53),fill=w)
        for x in (21,30,39):d.line((x,28,x,52),fill=P['wood_light'])
        d.line((17,29,46,51),fill=o,width=5);d.line((17,29,46,51),fill=c,width=2);d.rectangle((12,24,52,29),outline=e,width=2);d.rectangle((12,51,52,56),outline=e,width=2)
    return im


def landmark(name:str)->Image.Image:
    im=Image.new('RGBA',(128,192));d=ImageDraw.Draw(im);o=P['outline'];c=P['copper'];g=P['gold'];s=P['stone'];e=P['edge'];w=P['wood'];l=P['leaf'];b=P['blue']
    d.ellipse((11,166,117,182),fill=o)
    if name=='bell_oak':
        d.line([(59,176),(53,134),(69,96),(57,55),(68,20)],fill=o,width=23);d.line([(60,174),(57,133),(72,96),(61,55),(69,24)],fill=w,width=12)
        for points in ([(60,145),(33,123),(17,111)],[(68,98),(96,80),(111,52)],[(61,57),(36,44),(21,22)],[(60,129),(96,117),(112,126)]):d.line(points,fill=o,width=12);d.line(points,fill=P['wood_light'],width=5)
        for x,y in ((18,31),(35,49),(83,43),(103,64),(24,104),(94,105)):
            d.polygon([(x-15,y),(x-6,y-13),(x+12,y-9),(x+18,y+4),(x+3,y+13)],fill=P['deep']);d.line((x-9,y-5,x+6,y-8),fill=l,width=3)
        for x,y in ((24,62),(92,93),(40,115)):
            d.line((x,y-16,x,y+5),fill=c);d.polygon([(x-6,y),(x+6,y),(x+7,y+13),(x+10,y+16),(x-9,y+16),(x-6,y+12)],fill=o);d.line((x-3,y+3,x-3,y+12),fill=g,width=3)
        d.line([(57,158),(42,173),(22,176)],fill=w,width=7);d.line([(65,159),(83,174),(106,176)],fill=w,width=7)
    elif name=='glass_gate':
        d.rectangle((17,76,31,176),fill=o);d.rectangle((96,76,110,176),fill=o);d.arc((17,13,110,131),180,360,fill=o,width=15);d.arc((23,22,104,130),180,360,fill=s,width=7);d.rectangle((23,77,27,173),fill=e);d.rectangle((100,77,104,173),fill=e)
        for x in (43,63,84):d.line((x,46 if x!=63 else 32,x,168),fill=s,width=3)
        for y in (77,116,153):d.line((32,y,95,y),fill=c,width=2)
        d.polygon([(63,55),(83,96),(63,137),(43,96)],fill=P['deep']);d.line([(63,60),(78,96),(63,130),(48,96),(63,60)],fill=b,width=3);d.ellipse((56,89,70,103),fill=g)
        d.rectangle((11,169,117,179),fill=o);d.line((15,171,112,171),fill=e,width=2)
    elif name=='spool_tower':
        d.rectangle((24,60,100,176),fill=o);d.rectangle((31,66,93,170),fill=s)
        for y in (79,119,153):d.line((29,y,96,y),fill=P['deep'],width=4)
        d.ellipse((20,29,107,119),fill=o);d.ellipse((26,35,101,113),fill=w);d.ellipse((34,43,93,105),fill=P['deep'])
        for angle in range(0,360,45):
            a=math.radians(angle);d.line((64,74,64+math.cos(a)*32,74+math.sin(a)*32),fill=c,width=4)
        d.ellipse((51,61,77,87),fill=o);d.ellipse((56,66,72,82),fill=g)
        d.line([(14,168),(14,117),(25,105)],fill=o,width=9);d.line([(111,168),(111,121),(101,109)],fill=o,width=9);d.line((110,129,110,165),fill=b,width=3)
        d.rectangle((19,18,109,30),fill=o);d.line((23,22,105,22),fill=e,width=3)
    else:
        for x in (20,96):d.rectangle((x,37,x+12,176),fill=o);d.rectangle((x+4,41,x+8,171),fill=w)
        d.polygon([(14,39),(14,25),(33,33),(44,14),(62,29),(81,13),(94,31),(115,24),(115,40)],fill=o);d.line([(19,34),(32,38),(45,23),(62,36),(81,22),(95,37),(110,33)],fill=g,width=3)
        d.rectangle((30,47,97,154),fill=P['deep'])
        for x in range(38,96,8):d.line((x,50,x,150),fill=P['wood_light'])
        for y in range(57,151,10):d.line((34,y,93,y),fill=c)
        d.polygon([(64,58),(83,96),(64,140),(45,96)],fill=o);d.line([(64,65),(77,96),(64,130),(51,96),(64,65)],fill=b,width=3);d.ellipse((58,91,70,103),fill=g)
        d.rectangle((11,170,117,179),fill=o);d.line((16,172,112,172),fill=c,width=3)
    return im


def layers()->dict[str,Image.Image]:
    sky=Image.new('RGBA',(640,360));d=ImageDraw.Draw(sky)
    for y in range(360):
        t=y/359;d.line((0,y,639,y),fill=(round(12+10*t),round(27+21*t),round(42+16*t),255))
    d.ellipse((481,31,541,91),fill='#57777e');d.ellipse((492,27,549,84),fill='#11283b')
    for x,y in ((44,42),(118,76),(213,25),(338,63),(411,27),(580,116),(290,94)):d.point((x,y),fill='#75938c')
    for x,y in ((-26,103),(157,54),(358,117),(531,72)):
        d.polygon([(x,y+12),(x+25,y+3),(x+53,y+7),(x+72,y),(x+108,y+12),(x+142,y+17),(x+17,y+20)],fill='#213c4a')
    far=Image.new('RGBA',(640,360));d=ImageDraw.Draw(far)
    d.polygon([(0,264),(48,221),(101,250),(158,183),(216,224),(266,165),(322,218),(378,178),(431,231),(490,196),(546,245),(600,202),(640,225),(640,360),(0,360)],fill='#1b3944')
    for x,h in ((15,74),(82,47),(146,82),(228,49),(304,63),(392,74),(476,51),(552,83),(623,64)):
        d.polygon([(x-24,292),(x-11,259),(x-18,260),(x-6,240),(x-11,241),(x,292-h),(x+13,243),(x+8,244),(x+23,268),(x+16,267),(x+29,292)],fill='#24484b');d.rectangle((x-3,280,x+4,350),fill='#203e47')
    canopy=Image.new('RGBA',(640,360));d=ImageDraw.Draw(canopy)
    for x in (-12,211,497,650):
        d.polygon([(x-20,360),(x-12,240),(x-22,145),(x-10,54),(x-25,0),(x+3,0),(x+13,57),(x+2,151),(x+13,251),(x+22,360)],fill='#1b343c')
        d.line([(x-3,181),(x+47,138),(x+63,99)],fill='#1b343c',width=13);d.line([(x,109),(x-43,76),(x-61,39)],fill='#1b343c',width=11)
        for xx,yy in ((x+38,123),(x-40,64)):
            d.polygon([(xx-39,yy),(xx-22,yy-23),(xx+7,yy-29),(xx+35,yy-9),(xx+47,yy+12),(xx+10,yy+18)],fill='#24464a')
    foreground=Image.new('RGBA',(640,360));d=ImageDraw.Draw(foreground)
    for x,side in ((0,1),(640,-1)):
        d.line([(x,360),(x+side*10,311),(x+side*4,264)],fill='#0c202b',width=9)
        for y in (306,327,345):d.polygon([(x,y+17),(x+side*43,y-7),(x+side*19,y-13),(x+side*8,y)],fill='#13313b')
    d.line([(0,0),(81,12),(155,4),(236,17),(315,8),(393,19),(475,2),(552,13),(640,2)],fill='#102732',width=8)
    for x in (64,184,352,537):d.line([(x,7),(x+5,29),(x-3,43)],fill='#1b3c40',width=3);d.polygon([(x,25),(x+15,27),(x+4,38)],fill='#21464a')
    return {'sky':sky,'far':far,'canopy':canopy,'foreground':foreground}


def rebuild(root:Path=ROOT)->dict:
    output=root/'assets/arena/scenery';output.mkdir(parents=True,exist_ok=True)
    atlas=Image.new('RGBA',(512,192));props={}
    for n,name in enumerate(PROPS):atlas.alpha_composite(prop(name),((n%8)*64,(n//8)*64));props[name]={'rect':[(n%8)*64,(n//8)*64,64,64],'origin':[32,56]}
    atlas.save(output/'props.png');atlas=Image.new('RGBA',(512,192));marks={}
    for n,name in enumerate(LANDMARKS):atlas.alpha_composite(landmark(name),(n*128,0));marks[name]={'rect':[n*128,0,128,192],'origin':[64,176]}
    atlas.save(output/'landmarks.png');layer_records=[]
    for (name,image),factor,y_factor in zip(layers().items(),(.08,.22,.42,.68),(.03,.10,.25,.5)):
        image.save(output/f'{name}.png');layer_records.append({'id':name,'file':f'{name}.png','sha256':sha256(output/f'{name}.png'),'size':[640,360],'factor':factor,'y_factor':y_factor})
    source=root/'assets/arena/source/scenery.json'
    write_json(source,{'schema_version':1,'authorship':'Original project-authored pixel recipes; no resource packs or provider calls.','palette':P,'props':PROPS,'landmarks':LANDMARKS,'layers':layer_records})
    index={'schema_version':1,'content_version':'scrolling-world-v1','layers':layer_records,'props':props,'landmarks':marks,
           'files':{name:sha256(output/name) for name in ['props.png','landmarks.png','sky.png','far.png','canopy.png','foreground.png']},
           'sources':{'tools/forge/scenery.py':sha256(Path(__file__)),'assets/arena/source/scenery.json':sha256(source)}}
    write_json(output/'index.json',index);return validate(root)


def validate(root:Path=ROOT)->dict:
    folder=root/'assets/arena/scenery';index=json.loads((folder/'index.json').read_text())
    require(index.get('schema_version')==1 and index.get('content_version')=='scrolling-world-v1','Scenery version differs.')
    require(set(index.get('props',{}))==set(PROPS) and set(index.get('landmarks',{}))==set(LANDMARKS),'Scenery inventory differs.')
    expected={'props.png':(512,192),'landmarks.png':(512,192),'sky.png':(640,360),'far.png':(640,360),'canopy.png':(640,360),'foreground.png':(640,360)}
    require(set(index.get('files',{}))==set(expected),'Scenery filenames differ.')
    for name,size in expected.items():
        file=folder/name;require(file.is_file() and not file.is_symlink() and sha256(file)==index['files'][name],'Scenery hash/path differs.')
        with Image.open(file) as image:require(image.format=='PNG' and image.size==size,'Scenery dimensions differ.')
    require(len(index['layers'])==4 and [x['id'] for x in index['layers']]==['sky','far','canopy','foreground'],'Four ordered parallax layers required.')
    for record in index['layers']:
        require(record.get('file')==record['id']+'.png' and record.get('sha256')==index['files'][record['file']] and record.get('size')==[640,360],'Parallax media reference differs.')
        require(type(record.get('factor')) in (float,int) and 0<=record['factor']<1 and type(record.get('y_factor')) in (float,int) and 0<=record['y_factor']<1,'Parallax factors are unbounded.')
    for group,cell in [('props',(64,64)),('landmarks',(128,192))]:
        with Image.open(folder/(group+'.png')) as atlas:
            shapes=set()
            for record in index[group].values():
                rect=record.get('rect');origin=record.get('origin')
                require(isinstance(rect,list) and len(rect)==4 and all(type(n) is int for n in rect),'Scenery frame rectangle differs.')
                x,y,w,h=rect;require((w,h)==cell and x>=0 and y>=0 and x+w<=512 and y+h<=192,'Scenery frame is outside atlas.')
                require(isinstance(origin,list) and len(origin)==2 and all(type(n) is int for n in origin) and 0<=origin[0]<=w and 0<=origin[1]<=h,'Scenery pivot differs.')
                alpha=atlas.crop((x,y,x+w,y+h)).convert('RGBA').getchannel('A');require(alpha.getbbox() is not None,'Scenery frame is empty.');shapes.add(alpha.tobytes())
            require(len(shapes)==len(index[group]),'Scenery silhouettes must remain distinct.')
    return index


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--build',action='store_true');parser.add_argument('--validate',action='store_true');args=parser.parse_args()
    index=rebuild() if args.build else validate();print(f"PASS scenery: {len(index['props'])}props,{len(index['landmarks'])}landmarks,{len(index['layers'])}layers")

if __name__=='__main__':main()
