"""Prepare keyed stills and motion prompts; no network calls or credentials."""
import json
from pathlib import Path
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'art_source/generated/monster_video_frostfox'
COMMON = ('Locked camera, fixed 3/4 elevated side view facing RIGHT. Single full-body creature remains centered, '
          'walking in place on a treadmill. Solid uniform pure green #00FF00 background throughout. '
          'Keep the original painterly character design, anatomy, proportions, armor, color and shading. '
          'Smooth chronological motion, crisp frames, no motion blur, no camera movement, no zoom, '
          'no shadows, no scenery, no extra creatures or limbs, no text. '
          'Perform at least two complete, evenly paced walk cycles and return to the starting stance. '
          'Use the grounded weight transfer and readable anticipation of polished action RPG creature animation. ')

SPECIES = {
    'shadow_beast': ('ShadowBeast', 'A flexible FOUR-legged stalking predator: front legs attached to shoulders, '
                     'hind legs to hips, stable segment lengths. Natural alternating paw contacts; planted paws push '
                     'backwards relative to torso, then lift into a low forward recovery arc. Keep two or more paws '
                     'supporting the body. Shoulders roll subtly over planted paws, hips counterbalance, spine flexes '
                     'gently and tail provides restrained counter-motion. Low center of gravity; no hopping, '
                     'paddling, limb morphing or foot skating.'),
    'erosion_bug': ('ErosionBug', 'A SIX-legged insect with front, middle and rear pairs on fixed attachment points. '
                   'Use alternating tripod support: near front + near rear + far middle support while the opposite '
                   'tripod recovers. Three planted leg tips support the rigid heavy shell throughout. Short jointed '
                   'tapered legs, fixed lengths, low return arcs and steady backward planted-foot travel. '
                   'Mandibles remain closed; shell rocks only slightly with weight transfer. '
                   'No human hands, bird talons, added claws, legs stretching, hovering or shell bounce.')
}

if __name__ == '__main__':
    for name, (source, motion) in SPECIES.items():
        folder = OUT / name
        folder.mkdir(parents=True, exist_ok=True)
        image = Image.open(PROJECT / f'assets/enemies/ART_ENEMY_{source}_Move.png').convert('RGBA')
        image.thumbnail((640, 540), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (1024, 768), (0, 255, 0, 255))
        canvas.alpha_composite(image, ((1024-image.width)//2, 600-image.height))
        canvas.convert('RGB').save(folder / 'input-green.png')
        (folder / 'walk-prompt.txt').write_text(COMMON + motion, encoding='utf-8')
    (OUT / 'request-plan.json').write_text(json.dumps({
        'provider': 'frostfox', 'api_root': 'https://market.frostfox.ai/',
        'model': 'minimax_h3_image_audio_to_video', 'characters': list(SPECIES),
        'status': 'blocked_before_video_submission',
        'blocker': 'Video POST /v1/responses returned Cloudflare HTTP 403 / 1010. Official video API schema is unverified.',
        'credential_environment': 'FROSTFOX_API_KEY',
        'downstream': ['sprite-gen video-frames', 'sprite-gen video-loop', 'Godot manifest integration'],
        'motion_qa': ['anatomy', 'foot contact', 'weight transfer', 'loop seam', 'identity', 'chroma edges'],
        'reference_note': 'General action RPG animation principles; no external game footage has been used.',
    }, indent=2), encoding='utf-8')
