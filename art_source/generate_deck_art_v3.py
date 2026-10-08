"""Generate independent card illustrations through the installed sprite-gen engine.

Authentication is inherited from OPENAI_API_KEY, never stored here.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.codex/skills/sprite-gen'
OUTPUT = ROOT / 'art_source/generated/mm_tools/deck_builder/illustrations_v3'
SUBJECTS = {
    'card_sun_pierce': 'A single crystal-tipped sunflower lance firing a narrow golden ray diagonally through midnight greenhouse mist; striking luminous spearhead, elegant leaves, sense of precise focused piercing energy.',
    'card_root_snare': 'A spiral of living thorn-covered roots emerging from damp soil, wrapping around a dark stone at center; curling root silhouette, verdant moss, restrained warm amber highlights, botanical binding magic.',
    'card_emergency_dew': 'A glowing large dewdrop hanging from a pale white healing flower above a damaged leaf that is becoming healthy green again; luminous cool turquoise dew with warm golden highlights, gentle restorative botanical magic.',
    'card_root_wall': 'A sturdy protective wall woven from thick interlocking tree roots, moss and broad leaves; upward arching shield-like silhouette planted firmly in soil, warm light peeking through root gaps, defensive botanical magic.',
    'card_sun_mine': 'A closed sunflower seed pod nestled in dark soil, a brilliant golden sun core glowing through the segmented shell, small radial root tendrils and a halo of drifting pollen; a charged solar botanical trap.',
    'card_lure_bud': 'A delicate luminous golden flower bud on a curved green stem, with a few amber fireflies drawn toward it against dark teal greenhouse foliage; mysterious alluring beacon, simple strong bud silhouette.',
    'card_emergency_light': 'A botanical lantern formed by a living translucent green leaf enclosing a bright amber sun seed, sending soft golden rays to nearby drooping foliage; lifegiving light supply and green leaves, gentle radiant core.',
    'card_focus_mark': 'A single large golden glowing circular targeting sigil formed naturally from a ring of sunflower petals, with a sharply focused beam converging on a small crystal at its center; botanical concentration magic, precise symmetrical focal point.',
}
PREFIX = (
    'Create one finished collectible strategy card ILLUSTRATION, landscape 3:2, '
    'for The Last Sunflower, a post-apocalyptic botanical greenhouse game. '
    'Painterly premium fantasy botanical artwork, finely drawn organic forms, '
    'rich deep forest-green and dark petrol-blue shadows, aged golden amber highlights, '
    'soft upper-left illumination, subtly textured oil-paint and engraved botanical detail. '
    'One clearly readable main subject, large in the center, strong silhouette visible at 138x72 pixels. '
    'Art fills the canvas edge to edge, quiet dark foliage in background. '
    'No UI, frame, border, text, typography, letters, numbers, watermark or collage. '
)

def generate(item):
    card_id, subject = item
    out = OUTPUT / f'{card_id}.png'
    if out.exists():
        return card_id, 'existing'
    prompt = PREFIX + subject
    prompt_file = OUTPUT / f'{card_id}.prompt.txt'
    prompt_file.write_text(prompt, encoding='utf-8')
    args = [sys.executable, str(ROOT / 'aiskill/mm-tools/sprite_gen_gateway.py'),
            '--sprite-gen-root', str(ENGINE), '--api-base', 'https://newapi.oairegbox.cc/',
            '--', 'gen', '--provider', 'openai', '--model', 'gpt-image-2',
            '--aspect-ratio', '3:2', '--quality', 'high', '--prompt-file', str(prompt_file),
            '--out', str(out), '--report', str(OUTPUT / f'{card_id}.report.json')]
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True,
                            encoding='utf-8', env={**os.environ, 'PYTHONUTF8': '1'})
    if result.returncode:
        return card_id, result.stderr.strip()[-500:]
    return card_id, 'generated'

if __name__ == '__main__':
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for card_id, status in pool.map(generate, SUBJECTS.items()):
            print(json.dumps({'card': card_id, 'status': status}), flush=True)
