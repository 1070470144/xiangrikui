"""New root boss generation run. Credentials stay in child process environment."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import base64
import concurrent.futures
import time
import urllib.request
from monster_video_batch import ROOT, PYTHON, SKILL, RUNNER, request, save, API, MODEL

OUT = ROOT / 'art_source/generated/root_boss_redesign_20261009'
DESIGN = ('A completely new dark botanical fantasy boss, massive ancient ROOT CROWN COLOSSUS. '
          'Exactly two broad grounded root feet and two powerful asymmetrical root arms, '
          'a twisted dead branch crown, cracked charcoal brown bark armor with layered basalt, '
          'bright amber molten heart visible inside an open chest cavity. Heavy intimidating '
          'silhouette, sculptural photorealistic bark and mineral detail, warm ivory broken wood edges. '
          'Elevated orthographic three quarter game view facing RIGHT. Whole body occupies 60 percent '
          'of frame height, feet visible, generous empty margins. Single coherent character, neutral '
          'ready pose. Pure solid green #00FF00 background, no floor, no shadows, no particles, '
          'no scenery, no text, no green material or reflections. Not a sprite sheet.')

MOTIONS = {
    'idle': 'Repeat three gentle breathing cycles, root shoulders slowly rising and settling, amber heart pulsing, feet completely planted.',
    'walk': 'Heavy slow walking IN PLACE, alternating TWO root feet with clear lift and grounded weight transfer, same center position. Perform three full step cycles.',
    'attack': 'Exactly ONE short forward root fist punch. Hold ready 0.5 seconds, wind up then punch at 1.2 seconds, recoil, fully recover ready pose by 3 seconds and hold.',
    'slam': 'Exactly ONE exaggerated TWO ARM ground slam. Clearly lift both heavy arms far above shoulder height during seconds 0 to 1.1. Both fists hit ground forcefully at exactly 1.2 seconds. Deep knee compression and shoulder recoil. Recover neutral ready pose by 3.8 seconds, hold to end. No second strike.',
    'summon': 'Exactly ONE summoning gesture: spread root arms wide, lift open hands at 1 second, chest glows amber, lower arms and recover neutral ready pose by 3.5 seconds.',
    'exposed': 'Loop wounded core exposure breathing. Chest armor opens slightly revealing bright amber heart, shoulders stagger subtly, hands stay lowered. Repeat three full pulses.',
    'enraged': 'Loop aggressive furious breathing, shoulders braced, amber fissures glow strongly through bark armor. Three full pulses. No movement from center.',
    'death': 'Exactly ONE death collapse. Hold alive stance 0.3 seconds, heart extinguishes, knees buckle and massive body collapses into a grounded pile of bark and rock by 3 seconds, stays completely dead through end. No resurrection.',
    'spawn': 'Exactly ONE emergence from a compressed crouch. Rise slowly on two root feet into full upright ready stance by 2 seconds and hold until end.',
}
FX = {
    'impact': 'An amber and brown botanical ground impact: radial roots and broken bark shards burst outward with a thin golden shock ring, then settle and disappear.',
    'root_lock': 'A circular tangle of thick brown thorn roots rapidly grows upward from the ground, coils around an empty center, holds briefly, then retracts into ground.',
    'summon_fx': 'A circular brown root summoning portal with amber sap veins, root tendrils rise and part around an empty central opening, then retract and disappear.',
    'exposed_fx': 'A small isolated amber magical heart aura, warm sparks and concentric soft golden pulse rings around an empty center, rhythmic complete pulses.',
    'enraged_fx': 'An isolated fierce orange amber flame aura with jagged sap lightning arcs surrounding an empty center, three pulsing complete cycles.',
}

def engine(*args):
    result = subprocess.run([str(PYTHON), str(RUNNER), *map(str,args)], capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace')[-1200:])

def effects():
    def generate(state):
        folder = OUT/state
        folder.mkdir(parents=True, exist_ok=True)
        target = folder/'original.png'
        if target.exists(): return
        if (folder/'image.intent.json').exists(): raise RuntimeError(state+': image submission already recorded')
        prompt = ('Single isolated dark botanical fantasy game visual effect, elevated orthographic view, '+FX[state]+
                  ' A single coherent centered effect, compact and fully inside generous margins. Pure solid green #00FF00 background, no floor, no scenery, no character, no text, no green reflection. Brown roots, amber gold magic only. One initial visible effect pose for animation, not a sprite sheet.')
        (folder/'image-prompt.txt').write_text(prompt,encoding='utf-8')
        save(folder/'image.intent.json',{'status':'submission_started','model':'gpt-image-2'})
        args = [str(PYTHON),'-m','sprite_gen.cli','gen','--provider','mm-api','--model','gpt-image-2','--prompt-file',str(folder/'image-prompt.txt'),'--out',str(target),'--report',str(folder/'image.report.json')]
        result = subprocess.run(args,capture_output=True)
        output = (result.stdout+result.stderr).decode('utf-8',errors='replace')
        for key in ['OPENAI_API_KEY','ARK_API_KEY']: output = output.replace(os.environ[key],'[REDACTED]')
        (folder/'image.log').write_text(output,encoding='utf-8')
        if result.returncode: raise RuntimeError(state+': still failed; see sanitized log')
        print(state,'effect still ready',flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(generate,FX))

def videos(effect=False, revision=False, repair=False, centered=False, impact_only=False):
    if not (OUT/'original.png').exists():
        raise RuntimeError('Base drawing not ready')
    jobs = ['impact'] if impact_only else ['idle','walk','summon','spawn','exposed','enraged','impact','summon_fx','exposed_fx','enraged_fx'] if repair or centered else ['idle','walk','attack','slam'] if revision else list(FX if effect else MOTIONS)
    def generate(state):
        is_effect = state in FX
        folder = OUT/(state+'-v5' if impact_only else state+'-v4' if centered else state+'-v3' if repair else state+'-v2' if revision else state)
        folder.mkdir(parents=True, exist_ok=True)
        target = folder/'clip.mp4'
        if target.exists(): return True
        canvas = folder/'canvas.png'
        if not canvas.exists():
            source = OUT/state/'original.png' if is_effect else OUT/'original.png'
            if centered or impact_only:
                from PIL import Image
                engine('cutout', source, '--out', folder/'base-alpha.png', '--key', 'green')
                with Image.open(folder/'base-alpha.png') as alpha:
                    alpha = alpha.convert('RGBA'); box = alpha.getbbox(); subject = alpha.crop(box)
                    subject.thumbnail((160,120) if impact_only else (480,320),Image.Resampling.LANCZOS)
                    base = Image.new('RGB',(1280,720),(0,255,0))
                    base.paste(subject,((1280-subject.width)//2,(720-subject.height)//2),subject)
                    base.save(canvas)
                save(folder/'canvas-layout.json',{'canvas':[1280,720],'subject':list(subject.size),'placement':'centered','preparation':'sprite-gen cutout followed by centered input padding'})
            else:
                engine('video-canvas', '--still', source, '--out', canvas, '--state', 'attack', '--shape', 'wide', '--lead', '.75' if repair else '.67' if revision else '.28', '--key', 'green')
        task_file = folder/'task.json'
        if task_file.exists():
            task_id = json.loads(task_file.read_text())['id']
        else:
            if (folder/'intent.json').exists(): raise RuntimeError(state+': ambiguous task; no repeat POST')
            prompt = (('Locked elevated orthographic camera. Isolated game visual effect only, no character, no scenery. Entire effect stays inside frame. '+FX[state]+' Animate one complete appearance, expansion and disappearance by 4 seconds, end blank green. ') if is_effect else ('Locked elevated orthographic camera facing RIGHT. Preserve exact character identity, exactly TWO arms TWO legs and branch crown. Entire character remains inside frame. '
                      'Solid pure green #00FF00 background, NO floor, NO camera motion, NO shadow, NO particles, NO text, NO motion blur. '+MOTIONS[state])
                      )
            if is_effect: prompt += ' Solid pure green #00FF00 background at all times, no green effect colors, no camera movement.'
            if impact_only: prompt = ('Fixed 1280x720 green screen VFX sprite. A TINY compact brown root spike burst at the exact center. Start with the attached small root shape. Roots briefly extend outward by at most 20 pixels and retract completely by 2 seconds. Then pure green blank screen for 3 seconds. ABSOLUTELY NO light rings, NO glow wash, NO scene, NO ground, NO shadows, NO camera zoom, NO scale enlargement. Effect bounding box never exceeds 220x180 pixels. Background must remain exact pure green RGB 0,255,0 even next to the effect. Small amber sparks inside the tiny root shape only.')
            if revision or repair or centered: prompt += ' CRITICAL: keep the small reference scale and large green margins, never zoom or enlarge. Entire subject occupies at most 45 percent of frame height and width throughout. For breathing and walking, exactly THREE identical cycles, first and last pose exactly match. Keep the center and feet baseline completely fixed.'
            (folder/'prompt.txt').write_text(prompt, encoding='utf-8')
            payload = {'model':MODEL,'content':[{'type':'text','text':prompt},{'type':'image_url','image_url':{'url':'data:image/png;base64,'+base64.b64encode(canvas.read_bytes()).decode()},'role':'first_frame'}],
                       'generate_audio':False,'ratio':'16:9','duration':5,'watermark':False}
            if (repair or centered) and state in ['idle','walk','exposed','enraged']:
                payload['content'].append({'type':'image_url','image_url':{'url':'data:image/png;base64,'+base64.b64encode(canvas.read_bytes()).decode()},'role':'last_frame'})
            save(folder/'intent.json', {'status':'submission_started','model':MODEL})
            result = request('POST', API, payload)
            task_id = result['id']; save(task_file, {'id':task_id,'model':MODEL})
            print(state, 'submitted', task_id, flush=True)
        for attempt in range(100):
            result = request('GET', API+'/'+task_id)
            save(folder/'status.json', {k:v for k,v in result.items() if k!='content'})
            status = result.get('status')
            if status == 'succeeded':
                with urllib.request.urlopen(result['content']['video_url'], timeout=120) as response: data = response.read()
                if b'ftyp' not in data[:32]: raise RuntimeError('Invalid video')
                target.write_bytes(data); print(state,'downloaded',flush=True); return True
            if status in ['failed','expired','cancelled']: raise RuntimeError(state+': task '+status)
            if attempt % 4 == 0: print(state,status,flush=True)
            time.sleep(15)
        return False
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(generate,jobs))
    if not all(results): raise RuntimeError('Some saved tasks still pending; resume videos')

def effect_videos():
    videos(effect=True)

def revise_walk():
    videos(revision=True)

def repair():
    videos(repair=True)

def centered():
    videos(centered=True)

def repair_impact():
    videos(impact_only=True)

def process():
    for state in list(MOTIONS)+list(FX)+[s+'-v2' for s in ['idle','walk','attack','slam']]:
        folder = OUT/state
        if not (folder/'clip.mp4').exists(): continue
        if not (folder/'frames/frames.report.json').exists():
            try:
                engine('video-frames','--clip',folder/'clip.mp4','--out-dir',folder/'frames','--key','green')
            except RuntimeError as exc:
                (folder/'processing-error.txt').write_text(str(exc),encoding='utf-8')
                print(state,'framing failed; not published',flush=True)
                continue
        info = json.loads((folder/'frames/frames.report.json').read_text(encoding='utf-8'))
        if info.get('edge_contacts'):
            print(state,'edge contact review required; not published',flush=True)
            continue
        fps = info['fps']
        motion = state.removesuffix('-v2')
        try:
            engine('video-loop','--frames-dir',folder/'frames/keyed','--out-dir',folder/'loop','--fps',fps,
                   '--state','walk' if motion=='walk' else 'idle' if motion in ['idle','exposed','enraged'] else 'attack',
                   '--cycle','periodic' if motion in ['idle','walk','exposed','enraged'] else 'one-shot',
                   '--body-height',230,'--strip-height',380,'--name',state)
            print(state,'extraction and cycle ready',flush=True)
        except RuntimeError as exc:
            (folder/'processing-error.txt').write_text(str(exc),encoding='utf-8')
            print(state,'requires motion review; not published',flush=True)

def credentials():
    data = Path('C:/Users/mengmenglv/Desktop/秘钥.txt').read_text(encoding='utf-8-sig')
    image = re.search(r'\bsk-[A-Za-z0-9_-]+', data)
    video = re.search(r'\bark-[A-Za-z0-9_-]+', data)
    if not image or not video:
        raise RuntimeError('Required image/video credentials missing; no request submitted')
    os.environ['OPENAI_API_KEY'] = image.group(0)
    os.environ['ARK_API_KEY'] = video.group(0)
    os.environ['SPRITE_GEN_MM_API_KEY'] = image.group(0)
    os.environ['SPRITE_GEN_MM_API_BASE'] = 'https://newapi.oairegbox.cc'
    os.environ['PYTHONUTF8'] = '1'
    os.environ['PYTHONIOENCODING'] = 'utf-8'

def image():
    OUT.mkdir(parents=True, exist_ok=True)
    if (OUT/'original.png').exists():
        print('New original already saved; no repeat submission')
        return
    if (OUT/'image.intent.json').exists():
        log = (OUT/'image.log').read_text(encoding='utf-8') if (OUT/'image.log').exists() else ''
        if not any(reason in log for reason in ['sprite-gen root does not contain the OpenAI provider', 'WinError 10013']):
            raise RuntimeError('Previous submission recorded without output. Inspect before retrying.')
    (OUT/'image-prompt.txt').write_text(DESIGN, encoding='utf-8')
    (OUT/'image.intent.json').write_text(json.dumps({'status':'submission_started','model':'gpt-image-2'}))
    args = [str(PYTHON), '-m', 'sprite_gen.cli',
            'gen', '--provider', 'mm-api', '--model', 'gpt-image-2',
            '--prompt-file', str(OUT/'image-prompt.txt'),
            '--out', str(OUT/'original.png'), '--report', str(OUT/'image.report.json')]
    result = subprocess.run(args, capture_output=True)
    output = (result.stdout + result.stderr).decode('utf-8', errors='replace')
    for name in ['OPENAI_API_KEY','ARK_API_KEY']:
        output = output.replace(os.environ[name], '[REDACTED]')
    (OUT/'image.log').write_text(output, encoding='utf-8')
    print('Image generation', 'succeeded' if result.returncode == 0 else 'failed; see sanitized image.log')
    if result.returncode:
        raise SystemExit(result.returncode)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['image','videos','effects','effect_videos','revise_walk','repair','centered','repair_impact','process'])
    args = parser.parse_args()
    credentials()
    globals()[args.stage]()
