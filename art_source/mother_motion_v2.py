"""Four authorized, resumable Seedance requests. Never automatically resubmit."""
import base64
import concurrent.futures
import json
import time
import urllib.request
from pathlib import Path
from PIL import Image
from mother_video_ark import request, API, MODEL

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art_source/generated/mother_motion_v2'
IDS = ['base', 'sun_arrow', 'root_heart', 'dawn_pulse']

def generate(name):
    folder = OUT / name
    folder.mkdir(parents=True, exist_ok=True)
    source = ROOT / ('art_source/generated/mother_realism_v1/candidate-2.png' if name == 'base' else f'art_source/generated/plant_mother_static/{name}.source.png')
    im = Image.open(source).convert('RGBA')
    im = im.crop(im.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox())
    im.thumbnail((540, 540), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (768, 768), (255, 0, 255, 255))
    canvas.alpha_composite(im, ((768-im.width)//2, 666-im.height))
    ref = folder / 'reference-magenta.png'
    canvas.convert('RGB').save(ref)
    task = folder / 'task.json'
    marker = folder / 'submitted'
    if (folder / 'idle.mp4').exists(): return name, 'downloaded'
    if task.exists(): task_id = json.loads(task.read_text())['id']
    else:
        if marker.exists(): return name, 'submission already attempted; no retry'
        prompt = ('Create a clearly visible 4 second looping botanical idle animation of this exact rooted fantasy flower. '
                  'Locked orthographic three-quarter overhead camera, fixed scale. Solid uniform pure magenta #FF00FF background, no scenery or ground. '
                  'Keep the lowest roots perfectly fixed in the same pixels. The upper stem flexes naturally: flower crown slowly sways 10 degrees left then 10 degrees right and returns, '
                  'with crown horizontal travel about 6 percent of plant width. Large leaves alternately lift and lower, tips traveling 8 percent of plant height, '
                  'out of phase with each other. Petals visibly curl, bend and elastically spring back while retaining their exact number and anatomy. '
                  'The motion must be easily readable when the entire plant is only 120 pixels tall in a game. '
                  'Start and end at this exact reference pose with matching velocity for seamless looping. Preserve materials and colors. '
                  'No halo, aura, rays, glow expansion, particles, floating symbols, geometry, shadow on background, attack, transformation, new flowers, camera movement, cuts or zoom. '
                  'Do not freeze the crown or leaves. Only the bottom roots are stationary. No audio.')
        (folder/'prompt.txt').write_text(prompt, encoding='utf-8')
        encoded = 'data:image/png;base64,' + base64.b64encode(ref.read_bytes()).decode()
        marker.write_text('One submission maximum for this form. Never delete to retry.\n')
        result = request('POST', API, {'model':MODEL, 'content':[
            {'type':'text','text':prompt},
            {'type':'image_url','image_url':{'url':encoded},'role':'first_frame'},
            {'type':'image_url','image_url':{'url':encoded},'role':'last_frame'}],
            'duration':4,'ratio':'1:1','generate_audio':False,'watermark':False})
        task_id = result['id']
        task.write_text(json.dumps({'id':task_id,'model':MODEL,'duration':4,'source':str(source.relative_to(ROOT))},indent=2))
        print(name + ': submitted one task', flush=True)
    for _ in range(180):
        result = request('GET', API + '/' + task_id)
        status = result.get('status')
        (folder/'status.json').write_text(json.dumps({'status':status,'id':task_id,'error':result.get('error')},indent=2))
        if status == 'succeeded':
            last_error = None
            for _download_attempt in range(3):
                try:
                    with urllib.request.urlopen(result['content']['video_url'],timeout=120) as response: data=response.read()
                    break
                except Exception as error:
                    last_error = error
                    time.sleep(3)
            else:
                return name, 'download failed: ' + str(last_error)
            if b'ftyp' not in data[:32]: raise RuntimeError('invalid MP4')
            (folder/'idle.mp4').write_bytes(data)
            return name,'downloaded'
        if status in {'failed','expired','cancelled'}: return name,status
        time.sleep(10)
    return name,'pending; resume same task'

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = {pool.submit(generate,name): name for name in IDS}
        for job in concurrent.futures.as_completed(jobs):
            try: print(job.result(),flush=True)
            except Exception as error: print(jobs[job],type(error).__name__,str(error),flush=True)
