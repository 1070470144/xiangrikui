"""Two explicit image calls only. Credentials remain in process environment."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home() / '.codex/skills/sprite-gen'
OUT = ROOT / 'art_source/generated/mother_realism_v1'
PROMPT = '''Production game asset: one majestic rooted sunflower mother, grounded realistic dark-fantasy botanical creature. Orthographic three-quarter overhead view, full plant including all roots visible, centered isolated on genuine transparent background. Preserve sunflower identity: broad round finely textured brown seed disk with tightly packed spiral florets, tiny restrained amber light deep in the center, irregular overlapping elongated yellow-gold ray petals with thin translucent edges, natural veins and subtle curling, thick fibrous green-brown stem, four asymmetric deep-green leaves with real serrations and venation, sturdy woody branching roots spread horizontally at ground contact. Physically convincing organic materials and restrained cinematic warm lighting from upper left; natural roughness, soft self-shadowing and fine detail. Premium realistic fantasy game rendering inspired by botanical environment art in Diablo IV and Elden Ring, original design. Compact powerful silhouette readable at 140 pixels. No face, eyes, pot, pedestal, ground, scenery, text, border, aura, rays, floating ring, pink color, magical spikes, plastic or metallic petals. No blown-out white flower center. Plenty of transparent margin on every edge.'''

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / '.gdignore').write_text('')
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    for i, variant in enumerate(['Natural open sunflower crown with a strong readable oval flower disk.', 'Slightly cupped broad sunflower crown, asymmetric leaves and a short sturdy stem.'], 1):
        prompt = OUT / f'candidate-{i}.prompt.txt'
        prompt.write_text(PROMPT + '\n' + variant, encoding='utf-8')
        destination = OUT / f'candidate-{i}.png'
        marker = OUT / f'candidate-{i}.submitted'
        if marker.exists():
            print(f'Candidate {i}: already submitted; no paid retry')
            continue
        marker.write_text('One authorized image request; no automatic paid retry.\n')
        result = subprocess.run([str(ENGINE / '.venv/Scripts/python.exe'), str(ROOT / 'aiskill/mm-tools/sprite_gen_gateway.py'), '--sprite-gen-root', str(ENGINE), '--api-base', 'https://newapi.oairegbox.cc/', '--', 'gen', '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'medium', '--aspect-ratio', '1:1', '--transparent', '--prompt-file', str(prompt), '--out', str(destination), '--report', str(OUT / f'candidate-{i}.report.json')], capture_output=True, text=True, encoding='utf-8')
        (OUT / f'candidate-{i}.log.txt').write_text(result.stdout + result.stderr, encoding='utf-8')
        print(f'Candidate {i}: exit {result.returncode}', flush=True)

if __name__ == '__main__':
    main()
