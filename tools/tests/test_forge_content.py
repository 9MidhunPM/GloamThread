"""Behavioural acceptance for the wave catalog and shared fighter bundle boundary."""
from __future__ import annotations
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from PIL import Image

from tools.forge.art import RIG_PARTS,authored_parts,make_rig,bake_atlas
from tools.forge.catalog import catalog
from tools.forge.enemies import validate as validate_enemies
from tools.forge.audio import validate as validate_audio,arrange
from tools.forge.rigs import emit_bundle,write_json,load_rig,bake_job,convert_generated
from tools.forge.validation import BundleError,validate_catalog,validate_bundle,sha256

ROOT=Path(__file__).resolve().parents[2]
PROFILE=json.loads((ROOT/'assets/arena/source/builtin_profiles.json').read_text())['profiles'][0]


class FighterContentTests(unittest.TestCase):
    def setUp(self):self.work=tempfile.TemporaryDirectory();self.folder=Path(self.work.name)
    def tearDown(self):self.work.cleanup()
    def proposal(self,rig='upright'):
        p=copy.deepcopy(PROFILE);p['rig_id']=rig;p['features']=['original copper mask','long ears'];return p
    def make_job(self,rig='upright'):
        p=self.proposal(rig);job=self.folder/'job';job.mkdir();(job/'parts').mkdir()
        write_json(job/'job.json',{'schema_version':1,'proposal':p,'budget_usd':.5})
        write_json(job/'proposal.json',p);write_json(job/'rig.json',make_rig(rig))
        for name,im in authored_parts(rig,p['theme']['palette']).items():im.save(job/f'parts/{name}.png')
        return job
    def test_complete_wave_catalog_and_boss_schedule(self):
        value=validate_catalog(catalog())
        self.assertEqual([x['number'] for x in value['waves'] if x['boss']],[5,10,15,20])
        self.assertEqual({r for w in value['waves'] for r in w['enemies']},{'swarm','chaser','charger','shooter','flyer','heavy'})
        self.assertEqual(len([u for u in value['upgrades'] if u['kit']=='any']),12)
    def test_reject_unsafe_or_incomplete_content(self):
        mutations=[lambda c:c['waves'][3].update(number=5),lambda c:c['waves'][3].update(boss='warden'),lambda c:c['upgrades'][0].update(stat='exec'),lambda c:c['upgrades'][0].update(amount=float('nan')),lambda c:c['arenas'][0]['platforms'].append([0,100,500]),lambda c:c['upgrades'][0].update(id=c['upgrades'][1]['id'])]
        for mutate in mutations:
            c=catalog();mutate(c)
            with self.subTest(mutation=mutate),self.assertRaises(BundleError):validate_catalog(c)
    def test_arcade_audio_headroom_and_editable_score(self):
        audio=validate_audio(ROOT);self.assertEqual(len(audio['sfx']),5);self.assertEqual(len(audio['music']),3)
        source=json.loads((ROOT/'assets/arena/source/audio.json').read_text())
        for recipe in source['tracks'].values():
            score=arrange(recipe)
            self.assertEqual(score['beats'],recipe['bars']*4)
            self.assertTrue(all(note[0]+note[2]<=score['beats'] for part in score['parts'] for note in part['notes']))
    def test_six_enemy_and_four_boss_atlases(self):
        self.assertEqual(len(validate_enemies(ROOT)['assets']),10)
    def test_shipped_bundles_and_hashes(self):
        index=json.loads((ROOT/'assets/arena/builtin/index.json').read_text())
        self.assertEqual(len(index['bundles']),2)
        for identifier in index['bundles']:
            m=validate_bundle(ROOT/f'assets/arena/builtin/{identifier}');self.assertEqual(m['id'],identifier)
    def test_two_distinct_examples_of_each_rig_bake(self):
        for rig in RIG_PARTS:
            for variant in range(2):
                p=self.proposal(rig);p['theme']['palette']=p['theme']['palette'][::-1] if variant else p['theme']['palette']
                out=self.folder/f'{rig}-{variant}';emit_bundle(authored_parts(rig,p['theme']['palette']),make_rig(rig),p,out,{'provider_calls':0})
                self.assertEqual(validate_bundle(out)['rig_id'],rig)
    def test_bake_is_deterministic(self):
        p=self.proposal();parts=authored_parts('upright',p['theme']['palette']);rig=make_rig('upright')
        first,_=bake_atlas(parts,rig);second,_=bake_atlas(parts,rig);self.assertEqual(first.tobytes(),second.tobytes())
    def test_mask_and_pivot_edits_change_new_candidate_only(self):
        job=self.make_job();first=bake_job(job/'job.json');original=sha256(first/'character.png')
        (job/'masks').mkdir();mask=Image.new('L',(64,64),255)
        for y in range(0,20):
            for x in range(64):mask.putpixel((x,y),0)
        mask.save(job/'masks/head.png')
        write_json(job/'rig_edits.json',{'schema_version':1,'parts':{'head':{'pivot':[31,23],'mask_file':'masks/head.png'}}})
        second=bake_job(job/'job.json');self.assertNotEqual(first,second);self.assertEqual(sha256(first/'character.png'),original);self.assertNotEqual(sha256(second/'character.png'),original)
    def test_unknown_edit_and_path_traversal_are_rejected(self):
        job=self.make_job()
        for edit in ({'unknown':{'pivot':[1,1]}},{'head':{'mask_file':'../../secret.png'}},{'head':{'pivot':[1,100]}}):
            write_json(job/'rig_edits.json',{'schema_version':1,'parts':edit})
            with self.assertRaises(BundleError):load_rig(job,'upright')
    def test_bundle_hash_and_gutters_are_enforced(self):
        job=self.make_job();bundle=bake_job(job/'job.json');manifest=json.loads((bundle/'manifest.json').read_text())
        with Image.open(bundle/'character.png') as image:
            image.putpixel((0,0),(255,0,0,255));image.save(bundle/'character.png')
        with self.assertRaisesRegex(BundleError,'hash'):validate_bundle(bundle)
        manifest['files']['character.png']=sha256(bundle/'character.png');write_json(bundle/'manifest.json',manifest)
        with self.assertRaisesRegex(BundleError,'gutter'):validate_bundle(bundle)
    def make_raw_boards(self,job,rig):
        p=self.proposal(rig);board=Image.new('RGBA',(1024,1024))
        for n,(name,part) in enumerate(authored_parts(rig,p['theme']['palette']).items()):
            crop=part.crop(part.getbbox());crop=crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST)
            x0,x1=(n%3)*1024//3,((n%3)+1)*1024//3;y0,y1=(n//3)*1024//3,((n//3)+1)*1024//3
            board.alpha_composite(crop,(x0+(x1-x0-crop.width)//2,y0+(y1-y0-crop.height)//2))
        assembled=Image.new('RGBA',(64,64))
        for part in authored_parts(rig,p['theme']['palette']).values():assembled.alpha_composite(part)
        master=assembled.crop(assembled.getbbox());master=master.resize((master.width*4,master.height*4),Image.Resampling.NEAREST)
        board.alpha_composite(master,(2*1024//3+(342-master.width)//2,2*1024//3+(342-master.height)//2))
        board.save(job/'raw_parts.png');Image.new('RGBA',(1024,1024),(40,60,80,255)).save(job/'raw_theme.png')
    def test_generated_parts_cross_same_boundary_for_all_three_rigs(self):
        for rig in RIG_PARTS:
            job=self.folder/rig;job.mkdir();p=self.proposal(rig);write_json(job/'job.json',{'schema_version':1,'proposal':p});self.make_raw_boards(job,rig)
            result=convert_generated(job/'raw_parts.png',job/'raw_theme.png',p,job,{'provider':'mock','provider_calls':0})
            self.assertEqual(validate_bundle(result)['rig_id'],rig);self.assertTrue((job/'rig.json').is_file());self.assertTrue((job/'master.png').is_file())
    def test_empty_generated_part_rejects_without_installing(self):
        job=self.folder/'raw';job.mkdir();p=self.proposal();write_json(job/'job.json',{'schema_version':1,'proposal':p});self.make_raw_boards(job,'upright')
        with Image.open(job/'raw_parts.png') as im:
            im.paste((0,0,0,0),(0,0,341,341));im.save(job/'raw_parts.png')
        with self.assertRaisesRegex(BundleError,'blank'):convert_generated(job/'raw_parts.png',job/'raw_theme.png',p,job,{})
        self.assertFalse((job/'candidate').exists())
    def test_four_and_five_colour_proposals_convert_without_mutation(self):
        for count in (4,5):
            job=self.folder/f'palette-{count}';job.mkdir();p=self.proposal();p['theme']['palette']=p['theme']['palette'][:count]
            write_json(job/'job.json',{'schema_version':1,'proposal':p});self.make_raw_boards(job,'upright')
            result=convert_generated(job/'raw_parts.png',job/'raw_theme.png',p,job,{})
            manifest=validate_bundle(result);self.assertEqual(len(manifest['theme']['palette']),count);self.assertEqual(len(p['theme']['palette']),count)
    def test_missing_generated_master_is_rejected(self):
        job=self.folder/'master';job.mkdir();p=self.proposal();write_json(job/'job.json',{'schema_version':1,'proposal':p});self.make_raw_boards(job,'upright')
        with Image.open(job/'raw_parts.png') as im:
            im.paste((0,0,0,0),(682,682,1024,1024));im.save(job/'raw_parts.png')
        with self.assertRaisesRegex(BundleError,'master design'):convert_generated(job/'raw_parts.png',job/'raw_theme.png',p,job,{})
        self.assertFalse((job/'candidate').exists())
    def test_symlinked_part_is_rejected(self):
        job=self.make_job();(job/'parts/head.png').unlink();(job/'parts/head.png').symlink_to(ROOT/'assets/arena/builtin/cinderjack/portrait.png')
        with self.assertRaises(BundleError):load_rig(job,'upright')

if __name__=='__main__':unittest.main()
