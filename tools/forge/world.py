"""Authored connected scrolling-world templates and offline geometry validation."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from .rigs import write_json
from .validation import require

ROOT=Path(__file__).resolve().parents[2]


def world_data()->dict:
    stairs=[[112,y,48] for y in range(368,609,48)]+[[464,y,48] for y in range(368,609,48)]
    raised=[[[224,272,96],[288,224,96],[352,272,96]],[[208,272,96],[272,224,96],[336,272,96]],[[240,272,96],[288,224,96],[336,272,96]],[[192,272,128],[288,224,96],[352,272,128]]]
    names=['Orchard Steps','Glassroot Walk','Kilnside Hollow','Crown Terrace']
    templates=[]
    for n,platforms in enumerate(raised):
        templates.append({'id':names[n].lower().replace(' ','_'),'name':names[n],
          'solids':[[0,320,96,32],[176,320,272,32],[528,320,112,32],[0,624,640,96]],
          'platforms':[[96,320,80],[448,320,80],*stairs,*platforms],
          'anchors':[[48,320],[240,320],[400,320],[592,320],[304,224],[64,624],[288,624],[400,624],[576,624],[136,416],[488,512]],
          'decorations':[
            {'prop':'lantern_pole','position':[48,320],'flip':False},
            {'prop':['thread_spool','glass_fern','copper_cogs','woven_banner'][n],'position':[220,320],'flip':False},
            {'prop':['hollow_log','stone_stack','thorn_bush','old_crate'][n],'position':[568,320],'flip':bool(n%2)},
            {'prop':'cave_lantern','position':[64,624],'flip':False},
            {'prop':['blue_mushrooms','seed_pod','crystal_cluster','rope_coil'][n],'position':[344,624],'flip':False},
            {'prop':['root_arch','broken_column','ivy_pillar','iron_gate'][n],'position':[390,624],'flip':False},
            {'prop':['hanging_bell','little_shrine','water_pipe','tomb_marker'][n],'position':[320,224],'flip':False},
            {'prop':'wind_chimes','position':[600,320],'flip':False},
          ]})
    regions=[]
    for n,(name,family) in enumerate([('Copper Orchard','bell_oak'),('Moonroot Glasshouse','glass_gate'),('The Buried Works','spool_tower'),('Crown of Threads','crown_loom')]):
        regions.append({'id':n,'name':name,'landmark':family,
          'loot':[{'kind':'cache','chunk':0,'position':[80,320]},{'kind':'cache','chunk':1,'position':[304,224]},
                  {'kind':'cache','chunk':2,'position':[320,624]},{'kind':'cache','chunk':3,'position':[560,320]},
                  {'kind':'plant','chunk':1,'position':[544,320]},{'kind':'plant','chunk':3,'position':[176,624]}]})
    return {'schema_version':1,'content_version':'scrolling-world-v1','chunk_width':640,'height':720,'chunks_per_region':4,'max_regions':4,'main_y':320,'cave_y':624,'templates':templates,'regions':regions}


def validate(data:dict)->dict:
    require(isinstance(data,dict) and type(data.get('schema_version')) is int and data['schema_version']==1 and data.get('content_version')=='scrolling-world-v1','Scrolling world version differs.')
    for name,value in [('chunk_width',640),('height',720),('chunks_per_region',4),('max_regions',4),('main_y',320),('cave_y',624)]:require(type(data.get(name)) is int and data[name]==value,f'World {name} differs.')
    require(isinstance(data.get('templates'),list) and len(data['templates'])==4,'Four authored world templates required.')
    for template in data['templates']:
        require(isinstance(template.get('solids'),list) and isinstance(template.get('platforms'),list),'World surfaces missing.')
        for rect in template['solids']:
            require(isinstance(rect,list) and len(rect)==4 and all(type(x) is int for x in rect),'Solid must use integer x,y,width,height.')
            x,y,w,h=rect;require(x>=0 and y>=0 and w>0 and h>0 and x+w<=640 and y+h<=720,'Solid outside chunk.')
        for platform in template['platforms']:
            require(isinstance(platform,list) and len(platform)==3 and all(type(x) is int for x in platform),'Platform must use integer x,y,width.')
            x,y,w=platform;require(x>=0 and 0<y<720 and w>=32 and x+w<=640,'Platform outside chunk.')
        require([96,320,80] in template['platforms'] and [448,320,80] in template['platforms'],'Cave entrances must retain80pixel one-way bridges.')
        require([0,624,640,96] in template['solids'],'Continuous safe cave floor missing.')
        for x in (112,464):
            require(all([x,y,48] in template['platforms'] for y in range(368,609,48)),'Reachable48pixel cave stair missing.')
        surfaces=[(r[0],r[1],r[2]) for r in template['solids']]+[tuple(r) for r in template['platforms']]
        require(all(any(y==320 and left<=x<=left+w for left,y,w in surfaces) for x in range(0,641,8)),'Main trail is disconnected.')
        for anchor in template['anchors']:
            require(isinstance(anchor,list) and len(anchor)==2 and all(type(x) is int for x in anchor),'Anchor format differs.')
            require(any(y==anchor[1] and x+9<=anchor[0]<=x+w-9 for x,y,w in surfaces),'Spawn anchor lacks a safe surface.')
    regions=data.get('regions');require(isinstance(regions,list) and len(regions)==4,'Four regions required.')
    for n,region in enumerate(regions):
        require(region.get('id')==n and region.get('landmark') in ('bell_oak','glass_gate','spool_tower','crown_loom'),'Region identity differs.')
        loot=region.get('loot');require(isinstance(loot,list) and sum(x.get('kind')=='cache' for x in loot)==4 and sum(x.get('kind')=='plant' for x in loot)==2,'Each region needs four caches and two plants.')
        for item in loot:
            require(type(item.get('chunk')) is int and 0<=item['chunk']<4 and isinstance(item.get('position'),list) and len(item['position'])==2,'Loot placement differs.')
            x,y=item['position'];require(16<=x<=624 and y in (224,320,624),'Loot outside intended reachable routes.')
    return data


def rebuild(root:Path=ROOT)->dict:
    data=validate(world_data());write_json(root/'content/arena/world.json',data);return data


def main()->None:
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--build',action='store_true');parser.add_argument('--validate',action='store_true');args=parser.parse_args()
    data=rebuild() if args.build else validate(json.loads((ROOT/'content/arena/world.json').read_text()))
    print(f"PASS scrolling world: {len(data['templates'])}templates, {len(data['regions'])}regions, four caches/two plants each")

if __name__=='__main__':main()
