"""Single resumable gateway video trial; credentials never leave process memory."""
import json
import base64
import re
import time
import urllib.request
import urllib.error
from pathlib import Path
import root_boss_redesign as pipeline

class Response:
    def __init__(self, code, content):
        self.status_code, self.content = code, content
        self.ok = 200 <= code < 300
        self.text = content.decode('utf-8', errors='replace')
    def json(self):
        return json.loads(self.content)

def http(method, url, headers, body=None):
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return Response(response.status, response.read())
    except urllib.error.HTTPError as error:
        return Response(error.code, error.read())

OUT = pipeline.ROOT / 'art_source/generated/sun_boss_redesign_20261009/gateway-idle-reference-v2'
BASE = 'https://newapi.oairegbox.cc/v1/videos'

def main():
    data = Path('C:/Users/mengmenglv/Desktop/秘钥.txt').read_text(encoding='utf-8-sig')
    keys = re.findall(r'\bsk-[A-Za-z0-9_-]+', data)
    if not keys:
        raise RuntimeError('No gateway credential found')
    key = keys[-1]
    headers = {'Authorization': 'Bearer ' + key}
    OUT.mkdir(parents=True, exist_ok=True)
    task_file = OUT / 'task.json'
    if (OUT / 'clip.mp4').exists():
        print('Existing verified video; no submission')
        return
    if task_file.exists():
        task_id = json.loads(task_file.read_text())['id']
    else:
        rejection = OUT / 'rejection.json'
        known_rejection = rejection.exists() and json.loads(rejection.read_text()).get('http') == 400
        if (OUT / 'intent.json').exists() and not known_rejection:
            raise RuntimeError('Existing submission intent: inspect before repeating')
        canvas = OUT / 'canvas.png'
        pipeline.engine('video-canvas', '--still', OUT.parent / 'original.png', '--out', canvas,
                        '--state', 'idle', '--shape', 'wide', '--key', 'green')
        prompt = ('Locked orthographic camera, preserve this colossal botanical eclipse deity and black solar halo. '
                  'Two arms, two root legs. Gentle stationary breathing and gold-red chest core pulses. '
                  'Complete looping idle motion, matching first and last pose, fixed feet. '
                  'Entire body visible, no zoom, pure green background, no floor or shadows.')
        pipeline.save(OUT / 'intent.json', {'status': 'submission_started', 'model': 'seedance-2-0-mini'})
        reference = 'data:image/png;base64,' + base64.b64encode(canvas.read_bytes()).decode()
        payload = {'model': 'seedance-2-0-mini', 'prompt': prompt, 'seconds': '5', 'size': '1280x720',
                   'input_reference': reference}
        response = http('POST', BASE, {**headers, 'Content-Type': 'application/json'}, json.dumps(payload).encode())
        if not response.ok:
            safe = response.text.replace(key, '[REDACTED]')[:1200]
            pipeline.save(OUT / 'rejection.json', {'http': response.status_code, 'error': safe})
            print('Submission rejected:', response.status_code, safe)
            return
        result = response.json()
        task_id = result.get('id') or result.get('task_id')
        if not task_id:
            print('Response did not contain task ID; no repeat submission')
            return
        pipeline.save(task_file, {'id': task_id, 'model': 'seedance-2-0-mini'})
        print('Submitted task:', task_id, flush=True)
    for _ in range(100):
        response = http('GET', BASE + '/' + task_id, headers)
        if not response.ok:
            print('Status query HTTP', response.status_code)
            return
        result = response.json()
        status = result.get('status')
        pipeline.save(OUT / 'status.json', {'id': task_id, 'status': status, 'progress': result.get('progress')})
        print('Video status:', status, flush=True)
        if status in ('completed', 'succeeded'):
            download = http('GET', BASE + '/' + task_id + '/content', headers)
            if not download.ok or b'ftyp' not in download.content[:32]:
                print('Video content unavailable or invalid; task retained')
                return
            (OUT / 'clip.mp4').write_bytes(download.content)
            print('Verified MP4 saved:', OUT / 'clip.mp4')
            return
        if status in ('failed', 'cancelled', 'expired'):
            print('Generation ended:', status)
            return
        time.sleep(15)

if __name__ == '__main__':
    main()
