"""Generate the requested static art with the installed sprite-gen engine.

Credentials remain in OPENAI_API_KEY; resume skips verified published images.
No video calls or automatic paid retries are made.
"""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
STYLE = ('Hand-painted dark fantasy botanical storybook game art, visible painterly brushwork, '
         'muted ink green foliage, golden life veins, warm upper-left light, 3/4 overhead view. '
         'One complete isolated rooted plant centered, root contact at 85 percent canvas height, '
         'body inside 12 percent margins. Clear silhouette at small game size. No text, no UI, '
         'no scenery, no shadow, no watermark, no neon, no realistic photography. True transparent RGBA background. ')
PLANTS = {
    'lantern_flower': 'Lantern flower: drooping golden bell lantern under broad protective leaves.',
    'frost_bell': 'Frost bell: pale icy blue translucent bell flowers with frosted pointed leaves.',
    'honeydew_flower': 'Honeydew flower: pink-white petals cupping large golden nectar droplets.',
    'storm_flower': 'Lightning chain flower: three cobalt star flowers joined by fine golden electric veins.',
    'gale_flower': 'Wind chime grass: tall curved stems and airy jade bell flowers, swept leaves.',
    'sunwell_flower': 'Sun well flower: deep golden bowl-shaped blossom holding a luminous sun pearl.',
    'ember_flower': 'Ember flower: burnt orange pointed petals and dark red glowing ember stamens.',
    'slumber_flower': 'Slumber spore flower: violet poppy with rounded seed pods and soft lavender spores.',
    'spear_bamboo': 'Spear bamboo: three upright segmented bamboo stems with long sharp lance leaves.',
    'burst_flower': 'Burst fruit flower: red-orange plump explosive seed fruits among thick green leaves.',
    'stone_flower': 'A squat botanical lotus with thick grey-green overlapping stone-textured petals, a golden seed heart, broad rounded leaves and sturdy roots. Living flower, not a rock pile.',
    'cleanse_flower': 'Purifying dew orchid: ivory orchid blossom with turquoise dew drops and clean graceful leaves.',
    'drum_flower': 'Inspiring sunflower: golden sunflower with a drum-shaped seed heart and broad rhythmic leaf fans.',
}
MOTIFS = {
    'sunseed': 'sharp arrow-shaped golden petals, long aiming stamens and paired sunseed pods',
    'corona': 'layered flame-orange petal crown and ember pollen nodes',
    'sunburst': 'broad luminous gold circular petal rings and twin sun discs',
    'receptacle': 'thick woody stem, shield-like green bracts and layered armored flower receptacle',
    'sap': 'amber sap channels, translucent honey droplets and flourishing healing buds',
    'counterroot': 'branched curling thorn root whips guarding the golden sunflower',
    'charge': 'large warm gold luminous energy sacs connected by fine veins',
    'quelling': 'pale blue silver petal crescents and outward curved protective leaf wave fans',
    'morningstar': 'ivory-gold star petal crown, morning dew and concentric pale light petals',
}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sprite-gen-root', required=True, type=Path)
    parser.add_argument('--api-base', required=True)
    parser.add_argument('--workers', type=int, default=3)
    parser.add_argument('--only', default='')
    args = parser.parse_args()
    if not os.environ.get('OPENAI_API_KEY'): raise SystemExit('OPENAI_API_KEY is required')
    evidence = ROOT / 'art_source/generated/plant_mother_static'
    evidence.mkdir(parents=True, exist_ok=True)
    plan = json.loads((ROOT / 'art_source/manifests/plant_mother_motion_plan.json').read_text(encoding='utf-8'))
    content = (ROOT / 'scripts/content_data.gd').read_text(encoding='utf-8')
    names = dict(re.findall(r'\["(mother_[^"]+)","([^"]+)"\]', content))
    jobs = [(key, STYLE + subject, ROOT / f'assets/plants/generated/plant_expansion/{key}.png', '1:1') for key, subject in PLANTS.items()]
    paths = {'sun_arrow':'sunseed', 'root_heart':'receptacle', 'dawn_pulse':'morningstar'}
    for item in plan['mother_forms']:
        key = item['id'] if isinstance(item, dict) else item
        branch = paths.get(key, '') or key.split('_')[1]
        rank = 0 if key in paths else int(key.rsplit('_', 1)[1])
        prompt = (STYLE + 'An evolved central mother sunflower, same grounded mature sunflower botanical species. '
                  f'Form identity: {names.get(key, key)}. Distinct anatomy: {MOTIFS[branch]}. '
                  f'Branch evolution stage {rank} of 6: {rank+2} clearly visible motif structures, '
                  f'{rank+1} petal layers, increasingly intricate silhouette with rank. '
                  'Preserve the warm golden seed heart and root base. Avoid ordinary small plant proportions.')
        jobs.append((key, prompt, ROOT / f'assets/core/generated/mother_forms/{key}.png', '1:1'))
    manifest = json.loads((ROOT / 'art_source/manifests/mother_buff_ui.json').read_text(encoding='utf-8'))
    frame = manifest['assets'][0]
    jobs.insert(0, ('mother_buff_card_frame', frame['generation']['prompt'], ROOT / frame['output']['path'].removeprefix('res://'), '3:4'))
    if args.only: jobs = [job for job in jobs if job[0] in args.only.split(',')]
    def generate(job):
        key, prompt, out, ratio = job
        report = evidence / f'{key}.report.json'
        if out.exists() and report.exists(): return {'id':key, 'status':'existing'}
        out.parent.mkdir(parents=True, exist_ok=True)
        prompt_file = evidence / f'{key}.prompt.txt'
        prompt_file.write_text(prompt, encoding='utf-8')
        command = [str(args.sprite_gen_root / '.venv/Scripts/python.exe'), str(ROOT / 'aiskill/mm-tools/sprite_gen_gateway.py'),
                   '--sprite-gen-root', str(args.sprite_gen_root), '--api-base', args.api_base, '--', 'gen',
                   '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'medium',
                   '--prompt-file', str(prompt_file), '--out', str(out), '--report', str(report),
                   '--aspect-ratio', ratio, '--transparent', '--alpha-mode', 'native']
        result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8')
        # Provider errors deliberately contain no raw HTTP response or credentials.
        log = result.stdout + result.stderr
        secret = os.environ.get('OPENAI_API_KEY', '')
        if secret: log = log.replace(secret, '[REDACTED]')
        (evidence / f'{key}.log.txt').write_text(log, encoding='utf-8')
        status = 'generated' if result.returncode == 0 and out.exists() else 'failed'
        print(f'{key}: {status}', flush=True)
        return {'id':key, 'status':status}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(generate, jobs))
    (evidence / ('summary.json' if not args.only else f'{args.only}.summary.json')).write_text(json.dumps(results, indent=2), encoding='utf-8')
    print(json.dumps({'total':len(results), 'failed':sum(r['status']=='failed' for r in results)}), flush=True)
    return int(any(r['status']=='failed' for r in results))

if __name__ == '__main__': raise SystemExit(main())
