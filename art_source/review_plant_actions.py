"""Review published frames and verify provenance of the newly generated actions."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from plant_video_ark import root_center

ROOT = Path(__file__).resolve().parents[1]
folders = sorted((ROOT / 'assets/plants/animations').iterdir())
reports = []
previews = []
for state in ('attack', 'death', 'revive'):
    sheet = Image.new('RGB', (1600, len(folders) * 345), '#28352e')
    draw = ImageDraw.Draw(sheet)
    animations = []
    for row, folder in enumerate(folders):
        manifest = json.loads((folder / 'manifest.json').read_text())
        spec = manifest['states'][state]
        assert not spec['loop'] and spec['frames'] >= 24, (folder.name, state)
        if state != 'death':
            assert 'video_v' in spec['source'] and spec['source'].endswith('.mp4'), spec['source']
        assert (ROOT / spec['source']).is_file(), spec['source']
        report = json.loads((ROOT / spec['report']).read_text())
        assert report['status'] == 'passed', spec['report']
        frames = [Image.open(folder / f'{state}-{i:03d}.png').convert('RGBA') for i in range(spec['frames'])]
        unique = len({hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames})
        assert unique > 8, (folder.name, state, unique)
        for frame in frames:
            data = np.asarray(frame)
            assert frame.size in ((160, 160), (320, 320))
            assert np.all(data[data[:, :, 3] == 0, :3] == 0)
            box = frame.getchannel('A').getbbox()
            assert box and box[0] > 0 and box[1] > 0 and box[2] < frame.width and box[3] <= frame.height // 2 + 59, (folder.name, state, box)
        alive = Image.open(folder / 'idle-000.png').convert('RGBA')
        alive_box = alive.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
        endpoint = frames[-1] if state == 'revive' else frames[0]
        action_box = endpoint.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
        ratios = [(action_box[i + 2] - action_box[i]) / (alive_box[i + 2] - alive_box[i]) for i in (0, 1)]
        assert all(0.7 <= ratio <= 1.4 for ratio in ratios), (folder.name, state, 'endpoint size', ratios)
        offset = spec.get('draw_offset', [0, 0])
        assert abs(root_center(endpoint) + offset[0] - root_center(alive)) < 1.0, (folder.name, state, 'root alignment')
        draw.text((8, row * 345 + 3), folder.name + ' / ' + state, fill='white')
        poses = [alive] + [frames[i] for i in (0, len(frames) // 3, len(frames) * 2 // 3, len(frames) - 1)]
        for col, frame in enumerate(poses):
            shift = 0 if col == 0 else round(offset[0])
            sheet.paste(frame, (col * 320 + (320 - frame.width) // 2 + shift, row * 345 + 23 + (320 - frame.height) // 2), frame)
        animations.append((frames, round(offset[0])))
        reports.append({'species': folder.name, 'state': state, 'frames': len(frames), 'unique': unique, 'endpoint_size_ratios': ratios, 'source': spec['source'], 'status': 'passed'})
    sheet.save(ROOT / f'tmp/plant-{state}-review.png')
    for tick in range(64):
        page = Image.new('RGB', (1600, 1050), '#28352e')
        label = ImageDraw.Draw(page)
        for index, (frames, shift) in enumerate(animations):
            frame = frames[round(tick * (len(frames) - 1) / 63)]
            x, y = (index % 5) * 320, (index // 5) * 350
            page.paste(frame, (x + (320 - frame.width) // 2 + shift, y + (320 - frame.height) // 2), frame)
            label.text((x + 5, y + 325), folders[index].name + ' / ' + state, fill='white')
        page.thumbnail((960, 630), Image.Resampling.LANCZOS)
        previews.append(page)
    previews.extend([previews[-1]] * 8)
assert len(reports) == 45
(ROOT / 'tmp/plant-actions-review.json').write_text(json.dumps(reports, indent=2), encoding='utf-8')
previews[0].save(ROOT / 'tmp/plant-actions-preview.gif', save_all=True, append_images=previews[1:], duration=35, loop=0)
print('PLANT_ACTIONS_QA_PASS states=45')
