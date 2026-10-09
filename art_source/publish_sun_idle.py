"""Publish the keyed Sun Devourer idle with the established boss atlas pipeline."""
import json
from pathlib import Path
import publish_root_boss_redesign as publisher

publisher.RUN = publisher.ROOT / 'art_source/generated/sun_boss_redesign_20261009/ark-new-trial'
images, info, selection, seam = publisher.load('idle_preview', 'idle')
images = images + images[-2:0:-1]
selection = selection + selection[-2:0:-1]
images = [publisher.despill(image) for image in images]
images, ground = publisher.cells(images)
publisher.contact('idle', images)
dest = publisher.ROOT / 'assets/enemies/animations/sun_devourer'
dest.mkdir(parents=True, exist_ok=True)
root = json.loads((dest.parent / 'root_crown_colossus/atlas_manifest.json').read_text())
scale = float(root['runtime']['scale']) * 2.0
spec = {'fps': info['fps'], 'loop': True, 'frames': len(images), 'ground_y': ground,
        'width': 640, 'height': 480, 'regions': publisher.atlas(dest, 'idle', images)}
manifest = {'enemy_id': 'sun_devourer', 'visual_profile': 'idle_only',
            'runtime': {'scale': scale, 'ground_offset': 8.0}, 'states': {'idle': spec}}
publisher.write_json(dest / 'atlas_manifest.json', manifest)
publisher.write_json(dest / 'manifest.json', {'characterId': 'sun_devourer',
    'animation': {'rows': manifest['states']}, 'runtime': manifest['runtime']})
publisher.write_json(dest / 'review.json', {'source': 'ark-new-trial/idle/clip.mp4',
    'source_indices': selection, 'playback': 'ping_pong', 'seam_ratio': seam, 'edge_contacts': [], 'scale_ratio_to_root': 2.0})
print('SUN_IDLE_PUBLISHED', len(images), 'frames, scale', scale, 'seam', seam)
