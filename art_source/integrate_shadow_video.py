"""Publish Sprite-gen's verified strip cells as Godot walk textures."""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/generated/monster_video_ark/shadow_beast'
LOOP = SOURCE / 'loop'
DEST = ROOT / 'assets/enemies/animations/shadow_beast'

def main():
    report = json.loads((LOOP / 'walk.loop.report.json').read_text(encoding='utf-8'))
    meta = json.loads((LOOP / 'walk.strip.json').read_text(encoding='utf-8'))
    assert report['status'] == 'passed', 'Loop must pass Sprite-gen QA'
    assert not meta['subsampled'], 'Keep every source cycle frame'
    assert meta['frames'] == meta['cycle_frames']
    assert meta['h'] <= 178, 'No clipping allowed in game canvas'
    strip = Image.open(LOOP / 'walk.strip.png').convert('RGBA')
    backup = SOURCE / 'previous-game-walk'
    backup.mkdir(exist_ok=True)
    for old in [DEST / 'manifest.json', *DEST.glob('walk-frame-*.png')]:
        if not (backup / old.name).exists():
            shutil.copy2(old, backup / old.name)
    width = max(192, meta['w'] + meta['w'] % 2)
    for i in range(meta['frames']):
        # The canonical strip owns extraction, scale and motion alignment.
        # This adapter only adds transparent game padding at the existing floor.
        cell = strip.crop((i * meta['w'], 0, (i + 1) * meta['w'], meta['h']))
        canvas = Image.new('RGBA', (width, 192))
        canvas.alpha_composite(cell, ((width - meta['w']) // 2, 178 - meta['h']))
        canvas.save(DEST / f'walk-frame-{i}.png')
    manifest = json.loads((DEST / 'manifest.json').read_text(encoding='utf-8'))
    manifest['engine'] = 'sprite-gen-video-walk/component-row-attack'
    manifest['game_input'] = 'per-state-png-frames'
    manifest['animation']['rows']['walk'] = {
        'frames': meta['frames'], 'fps': 24, 'loop': True,
        'durations_ms': [1000 / 24] * meta['frames'],
        'frame_variant': 'video-alpha', 'width': width, 'height': 192,
        'ground_y': 178, 'body_height': 123,
        'source': 'art_source/generated/monster_video_ark/shadow_beast/walk.mp4',
        'pipeline_metadata': 'art_source/generated/monster_video_ark/shadow_beast/loop/walk.strip.json',
        'source_cycle': {key: report['cycle'].get(key) for key in
                         ('kind', 'start', 'length', 'ratio', 'review_recommended')},
    }
    if 'sprite_sheet_alpha' in manifest:
        manifest['legacy_component_sheet'] = manifest.pop('sprite_sheet_alpha')
    manifest.pop('sprite_sheet_alpha_report', None)
    manifest.pop('frame_layout', None)
    manifest['animation'].pop('columns', None)
    (DEST / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"Published {meta['frames']} walk frames at 24 FPS, canvas {width}x192")

if __name__ == '__main__':
    main()
