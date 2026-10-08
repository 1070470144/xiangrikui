"""Resumable Seedance clips and canonical sprite-gen keyed frames."""
import base64
import concurrent.futures
import json
import os
import subprocess
import time
import urllib.request
import sys
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'aiskill/mm-tools'))
from seedance_weather_video import request, BASE, MODEL
OUT = ROOT / 'art_source/generated/sun_arrow_attack'
PYTHON = Path.home() / '.codex/skills/sprite-gen/.venv/Scripts/python.exe'
os.environ['PATH'] = str(next((ROOT.parent/'tools/video').glob('ffmpeg-*/bin'))) + os.pathsep + os.environ.get('PATH', '')


def generate(name):
    folder = OUT / ('attack_v3' if name == 'attack' else 'impact_v2' if name == 'impact' else name)
    folder.mkdir(parents=True, exist_ok=True)
    ref = folder / 'reference.png'
    if not ref.exists():
        if name == 'attack':
            source = ROOT / 'art_source/generated/mother_motion_v2/sun_arrow/reference-magenta.png'
            Image.open(source).save(ref)
        else:
            prompt = ('Single isolated golden sunlight arrow pointing right, sharp spearhead, warm amber core, short tapering flame tail, realistic fantasy game effect' if name == 'flight' else
                      'Single isolated small golden sunlight impact burst, sharp sparks and warm amber flame petals, realistic fantasy game effect')
            if name == 'impact' and (OUT/'impact/reference.png').exists():
	            im = Image.open(OUT/'impact/reference.png').convert('RGB')
	            im.thumbnail((240,240))
	            base = Image.new('RGB',(1024,1024),(255,0,255))
	            base.paste(im,((1024-im.width)//2,(1024-im.height)//2))
	            base.save(ref)
            else:
                subprocess.run([str(PYTHON), '-m', 'sprite_gen.cli', 'gen', '--provider', 'mm-api', '--model', 'gpt-image-2', '--prompt', prompt + '. Solid uniform pure magenta #FF00FF background, no shadow, no text. Centered with large empty margins.', '--out', str(ref)], check=True)
    canvas = folder / 'canvas.png'
    if not canvas.exists():
        subprocess.run([str(PYTHON), '-m', 'sprite_gen.cli', 'video-canvas', '--still', str(ref), '--out', str(canvas), '--state', 'attack' if name == 'attack' else 'projectile', '--shape', 'square', '--key', 'magenta'], check=True)
    task = folder / 'task.json'
    video = folder / 'clip.mp4'
    if not video.exists():
        if not task.exists():
            marker = folder / 'submitted'
            if marker.exists():
                raise RuntimeError('Submission attempted without task receipt; inspect before retry')
            action = {'attack': 'One physical attack animation: seconds 0 to 0.6 flower crown bends backward 8 degrees with a visibly flexible upper stem, seconds 0.6 to 0.9 crown springs forward, seconds 0.9 to 2 crown and leaves settle back to the exact starting pose, seconds 2 to 4 hold still. No glow, no flashes, no particles, no projectiles, no rays or effects at all. Roots remain perfectly fixed in the exact pixels. Preserve exact anatomy, materials and scale.',
                      'flight': 'Keep this exact golden arrow stationary in the center pointing right throughout. Animate flickering amber core and short streaming tail continuously. Never translate the arrow or change its size.',
                      'impact': 'One tiny compact golden impact burst, constrained to the central 25 percent of the canvas: brief sparks then fade completely within the first second. Remaining seconds blank magenta. No repeating bursts, no long rays, no purple tint, do not expand beyond the central 25 percent.'}[name]
            prompt = action + ' Fixed camera, pure uniform magenta #FF00FF background throughout, no ground, shadow, scenery, text or audio. Keep all effect pixels well inside frame.'
            (folder / 'prompt.txt').write_text(prompt, encoding='utf-8')
            marker.write_text('One authorized submission; resume receipt.\n')
            data = 'data:image/png;base64,' + base64.b64encode(canvas.read_bytes()).decode()
            reply = request('POST', BASE, {'model': MODEL, 'content': [{'type': 'text', 'text': prompt}, {'type': 'image_url', 'image_url': {'url': data}, 'role': 'first_frame'}], 'duration': 4, 'ratio': '1:1', 'resolution': '720p', 'generate_audio': False, 'watermark': False})
            task.write_text(json.dumps({'id': reply['id'], 'model': MODEL}))
            print(name + ': submitted', flush=True)
        task_id = json.loads(task.read_text())['id']
        for _ in range(180):
            result = request('GET', BASE + '/' + task_id)
            status = result.get('status')
            (folder / 'status.json').write_text(json.dumps({'status': status, 'error': result.get('error', {}).get('code') if result.get('error') else None}))
            if status == 'succeeded':
                with urllib.request.urlopen(result['content']['video_url'], timeout=120) as response:
                    data = response.read()
                if b'ftyp' not in data[:32]:
                    raise RuntimeError('Invalid MP4')
                video.write_bytes(data)
                break
            if status in ['failed', 'expired', 'cancelled']:
                raise RuntimeError(name + ': video ' + status)
            time.sleep(5)
        else:
            raise RuntimeError('Still pending; resume existing task')
    subprocess.run([str(PYTHON), str(ROOT.parent/'tools/video/sprite_video.py'), 'video-frames', '--clip', str(video), '--out-dir', str(folder / 'frames'), '--key', 'magenta', '--allow-edge-contact'], check=True)
    print(name + ': extracted', flush=True)


if __name__ == '__main__':
    import sys
    sys.path.insert(0, str(ROOT / 'aiskill/mm-tools'))
    lines = Path('C:/Users/mengmenglv/Desktop/秘钥.txt').read_text(encoding='utf-8-sig').splitlines()
    keys = [line.split(maxsplit=1)[1].strip() for line in lines if line.strip().startswith('秘钥 ')]
    if len(keys) != 2:
        raise SystemExit('Expected image and video credentials')
    os.environ['SPRITE_GEN_MM_API_KEY'] = keys[0]
    os.environ['SPRITE_GEN_MM_API_BASE'] = 'https://newapi.oairegbox.cc'
    os.environ['ARK_API_KEY'] = keys[1]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for result in pool.map(generate, sys.argv[1:] or ['attack', 'flight', 'impact']):
            pass
