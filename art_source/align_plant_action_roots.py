"""Record one fixed root alignment per action without modifying any video frames."""
import json
from plant_video_ark import ROOT, root_center, save
from PIL import Image

for folder in (ROOT / 'assets/plants/animations').iterdir():
    path = folder / 'manifest.json'
    manifest = json.loads(path.read_text())
    idle = root_center(Image.open(folder / 'idle-000.png'))
    for state, spec in manifest['states'].items():
        endpoint = spec['frames'] - 1 if state == 'revive' else 0
        pose = Image.open(folder / f'{state}-{endpoint:03d}.png')
        spec['draw_offset'] = [round(idle - root_center(pose), 2), 0]
        spec['canvas'] = list(pose.size)
    save(path, manifest)
print('PLANT_ROOT_ALIGNMENT_PASS species=15')
