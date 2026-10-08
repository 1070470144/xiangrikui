"""Publish manually reviewed Sprite-gen video strips, preserving existing state backups."""
import argparse
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'art_source/generated/monster_video_batch'
SCALES = {'shadow_beast':0.36, 'erosion_bug':0.32, 'husk_ram':0.46, 'spore_moth':0.50, 'shell_scarab':0.45}

def contact(name, state):
    folder = OUT/name/f'{state}-loop'
    meta = json.loads((folder/f'{state}.strip.json').read_text(encoding='utf-8'))
    strip = Image.open(folder/f'{state}.strip.png').convert('RGBA')
    count = min(12, meta['frames'])
    w, h = meta['w'], meta['h']
    preview_scale = min(1, 250/w, 170/h)
    pw, ph = round(w*preview_scale), round(h*preview_scale)
    out = Image.new('RGB', (pw*4, (ph+20)*3), (45,48,57))
    draw = ImageDraw.Draw(out)
    for k in range(count):
        index = round(k*(meta['frames']-1)/max(1,count-1))
        cell = strip.crop((index*w,0,(index+1)*w,h)).resize((pw,ph),Image.Resampling.LANCZOS)
        pos = ((k%4)*pw,(k//4)*(ph+20))
        out.paste(cell,pos,cell)
        draw.text((pos[0]+5,pos[1]+ph),str(index),fill='white')
    out.save(folder/'contact.png')
    return meta

def publish(name):
    dest = ROOT/'assets/enemies/animations'/name
    manifest_path = dest/'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {'characterId':name, 'animation':{'rows':{}}}
    backup = OUT/name/'previous-game-resources'
    backup.mkdir(exist_ok=True)
    if dest.exists():
        for file in dest.glob('*'):
            if file.is_file() and not (backup/file.name).exists(): shutil.copy2(file,backup/file.name)
    dest.mkdir(parents=True,exist_ok=True)
    states = ['attack'] if name == 'shadow_beast' else ['walk','attack']
    for state in states:
        folder = OUT/name/f'{state}-loop'
        report = json.loads((folder/f'{state}.loop.report.json').read_text(encoding='utf-8'))
        review = json.loads((folder/'visual-review.json').read_text(encoding='utf-8'))
        assert report['status'] == 'passed' and review['accepted']
        meta = contact(name,state)
        assert not meta['subsampled'] and meta['frames'] == meta['cycle_frames'], 'Preserve native frames'
        strip = Image.open(folder/f'{state}.strip.png').convert('RGBA')
        width = max(192,meta['w']+meta['w']%2)
        height = max(192,meta['h']+28)
        ground = height-14
        for i in range(meta['frames']):
            cell = strip.crop((i*meta['w'],0,(i+1)*meta['w'],meta['h']))
            canvas = Image.new('RGBA',(width,height))
            canvas.alpha_composite(cell,((width-meta['w'])//2,ground-meta['h']))
            target = dest/f'{state}-frame-{i}.png'
            tmp = target.with_suffix('.png.part')
            canvas.save(tmp,format='PNG'); tmp.replace(target)
        fps = float(report['fps'])
        manifest['animation']['rows'][state] = {'frames':meta['frames'],'fps':fps,'loop':state=='walk',
             'durations_ms':[1000/fps]*meta['frames'], 'width':width,'height':height,'ground_y':ground,'body_height':meta['body_h'],
             'source':f'art_source/generated/monster_video_batch/{name}/{state}.mp4',
             'pipeline_metadata':f'art_source/generated/monster_video_batch/{name}/{state}-loop/{state}.strip.json',
             'source_cycle':{k:report['cycle'].get(k) for k in ('kind','start','length','ratio','review_recommended')}}
    manifest.update({'engine':'sprite-gen-video', 'game_input':'per-state-png-frames',
                     'runtime':{'scale':SCALES[name],'ground_offset':-18.0 if name=='spore_moth' else 8-28*SCALES[name],
                                'idle_walk':name=='spore_moth'}})
    for key in ('frame_layout','sprite_sheet_alpha','sprite_sheet_alpha_report'): manifest.pop(key,None)
    manifest['animation'].pop('columns',None)
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(name,[(s,manifest['animation']['rows'][s]['frames']) for s in states])

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('stage',choices=['contact','publish'])
    parser.add_argument('--names',nargs='+',default=list(SCALES))
    args=parser.parse_args()
    for name in args.names:
        if args.stage=='publish': publish(name)
        else:
            for state in (['attack'] if name=='shadow_beast' else ['walk','attack']):
                if (OUT/name/f'{state}-loop'/f'{state}.strip.json').exists(): contact(name,state)
