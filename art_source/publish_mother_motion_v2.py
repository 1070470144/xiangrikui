"""Publish only canonical sprite-gen loops; fixed transform across each clip."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_mother_realism import fit

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/generated/mother_motion_v2'
DEST = ROOT / 'assets/core/generated/mother_motion_v2'

def publish(name):
    folder = SOURCE/name
    loop = folder/'sequence/loop'
    report = json.loads((loop/'idle.loop.report.json').read_text(encoding='utf-8'))
    if report['status'] != 'passed': raise ValueError('loop QA failed')
    meta = json.loads((loop/'idle.strip.json').read_text(encoding='utf-8'))
    strip = Image.open(loop/'idle.strip.png').convert('RGBA')
    n,w,h = (int(meta[k]) for k in ['frames','w','h'])
    images = [strip.crop((i*w,0,(i+1)*w,h)) for i in range(n)]
    boxes = [im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox() for im in images]
    bounds = (min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    count = round(float(report['cycle_seconds'])*12)
    delivered = [fit(images[min(n-1,int(i*n/count))],bounds) for i in range(count)]
    # Measurement only: no per-frame alignment hides root movement.
    roots=[]
    purple=0
    for im in delivered:
        a=np.array(im).astype(float)
        ys,xs=np.mgrid[:256,:256]
        mask=(ys>=208)*(a[:,:,3]>32)
        roots.append(float(xs[mask].mean()) if mask.any() else 0)
        purple+=int(((a[:,:,0]>a[:,:,1]*1.4)&(a[:,:,2]>a[:,:,1]*1.4)&(a[:,:,3]>32)).sum())
    spread=max(roots)-min(roots)
    metrics={'root_horizontal_spread_px':spread,'purple_pixels':purple,'duration':count/12,'frames':count}
    (folder/'publish-report.json').write_text(json.dumps(metrics,indent=2))
    if spread>3 or purple>0: raise ValueError('root/spill inspection failed: '+str(metrics))
    target=DEST/name
    target.mkdir(parents=True,exist_ok=True)
    paths=[]
    for i,im in enumerate(delivered):
        path=target/f'idle-{i:03d}.png'; im.save(path)
        paths.append('res://'+path.relative_to(ROOT).as_posix())
    delivered[0].save(folder/'transparent-preview.gif',save_all=True,append_images=delivered[1:],duration=round(1000/12),loop=0,disposal=2)
    contact=Image.new('RGBA',(256*6,256*2),(30,34,30,255))
    for i in range(12): contact.alpha_composite(delivered[round(i*(count-1)/11)],((i%6)*256,(i//6)*256))
    contact.convert('RGB').save(folder/'contact.png')
    (target/'manifest.json').write_text(json.dumps({'status':'passed','fps':12,'loop':True,'frame_paths':paths,'anchor':[128,222],'duration_seconds':count/12,'source':str((folder/'idle.mp4').relative_to(ROOT))},indent=2))
    print(name,metrics)

if __name__=='__main__':
    for name in ['base','sun_arrow','root_heart','dawn_pulse']:
        try: publish(name)
        except Exception as error: print(name,'NOT PUBLISHED',str(error))
