"""Build paged lossless plant atlases and verify every packed pixel."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'assets/plants/animations'

def build():
    total = 0
    for folder in sorted(ROOT.iterdir()):
        source = folder / 'manifest.json'
        if not source.exists():
            continue
        manifest = json.loads(source.read_text(encoding='utf-8'))
        result = {'species': folder.name, 'states': {}}
        for state, spec in manifest['states'].items():
            images = []
            for i in range(spec['frames']):
                with Image.open(folder / f'{state}-{i:03d}.png') as image:
                    images.append(image.convert('RGBA'))
            width = max(im.width for im in images)
            height = max(im.height for im in images)
            assert width <= 2048 and height <= 2048
            cols, rows = 2048 // width, 2048 // height
            capacity = cols * rows
            records = []
            pages = []
            for start in range(0, len(images), capacity):
                chunk = images[start:start + capacity]
                page = Image.new('RGBA', (min(cols, len(chunk)) * width,
                                         ((len(chunk) + cols - 1) // cols) * height))
                name = f'{state}-atlas-{len(pages):02d}.png'
                for index, image in enumerate(chunk):
                    x, y = index % cols * width, index // cols * height
                    page.paste(image, (x, y))
                    assert page.crop((x, y, x + image.width, y + image.height)).tobytes() == image.tobytes()
                    records.append({'page': name, 'region': [x, y, image.width, image.height]})
                page.save(folder / name, compress_level=6)
                with Image.open(folder / name) as saved:
                    assert saved.tobytes() == page.tobytes()
                pages.append(name)
            result['states'][state] = dict(spec, pages=pages, regions=records)
            total += len(records)
        (folder / 'atlas_manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Verified {total} frames across lossless paged atlases')

if __name__ == '__main__':
    build()
