"""Derive consistent health states, align all frames once, publish accepted assets."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/generated/mother_realism_v1'
DEST = ROOT / 'assets/core/generated/mother_realism_v1'

def damage(image, severity):
    a = np.array(image).astype(float)
    h,w = a.shape[:2]
    y,x = np.mgrid[:h,:w]
    yellow = (a[:,:,0] > a[:,:,1]*1.12) & (a[:,:,1] > a[:,:,2]*1.35) & (y < h*.52)
    leaf = (a[:,:,1] > a[:,:,2]*1.15) & (y > h*.34) & (y < h*.76)
    region = yellow | leaf
    # Botanical wilt: outer petals/leaves sag; the stem and root pixels do not move.
    edge = np.clip(abs(x-w*.52)/(w*.38),0,1)
    shift = severity*85*edge*region
    sy = np.clip(np.rint(y-shift),0,h-1).astype(int)
    a = a[sy,x]
    luminance = a[:,:,:3].mean(axis=2,keepdims=True)
    a[:,:,:3] = a[:,:,:3]*(1-.25*severity)+luminance*.25*severity
    a[:,:,:3] *= np.array([1-.12*severity,1-.23*severity,1-.20*severity])
    # Local dry lesions rather than a uniform health tint.
    for cx,cy,r in [(0.23,.27,.032),(.77,.23,.035),(.83,.40,.026),(.26,.50,.04),(.75,.65,.038)]:
        mask = np.exp(-((x-w*cx)**2+(y-h*cy)**2)/(2*(w*r)**2))*.65*severity
        a[:,:,:3] = a[:,:,:3]*(1-mask[:,:,None])+np.array([82,48,24])*mask[:,:,None]
    a[a[:,:,3]==0]=0
    return Image.fromarray(np.clip(a,0,255).astype('uint8'))

def fit(image,bbox):
    # One transform for all states/frames protects the root anchor.
    l,t,r,b=bbox
    scale=210/max(r-l,b-t)
    resized=image.resize((round(image.width*scale),round(image.height*scale)),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(256,256))
    offset=(round(128-(l+r)*.5*scale),round(222-b*scale))
    canvas.alpha_composite(resized,offset)
    a=np.array(canvas)
    # Last isolated purple spill pixels in root antialiasing; protect yellow/green.
    purple=(a[:,:,0]>a[:,:,1].astype(float)*1.4)&(a[:,:,2]>a[:,:,1].astype(float)*1.4)&(a[:,:,3]>0)
    a[:,:,2][purple]=np.minimum(a[:,:,2][purple],a[:,:,1][purple])
    a[a[:,:,3]==0]=0
    return Image.fromarray(a)

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    base=Image.open(SOURCE/'candidate-2.png').convert('RGBA')
    bbox=base.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox()
    for state,severity in [('healthy',0),('damaged',.55),('critical',1)]:
        full=damage(base,severity) if severity else base
        full.save(SOURCE/f'{state}.source.png')
        fit(full,bbox).save(DEST/f'{state}.png')
    manifest={'status':'static-only','fps':12,'loop':True,'frame_paths':[], 'anchor':[128,222], 'selected_candidate':2}
    loop=SOURCE/'sequence/loop'
    if (loop/'idle.loop.report.json').exists():
        report=json.loads((loop/'idle.loop.report.json').read_text())
        if report['status']=='passed':
            meta=json.loads((loop/'idle.strip.json').read_text())
            strip=Image.open(loop/'idle.strip.png').convert('RGBA')
            n=int(meta['frames']); w=int(meta['w']); h=int(meta['h'])
            images=[strip.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
            boxes=[im.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox() for im in images]
            bounds=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
            duration=float(report['cycle_seconds']); count=round(duration*12)
            delivered=[]
            for i in range(count):
                image=images[min(n-1,int(i*n/count))]
                frame=fit(image,bounds)
                path=DEST/f'idle-{i:03d}.png'; frame.save(path)
                manifest['frame_paths'].append('res://'+path.relative_to(ROOT).as_posix())
                delivered.append(frame)
            delivered[0].save(SOURCE/'idle-preview.gif',save_all=True,append_images=delivered[1:],duration=round(1000/12),loop=0,disposal=2)
            contact=Image.new('RGBA',(256*6,256*2),(25,30,32,255))
            for i in range(12): contact.alpha_composite(delivered[min(count-1,round(i*(count-1)/11))],((i%6)*256,(i//6)*256))
            contact.convert('RGB').save(SOURCE/'idle-contact.png')
            manifest.update(status='passed',duration_seconds=count/12,source_duration_seconds=duration,source='art_source/generated/mother_realism_v1/idle.mp4')
    (DEST/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print(json.dumps({'status':manifest['status'],'frames':len(manifest['frame_paths'])}))

if __name__=='__main__':main()
