"""Reproducible Ark generation and Sprite-gen processing; keys only in environment."""
import argparse
import base64
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import urllib.request
import urllib.error
import uuid

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art_source/generated/monster_video_batch'
SKILL = Path.home() / '.codex/skills/sprite-gen'
PYTHON = SKILL / '.venv/Scripts/python.exe'
RUNNER = ROOT.parent / 'tools/video/sprite_video.py'
API = 'https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks'
MODEL = 'doubao-seedance-2-0-mini-260615'
SPECS = {
 'shadow_beast': ('影兽', 'A low dark-purple armored feline quadruped with cyan eyes and a long tail.', 'Flexible predatory four-legged locomotion.', 'One powerful forward jaw bite: crouch anticipation, push with rear paws, extend neck and open jaws, snap shut, recoil, recover the same grounded ready stance.'),
 'erosion_bug': ('蚀芽虫', 'A six-legged corrupted garden insect, purple segmented armor, turquoise eyes, short insect legs, mandibles. Preserve the attached reference design.', 'Six insect legs alternating in tripod support groups, stable heavy shell, low foot recovery arcs, no hopping, no human hands, steady forward crawling in place.', 'One mandible attack: brace six short legs, draw head backward, thrust head and mandibles forward, close mandibles, retract and recover ready stance. Body remains grounded.'),
 'husk_ram': ('枯壳撞兽', 'A hulking four-legged corrupted ram, heavy cracked dried bark shell on shoulders, two curved deadwood horns, stocky legs with hooves, tiny amber eyes. Charcoal plum armor with muted moss accents.', 'Heavy four-legged ram walking in place, alternating hoof contacts and deliberate shoulder weight transfer, head stable, slight shell inertia.', 'One horn ram: plant rear hooves, lower horned head, coil shoulders, thrust forward briefly, absorb impact through forelegs, retract and stand ready. Entire animal remains inside frame.'),
 'spore_moth': ('腐孢蛾', 'A corrupted giant moth, exactly two broad pairs of ragged dusty purple moth wings with cream botanical markings, dark furry thorax, turquoise eyes, curled abdomen, two antennae, six small insect legs. Distinct graceful flying silhouette.', 'Hovering forward flight in place, anatomically consistent coordinated wing beats, subtle thorax lift and abdomen counterbalance. Repeat complete wing cycles, no walking, fixed altitude, no detaching wings.', 'One airborne spore attack: stabilize wings, arch abdomen forward, tense and pulse thorax, release a tiny brief muted violet spore puff straight right, recoil and recover hovering ready pose. No green particles, keep wing count unchanged.'),
 'shell_scarab': ('黑甲育虫', 'An armored black-purple scarab beetle with a massive rounded layered carapace, exactly six sturdy jointed insect legs, cyan slit eyes, short symmetrical mandibles, subtle ivory shell cracks and tiny dim violet abdominal brood sacs. Broad grounded silhouette distinct from the erosion bug.', 'Slow heavy six-legged beetle crawling in place using alternating tripod support. Shell remains rigid, short jointed legs stay attached, low return arc, realistic weight transfer, no hopping.', 'One heavy mandible strike: brace all six legs, compress head backward, lift front shell slightly, thrust mandibles forward, clamp, settle armor and recover original grounded ready pose.'),
}
COMMON = ('Locked camera, fixed orthographic three-quarter side view facing RIGHT. Single full-body creature centered and fully visible with generous empty margins. '
          'Solid uniform pure green #00FF00 background, no floor, no cast shadow, no scenery, no camera motion, no zoom. '
          'Preserve the reference character identity, colors, texture, anatomy and exact limb count. Smooth chronological crisp game animation with no motion blur, no morphing, no extra creatures, no text. ')

def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + '.part')
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    tmp.replace(path)

