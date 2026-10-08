"""Publish canonical keyed video frames with one fixed transform per animation."""
import json
from pathlib import Path
from PIL import Image
import numpy as np
from prepare_mother_realism import fit

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/generated/sun_arrow_attack'

def publish(kind):
    folder = SOURCE / ('attack_v3' if kind == 'attack' else 'impact_v2' if kind == 'impact' else kind)
    report = json.loads((folder / 'frames/frames.report.json').read_text())
    if not report.get('frames'):
        raise RuntimeError('No canonical extracted frames')
    paths = sorted((folder / 'frames/keyed').glob('*.png'))
    # Preserve frame ordering; deliver the first action second at 24fps.
    selected = [paths[round(60*i/11)] for i in range(12)] if kind == 'attack' else paths[:24:4] if kind == 'impact' else paths[:24]
    images = [Image.open(p).convert('RGBA') for p in selected]
    if kind == 'impact':
        # Localize detached long rays; preserve the compact core and feather its fringe.
        first = np.asarray(images[0]).astype(float)
        weights = (first[:,:,:3].sum(axis=2)/765.0)**8 * first[:,:,3]
        yy,xx = np.mgrid[:first.shape[0],:first.shape[1]]
        cx,cy = (float((xx*weights).sum()/weights.sum()),float((yy*weights).sum()/weights.sum()))
        radius = min(cx, first.shape[1]-cx, cy, first.shape[0]-cy) * 0.85
        feather = np.clip((radius-np.hypot(xx-cx,yy-cy))/15.0,0,1)
        localized=[]
        for im in images:
            a=np.array(im).astype(float)
            a[:,:,3]*=feather
            purple=(a[:,:,0]>a[:,:,1]*1.2)&(a[:,:,2]>a[:,:,1]*1.2)
            a[:,:,2][purple]=a[:,:,1][purple]*0.35
            a[a[:,:,3]==0]=0
            localized.append(Image.fromarray(a.astype('uint8')))
        images=localized
    if kind == 'flight':
        cleaned=[]
        for im in images:
            a=np.array(im).astype(float)
            purple=(a[:,:,0]>a[:,:,1]*1.2)&(a[:,:,2]>a[:,:,1]*1.2)
            a[:,:,2][purple]=a[:,:,1][purple]*0.35
            a[a[:,:,3]==0]=0
            cleaned.append(Image.fromarray(a.astype('uint8')))
        images=cleaned
    for im in images:
        alpha = np.asarray(im)[:,:,3]
        if max(alpha[:4].max(), alpha[:,:4].max(), alpha[:,-4:].max()) > 32:
            raise RuntimeError('Selected action frames touch edge; do not publish')
    boxes = [im.getchannel('A').point(lambda v: 255 if v > 16 else 0).getbbox() for im in images]
    boxes = [b for b in boxes if b]
    bounds = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    if kind == 'attack':
        # Use idle's exact source pose to protect transition scale and root anchor.
        idle = Image.open(folder / 'frames/keyed' / paths[0].name).convert('RGBA')
        bounds = idle.getchannel('A').point(lambda v: 255 if v > 16 else 0).getbbox()
        delivered = [fit(im, bounds) for im in images]
        fps = 24.0
    else:
        l,t,r,b = bounds
        scale = 210 / max(r-l,b-t)
        delivered = []
        for im in images:
            resized = im.resize((round(im.width*scale), round(im.height*scale)), Image.Resampling.LANCZOS)
            canvas = Image.new('RGBA', (256,256))
            canvas.alpha_composite(resized, (round(128-(l+r)*0.5*scale), round(128-(t+b)*0.5*scale)))
            delivered.append(canvas)
        fps = 24.0
    target = ROOT / 'assets/effects/sun_arrow' / kind
    target.mkdir(parents=True, exist_ok=True)
    frame_paths = []
    for i, im in enumerate(delivered):
        path = target / f'frame-{i:03d}.png'
        im.save(path)
        frame_paths.append('res://' + path.relative_to(ROOT).as_posix())
    contact = Image.new('RGBA',(256*6,256*2),(35,38,32,255))
    for i in range(12):
        contact.alpha_composite(delivered[round(i*(len(delivered)-1)/11)],((i%6)*256,(i//6)*256))
    contact.convert('RGB').save(folder / 'contact.png')
    delivered[0].save(folder/'preview.gif',save_all=True,append_images=delivered[1:],duration=round(1000/fps),loop=0,disposal=2)
    (target/'manifest.json').write_text(json.dumps({'status':'passed','fps':fps,'frame_paths':frame_paths,'source':str((folder/'clip.mp4').relative_to(ROOT)), 'source_fps':24,'duration':len(delivered)/fps},indent=2))
    (folder/'publish-report.json').write_text(json.dumps({'source_frames':[p.name for p in selected], 'fps':fps,'duration':len(delivered)/fps,'fixed_transform':True,'selected_frames_edge_check':'passed','impact_localization':kind=='impact'},indent=2))
    print(kind, 'published', len(delivered), 'frames')

if __name__ == '__main__':
    import sys
    for kind in sys.argv[1:] or ['attack','flight','impact']: publish(kind)
