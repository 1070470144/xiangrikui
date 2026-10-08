"""Lossless offline monster atlas conversion and shared soft-shadow masks."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def build():
    total = pages = 0
    for folder in sorted((ROOT / 'assets/enemies/animations').iterdir()):
        source = folder / 'manifest.json'
        if not source.exists():
            continue
        manifest = json.loads(source.read_text(encoding='utf-8'))
        if manifest.get('placeholder'):
            continue
        result = {'enemy_id': folder.name, 'runtime': manifest.get('runtime', {}), 'states': {}}
        if 'review_sample' in manifest:
            result['review_sample'] = manifest['review_sample']
        for state, spec in manifest['animation']['rows'].items():
            if state not in ('idle', 'walk', 'attack', 'spawn', 'death', 'slam', 'summon', 'exposed', 'enraged'):
                continue
            images = []
            for i in range(spec['frames']):
                with Image.open(folder / f'{state}-frame-{i}.png') as image:
                    images.append(image.convert('RGBA'))
            width, height = max(im.width for im in images), max(im.height for im in images)
            assert width <= 2048 and height <= 2048
            cols, rows = 2048 // width, 2048 // height
            capacity = cols * rows
            records = []
            for page_index, start in enumerate(range(0, len(images), capacity)):
                chunk = images[start:start + capacity]
                page = Image.new('RGBA', (min(cols, len(chunk)) * width, ((len(chunk) + cols - 1) // cols) * height))
                name = f'{state}-atlas-{page_index:02d}.png'
                for index, image in enumerate(chunk):
                    x, y = index % cols * width, index // cols * height
                    page.paste(image, (x, y))
                    records.append({'page': name, 'region': [x, y, image.width, image.height]})
                page.save(folder / name, compress_level=6)
                with Image.open(folder / name) as saved:
                    for record, image in zip(records[-len(chunk):], chunk):
                        x, y, w, h = record['region']
                        assert saved.crop((x, y, x + w, y + h)).tobytes() == image.tobytes()
                pages += 1
            result['states'][state] = dict(spec, regions=records)
            total += len(records)
        required = {'idle', 'slam'} if folder.name == 'root_crown_colossus' and manifest.get('review_sample') else {'walk', 'attack', 'spawn', 'death'}
        assert required.issubset(result['states'])
        (folder / 'atlas_manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    # Circular masks reproduce the original nested-circle alpha composition.
    # Projection/stretch and color remain runtime parameters, not baked lighting.
    dest = ROOT / 'assets/effects/shadows'
    dest.mkdir(parents=True, exist_ok=True)
    for name, count, start, step, opacity in [('projected', 16, 1.9, .085, .045), ('contact', 12, 1.75, .1, .028)]:
        size = 256
        mask = Image.new('RGBA', (size, size))
        data = []
        for y in range(size):
            for x in range(size):
                distance = (((x + .5 - size / 2) / (size / 4)) ** 2 + ((y + .5 - size / 2) / (size / 4)) ** 2) ** .5
                alpha = 0.0
                for i in range(count):
                    coverage = max(0.0, min(1.0, (start - i * step - distance) * size / 4 + .5))
                    alpha = 1 - (1 - alpha) * (1 - opacity * coverage)
                data.append((255, 255, 255, round(alpha * 255)))
        mask.putdata(data)
        mask.save(dest / f'{name}.png')
    print(f'PASS: {total} exact monster frames, {pages} bounded atlas pages; two shared shadow masks')

if __name__ == '__main__':
    build()
