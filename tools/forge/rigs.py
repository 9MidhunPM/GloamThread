"""Deterministic art conversion/baking; never makes provider requests."""
from __future__ import annotations
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
from PIL import Image
from .art import RIG_PARTS, PIVOTS, authored_parts, make_rig, bake_atlas, background, materials
from .validation import BundleError, require, validate_bundle, validate_proposal, sha256


def write_json(path:Path,value:dict)->None:
    path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n');temp.replace(path)


def bundle_id(proposal:dict,source_digest:str='')->str:
    base=re.sub(r'[^a-z0-9]+','-',proposal['name'].lower()).strip('-')[:40] or 'fighter'
    return base+('-'+source_digest[:12] if source_digest else '')


def emit_bundle(parts:dict,rig:dict,proposal:dict,output:Path,provenance:dict,theme_images:tuple|None=None,masks:dict|None=None,identifier:str|None=None)->Path:
    validate_proposal(proposal)
    require(not output.exists(),'Candidate destination already exists; retain it or choose a new job.')
    output.mkdir(parents=True)
    try:
        atlas,portrait=bake_atlas(parts,rig,masks)
        atlas.save(output/'character.png');portrait.save(output/'portrait.png')
        bg,mat=theme_images if theme_images else (background(proposal['theme']),materials(proposal['theme']))
        bg.convert('RGBA').save(output/'background.png');mat.convert('RGBA').save(output/'materials.png')
        write_json(output/'provenance.json',{'schema_version':1,**provenance})
        manifest={'schema_version':1,'kind':'fighter-character','id':identifier or bundle_id(proposal),
                  'name':proposal['name'],'rig_id':proposal['rig_id'],'kit_id':proposal['kit_id'],'theme':proposal['theme'],
                  'files':{name:sha256(output/name) for name in ['character.png','portrait.png','background.png','materials.png','provenance.json']}}
        write_json(output/'manifest.json',manifest);validate_bundle(output)
        return output
    except Exception:
        # Retained as a rejected candidate; never silently installs or erases work.
        write_json(output/'rejected.json',{'schema_version':1,'reason':'Local bundle validation failed. Inspect retained source and masks.'})
        raise


def _read_part(path:Path)->Image.Image:
    require(path.is_file() and not path.is_symlink() and path.stat().st_size<=1024*1024,'Part file is unsafe or oversized.')
    with Image.open(path) as image:
        require(image.format=='PNG' and image.size==(64,64) and getattr(image,'n_frames',1)==1,'Part must be a64×64PNG.')
        image.load();return image.convert('RGBA')


def load_rig(job_dir:Path,rig_id:str)->tuple[dict,dict,dict]:
    require(not (job_dir/'rig.json').is_symlink(),'Rig metadata cannot be a symlink.')
    rig=json.loads((job_dir/'rig.json').read_text());require(rig.get('schema_version')==1 and rig.get('rig_id')==rig_id,'Rig type/version differs.')
    records=rig.get('parts');require(isinstance(records,list) and {p.get('id') for p in records}==set(RIG_PARTS[rig_id]) and len(records)==len(RIG_PARTS[rig_id]),'Rig part IDs differ.')
    parts={};masks={}
    edits_path=job_dir/'rig_edits.json'
    edits={}
    if edits_path.exists():
        require(not edits_path.is_symlink() and edits_path.stat().st_size<=65536,'Rig edits are unsafe.')
        edits_doc=json.loads(edits_path.read_text());require(edits_doc.get('schema_version')==1 and isinstance(edits_doc.get('parts'),dict),'Rig edit version is invalid.');edits=edits_doc['parts']
        require(set(edits)<=set(RIG_PARTS[rig_id]),'Unknown edited part.')
    for record in records:
        name=record['id'];require(record.get('file')==f'parts/{name}.png','Part paths must be fixed.')
        require(not (job_dir/'parts').is_symlink(),'Part directory cannot be a symlink.')
        parts[name]=_read_part(job_dir/record['file'])
        edit=edits.get(name,{})
        require(isinstance(edit,dict),'Rig edit must be an object.')
        if 'pivot' in edit:record['pivot']=edit['pivot']
        for field in ('pivot','anchor'):
            pair=record.get(field)
            require(isinstance(pair,list) and len(pair)==2 and all(type(n) in (float,int) and 0<=n<=63 for n in pair),'Pivot/anchor must be two bounded coordinates.')
        if 'mask_file' in edit:
            require(edit['mask_file']==f'masks/{name}.png','Mask paths must be fixed.')
            mask_path=job_dir/edit['mask_file'];require(not (job_dir/'masks').is_symlink() and mask_path.is_file() and not mask_path.is_symlink() and mask_path.stat().st_size<=1024*1024,'Mask is unsafe.')
            with Image.open(mask_path) as im:
                require(im.format=='PNG' and im.size==(64,64) and getattr(im,'n_frames',1)==1,'Mask must be64×64PNG.')
                masks[name]=im.getchannel('A') if im.mode=='RGBA' else im.convert('L')
        require(parts[name].getchannel('A').getbbox() is not None,'Part cannot be empty.')
    return parts,rig,masks


