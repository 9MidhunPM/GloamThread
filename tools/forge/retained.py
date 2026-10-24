"""Publish reviewed retained image outputs offline through the same bundle gate.

Every source filename is fixed/allowlisted and hashed. Rebuilds make no network
requests; generated originals, manual annotations and editable parts survive.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import shutil
import tempfile
from PIL import Image
from .art import RIG_PARTS
from .rigs import convert_generated,bake_job,write_json,_source_layout
from .validation import require,sha256,validate_proposal,validate_bundle

ROOT=Path(__file__).resolve().parents[2]
BASE_FILES={'original_source.png','request_source.png','raw_parts.png','raw_theme.png','proposal.json','source_layout.json','generation.json',
            'rig.json','source_provenance.json','master.png','theme_background.png','theme_materials.png'}
SLUG=re.compile(r'[a-z0-9][a-z0-9_-]{0,63}')
HASH=re.compile(r'[0-9a-f]{64}')


def _json(path:Path,max_bytes:int=512*1024)->dict:
    require(path.is_file() and not path.is_symlink() and path.stat().st_size<=max_bytes,'Retained metadata is missing, unsafe or oversized.')
    value=json.loads(path.read_text());require(isinstance(value,dict),'Retained metadata must be a JSON object.');return value


def source_registry(root:Path=ROOT)->list[dict]:
    path=root/'assets/arena/source/retained_generations.json';registry=_json(path)
    require(type(registry.get('schema_version')) is int and registry['schema_version']==1,'Retained source registry version differs.')
    records=registry.get('bundles');require(isinstance(records,list) and 1<=len(records)<=32,'Retained registry needs a bounded bundle list.')
    ids=set();directories=set()
    for record in records:
        require(isinstance(record,dict) and set(record)=={'id','directory','manifest_sha256'},'Retained registry fields differ.')
        require(isinstance(record['id'],str) and SLUG.fullmatch(record['id']) is not None and record['id'] not in ids,'Retained bundle IDs must be safe and unique.')
        require(isinstance(record['directory'],str) and SLUG.fullmatch(record['directory']) is not None and record['directory'] not in directories,'Retained directories must be safe and unique.')
        require(isinstance(record['manifest_sha256'],str) and HASH.fullmatch(record['manifest_sha256']) is not None,'Retained manifest hash is invalid.')
        ids.add(record['id']);directories.add(record['directory'])
    return records


def validate_source(root:Path,record:dict)->dict:
    source=root/'assets/arena/source'/record['directory']
    require(source.is_dir() and not source.is_symlink(),'Retained source directory is unsafe.')
    manifest=_json(source/'manifest.json');require(sha256(source/'manifest.json')==record['manifest_sha256'],'Retained source manifest hash differs.')
    require(type(manifest.get('schema_version')) is int and manifest['schema_version']==1 and manifest.get('kind')=='retained-fighter-generation' and manifest.get('id')==record['id'],'Retained source manifest identity differs.')
    proposal=_json(source/'proposal.json');validate_proposal(proposal)
    part_files={f'parts/{name}.png' for name in RIG_PARTS[proposal['rig_id']]}
    allowed=BASE_FILES|part_files|{'rig_edits.json'}|{f'masks/{name}.png' for name in RIG_PARTS[proposal['rig_id']]}
    files=manifest.get('files');require(isinstance(files,dict) and BASE_FILES|part_files<=set(files)<=allowed,'Retained source filenames differ from the allowlist.')
    for name,digest in files.items():
        file=source/name
        require(isinstance(digest,str) and HASH.fullmatch(digest) is not None,'Retained source hash is malformed.')
        require(file.is_file() and not file.is_symlink() and not file.parent.is_symlink(),'Retained source file is missing or unsafe.')
        require(file.stat().st_size<=(25*1024*1024 if name in ('raw_parts.png','raw_theme.png') else 8*1024*1024),'Retained source file exceeds the byte limit.')
        require(sha256(file)==digest,f'Retained source hash differs: {name}.')
    hashes={'raw_parts_sha256':files['raw_parts.png'],'raw_theme_sha256':files['raw_theme.png']}
    _source_layout(source,proposal['rig_id'],hashes)
    generation=_json(source/'generation.json')
    source_record=generation.get('source')
    require(isinstance(source_record,dict) and source_record.get('original_sha256')==files['original_source.png'] and source_record.get('request_source_sha256')==files['request_source.png'],'Retained original/request source receipts differ.')
    require(generation.get('approved_proposal')==proposal,'Retained approved proposal differs.')
    with Image.open(source/'request_source.png') as image:
        require(image.format=='PNG' and list(image.size)==source_record.get('size') and getattr(image,'n_frames',1)==1,'Retained request source dimensions differ.')
    require(generation.get('schema_version')==1 and generation.get('provider')=='OpenAI','Retained generation metadata differs.')
    require(isinstance(generation.get('requests'),dict) and set(generation['requests'])=={'parts','theme'},'Retained generation needs both image receipts.')
    for key in ('parts','theme'):
        request=generation['requests'][key]
        require(isinstance(request,dict) and request.get('sha256')==files[f'raw_{key}.png'],'Retained image receipt/hash differs.')
        require(isinstance(request.get('model'),str) and isinstance(request.get('received_at'),str) and isinstance(request.get('prompt'),str),'Retained request receipt is incomplete.')
    return {'source':source,'manifest':manifest,'proposal':proposal,'generation':generation}


def validate_sources(root:Path=ROOT)->list[dict]:
    return [validate_source(root,record) for record in source_registry(root)]


def _publish_bundle(candidate:Path,target:Path)->None:
    target.parent.mkdir(parents=True,exist_ok=True)
    require(not target.is_symlink(),'Builtin destination cannot be a symlink.')
    with tempfile.TemporaryDirectory(prefix='.retained-publish-',dir=target.parent) as temporary:
        stage=Path(temporary)/'bundle';backup=Path(temporary)/'previous'
        shutil.copytree(candidate,stage);validate_bundle(stage)
        if target.exists():target.rename(backup)
        try:stage.rename(target)
        except Exception:
            if backup.exists() and not target.exists():backup.rename(target)
            raise


def publish_all(root:Path=ROOT)->list[str]:
    # Verify the entire retained set before replacing any published bundle.
    checked=validate_sources(root);identifiers=[]
    for item in checked:
        source=item['source'];manifest=item['manifest'];proposal=item['proposal'];identifier=manifest['id']
        with tempfile.TemporaryDirectory(prefix='gloamthread-retained-') as temporary:
            job=Path(temporary);write_json(job/'job.json',{'schema_version':1,'proposal':proposal})
            shutil.copy2(source/'source_layout.json',job/'source_layout.json')
            parent={'schema_version':1,'provider':'OpenAI','generation':item['generation'],
                    'retained_source_manifest_sha256':sha256(source/'manifest.json'),
                    'retained_source_directory':f'assets/arena/source/{source.name}',
                    'editable_snapshot_provenance_sha256':sha256(source/'source_provenance.json'),
                    'retained_publisher_sha256':sha256(Path(__file__)),
                    'provider_calls_during_rebuild':0}
            initial=convert_generated(source/'raw_parts.png',source/'raw_theme.png',proposal,job,parent)
            # Retained editable output is authoritative after the reviewed raw conversion.
            # This preserves later reviewed mask/pivot/part edits without losing raw lineage.
            for name in ('rig.json','master.png','theme_background.png','theme_materials.png'):
                shutil.copy2(source/name,job/name)
            for name in manifest['files']:
                if name.startswith(('parts/','masks/')):
                    (job/name).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/name,job/name)
            if 'rig_edits.json' in manifest['files']:shutil.copy2(source/'rig_edits.json',job/'rig_edits.json')
            shutil.rmtree(initial)
            candidate=bake_job(job/'job.json');bundle=_json(candidate/'manifest.json');provenance=_json(candidate/'provenance.json')
            provenance.update({'published_id':identifier,'derived_generated_id':bundle['id'],
                               'publication_method':'offline retained image conversion plus reviewed editable snapshot',
                               'reviewed_transform':'explicit hash-bound crops and alpha cutoff; original source RGB retained'})
            write_json(candidate/'provenance.json',provenance)
            bundle['id']=identifier;bundle['files']['provenance.json']=sha256(candidate/'provenance.json');write_json(candidate/'manifest.json',bundle)
            validate_bundle(candidate);_publish_bundle(candidate,root/f'assets/arena/builtin/{identifier}');identifiers.append(identifier)
    return identifiers


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--validate',action='store_true');args=parser.parse_args()
    result=validate_sources();print('PASS retained generated sources '+json.dumps([item['manifest']['id'] for item in result]))

if __name__=='__main__':main()
