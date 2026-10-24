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


def _json_digest(value:dict)->str:
    encoded=json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode('utf-8')
    return hashlib.sha256(encoded).hexdigest()


def _source_layout(job_dir:Path,rig_id:str,raw_hashes:dict)->dict|None:
    """Explicit reviewed coordinates only; never infer or relax an invalid grid."""
    file=job_dir/'source_layout.json'
    if not file.exists():return None
    require(file.is_file() and not file.is_symlink() and file.stat().st_size<=128*1024,'Source layout is unsafe or oversized.')
    layout=json.loads(file.read_text())
    required={'schema_version','raw_parts_sha256','raw_theme_sha256','alpha_cutoff','parts','master_crop','background_crop'}
    require(isinstance(layout,dict) and required<=set(layout)<=required|{'material_crops'},'Source layout fields are invalid.')
    require(type(layout['schema_version']) is int and layout['schema_version']==1,'Source layout version is invalid.')
    for field in ('raw_parts_sha256','raw_theme_sha256'):
        require(isinstance(layout[field],str) and re.fullmatch(r'[0-9a-f]{64}',layout[field]) is not None and layout[field]==raw_hashes.get(field),'Source layout belongs to different raw images.')
    require(type(layout['alpha_cutoff']) is int and 1<=layout['alpha_cutoff']<=255,'Source alpha cutoff must be an integer from1to255.')
    def crop(value):
        require(isinstance(value,list) and len(value)==4 and all(type(n) is int for n in value),'Source crop must be integer x,y,width,height.')
        x,y,w,h=value
        require(x>=0 and y>=0 and w>=4 and h>=4 and x+w<=1024 and y+h<=1024,'Source crop is outside its1024square image.')
    require(isinstance(layout['parts'],dict) and set(layout['parts'])==set(RIG_PARTS[rig_id]),'Source layout part IDs must match the rig.')
    for part in layout['parts'].values():
        require(isinstance(part,dict) and set(part)=={'crop'},'Source part annotation only accepts a crop.')
        crop(part['crop'])
    crop(layout['master_crop']);crop(layout['background_crop'])
    if 'material_crops' in layout:
        require(isinstance(layout['material_crops'],list) and len(layout['material_crops'])==4,'Source material annotations need four crops.')
        for value in layout['material_crops']:crop(value)
    return layout


def _crop_source(image:Image.Image,crop:list[int],alpha_cutoff:int|None=None)->Image.Image:
    x,y,w,h=crop;result=image.crop((x,y,x+w,y+h))
    if alpha_cutoff is not None:result.putalpha(result.getchannel('A').point(lambda value:255 if value>=alpha_cutoff else 0))
    return result


def _bake_provenance(job_dir:Path,proposal:dict,parts:dict,rig:dict,masks:dict,
                     parent:dict,parent_digest:str|None,theme_images:tuple,theme_mode:str)->dict:
    """Bind the actual decoded inputs as well as retained source-file identities."""
    edits_path=job_dir/'rig_edits.json'
    edits_digest=sha256(edits_path) if edits_path.exists() else None
    layout=_source_layout(job_dir,proposal['rig_id'],parent)
    layout_digest=sha256(job_dir/'source_layout.json') if layout is not None else None
    require(layout_digest==parent.get('source_layout_sha256'),'Source-layout annotations changed; reconvert the retained raw images before rebaking.')
    inputs={
        'schema_version':1,
        'proposal_sha256':_json_digest(proposal),
        'rig_file_sha256':sha256(job_dir/'rig.json'),
        'applied_rig_sha256':_json_digest(rig),
        'applied_pivots':{record['id']:{'pivot':record['pivot'],'anchor':record['anchor']} for record in rig['parts']},
        'rig_edits_sha256':edits_digest,
        'source_layout_sha256':layout_digest,
        'source_layout':layout,
        'parts':{name:{'file_sha256':sha256(job_dir/f'parts/{name}.png'),
                       'pixels_sha256':hashlib.sha256(image.tobytes()).hexdigest()} for name,image in sorted(parts.items())},
        'masks':{name:{'file_sha256':sha256(job_dir/f'masks/{name}.png'),
                       'applied_alpha_sha256':hashlib.sha256(mask.tobytes()).hexdigest()} for name,mask in sorted(masks.items())},
        'theme':{'mode':theme_mode,'background_pixels_sha256':hashlib.sha256(theme_images[0].tobytes()).hexdigest(),
                 'materials_pixels_sha256':hashlib.sha256(theme_images[1].tobytes()).hexdigest()},
        'parent_generation_provenance_sha256':parent_digest,
        'converter_source_sha256':sha256(Path(__file__)),
        'animation_source_sha256':sha256(Path(__file__).with_name('art.py')),
    }
    if theme_mode!='authored':
        inputs['theme'].update({'background_file_sha256':sha256(job_dir/'theme_background.png'),
                                'materials_file_sha256':sha256(job_dir/'theme_materials.png')})
    provenance=dict(parent)
    provenance.update({'rig_sha256':inputs['rig_file_sha256'],
                       'parent_generation_provenance_sha256':parent_digest,
                       'bake_inputs':inputs,'bake_sha256':_json_digest(inputs)})
    if edits_digest is not None:provenance['rig_edits_sha256']=edits_digest
    return provenance


