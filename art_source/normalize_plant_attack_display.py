"""Match the actual attack ready pose to idle without resizing video frames."""
import json
from PIL import Image
from plant_video_ark import ROOT, attack_display_alignment, save

reports = []
for folder in sorted((ROOT / 'assets/plants/animations').iterdir()):
    path = folder / 'manifest.json'
    manifest = json.loads(path.read_text())
    idle = Image.open(folder / 'idle-000.png')
    attack = Image.open(folder / 'attack-000.png')
    scale, offset = attack_display_alignment(idle, attack)
    manifest['states']['attack'].update(display_scale=scale, draw_offset=offset)
    for state in ('death', 'revive'):
        manifest['states'][state].pop('display_scale', None)
    idle_box = idle.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    attack_box = attack.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    size_error = abs((attack_box[3] - attack_box[1]) * scale - (idle_box[3] - idle_box[1]))
    root_error = abs((attack_box[3] - attack.height / 2 + offset[1]) * scale - (idle_box[3] - idle.height / 2))
    assert size_error < 0.01 and root_error < 0.01, folder.name
    save(path, manifest)
    reports.append({'species': folder.name, 'display_scale': scale, 'size_error': size_error, 'root_error': root_error})
save(ROOT / 'tmp/plant-attack-size-review.json', reports)
print('PLANT_ATTACK_SIZE_PASS species=15 size_and_root_error<0.01px')
