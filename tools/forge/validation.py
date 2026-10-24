"""Strict local admission of authored/generated fighter bundles and waves."""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path
import re
from PIL import Image
from .art import RIG_PARTS

KITS={'ember','frost','storm','stone','nature','shadow'}
STATS={'damage','attack_speed','special_cooldown','max_health','move_speed','crit','magnet','dodge_cooldown','lifesteal','thorns','projectile_count','area','burn','freeze','chain','stagger','regen','pierce'}
ROLES={'swarm','chaser','charger','shooter','flyer','heavy'}
IMAGE_SIZES={'character.png':(544,272),'portrait.png':(128,128),'background.png':(640,360),'materials.png':(256,256)}
FILES=set(IMAGE_SIZES)|{'provenance.json'}


class BundleError(ValueError): pass


def require(value:bool,message:str) -> None:
    if not value:raise BundleError(message)


def sha256(path:Path)->str:return hashlib.sha256(path.read_bytes()).hexdigest()


def text(value,minimum=1,maximum=160)->bool:
    return isinstance(value,str) and minimum<=len(value)<=maximum and not any(ord(x)<32 for x in value)


def number(value)->bool:return type(value) in (int,float) and math.isfinite(value)


def validate_proposal(value:dict)->dict:
    require(isinstance(value,dict),'Character proposal must be an object.')
    require(text(value.get('name'),1,40),'Character name must contain 1–40 printable characters.')
    require(value.get('rig_id') in RIG_PARTS,'Choose an upright, quadruped or floating rig.')
    require(value.get('kit_id') in KITS,'Choose a tested ability family.')
    theme=value.get('theme');require(isinstance(theme,dict),'Theme is missing.')
    require(text(theme.get('name'),1,60),'Theme name must contain 1–60 printable characters.')
    require(text(theme.get('motif'),1,400),'Theme motif must contain 1–400 printable characters.')
    palette=theme.get('palette');require(isinstance(palette,list) and 4<=len(palette)<=8,'Theme needs 4–8 colours.')
    require(all(isinstance(c,str) and re.fullmatch(r'#[0-9a-fA-F]{6}',c) for c in palette),'Theme colours must be #RRGGBB.')
    if 'features' in value:
        require(isinstance(value['features'],list) and len(value['features'])<=12 and all(text(x,1,160) for x in value['features']),'Features must be short text labels.')
    return value


