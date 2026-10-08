"""Generate transparent quality-specific card frames with sprite-gen."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.codex/skills/sprite-gen'
OUT = ROOT / 'art_source/generated/mm_tools/deck_builder/faces_v5'
SPECS = {
    'back': 'A single finished physical trading-card BACK, portrait 3:4, nearly fills canvas with tiny transparent exterior margin. Rounded clipped corners, deep midnight green woven leather and printed cardstock, symmetric antique brass botanical filigree, central embossed sunflower seed seal within concentric leaf mandala, luminous restrained warm amber center, corner root motifs, tactile fine grain, thin bevel edge and real card thickness. Entire inside opaque richly designed; only outside silhouette transparent. Original botanical greenhouse fantasy card back, no text, letters, numbers, watermark, empty panels, illustration windows, floating elements or surrounding backdrop.',
    'common': 'Common quality: restrained weathered dark green painted metal and aged oxidized brass, thin practical corners, tiny botanical etching, one subtle warm amber gem at top and bottom, low ornament, grounded handcrafted game card frame.',
    'rare': 'Rare quality: dark emerald lacquer frame with cool moonlit silver and muted blue-violet enamel inlays, elegant branching leaf veins and two small pale sapphire gems, visibly more refined than common but still readable and restrained.',
    'legendary': 'Legendary quality: deep forest-black frame with rich antique gold, warm sunflower medallions at top and bottom, precise art-nouveau leaf engraving and a few restrained sun rays, premium heirloom card frame, clearly the most ornate quality.',
}
BASE = ('One finished physical trading-card FRONT chassis only, portrait 3:4. Single card nearly fills canvas with very small transparent exterior margin, rounded clipped corners. '
        'Realistic layered printed cardstock, beveled thin metal trim, tactile paper grain, premium hand-painted botanical fantasy collectible. '
        'Top 8 percent narrow empty name ribbon, upper middle from y=12 to y=46 percent an empty dark rectangular artwork window, lower half y=49 to y=87 percent quiet pale warm parchment rules panel entirely empty. '
        'Bottom 8 percent narrow empty metadata strip. A small EMPTY circular cost medallion fully INSIDE top-left card corner. Everything contained within card silhouette. '
        'Inspired by mature collectible game card information hierarchy, original greenhouse sunflower design. No text, letters, numbers, scene illustration, watermark, logo, floating ornaments, surrounding background. ')

def run(item):
    quality, detail = item
    target = OUT / f'card_face_{quality}_v5.png'
    prompt = (BASE + detail if quality != 'back' else detail) + ' Outside the single card silhouette use flat pure magenta #FF00FF, no gradient, shadow or checkerboard outside. This is a chroma key production asset.'
    prompt_path = OUT / f'{quality}.prompt.txt'
    report = OUT / f'{quality}.report.json'
    prompt_path.write_text(prompt, encoding='utf-8')
    args = [sys.executable, str(ROOT/'aiskill/mm-tools/sprite_gen_gateway.py'), '--sprite-gen-root', str(ENGINE), '--api-base', 'https://newapi.oairegbox.cc/', '--', 'gen', '--provider', 'openai', '--model', 'gpt-image-2', '--aspect-ratio', '3:4', '--quality', 'high', '--transparent', '--alpha-mode', 'chroma', '--chroma-key', 'magenta', '--prompt-file', str(prompt_path), '--out', str(target), '--report', str(report)]
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', env={**os.environ, 'PYTHONUTF8':'1'})
    print(quality, 'ok' if result.returncode == 0 else result.stderr[-500:], flush=True)
    return result.returncode

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=2) as pool:
        codes = list(pool.map(run, SPECS.items()))
    raise SystemExit(max(codes))