def bake_job(job_json:Path)->Path:
    job_dir=job_json.parent;job=json.loads(job_json.read_text())
    proposal=job.get('proposal')
    if proposal is None:proposal=json.loads((job_dir/'proposal.json').read_text())
    validate_proposal(proposal);parts,rig,masks=load_rig(job_dir,proposal['rig_id'])
    source_provenance=job_dir/'source_provenance.json'
    provenance=json.loads(source_provenance.read_text()) if source_provenance.exists() else {'method':'local authored rig bake','notice':'No provider request made by bake.'}
    provenance['rig_sha256']=sha256(job_dir/'rig.json')
    if (job_dir/'rig_edits.json').exists():provenance['rig_edits_sha256']=sha256(job_dir/'rig_edits.json')
    theme_files=(job_dir/'theme_background.png',job_dir/'theme_materials.png')
    theme_images=None
    if all(p.is_file() for p in theme_files):
        for file,size in zip(theme_files,[(640,360),(256,256)]):
            require(not file.is_symlink(),'Theme image is unsafe.')
            with Image.open(file) as im:require(im.format=='PNG' and im.size==size,'Theme dimensions are invalid.')
        theme_images=tuple(Image.open(p).convert('RGBA') for p in theme_files)
    # Each rebake gets a new sibling so preview acceptance never replaces a prior candidate.
    destination=job_dir/'candidate'
    if destination.exists():
        n=1
        while (job_dir/f'candidate-bake-{n}').exists():n+=1
        destination=job_dir/f'candidate-bake-{n}'
    return emit_bundle(parts,rig,proposal,destination,provenance,theme_images,masks,
                       identifier=bundle_id(proposal,hashlib.sha256(b''.join(p.tobytes() for p in parts.values())).hexdigest()))


def convert_generated(raw_parts:Path,raw_theme:Path,proposal:dict,job_dir:Path,provenance:dict)->Path:
    validate_proposal(proposal);require(not (job_dir/'parts').exists(),'Generated parts already exist; use bake to revise them.')
    for path in (raw_parts,raw_theme):
        require(path.is_file() and not path.is_symlink() and path.stat().st_size<=25*1024*1024,'Raw image is unsafe or oversized.')
    with Image.open(raw_parts) as image:
        require(image.format=='PNG' and image.size==(1024,1024) and getattr(image,'n_frames',1)==1,'Parts board must be a1024squarePNG.')
        board=image.convert('RGBA');require(board.getchannel('A').getextrema()==(0,255),'Parts board must have real transparency.')
    with Image.open(raw_theme) as image:
        require(image.format=='PNG' and image.size==(1024,1024) and getattr(image,'n_frames',1)==1,'Theme board must be a1024squarePNG.')
        theme=image.convert('RGBA');require(theme.getchannel('A').getextrema()==(255,255),'Theme board must be opaque.')
    # Target envelopes are authored by rig; the supplied artwork keeps its shapes/details.
    templates=authored_parts(proposal['rig_id'],proposal['theme']['palette']);parts={}
    for n,name in enumerate(RIG_PARTS[proposal['rig_id']]):
        x0,x1=(n%3)*1024//3,((n%3)+1)*1024//3;y0,y1=(n//3)*1024//3,((n//3)+1)*1024//3
        raw=board.crop((x0,y0,x1,y1));box=raw.getchannel('A').getbbox();require(box is not None,f'Generated part {name} is blank.')
        require(box[0]>2 and box[1]>2 and box[2]<raw.width-2 and box[3]<raw.height-2,f'Generated part {name} is clipped by its grid slot.')
        silhouette=raw.crop(box);target=templates[name].getchannel('A').getbbox();require(target is not None,'Missing authored rig envelope.')
        width,height=target[2]-target[0],target[3]-target[1]
        silhouette.thumbnail((width,height),Image.Resampling.NEAREST)
        require(silhouette.width>=2 and silhouette.height>=2,f'Generated part {name} is too narrow to rig.')
        part=Image.new('RGBA',(64,64));part.alpha_composite(silhouette,(target[0]+(width-silhouette.width)//2,target[1]+(height-silhouette.height)//2));parts[name]=part
    (job_dir/'parts').mkdir();rig=make_rig(proposal['rig_id'])
    for name,image in parts.items():image.save(job_dir/f'parts/{name}.png')
    write_json(job_dir/'rig.json',rig);write_json(job_dir/'proposal.json',proposal)
    theme.crop((0,0,1024,576)).resize((640,360),Image.Resampling.NEAREST).save(job_dir/'theme_background.png')
    mat=Image.new('RGBA',(256,256))
    for col in range(4):
        tile=theme.crop((col*256,576,(col+1)*256,1024)).resize((128,128),Image.Resampling.NEAREST)
        mat.alpha_composite(tile,((col%2)*128,(col//2)*128))
    mat.save(job_dir/'theme_materials.png')
    write_json(job_dir/'source_provenance.json',{'schema_version':1,**provenance,'raw_parts_sha256':sha256(raw_parts),'raw_theme_sha256':sha256(raw_theme),'conversion':'three-family authored envelopes, nearest sampling and deterministic animation'})
    return bake_job(job_dir/'job.json')