def validate_bundle(folder:Path)->dict:
    require(folder.is_dir() and not folder.is_symlink(),'Bundle must be a local directory.')
    require((folder/'manifest.json').is_file() and not (folder/'manifest.json').is_symlink(),'Manifest is missing or unsafe.')
    require((folder/'manifest.json').stat().st_size<=128*1024,'Manifest is too large.')
    try: manifest=json.loads((folder/'manifest.json').read_text())
    except (OSError,ValueError):raise BundleError('Manifest must be valid JSON.') from None
    require(type(manifest.get('schema_version')) is int and manifest['schema_version']==1,'Unsupported bundle schema.')
    require(manifest.get('kind')=='fighter-character','Bundle kind must be fighter-character.')
    require(isinstance(manifest.get('id'),str) and re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,63}',manifest['id']),'Unsafe bundle ID.')
    validate_proposal(manifest)
    files=manifest.get('files');require(isinstance(files,dict) and set(files)==FILES,'Bundle files must match the fixed allowlist.')
    for name in FILES:
        file=folder/name
        require(file.is_file() and not file.is_symlink(),f'{name} is missing or unsafe.')
        require(file.stat().st_size<=8*1024*1024,f'{name} exceeds the byte limit.')
        require(isinstance(files[name],str) and re.fullmatch(r'[0-9a-f]{64}',files[name]) is not None,f'{name} hash is malformed.')
        require(sha256(file)==files[name],f'{name} hash does not match.')
        if name in IMAGE_SIZES:
            try:
                with Image.open(file) as image:
                    require(image.format=='PNG' and image.size==IMAGE_SIZES[name] and getattr(image,'n_frames',1)==1,f'{name} dimensions/format are invalid.')
                    image.load(); alpha=image.convert('RGBA').getchannel('A')
                    if name in ('background.png','materials.png'):require(alpha.getextrema()==(255,255),f'{name} must be opaque.')
                    elif name=='character.png':
                        require(alpha.getextrema()==(0,255),'Character needs transparent gutters and opaque content.')
                        seen=[]
                        for i in range(32):
                            x,y=(i%8)*68,(i//8)*68
                            cell=alpha.crop((x+2,y+2,x+66,y+66));require(cell.getbbox() is not None,f'Frame {i} is empty.')
                            gutter=alpha.crop((x,y,x+68,y+68));gutter.paste(0,(2,2,66,66));require(gutter.getbbox() is None,f'Frame {i} touches the atlas gutter.')
                            seen.append(hashlib.sha256(cell.tobytes()).hexdigest())
                        require(len(set(seen))>=8,'Character animation has too few distinct poses.')
            except (OSError,Image.DecompressionBombError):raise BundleError(f'{name} is not a safe PNG.') from None
    try:prov=json.loads((folder/'provenance.json').read_text())
    except (OSError,ValueError):raise BundleError('Provenance must be valid JSON.') from None
    require(isinstance(prov,dict) and prov.get('schema_version')==1,'Provenance schema is invalid.')
    return manifest


def validate_catalog(value:dict)->dict:
    require(value.get('schema_version')==1 and type(value.get('schema_version')) is int and value.get('content_version')=='arena-v1','Invalid arena catalog version.')
    require(isinstance(value.get('kits'),dict) and set(value['kits'])==KITS,'Catalog must contain six kit families.')
    for key,item in value['kits'].items():
        require(isinstance(item,dict) and all(text(item.get(k),1,400) for k in ('name','description','basic_name','special_name','passive_name')),f'Kit {key} is incomplete.')
        require(re.fullmatch(r'#[0-9a-fA-F]{6}',item.get('color','')) is not None,f'Kit {key} colour is invalid.')
    ups=value.get('upgrades');require(isinstance(ups,list) and len(ups)==30,'Catalog needs 30 upgrades.')
    ids=set()
    for item in ups:
        require(isinstance(item,dict) and re.fullmatch(r'[a-z][a-z0-9_]{0,47}',item.get('id','')) is not None and item['id'] not in ids,'Upgrade IDs must be safe and unique.');ids.add(item['id'])
        require(item.get('kit') in KITS|{'any'} and item.get('stat') in STATS,'Unknown upgrade family/stat.')
        require(text(item.get('name'),1,60) and text(item.get('description'),1,240),'Upgrade text missing.')
        require(number(item.get('amount')) and abs(item['amount'])<=100,'Upgrade amount is invalid.')
        require(type(item.get('price')) is int and 1<=item['price']<=100,'Upgrade price is invalid.')
        require(type(item.get('max_rank')) is int and 1<=item['max_rank']<=3,'Upgrade rank is invalid.')
    require(sum(x['kit']=='any' for x in ups)==12 and all(sum(x['kit']==k for x in ups)==3 for k in KITS),'Upgrade family counts differ.')
    waves=value.get('waves');require(isinstance(waves,list) and len(waves)==20,'Catalog needs 20 waves.')
    for n,item in enumerate(waves,1):
        require(item.get('number')==n and type(item['number']) is int,'Waves must be ordered 1–20.')
        require(type(item.get('count')) is int and 1<=item['count']<=100,'Wave count is invalid.')
        require(type(item.get('interval_ticks')) is int and 1<=item['interval_ticks']<=180,'Spawn interval is invalid.')
        require(isinstance(item.get('enemies'),list) and bool(item['enemies']) and set(item['enemies'])<=ROLES,'Wave enemy roles are invalid.')
        require(item.get('boss')==(['warden','artillery','tempest','loom'][(n-1)//5] if n%5==0 else ''),'Boss schedule is invalid.')
        require(type(item.get('elite_every')) is int and 0<=item['elite_every']<=100,'Elite cadence is invalid.')
    arenas=value.get('arenas');require(isinstance(arenas,list) and len(arenas)==4,'Catalog needs four arenas.')
    require(len({x.get('id') for x in arenas})==4,'Arena IDs must be unique.')
    for arena in arenas:
        require(text(arena.get('name'),1,60) and isinstance(arena.get('platforms'),list),'Arena is incomplete.')
        for rect in arena['platforms']:
            require(isinstance(rect,list) and len(rect)==3 and all(type(x) is int for x in rect),'Platform must have integer x,y,width.')
            x,y,w=rect;require(32<=x and x+w<=608 and 32<=w<=192 and y in (256,288),'Platform outside reachable arena bounds.')
    return value