def stills():
    for name, (label, design, walk, attack) in SPECS.items():
        folder = OUT / name
        folder.mkdir(parents=True, exist_ok=True)
        for state, motion in [('walk', walk), ('attack', attack)]:
            tail = ('Perform at least three evenly paced COMPLETE locomotion cycles. In-place motion, no drifting.' if state == 'walk' else
                    'Start by holding the ready stance for 0.6 seconds, perform this attack exactly ONCE during seconds 0.6 to 2.2, recover fully by 2.6 seconds, hold the original ready stance until the end. No second strike.')
            prompt_file = folder / f'{state}-prompt.txt'
            if not prompt_file.exists():
                prompt_file.write_text(COMMON + motion + ' ' + tail, encoding='utf-8')
        if name == 'shadow_beast':
            if not (folder/'input-green.png').exists():
                shutil.copy2(ROOT/'art_source/generated/monster_video_ark/shadow_beast/frames/raw/frame-0047.png', folder/'input-green.png')
            continue
        if (folder/'input-green.png').exists():
            continue
        prompt = ('One single finished game creature sprite, high definition painterly dark fantasy botanical storybook style matching the attached creature reference. '
                  'Three-quarter elevated side view facing RIGHT, full body, neutral ready stance, anatomically credible joints. '+design+
                  ' Large subject occupies 65 percent of image width and 55 percent of image height, centered, all appendages have generous empty margins. '
                  'Entire background solid pure green #00FF00, no floor or shadows, no scenery, no text, no panels or sprite sheet, no blur. No green reflections on creature.')
        (folder/'image-prompt.txt').write_text(prompt, encoding='utf-8')
    jobs = [n for n in SPECS if not (OUT/n/'input-green.png').exists()]
    def image(name):
        folder = OUT/name
        ref = ROOT/'assets/enemies/ART_ENEMY_ErosionBug_Move.png' if name == 'erosion_bug' else ROOT/'assets/enemies/ART_ENEMY_ShadowBeast_Move.png'
        args = [str(PYTHON), str(ROOT/'aiskill/mm-tools/sprite_gen_gateway.py'), '--sprite-gen-root', str(SKILL), '--api-base', 'https://newapi.oairegbox.cc/', '--',
                'gen', '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'high', '--aspect-ratio', '16:9', '--prompt-file', str(folder/'image-prompt.txt'),
                '--ref', str(ref), '--out', str(folder/'input-green.png'), '--report', str(folder/'image.report.json')]
        result = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace')
        (folder/'image.log').write_text(result.stdout+result.stderr, encoding='utf-8')
        print(name, 'still ready' if result.returncode == 0 else 'still FAILED; see image.log', flush=True)
        return result.returncode == 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        if not all(pool.map(image, jobs)): raise SystemExit('Image stage incomplete')

