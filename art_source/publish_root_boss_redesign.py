"""Publish reviewed Sprite-gen keyed videos as native-rate bounded Godot atlases."""
import argparse
import json
from pathlib import Path
import sys
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT/'art_source/generated/root_boss_redesign_20261009'
sys.path.insert(0, str(Path.home()/'.codex/skills/sprite-gen'))
from sprite_gen.video.loop import _scrub, _drop_specks, SPECK_MIN_FRACTION, distance_matrix

BODY = {'idle':'idle-v4', 'walk':'walk-v4', 'attack':'attack-v2', 'slam':'slam-v2',
        'summon':'summon-v4', 'spawn':'spawn-v4', 'death':'death',
        'exposed':'exposed-v4', 'enraged':'enraged-v4'}
EFFECTS = {'impact':'impact-v5','root_lock':'root_lock','summon_fx':'summon_fx-v4',
           'exposed_fx':'exposed_fx-v4','enraged_fx':'enraged_fx-v4'}
LOOPS = {'idle','walk','exposed','enraged'}

def write_json(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n',encoding='utf-8')

def load(state, source):
    folder = RUN/source
    info = json.loads((folder/'frames/frames.report.json').read_text(encoding='utf-8'))
    if info.get('edge_contacts'): raise RuntimeError(source+': clipped video cannot publish')
    files = sorted((folder/'frames/keyed').glob('*.png'))
    if len(files) != info['frames']: raise RuntimeError(source+': extraction incomplete')
    selection = list(range(len(files)))
    seam = None
    if state in LOOPS:
        matrix = distance_matrix(files)
        candidates = []
        for length in range(24, len(files)):
            for start in range(len(files)-length+1):
                adjacent = float(np.mean([matrix[i,i+1] for i in range(start,start+length-1)]))
                ratio = float(matrix[start,start+length-1])/max(adjacent,1e-6)
                if ratio <= 2.0: candidates.append((length, -ratio, start))
        if not candidates: raise RuntimeError(source+': no closed loop under seam ratio 2')
        length, negative, start = max(candidates)
        selection = list(range(start,start+length)); seam = -negative
    images = []
    for index in selection:
        im = Image.open(files[index]).convert('RGBA')
        _scrub(im)
        im, _ = _drop_specks(im, SPECK_MIN_FRACTION)
        images.append(im)
    return images, info, selection, seam

def despill(image):
    data=np.array(image)
    r,g,b=[data[:,:,i].astype(np.float32) for i in range(3)]
    mask=(g>r*1.15+8)&(g>b*1.15+8)&(data[:,:,3]>0)
    data[:,:,1][mask]=np.maximum(r,b)[mask].astype(np.uint8)
    return Image.fromarray(data)

def cells(images, effect=False):
    bounds = [im.getbbox() for im in images]
    valid = [b for b in bounds if b]
    if not valid: raise RuntimeError('Empty animation')
    width, height = (400, 300) if effect else (640, 480)
    if effect:
        box = (min(b[0] for b in valid),min(b[1] for b in valid),max(b[2] for b in valid),max(b[3] for b in valid))
        scale = min((width-24)/(box[2]-box[0]),(height-24)/(box[3]-box[1]))
        cx, cy = (box[0]+box[2])/2, (box[1]+box[3])/2
        anchor_y = height/2
    else:
        standing = [b for b in bounds[:12] if b]
        scale = 230/float(np.median([b[3]-b[1] for b in standing]))
        cx = float(np.median([(b[0]+b[2])/2 for b in standing]))
        cy = float(np.median([b[3] for b in standing]))
        anchor_y = 420
    result = []
    for im in images:
        resized = im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA',(width,height))
        x, y = round(width/2-cx*scale), round(anchor_y-cy*scale)
        canvas.alpha_composite(resized,(x,y))
        if not effect:
            data=np.array(canvas)
            r,g,b=[data[:,:,i].astype(float) for i in range(3)]
            floor=np.arange(height)[:,None]>anchor_y
            residue=floor&(g>r*.75)&(g>b*1.5)&(data[:,:,3]>0)
            data[residue]=0
            canvas=Image.fromarray(data)
        # Assert that transformed opaque bounds remain inside the runtime canvas.
        b = im.getbbox()
        if b and (b[0]*scale+x<1 or b[1]*scale+y<1 or b[2]*scale+x>width-1 or b[3]*scale+y>height-1):
            raise RuntimeError(f'Runtime framing clips an opaque frame: bbox={b}, scale={scale:.3f}, offset={x,y}, canvas={width,height}')
        result.append(canvas)
    return result, anchor_y

def atlas(dest, state, images):
    w,h = images[0].size; cols,rows = 2048//w,2048//h; capacity=cols*rows
    records=[]
    for page_no,start in enumerate(range(0,len(images),capacity)):
        group=images[start:start+capacity]
        page=Image.new('RGBA',(min(cols,len(group))*w,((len(group)+cols-1)//cols)*h))
        name=f'{state}-atlas-{page_no:02d}.png'
        for i,im in enumerate(group):
            x,y=i%cols*w,i//cols*h; page.paste(im,(x,y)); records.append({'page':name,'region':[x,y,w,h]})
        page.save(dest/name)
        with Image.open(dest/name) as saved:
            for record,im in zip(records[-len(group):],group):
                x,y,w,h=record['region']; assert saved.crop((x,y,x+w,y+h)).tobytes()==im.tobytes()
    return records

def contact(state, images):
    sheet=Image.new('RGB',(1200,780),(38,38,43)); draw=ImageDraw.Draw(sheet)
    for i in range(12):
        index=round(i*(len(images)-1)/11); im=images[index].copy(); im.thumbnail((300,230))
        x,y=i%4*300+(300-im.width)//2,i//4*260
        sheet.paste(im,(x,y),im); draw.text((i%4*300+5,y+235),f'{state} {index}',fill='white')
    sheet.save(RUN/f'{state}-review.png')

def build(effect=False, publish=False):
    source = EFFECTS if effect else BODY
    dest=RUN/('effects-staging' if effect else 'boss-staging'); dest.mkdir(exist_ok=True)
    manifest={'enemy_id':'root_crown_colossus','runtime':{'scale':0.9,'ground_offset':8.0},'states':{}}
    reviews={}
    for state,folder in source.items():
        images,info,selection,seam=load(state,folder)
        images=[despill(im) for im in images]
        images,ground=cells(images,effect)
        contact(state,images)
        spec={'fps':info['fps'],'loop':state in LOOPS,'frames':len(images),'ground_y':ground,'width':images[0].width,'height':images[0].height,
              'regions':atlas(dest,state,images),'source_video':folder+'/clip.mp4'}
        if state=='slam': spec['impact_time']=50/24
        manifest['states'][state]=spec
        reviews[state]={'source':folder,'source_indices':selection,'fps':info['fps'],'seam_ratio':seam,'edge_contacts':[],'native_frames':True}
        print(state,len(images),'frames',flush=True)
    write_json(dest/'atlas_manifest.json',manifest)
    write_json(dest/'review.json',reviews)
    write_json(dest/'manifest.json',{'characterId':'root_crown_colossus','animation':{'rows':manifest['states']},'runtime':manifest['runtime']})
    if publish:
        approval=RUN/('effects-visual-review.json' if effect else 'boss-visual-review.json')
        if not approval.exists() or not json.loads(approval.read_text()).get('accepted'): raise RuntimeError('Visual review required')
        import shutil
        target=ROOT/('assets/effects/root_boss' if effect else 'assets/enemies/animations/root_crown_colossus')
        target.mkdir(parents=True,exist_ok=True)
        for file in dest.glob('*'): shutil.copy2(file,target/file.name)

def clean_staging():
    for name in ['boss-staging','effects-staging']:
        folder=RUN/name
        if not (folder/'atlas_manifest.json').exists(): continue
        for path in folder.glob('*-atlas-*.png'):
            with Image.open(path) as im: clean=despill(im.convert('RGBA'))
            clean.save(path)
        manifest=json.loads((folder/'atlas_manifest.json').read_text())
        for state,spec in manifest['states'].items():
            images=[]
            indices=[round(i*(len(spec['regions'])-1)/11) for i in range(12)]
            for i in indices:
                record=spec['regions'][i]; x,y,w,h=record['region']
                with Image.open(folder/record['page']) as page: images.append(page.crop((x,y,x+w,y+h)).convert('RGBA'))
            contact(state,images)
        print(name,'despill complete',flush=True)

def publish_staging(effect):
    import shutil
    folder=RUN/('effects-staging' if effect else 'boss-staging')
    approval=RUN/('effects-visual-review.json' if effect else 'boss-visual-review.json')
    if not approval.exists() or not json.loads(approval.read_text()).get('accepted'): raise RuntimeError('Visual review required')
    target=ROOT/('assets/effects/root_boss' if effect else 'assets/enemies/animations/root_crown_colossus')
    target.mkdir(parents=True,exist_ok=True)
    for file in folder.glob('*'): shutil.copy2(file,target/file.name)
    print('Published',target,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--effects',action='store_true'); parser.add_argument('--publish',action='store_true'); parser.add_argument('--clean-staging',action='store_true'); parser.add_argument('--publish-staging',action='store_true')
    args=parser.parse_args()
    if args.clean_staging: clean_staging()
    elif args.publish_staging: publish_staging(args.effects)
    else: build(args.effects,args.publish)
