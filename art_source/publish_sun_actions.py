"""Merge reviewed native-rate actions into the Sun Devourer atlas manifest."""
import json
import publish_root_boss_redesign as p
p.RUN = p.ROOT / 'art_source/generated/sun_boss_redesign_20261009/ark-new-animations'
dest = p.ROOT / 'assets/enemies/animations/sun_devourer'
manifest = json.loads((dest / 'atlas_manifest.json').read_text())
for state in ['attack', 'summon', 'laser_charge']:
    images, info, selection, seam = p.load(state, state)
    images, ground = p.cells([p.despill(im) for im in images])
    p.contact(state, images)
    manifest['states'][state] = {'fps': info['fps'], 'loop': False, 'frames': len(images),
        'ground_y': ground, 'width': 640, 'height': 480, 'regions': p.atlas(dest, state, images)}
    print(state, len(images), 'frames published', flush=True)
p.write_json(dest / 'atlas_manifest.json', manifest)
p.write_json(dest / 'manifest.json', {'characterId': 'sun_devourer', 'animation': {'rows': manifest['states']}, 'runtime': manifest['runtime']})
