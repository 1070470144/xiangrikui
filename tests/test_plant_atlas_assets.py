"""Read-only atlas integrity and cache-only hot-path checks."""
import json
import re
from pathlib import Path
from PIL import Image

project = Path(__file__).resolve().parents[1]
count = 0
pages_count = 0
for folder in sorted((project / 'assets/plants/animations').iterdir()):
    if not (folder / 'manifest.json').exists():
        continue
    original = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
    atlas = json.loads((folder / 'atlas_manifest.json').read_text(encoding='utf-8'))
    assert original['states'].keys() == atlas['states'].keys()
    for state, spec in original['states'].items():
        packed = atlas['states'][state]
        for key, value in spec.items():
            assert packed[key] == value, (folder.name, state, key)
        assert len(packed['regions']) == spec['frames']
        pages = {}
        for name in packed['pages']:
            with Image.open(folder / name) as im:
                assert im.width <= 2048 and im.height <= 2048
                pages[name] = im.convert('RGBA')
            pages_count += 1
        for index, record in enumerate(packed['regions']):
            x, y, w, h = record['region']
            page = pages[record['page']]
            assert x >= 0 and y >= 0 and x + w <= page.width and y + h <= page.height
            with Image.open(folder / f'{state}-{index:03d}.png') as source:
                assert source.size == (w, h)
                assert source.convert('RGBA').tobytes() == page.crop((x, y, x + w, y + h)).tobytes()
            count += 1
for name in ['plant_animation_library.gd', 'plant_attack_fx.gd', 'plant.gd']:
    text = (project / 'scripts' / name).read_text(encoding='utf-8')
    assert not re.search(r'(?<!pre)\bload\s*\(', text), name
    assert 'ArtLibrary.load_texture(' not in text, name
print(f'PASS: {count} exact frames, {pages_count} bounded pages, no synchronous plant texture loads')
