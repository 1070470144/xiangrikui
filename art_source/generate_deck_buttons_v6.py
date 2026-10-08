"""Generate original tactile botanical button plates through sprite-gen."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.codex/skills/sprite-gen'
OUT = ROOT / 'art_source/generated/mm_tools/deck_builder/buttons_v6'
BASE = ('One single horizontal game UI button plate, wide 3:1 silhouette, centered and nearly filling canvas. '
        'Front orthographic view, clipped rounded corners, realistic fine-grain embossed dark forest green leather center, '
        'slim weathered brass double bevel rim, tactile worn metal, delicate botanical engravings only at the two ends. '
        'Inspired by mature fantasy collectible card game material hierarchy, original post-apocalyptic greenhouse botanical art. '
        'Center 75 percent quiet dark leather with visible subtle grain to support runtime white Chinese text. '
        'No text, glyphs, letters, numbers, icons, watermark, surrounding panel or scenery. '
        'Button entire interior opaque; outside silhouette pure flat magenta #FF00FF for chroma key production. ')
SPECS = {'secondary': 'Restrained oxidized old copper rim, cool emerald leather, tiny etched leaf tips at ends, subtle upper-left highlight.',
         'primary': 'Premium antique gold rim, warm gold etched laurel leaves at ends, rich emerald leather, fine amber upper bevel highlight; more important action without bright central glow.'}

def run(item):
    name, detail = item
    prompt_path = OUT / f'{name}.prompt.txt'
    prompt_path.write_text(BASE + detail, encoding='utf-8')
    args = [sys.executable, str(ROOT/'aiskill/mm-tools/sprite_gen_gateway.py'), '--sprite-gen-root', str(ENGINE),
            '--api-base', 'https://newapi.oairegbox.cc/', '--', 'gen', '--provider', 'openai', '--model', 'gpt-image-2',
            '--aspect-ratio', '3:1', '--quality', 'high', '--transparent', '--alpha-mode', 'chroma', '--chroma-key', 'magenta',
            '--prompt-file', str(prompt_path), '--out', str(OUT/f'button_{name}_v6.png'), '--report', str(OUT/f'{name}.report.json')]
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', env={**os.environ, 'PYTHONUTF8':'1'})
    print(name, 'ok' if result.returncode == 0 else result.stderr[-600:], flush=True)
    return result.returncode

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=2) as pool:
        raise SystemExit(max(pool.map(run, SPECS.items())))
