"""Authored wave/upgrade content; mechanics stay in Godot."""
from __future__ import annotations

KIT_ROWS = [
    ('ember','Ember','Close the gap, breathe fire and spread burns.','#ff9858','Coalcleaver','Furnace Breath','Kindling'),
    ('frost','Frost','Keep a cold distance; frozen crowds shatter together.','#8be6ee','Ice Needle','Winter Ring','Brittle'),
    ('storm','Storm','Rapid strikes store charge for leaping lightning.','#e8dc77','Spark Knuckle','Stormchain','Static'),
    ('stone','Stone','Heavy impacts turn a packed arena into breathing room.','#c6ad91','Basalt Fist','Faultline','Bedrock'),
    ('nature','Nature','Thorns pierce a crowd while roots hold the front line.','#9ee29a','Briar Needle','Rootwake','Renewal'),
    ('shadow','Shadow','Mark opponents, pass through the line and detonate.','#c9a5ed','Nightedge','Umbral Lance','Aftermark'),
]


def catalog() -> dict:
    kits = {r[0]: dict(zip(('name','description','color','basic_name','special_name','passive_name'), r[1:])) for r in KIT_ROWS}
    general = [
        ('keen_edge','Keen Edge','Every attack hits harder.','damage',3,7),
        ('quick_hands','Quick Hands','Shorter recovery between basic attacks.','attack_speed',.12,7),
        ('second_wind','Second Wind','Use your special more often.','special_cooldown',-36,8),
        ('heartwood','Heartwood','Raise maximum health and recover the increase.','max_health',20,7),
        ('light_feet','Light Feet','Move faster without changing jump reach.','move_speed',10,6),
        ('lucky_thread','Lucky Thread','A greater chance to land critical hits.','crit',.06,8),
        ('slipstream','Slipstream','Dodge comes back sooner.','dodge_cooldown',-6,6),
        ('blood_bloom','Blood Bloom','A little attack damage returns as health.','lifesteal',.025,10),
        ('barbed_guard','Barbed Guard','Return a portion of damage to attackers.','thorns',.12,7),
        ('twin_stitch','Twin Stitch','An extra bolt in projectile attacks.','projectile_count',1,12),
        ('wide_arc','Wide Arc','Cover more ground with attacks and specials.','area',.15,8),
        ('coin_song','Coin Song','Stretch cosmetic coin trails toward you.','magnet',.5,6),
    ]
    family = {
      'ember':[('wildfire','Wildfire','Burns grow fiercer.','burn',1,8),('bellows','Bellows','Breathe over a wider arc.','area',.25,9),('hot_coals','Hot Coals','A faster second breath.','special_cooldown',-48,10)],
      'frost':[('deep_freeze','Deep Freeze','Longer frost control on ordinary enemies.','freeze',1,8),('ice_fan','Ice Fan','Split your needles into more bolts.','projectile_count',1,10),('cold_snap','Cold Snap','Shattering blows hit harder.','damage',5,9)],
      'storm':[('forked_sky','Forked Sky','Lightning leaps to another target.','chain',1,9),('overcharge','Overcharge','More critical sparks.','crit',.08,9),('live_wire','Live Wire','Faster strikes build charge quickly.','attack_speed',.18,10)],
      'stone':[('earthshaker','Earthshaker','More impact and stagger.','stagger',1,8),('tectonic','Tectonic','The slam reaches farther.','area',.25,9),('mountain_heart','Mountain Heart','More health behind the armour.','max_health',30,10)],
      'nature':[('deep_roots','Deep Roots','Roots hold the swarm longer.','freeze',1,8),('thornline','Thornline','Thorns pierce another opponent.','pierce',1,9),('green_pulse','Green Pulse','Recover a little health each second.','regen',.6,10)],
      'shadow':[('long_night','Long Night','A lance passes through more enemies.','pierce',1,8),('hungry_mark','Hungry Mark','Marked hits return more health.','lifesteal',.035,10),('double_omen','Double Omen','Another shadow projectile.','projectile_count',1,10)],
    }
    upgrades=[]
    for kit, rows in [('any',general), *family.items()]:
        for uid,name,desc,stat,amount,price in rows:
            upgrades.append({'id':uid,'name':name,'description':desc,'kit':kit,'stat':stat,'amount':amount,'price':price,'max_rank':3})
    waves=[]
    pools=[['swarm','chaser'],['swarm','chaser','charger','shooter'],['chaser','charger','shooter','flyer'],['swarm','charger','shooter','flyer','heavy']]
    bosses=['warden','artillery','tempest','loom']
    for n in range(1,21):
        stage=(n-1)//5
        waves.append({'number':n,'count':8+((n-1)*2) if n%5 else 4+stage*3,
          'interval_ticks':max(16,45-(n-1)*2),'enemies':pools[stage],
          'boss':bosses[stage] if n%5==0 else '', 'elite_every':0 if n<7 else max(5,12-stage*2)})
    arenas=[
      {'id':'lantern_pit','name':'Lantern Pit','platforms':[[144,288,80],[416,288,80]]},
      {'id':'bell_foundry','name':'Bell Foundry','platforms':[[80,288,96],[464,288,96],[272,256,96]]},
      {'id':'root_terrace','name':'Root Terrace','platforms':[[176,288,96],[368,288,96],[272,256,96]]},
      {'id':'crown_of_threads','name':'Crown of Threads','platforms':[[64,288,112],[464,288,112],[208,256,96],[336,256,96]]},
    ]
    return {'schema_version':1,'content_version':'arena-v1','kits':kits,'upgrades':upgrades,'waves':waves,'arenas':arenas}
