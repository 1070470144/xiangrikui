"""Regenerate walking rows without replacing previous runs or attack sources."""
import json
import shutil
from concurrent.futures import ThreadPoolExecutor
from generate_monster_animations import PROJECT, OUTPUT, engine

TARGET = PROJECT / 'art_source/generated/monster_gait_v3'
GAITS = {
    'shadow_beast': '''An anatomically correct FOUR-legged stalking quadruped walk, never hopping or paddling. Exactly two front legs attached at shoulders and two hind legs attached at hips; joints keep identical segment lengths. Eight chronological phases of ONE stride, facing right in place: 1 near forepaw forward on ground and near hindpaw back; 2 both planted paws slide gradually backward relative to torso; 3 near hindpaw lifts and swings forward low under belly while near forepaw stays grounded; 4 near hindpaw plants forward and near forepaw lifts; 5 near forepaw is back and near hindpaw is forward, opposite contact to frame 1; 6 near forepaw swings forward low; 7 near forepaw extends toward landing while near hindpaw slides back; 8 near forepaw almost lands in phase 1. Far legs are offset half a cycle. Always at least two grounded paws. Planted feet move steadily backward, lifted feet return forward in a low arc. Paw positions change a small amount each adjacent frame. Same rigid torso, skull, shoulder and hip positions in all eight poses, no vertical jumping. Never draw a dangling fifth paw. Frame 8 to 1 is the smallest continuation step, not a reset.''',
    'erosion_bug': '''An anatomically correct SIX-legged insect alternating-tripod crawl, never a quadruped gait. Three pairs attached under fixed thorax: front, middle, rear. Exactly six legs total, three on each side; claws and joints retain lengths and attachment points. Group A = near front + near rear + far middle, Group B = far front + far rear + near middle. Eight chronological phases of ONE stride: 1 group A reaches forward and plants, group B starts low forward swing; 2 A grounded moves gently back and B swings forward; 3 A remains grounded and B approaches forward landing; 4 B lands forward as A reaches rear limit; 5 B grounded and A lifts for recovery, opposite contact to frame 1; 6 B moves gently backward and A swings forward low; 7 B stays planted and A extends toward landing; 8 A almost lands matching phase 1. Each leg moves as a jointed limb with two rigid segments, not a changing tentacle. Keep shell absolutely stable, mandibles closed and unmoving, no body stretching or floating. Only legs move. Three legs support the body throughout. Foot tips follow low elliptical paths; no legs disappearing or extra claws. Frame 8 to 1 must be a small smooth step.'''
}

def prepare(name):
    old = OUTPUT / name
    run = TARGET / name
    if run.exists():
        return run
    request = json.loads((old / 'sprite-request.json').read_text(encoding='utf-8'))
    request['states']['walk']['action'] = GAITS[name]
    request['states']['walk']['fps'] = 12
    request['fit']['align_x'] = 'alpha-centroid'
    TARGET.mkdir(parents=True, exist_ok=True)
    recipe = TARGET / f'{name}-request.json'
    recipe.write_text(json.dumps(request, indent=2), encoding='utf-8')
    engine('prepare', '--out-dir', str(run), '--character-id', name,
           '--description', request['character']['description'], '--base-image', str(old / 'base-source.png'),
           '--request', str(recipe), '--chroma-key', '#00FF00')
    shutil.copy2(old / 'raw/attack.png', run / 'raw/attack.png')
    (run / 'reports').mkdir(exist_ok=True)
    return run

def generate(name):
    run = prepare(name)
    if (run / 'raw/walk.png').exists():
        return
    engine('gen', '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'high',
           '--aspect-ratio', '3:1', '--prompt-file', str(run / 'prompts/walk.txt'),
           '--ref', str(run / 'base-source.png'), '--ref', str(run / 'references/layout-guides/walk.png'),
           '--out', str(run / 'raw/walk.png'), '--report', str(run / 'reports/walk-generation.json'))

if __name__ == '__main__':
    import sys
    if sys.argv[1] == 'generate':
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(generate, GAITS))
    else:
        for name in GAITS:
            for cmd in ['extract', 'compose-atlas', 'preview', 'compose-gif', 'inspect', 'export-pngs']:
                engine(cmd, '--run-dir', str(TARGET / name))
