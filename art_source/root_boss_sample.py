"""Single review sample only. Never retry ambiguous paid submissions."""
import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import time
import uuid
from monster_video_batch import request, save, API, MODEL, PYTHON, SKILL, RUNNER, ROOT

OUT = ROOT / 'art_source/generated/root_boss_sample'
DESIGN = ('One photorealistic dark fantasy tree colossus game character, massive heavy trunk torso, '
          'exactly two root legs and two thick root arms, dead branch crown, wet weathered brown bark '
          'and layered embedded dark rocks, clearly visible amber chest core. Elevated orthographic '
          'three quarter view facing RIGHT, neutral grounded stance, entire body with generous margins. '
          'Pure uniform green #00FF00 background, no ground, no shadows, no environment, no text, '
          'no green reflections, sharp realistic materials and readable silhouette. Single character only.')
MOTION = ('Locked fixed elevated orthographic camera, same view and identity as reference, facing RIGHT. '
          'Entire character remains inside frame with ample margins. Pure green background, no floor, '
          'no cast shadow, no dust, no particles, no shockwave, no camera movement or blur. '
          'Exactly ONE heavy two-arm ground slam: start braced, sink weight and slowly raise arms '
          'during seconds 0 to 1.1, land both root fists at exactly 1.2 seconds, absorb the weight '
          'with knees and shoulders, rebound slightly, recover the starting stance by 4.5 seconds, '
          'hold until 5 seconds. Keep feet planted, anatomically stable root limbs, no extra limbs.')

def run(*args):
    subprocess.run([str(PYTHON), str(RUNNER), *map(str, args)], check=True)

def image():
    target = OUT / 'original.png'
    intent = OUT / 'image.intent.json'
    if target.exists(): return
    if intent.exists(): raise RuntimeError('Image creation already attempted; inspect result before another paid call')
    if not os.environ.get('OPENAI_API_KEY'):
        raise RuntimeError('OPENAI_API_KEY missing; no image request submitted')
    (OUT / 'image-prompt.txt').write_text(DESIGN, encoding='utf-8')
    save(intent, {'request_id': str(uuid.uuid4()), 'model': 'gpt-image-2', 'status': 'submission_started'})
    subprocess.run([str(PYTHON), str(ROOT/'aiskill/mm-tools/sprite_gen_gateway.py'),
        '--sprite-gen-root', str(SKILL), '--api-base', 'https://newapi.oairegbox.cc/', '--',
        'gen', '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'high',
        '--aspect-ratio', '16:9', '--prompt-file', str(OUT/'image-prompt.txt'),
        '--out', str(target), '--report', str(OUT/'image.report.json')], check=True)
    save(intent, {'status': 'completed', 'model': 'gpt-image-2'})

def video():
    target = OUT/'slam.mp4'
    if target.exists(): return
    task_file = OUT/'slam.task.json'
    intent = OUT/'slam.intent.json'
    if task_file.exists():
        task_id = json.loads(task_file.read_text(encoding='utf-8'))['id']
    else:
        if intent.exists(): raise RuntimeError('Ambiguous creation: no task ID; do not repeat POST')
        if not os.environ.get('ARK_API_KEY'):
            raise RuntimeError('ARK_API_KEY missing; no video request submitted')
        run('video-canvas', '--still', OUT/'original.png', '--out', OUT/'slam-canvas.png',
            '--state', 'attack', '--shape', 'wide', '--headroom', '.18', '--lead', '.20', '--trail', '.15', '--key', 'green')
        payload = {'model': MODEL, 'content': [{'type': 'text', 'text': MOTION},
            {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,'+base64.b64encode((OUT/'slam-canvas.png').read_bytes()).decode()}, 'role': 'first_frame'}],
            'generate_audio': False, 'ratio': '16:9', 'duration': 5, 'watermark': False}
        save(intent, {'request_id': str(uuid.uuid4()), 'model': MODEL, 'status': 'submission_started'})
        result = request('POST', API, payload)
        save(OUT/'slam.create.json', result)
        task_id = result['id']
        save(task_file, {'id': task_id, 'model': MODEL})
    print('Task:', task_id, flush=True)
    for _ in range(100):
        result = request('GET', API+'/'+task_id)
        save(OUT/'slam.status.json', result)
        status = result.get('status')
        if status == 'succeeded':
            import urllib.request
            with urllib.request.urlopen(result['content']['video_url'], timeout=120) as response: data = response.read()
            if b'ftyp' not in data[:32]: raise RuntimeError('Invalid MP4')
            target.with_suffix('.mp4.part').write_bytes(data)
            target.with_suffix('.mp4.part').replace(target)
            return
        if status in ('failed', 'expired', 'cancelled'): raise RuntimeError(str(result.get('error')))
        print('Status:', status, flush=True)
        time.sleep(15)
    raise RuntimeError('Pending task saved; resume video stage later')

def process():
    run('video-frames', '--clip', OUT/'slam.mp4', '--out-dir', OUT/'frames', '--key', 'green',
        '--spill', 'auto', '--reference', OUT/'slam-canvas.png', '--decontam', 'auto')
    fps = json.loads((OUT/'frames/frames.report.json').read_text(encoding='utf-8'))['fps']
    run('video-loop', '--frames-dir', OUT/'frames/keyed', '--out-dir', OUT/'loop', '--fps', fps,
        '--state', 'attack', '--cycle', 'one-shot', '--anchor', 'feet', '--body-height', '230',
        '--strip-height', '380', '--gif-fps', fps, '--name', 'slam')

def status():
    """Inspect saved progress without submitting another paid generation."""
    result = {'original_exists': (OUT/'original.png').exists(),
              'video_exists': (OUT/'slam.mp4').exists()}
    for name in ['image.intent', 'image.report', 'slam.intent', 'slam.task', 'slam.status']:
        path = OUT/(name+'.json')
        if path.exists(): result[name] = json.loads(path.read_text(encoding='utf-8'))
    if 'slam.task' in result:
        task_id = result['slam.task']['id']
        latest = request('GET', API+'/'+task_id)
        save(OUT/'slam.status.json', latest)
        result['slam.status'] = latest
    if not result['original_exists'] and 'image.intent' in result:
        result['blocked_reason'] = 'Image submission has no saved result; no repeated POST is permitted.'
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['image', 'video', 'process', 'status'])
    parser.add_argument('--run-name', default='root_boss_sample',
                        help='Isolated run directory; use a new name only after explicitly authorizing a new creation')
    args = parser.parse_args()
    if not args.run_name or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-' for c in args.run_name):
        parser.error('run-name must be a simple directory name')
    OUT = ROOT / 'art_source/generated' / args.run_name
    OUT.mkdir(parents=True, exist_ok=True)
    globals()[args.stage]()
