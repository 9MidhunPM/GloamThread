"""Original arcade score arrangement using retained original instrument synthesis."""
from __future__ import annotations
import json
from pathlib import Path
import wave
import numpy as np
from tools.gen.audio import render_cue,render_track,_write_wave,SAMPLE_RATE
from .rigs import write_json
from .validation import sha256,require


def arrange(source:dict)->dict:
    bars=source['bars'];beats=bars*4;shop=source['bpm']<110
    bass=[];pulse=[];knocks=[];lead=[];arpeggio=[]
    for bar in range(bars):
        start=bar*4;root=source['bass'][bar%len(source['bass'])]
        for beat,length,gain in ((0,.8,.65),(1.5,.35,.42),(2,.8,.6),(3.5,.35,.4)):
            bass.append([start+beat,root,length,gain,0])
        for beat in (0,2):pulse.append([start+beat,38,.26,source['drum_gain'],0])
        for beat in (1,3):knocks.append([start+beat,62,.22,source['drum_gain']*.6,-.15 if beat==1 else .15])
        for n in range(8):
            offset=(0,7,12,7,3,7,12,10)[n];arpeggio.append([start+n*.5,root+24+offset,.3,.14 if shop else .19,(-.35 if n%2 else .35)])
        # Two related phrases leave room for battle transients and answer every fourth bar.
        if bar%4 in (0,1,3):
            phrase=(bar//4)%2
            for n,beat in enumerate((.5,1.25,2.5,3.25)):
                note=source['motif'][(bar*3+n+phrase)%len(source['motif'])]
                lead.append([start+beat,note,.55,source['lead_gain'],(-.22 if bar%2 else .22)])
    return {'bpm':source['bpm'],'beats':beats,'peak':source['peak'],'parts':[
      {'instrument':'low_pulse','notes':bass},{'instrument':'low_pulse','notes':pulse},
      {'instrument':'wood_knock','notes':knocks},{'instrument':'thread_pluck','notes':arpeggio},
      {'instrument':'soft_chime' if shop else 'soft_bell','notes':lead}]}


def rebuild(root:Path)->dict:
    source_path=root/'assets/arena/source/audio.json';source=json.loads(source_path.read_text())
    instruments_path=root/'assets/source/audio/instruments.json';instruments=json.loads(instruments_path.read_text())['instruments']
    folder=root/'assets/arena/audio';folder.mkdir(parents=True,exist_ok=True)
    index={'schema_version':1,'sfx':{},'music':{},'sources':{'assets/arena/source/audio.json':sha256(source_path),'assets/source/audio/instruments.json':sha256(instruments_path),'tools/forge/audio.py':sha256(Path(__file__)),'tools/gen/audio.py':sha256(root/'tools/gen/audio.py')},'provider_calls':0}
    for kind,sources in [('sfx',source['cues']),('music',source['tracks'])]:
        for name,recipe in sources.items():
            pcm=render_cue(name,recipe,instruments,18427) if kind=='sfx' else render_track(name,arrange(recipe),instruments,18427)
            file=folder/f'{name}.wav';_write_wave(file,pcm)
            index[kind][name]={'file':file.name,'sha256':sha256(file),'sample_rate':SAMPLE_RATE,'channels':1 if pcm.ndim==1 else 2,'frames':len(pcm),'loop':kind=='music'}
    write_json(folder/'index.json',index);return index


def validate(root:Path)->dict:
    folder=root/'assets/arena/audio';index=json.loads((folder/'index.json').read_text())
    require(index.get('schema_version')==1,'Audio index version differs.')
    require(set(index.get('sfx',{}))=={'coin','purchase','wave_clear','ready','combo'},'Arena cue set differs.')
    require(set(index.get('music',{}))=={'arena','arena_boss','shop'},'Arena score set differs.')
    for kind in ('sfx','music'):
        for name,record in index[kind].items():
            file=folder/record['file'];require(record['file']==name+'.wav' and file.is_file() and not file.is_symlink() and sha256(file)==record['sha256'],'Audio file hash/path differs.')
            with wave.open(str(file),'rb') as wav:
                require(wav.getnchannels()==(1 if kind=='sfx' else 2) and wav.getsampwidth()==2 and wav.getframerate()==44100 and wav.getnframes()==record['frames'],'Audio PCM metadata differs.')
                pcm=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2')
            require(len(pcm)>1000 and 100<float(np.sqrt(np.mean(pcm.astype(float)**2)))<12000,'Audio RMS outside intentional headroom range.')
            require(0<np.max(np.abs(pcm))<12000,'Audio clips or is silent.')
            require(pcm[0]==0 and pcm[-1]==0,'Audio endpoints must be zero.')
    return index
