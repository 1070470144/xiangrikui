"""One resumable Ark task for the selected realistic mother. No paid retries."""
import base64
import json
import sys
import time
import urllib.request
from pathlib import Path
from PIL import Image
from mother_video_ark import request, API, MODEL

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art_source/generated/mother_realism_v1'

def main():
    image = Image.open(OUT / 'candidate-2.png').convert('RGBA')
    bbox = image.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
    image = image.crop(bbox)
    image.thumbnail((590, 590), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (768, 768), (255, 0, 255, 255))
    canvas.alpha_composite(image, ((768-image.width)//2, 684-image.height))
    reference = OUT / 'reference-magenta.png'
    canvas.convert('RGB').save(reference)
    task_file = OUT / 'idle.task.json'
    marker = OUT / 'idle.submitted'
    if (OUT / 'idle.mp4').exists(): return
    if task_file.exists():
        task_id = json.loads(task_file.read_text())['id']
    else:
        if marker.exists(): raise SystemExit('Submission already attempted; do not create a duplicate task')
        prompt = ('Locked orthographic three-quarter overhead camera. Preserve this exact realistic sunflower mother and its natural botanical anatomy. '
                  'Solid uniform pure magenta #FF00FF background throughout. The woody roots and entire stem remain perfectly stationary at identical pixel coordinates. '
                  'Four seconds of extremely gentle natural idle motion: petal tips flex slightly and two leaf tips slowly bend then return. '
                  'Flower center emits only a tiny restrained amber shimmer, no bloom. Exact starting pose at the end. '
                  'No camera motion, zoom, rotation, cuts, growth, morphing, petal count change, pink objects, aura, halo, rays, energy pulse, ground, shadows on background, or extra objects. '
                  'Maintain fine realistic petal texture and root bark, fixed scale and silhouette. This is a subtle looping game sprite, not a dramatic transformation.')
        (OUT / 'idle.prompt.txt').write_text(prompt, encoding='utf-8')
        encoded = 'data:image/png;base64,' + base64.b64encode(reference.read_bytes()).decode()
        marker.write_text('One authorized task only. Resume via idle.task.json, never resubmit.\n')
        result = request('POST', API, {'model': MODEL, 'content':[
            {'type':'text','text':prompt},
            {'type':'image_url','image_url':{'url':encoded},'role':'first_frame'},
            {'type':'image_url','image_url':{'url':encoded},'role':'last_frame'}],
            'duration':4,'ratio':'1:1','generate_audio':False,'watermark':False})
        task_id = result['id']
        task_file.write_text(json.dumps({'id':task_id,'model':MODEL,'duration':4},indent=2))
    print('Ark task submitted; polling same task', flush=True)
    for _ in range(120):
        result = request('GET', API + '/' + task_id)
        status = result.get('status')
        (OUT / 'idle.status.json').write_text(json.dumps({'status':status,'id':task_id},indent=2))
        if status == 'succeeded':
            with urllib.request.urlopen(result['content']['video_url'],timeout=120) as response:
                data=response.read()
            if b'ftyp' not in data[:32]: raise RuntimeError('Response is not an MP4')
            (OUT / 'idle.mp4').write_bytes(data)
            print('Video downloaded',flush=True)
            return
        if status in {'failed','expired','cancelled'}: raise SystemExit('Ark task '+status)
        time.sleep(10)
    raise SystemExit('Task pending; resume without a new POST')

if __name__=='__main__': main()
