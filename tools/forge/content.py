"""Rebuild/validate original arena content without network access.

Run: python3 -m tools.forge.content --build --validate
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
from .art import authored_parts,make_rig
from .catalog import catalog
from .rigs import emit_bundle,write_json
from .validation import validate_catalog,validate_bundle,sha256
from .enemies import rebuild as rebuild_enemies,validate as validate_enemies
from .audio import rebuild as rebuild_audio,validate as validate_audio
from .fixtures import rebuild as rebuild_fixtures

ROOT=Path(__file__).resolve().parents[2]


def rebuild(root:Path=ROOT)->dict:
    source=root/'assets/arena/source/builtin_profiles.json'
    profiles=json.loads(source.read_text())['profiles']
    write_json(root/'content/arena/catalog.json',catalog())
    index=[]
    for profile in profiles:
        identifier=profile['id'];folder=root/f'assets/arena/builtin/{identifier}'
        # Only the deterministic built-in output tree is replaced by this explicit rebuild command.
        if folder.exists():shutil.rmtree(folder)
        rig=make_rig(profile['rig_id']);parts=authored_parts(profile['rig_id'],profile['theme']['palette'])
        src=root/f'assets/arena/source/{identifier}'
        src.mkdir(parents=True,exist_ok=True);write_json(src/'rig.json',rig)
        for name,image in parts.items():(src/'parts').mkdir(exist_ok=True);image.save(src/f'parts/{name}.png')
        emit_bundle(parts,rig,profile,folder,{'method':'original authored pixel art and deterministic cutout animation','tool':'Python/Pillow','provider_calls':0,
          'sources':{'assets/arena/source/builtin_profiles.json':sha256(source),'tools/forge/art.py':sha256(ROOT/'tools/forge/art.py'),'tools/forge/rigs.py':sha256(ROOT/'tools/forge/rigs.py')},
          'notice':'Source-authored offline built-in. Not a live generated or human-reviewed character.'},identifier=identifier)
        index.append(identifier)
    write_json(root/'assets/arena/builtin/index.json',{'schema_version':1,'bundles':index})
    # An explicit editable floating-rig fixture proves the third family exists without claiming AI quality.
    rig=make_rig('floating');src=root/'assets/arena/source/lantern_manta';src.mkdir(parents=True,exist_ok=True);write_json(src/'rig.json',rig)
    for name,image in authored_parts('floating',profiles[0]['theme']['palette']).items():(src/'parts').mkdir(exist_ok=True);image.save(src/f'parts/{name}.png')
    rebuild_enemies(root)
    rebuild_audio(root)
    rebuild_fixtures(root)
    return validate(root)


def validate(root:Path=ROOT)->dict:
    data=validate_catalog(json.loads((root/'content/arena/catalog.json').read_text()))
    index=json.loads((root/'assets/arena/builtin/index.json').read_text());assert index['schema_version']==1
    for identifier in index['bundles']:validate_bundle(root/f'assets/arena/builtin/{identifier}')
    enemies=validate_enemies(root)
    audio=validate_audio(root)
    return {'music_tracks':len(audio['music']),'arena_cues':len(audio['sfx']),'enemy_atlases':len(enemies['assets']),'kits':len(data['kits']),'upgrades':len(data['upgrades']),'waves':len(data['waves']),'arenas':len(data['arenas']),'bundles':len(index['bundles'])}


def main()->None:
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',action='store_true');p.add_argument('--validate',action='store_true');args=p.parse_args()
    result=rebuild() if args.build else validate()
    print('PASS arena content '+json.dumps(result,sort_keys=True))

if __name__=='__main__':main()