def bake_job(job_json:Path)->Path:
    job_dir=job_json.parent;job=json.loads(job_json.read_text())
    proposal=job.get('proposal')
    if proposal is None:proposal=json.loads((job_dir/'proposal.json').read_text())
    validate_proposal(proposal);parts,rig,masks=load_rig(job_dir,proposal['rig_id'])
    source_provenance=job_dir/'source_provenance.json'
    parent_digest=None
    provenance={'method':'local authored rig bake','notice':'No provider request made by bake.'}
    if source_provenance.exists():
        require(source_provenance.is_file() and not source_provenance.is_symlink() and source_provenance.stat().st_size<=512*1024,'Generation provenance is unsafe or oversized.')
        provenance=json.loads(source_provenance.read_text())
        require(isinstance(provenance,dict),'Generation provenance must be an object.')
        parent_digest=sha256(source_provenance)
    generated=rig.get('source_kind')=='generated-parts' or 'raw_theme_sha256' in provenance or 'raw_parts_sha256' in provenance
    if generated:require(parent_digest is not None,'Generated rebake requires retained generation provenance.')
    theme_files=(job_dir/'theme_background.png',job_dir/'theme_materials.png')
    retained_theme=any(path.exists() for path in theme_files)
    if generated or retained_theme:
        require(all(path.is_file() for path in theme_files),'Rebake requires both retained theme images; the previous candidate is unchanged.')
        images=[]
        for file,size in zip(theme_files,[(640,360),(256,256)]):
            require(not file.is_symlink() and file.stat().st_size<=8*1024*1024,'Theme image is unsafe or oversized.')
            with Image.open(file) as image:
                require(image.format=='PNG' and image.size==size and getattr(image,'n_frames',1)==1,'Theme dimensions are invalid.')
                image.load();images.append(image.convert('RGBA'))
        theme_images=tuple(images);theme_mode='generated' if generated else 'retained'
    else:
        theme_images=(background(proposal['theme']),materials(proposal['theme']));theme_mode='authored'
    provenance=_bake_provenance(job_dir,proposal,parts,rig,masks,provenance,parent_digest,theme_images,theme_mode)
    # Each rebake gets a new sibling so preview acceptance never replaces a prior candidate.
    destination=job_dir/'candidate'
    if destination.exists():
        n=1
        while (job_dir/f'candidate-bake-{n}').exists():n+=1
        destination=job_dir/f'candidate-bake-{n}'
    return emit_bundle(parts,rig,proposal,destination,provenance,theme_images,masks,
                       identifier=bundle_id(proposal,provenance['bake_sha256']))


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
    layout=_source_layout(job_dir,proposal['rig_id'],{'raw_parts_sha256':sha256(raw_parts),'raw_theme_sha256':sha256(raw_theme)})
    # Target envelopes are authored by rig; the supplied artwork keeps its shapes/details.
    templates=authored_parts(proposal['rig_id'],proposal['theme']['palette']);parts={}
    for n,name in enumerate(RIG_PARTS[proposal['rig_id']]):
        if layout is None:
            x0,x1=(n%3)*1024//3,((n%3)+1)*1024//3;y0,y1=(n//3)*1024//3,((n//3)+1)*1024//3
            raw=board.crop((x0,y0,x1,y1))
        else:raw=_crop_source(board,layout['parts'][name]['crop'],layout['alpha_cutoff'])
        box=raw.getchannel('A').getbbox();require(box is not None,f'Generated part {name} is blank.')
        if layout is None:require(box[0]>2 and box[1]>2 and box[2]<raw.width-2 and box[3]<raw.height-2,f'Generated part {name} is clipped by its grid slot. Retain the image and provide reviewed source-layout annotations.')
        silhouette=raw.crop(box);target=templates[name].getchannel('A').getbbox();require(target is not None,'Missing authored rig envelope.')
        width,height=target[2]-target[0],target[3]-target[1]
        silhouette.thumbnail((width,height),Image.Resampling.NEAREST)
        require(silhouette.width>=2 and silhouette.height>=2,f'Generated part {name} is too narrow to rig.')
        part=Image.new('RGBA',(64,64));part.alpha_composite(silhouette,(target[0]+(width-silhouette.width)//2,target[1]+(height-silhouette.height)//2));parts[name]=part
    # The ninth slot is the approved full design, separate from the rig pieces.
    raw_master=board.crop((2*1024//3,2*1024//3,1024,1024)) if layout is None else _crop_source(board,layout['master_crop'],layout['alpha_cutoff'])
    master_box=raw_master.getchannel('A').getbbox()
    require(master_box is not None,'Generated master design in slot8 is blank.')
    if layout is None:require(master_box[0]>2 and master_box[1]>2 and master_box[2]<raw_master.width-2 and master_box[3]<raw_master.height-2,'Generated master design is clipped by its grid slot.')
    master=raw_master.crop(master_box);master.thumbnail((116,116),Image.Resampling.NEAREST)
    master_preview=Image.new('RGBA',(128,128));master_preview.alpha_composite(master,((128-master.width)//2,(128-master.height)//2));master_preview.save(job_dir/'master.png')
    (job_dir/'parts').mkdir();rig=make_rig(proposal['rig_id']);rig['source_kind']='generated-parts'
    for name,image in parts.items():image.save(job_dir/f'parts/{name}.png')
    write_json(job_dir/'rig.json',rig);write_json(job_dir/'proposal.json',proposal)
    background_source=theme.crop((0,0,1024,576)) if layout is None else _crop_source(theme,layout['background_crop'])
    background_source.resize((640,360),Image.Resampling.NEAREST).save(job_dir/'theme_background.png')
    mat=Image.new('RGBA',(256,256))
    for col in range(4):
        tile_source=theme.crop((col*256,576,(col+1)*256,1024)) if layout is None or 'material_crops' not in layout else _crop_source(theme,layout['material_crops'][col])
        tile=tile_source.resize((128,128),Image.Resampling.NEAREST)
        mat.alpha_composite(tile,((col%2)*128,(col//2)*128))
    mat.save(job_dir/'theme_materials.png')
    write_json(job_dir/'source_provenance.json',{'schema_version':1,**provenance,'raw_parts_sha256':sha256(raw_parts),'raw_theme_sha256':sha256(raw_theme),
      'source_layout_sha256':sha256(job_dir/'source_layout.json') if layout is not None else None,'source_layout':layout,
      'conversion':'explicit reviewed source-layout crops' if layout is not None else 'strict three-by-three parts grid','animation':'three-family authored envelopes, nearest sampling and deterministic animation'})
    return bake_job(job_dir/'job.json')
