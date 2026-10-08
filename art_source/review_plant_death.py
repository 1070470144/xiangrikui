"""Contact sheet of published video frames; does not modify animation assets."""
import json
import hashlib
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
folders = sorted((ROOT / 'assets/plants/animations').iterdir())
sheet = Image.new('RGB', (800, len(folders) * 190), '#28352e')
draw = ImageDraw.Draw(sheet)
reports = []
for row, folder in enumerate(folders):
    manifest = json.loads((folder / 'manifest.json').read_text())
    draw.text((10, row * 190 + 5), folder.name, fill='white')
    spec = manifest['states'].get('death')
    if not spec:
        continue
    count = spec['frames']
    arrays = [np.asarray(Image.open(folder / f'death-{i:03d}.png').convert('RGBA')) for i in range(count)]
    assert not spec['loop'] and count >= 24, folder.name
    assert len({hashlib.sha256(a.tobytes()).hexdigest() for a in arrays}) > 8, folder.name
    assert all(a.shape == (160, 160, 4) for a in arrays), folder.name
    assert all(np.all(a[a[:, :, 3] == 0, :3] == 0) for a in arrays), folder.name
    boxes = [Image.fromarray(a).getchannel('A').getbbox() for a in arrays]
    assert all(b and b[0] > 0 and b[1] > 0 and b[2] < 160 and b[3] <= 139 for b in boxes), folder.name
    idle_box = Image.open(folder / 'idle-000.png').getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    death_box = Image.fromarray(arrays[0]).getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    for axis in (0, 1):
        ratio = (death_box[axis + 2] - death_box[axis]) / (idle_box[axis + 2] - idle_box[axis])
        assert 0.75 <= ratio <= 1.33, (folder.name, 'death first-frame size mismatch', ratio)
    reports.append({'species': folder.name, 'frames': count, 'loop': False, 'status': 'passed'})
    paths = [folder / 'idle-000.png'] + [folder / f'death-{i:03d}.png' for i in (0, count // 3, count * 2 // 3, count - 1)]
    for col, path in enumerate(paths):
        frame = Image.open(path).convert('RGBA')
        sheet.paste(frame, (col * 160, row * 190 + 25), frame)
target = ROOT / 'tmp/plant-death-review.png'
target.parent.mkdir(exist_ok=True)
sheet.save(target)
(target.with_suffix('.json')).write_text(json.dumps(reports, indent=2), encoding='utf-8')
assert len(reports) == 15, f'Only {len(reports)}/15 death animations published'
print(target)