def request(method, url, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method,
          headers={'Authorization':'Bearer '+os.environ['ARK_API_KEY'], 'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # API errors have no credentials; never print successful response URLs.
        raise RuntimeError(f'HTTP {error.code}: {error.read().decode()[:700]}') from None

def generate(name, state):
    folder = OUT/name
    target = folder/f'{state}.mp4'
    task_file = folder/f'{state}.task.json'
    if target.exists():
        print(name, state, 'existing video', flush=True); return True
    if task_file.exists():
        task_id = json.loads(task_file.read_text(encoding='utf-8'))['id']
    else:
        reference = folder/f'{state}-canvas.png'
        if not reference.exists():
            subprocess.run([str(PYTHON),str(RUNNER),'video-canvas','--still',str(folder/'input-green.png'),
                            '--out',str(reference),'--state',state,'--shape','wide','--headroom','0.18',
                            '--lead','0.20','--trail','0.15','--key','green'], check=True, stdout=subprocess.DEVNULL)
        image = base64.b64encode(reference.read_bytes()).decode()
        payload = {'model':MODEL,'content':[{'type':'text','text':(folder/f'{state}-prompt.txt').read_text(encoding='utf-8')},
                     {'type':'image_url','image_url':{'url':'data:image/png;base64,'+image},'role':'first_frame'}],
                   'generate_audio':False,'ratio':'16:9','duration':5 if state == 'walk' else 4,'watermark':False}
        # Persist intent before POST; do not automatically retry an ambiguous creation.
        save(folder/f'{state}.intent.json', {'model':MODEL,'request_id':str(uuid.uuid4()),'duration':payload['duration']})
        result = request('POST', API, payload)
        task_id = result['id']
        save(task_file, {'id':task_id,'model':MODEL})
        print(name, state, 'submitted', task_id, flush=True)
    for attempt in range(90):
        result = request('GET', API+'/'+task_id)
        status = result.get('status')
        save(folder/f'{state}.status.json', {k:v for k,v in result.items() if k != 'content'})
        if status == 'succeeded':
            url = result['content']['video_url']
            with urllib.request.urlopen(url, timeout=120) as response:
                data = response.read()
            if b'ftyp' not in data[:32]: raise RuntimeError('Video is not verified MP4')
            target.with_suffix('.mp4.part').write_bytes(data)
            target.with_suffix('.mp4.part').replace(target)
            print(name, state, 'downloaded', flush=True); return True
        if status in ('failed','expired','cancelled'):
            print(name, state, 'FAILED', result.get('error'), flush=True); return False
        if attempt % 4 == 0: print(name, state, status, flush=True)
        time.sleep(15)
    print(name, state, 'pending; rerun to resume', flush=True)
    return False

def videos(names):
    jobs = [(n,s) for n in names for s in ('walk','attack') if not (n == 'shadow_beast' and s == 'walk')]
    def run(job):
        try: return generate(*job)
        except Exception as error:
            print(*job, str(error), flush=True); return False
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        if not all(pool.map(run, jobs)): raise SystemExit('Some video tasks incomplete')

def process(name, state):
    folder = OUT/name
    frames = folder/f'{state}-frames'
    loop = folder/f'{state}-loop'
    report_file = loop/f'{state}.loop.report.json'
    if report_file.exists() and json.loads(report_file.read_text(encoding='utf-8')).get('status') == 'passed':
        print(name,state,'existing verified loop',flush=True); return True
    if not (frames/'frames.report.json').exists():
        reference = folder/f'{state}-canvas.png'
        if not reference.exists(): reference = folder/'input-green.png'
        args = ['video-frames','--clip',str(folder/f'{state}.mp4'),'--out-dir',str(frames),'--key','green','--spill','auto','--reference',str(reference),'--decontam','auto']
        result = subprocess.run([str(PYTHON),str(RUNNER),*args], capture_output=True, text=True, encoding='utf-8', errors='replace')
        (folder/f'{state}-frames.log').write_text(result.stdout+result.stderr, encoding='utf-8')
        if result.returncode: print(name,state,'KEY FAILED',flush=True); return False
    info = json.loads((frames/'frames.report.json').read_text(encoding='utf-8'))
    fps = info['fps']
    profile = 'flight' if name == 'spore_moth' and state == 'walk' else state
    anchor = 'body' if profile == 'flight' else 'motion-auto' if state == 'walk' else 'none'
    args = ['video-loop','--frames-dir',str(frames/'keyed'),'--out-dir',str(loop),'--fps',str(fps),'--state',profile,
            '--cycle','periodic' if profile == 'flight' else 'auto' if state == 'walk' else 'one-shot','--anchor',anchor,
            '--body-height','123','--strip-height','240','--gif-fps',str(fps),'--name',state]
    if state == 'walk' and name in ('erosion_bug','spore_moth','shell_scarab'):
        # Source inspection shows 1.7–2.1 s leg/wing cycles, beyond the default 1.6 s.
        # Keep the unchanged periodicity and seam gates; observe at least two cycles.
        args += ['--min-len','12','--max-len','60']
    result = subprocess.run([str(PYTHON),str(RUNNER),*args], capture_output=True, text=True, encoding='utf-8', errors='replace')
    (folder/f'{state}-loop.log').write_text(result.stdout+result.stderr, encoding='utf-8')
    print(name,state,'LOOP READY' if not result.returncode else 'LOOP FAILED', flush=True)
    return result.returncode == 0

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['stills','videos','process'])
    parser.add_argument('--names', nargs='+', default=list(SPECS))
    args = parser.parse_args()
    if args.stage == 'stills': stills()
    elif args.stage == 'videos': videos(args.names)
    else:
        jobs = [(n,s) for n in args.names for s in ('walk','attack') if not (n == 'shadow_beast' and s == 'walk')]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            if not all(pool.map(lambda job: process(*job), jobs)): raise SystemExit('Some processing tasks incomplete')
