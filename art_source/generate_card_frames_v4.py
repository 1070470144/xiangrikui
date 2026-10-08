"""Generate transparent quality-specific card frames with sprite-gen."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.codex/skills/sprite-gen'
OUT = ROOT / 'art_source/generated/mm_tools/deck_builder/frames_v4'
SPECS = {
    'common': 'Common quality: restrained weathered dark green painted metal and aged oxidized brass, thin practical corners, tiny botanical etching, one subtle warm amber gem at top and bottom, low ornament, grounded handcrafted game card frame.',
    'rare': 'Rare quality: dark emerald lacquer frame with cool moonlit silver and muted blue-violet enamel inlays, elegant branching leaf veins and two small pale sapphire gems, visibly more refined than common but still readable and restrained.',
    'legendary': 'Legendary quality: deep forest-black frame with rich antique gold, warm sunflower medallions at top and bottom, precise art-nouveau leaf engraving and a few restrained sun rays, premium heirloom card frame, clearly the most ornate quality.',
}
BASE = ('A single complete vertical collectible strategy card FRAME only, portrait 3:4, 768x1024. '
        'Transparent center aperture must be perfectly empty and transparent from x=100 to x=668 and y=150 to y=900, for runtime artwork and text. '
        'Frame occupies only the outer 12 percent of the canvas; crisp symmetric silhouette, consistent 3:4 geometry, no interior background. '
        'Premium hand-painted game UI asset for The Last Sunflower, post-apocalyptic botanical greenhouse archive, realistic material texture, soft upper-left warm light. '
        'No text, letters, numbers, symbols, logos, watermark, illustration, scene, card title, cost badge, or button. ')

def run(item):
    quality, detail = item
    target = OUT / f'card_frame_{quality}_v4.png'
    prompt = BASE + detail
    prompt_path = OUT / f'{quality}.prompt.txt'
    report = OUT / f'{quality}.report.json'
    prompt_path.write_text(prompt, encoding='utf-8')
    args = [sys.executable, str(ROOT/'aiskill/mm-tools/sprite_gen_gateway.py'), '--sprite-gen-root', str(ENGINE), '--api-base', 'https://newapi.oairegbox.cc/', '--', 'gen', '--provider', 'openai', '--model', 'gpt-image-2', '--aspect-ratio', '3:4', '--quality', 'high', '--transparent', '--prompt-file', str(prompt_path), '--out', str(target), '--report', str(report)]
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', env={**os.environ, 'PYTHONUTF8':'1'})
    print(quality, 'ok' if result.returncode == 0 else result.stderr[-500:], flush=True)
    return result.returncode

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        codes = list(pool.map(run, SPECS.items()))
    raise SystemExit(max(codes))
