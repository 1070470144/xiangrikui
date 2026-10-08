"""Generate monster rows with sprite-gen; credentials come from the environment."""
import argparse
import json
import subprocess
import shutil
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
ROOT = Path.home() / '.codex/skills/sprite-gen'
PYTHON = ROOT / '.venv/Scripts/python.exe'
GATEWAY = PROJECT / 'aiskill/mm-tools/sprite_gen_gateway.py'
OUTPUT = PROJECT / 'art_source/generated/monster_animations'

def engine(*args):
    subprocess.run([str(PYTHON), str(GATEWAY), '--sprite-gen-root', str(ROOT),
                    '--api-base', 'https://newapi.oairegbox.cc/', '--', *args], check=True)

def prepare():
    for name, source, description in [
        ('shadow_beast', 'ShadowBeast', 'Low slung corrupted quadruped shadow beast, slate purple overlapping armor, cyan eyes, long curled tail; preserve the reference anatomy.'),
        ('erosion_bug', 'ErosionBug', 'Corrupted armored garden insect, purple segmented shell, cyan eyes and mandibles; preserve the reference anatomy and leg count.')]:
        run = OUTPUT / name
        if (run / 'sprite-request.json').exists():
            continue
        OUTPUT.mkdir(parents=True, exist_ok=True)
        request = {'version': 1, 'kind': 'sprite-gen-request', 'engine': 'component-row',
                   'character': {'id': name, 'description': description},
                   'cell': {'width': 192, 'height': 192, 'safe_margin': 14},
                   'chroma_key': {'name': 'green', 'hex': '#00FF00', 'rgb': [0,255,0]},
                   'style': 'High definition painterly dark fantasy storybook, 3/4 elevated side view facing RIGHT, same colors and proportions as reference. Not pixel art.',
                   'fit': {'resample': 'lanczos', 'align_x': 'bbox-center', 'align_y': 'bottom', 'ground_frames': True, 'pixel_unfake': False},
                   'states': {
                       'walk': {'frames': 8, 'fps': 12, 'loop': True, 'action': 'Eight evenly spaced phases of a continuous forward creeping gait, in place facing RIGHT. Use a smooth quadruped walk cycle: two contact poses, two passing poses, two compression poses and two opposite contact poses. Every frame must have a distinct leg placement, with paws moving gradually between neighboring frames; stable head, torso scale and ground line; frame 8 flows into frame 1. No ghost trails.'},
                       'attack': {'frames': 8, 'fps': 12, 'loop': False, 'action': 'Eight readable attack phases facing RIGHT: neutral, crouch anticipation, coil, launch, jaws opening, full bite strike, recoil, recovery to neutral. Each neighboring frame is a small pose change. All limbs and tail intact, stable scale. No effects, no extra creatures.'}}}
        recipe = OUTPUT / f'{name}-request.json'
        recipe.write_text(json.dumps(request, indent=2), encoding='utf-8')
        engine('prepare', '--out-dir', str(run), '--character-id', name, '--description', description, '--chroma-key', '#00FF00', '--base-image',
               str(PROJECT / f'assets/enemies/ART_ENEMY_{source}_Move.png'), '--request', str(recipe), '--cell-width', '192', '--cell-height', '192', '--force')

def generate_row(job, force=False):
    name, state = job
    run = OUTPUT / name
    out = run / f'raw/{state}.png'
    if out.exists() and not force:
        return
    (run / 'reports').mkdir(exist_ok=True)
    engine('gen', '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'high',
           '--aspect-ratio', '3:1', '--prompt-file', str(run / f'prompts/{state}.txt'),
           '--ref', str(run / 'base-source.png'), '--ref', str(run / f'references/layout-guides/{state}.png'),
           '--out', str(out), '--report', str(run / f'reports/{state}-generation.json'))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['prepare', 'generate', 'finish', 'publish'])
    args = parser.parse_args()
    if args.stage == 'prepare':
        prepare()
    elif args.stage == 'generate':
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(generate_row, [(n,s) for n in ['shadow_beast','erosion_bug'] for s in ['walk','attack']]))
    elif args.stage == 'finish':
        for name in ['shadow_beast','erosion_bug']:
            run = OUTPUT / name
            for command in ['extract', 'compose-atlas', 'compose-gif', 'preview', 'inspect', 'export-pngs']:
                engine(command, '--run-dir', str(run))
    else:
        for name in ['shadow_beast', 'erosion_bug']:
            run = OUTPUT / name
            destination = PROJECT / 'assets/enemies/animations' / name
            manifest = json.loads((run / 'manifest.json').read_text(encoding='utf-8'))
            sources = [run / 'manifest.json', run / manifest['game_input']]
            for state, spec in manifest['animation']['rows'].items():
                sources.extend(run / f'curated/{state}-frame-{i}.png' for i in range(spec['frames']))
            if not all(path.is_file() for path in sources):
                raise SystemExit(f'Incomplete export: {name}')
            destination.mkdir(parents=True, exist_ok=True)
            for source in sources:
                shutil.copy2(source, destination / source.name)
