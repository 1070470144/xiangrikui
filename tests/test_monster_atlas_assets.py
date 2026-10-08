"""Read-only lossless monster atlas and hot-path contract checks."""
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
frames = 0
pages = set()
for manifest_path in sorted((ROOT / 'assets/enemies/animations').glob('*/atlas_manifest.json')):
    folder = manifest_path.parent
    packed = json.loads(manifest_path.read_text(encoding='utf-8'))
    source = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
    assert packed['runtime'] == source.get('runtime', {})
    for state, spec in packed['states'].items():
        original = source['animation']['rows'][state]
        assert {k: v for k, v in spec.items() if k != 'regions'} == original
        assert len(spec['regions']) == original['frames']
        images = {}
        for i, record in enumerate(spec['regions']):
            path = folder / record['page']
            if path not in images:
                images[path] = Image.open(path).convert('RGBA')
            page = images[path]
            assert max(page.size) <= 2048
            x, y, w, h = record['region']
            assert x >= 0 and y >= 0 and x + w <= page.width and y + h <= page.height
            with Image.open(folder / f'{state}-frame-{i}.png') as image:
                assert (w, h) == image.size
                assert page.crop((x, y, x + w, y + h)).tobytes() == image.convert('RGBA').tobytes()
            frames += 1
            pages.add(path)
        for image in images.values(): image.close()
for name in ('enemy.gd', 'monster_animation_library.gd', 'monster_attack_fx.gd', 'effects.gd'):
    text = (ROOT / 'scripts' / name).read_text(encoding='utf-8')
    assert not re.search(r'(?<![\w])load\(', text), name
    assert 'ArtLibrary.load_texture(' not in text, name
game = (ROOT / 'scripts/game.gd').read_text(encoding='utf-8')
assert 'spawn_queue.pop_front()' not in game
assert 'query_enemies_in_radius' in game
shadows = (ROOT / 'scripts/ground_contact_shadows.gd').read_text(encoding='utf-8')
assert 'draw_circle' not in shadows and 'draw_texture_rect' in shadows
assert frames > 0
print(f'PASS: {frames} exact monster frames, {len(pages)} bounded pages; cache-only resources, cursor queue, textured shadows')
