"""Original seven-night journal assets via the installed sprite-gen engine."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os, subprocess, sys, json

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home()/'.codex/skills/sprite-gen'
OUT = ROOT/'art_source/generated/mm_tools/greenhouse_codex'
STYLE = ('Premium painterly fantasy botanical bestiary illustration for The Last Sunflower. Dark emerald and petrol blue greenhouse background, warm amber rim light, tactile organic details. One prominent centered complete subject filling 70 percent of canvas, landscape 3:2. Quiet environment, no UI, frame, text, letters, numbers, watermark. ')
SPECS = {
 'thorn_flower': (STYLE+'A defensive emerald thorn flower with a radiant golden flower head, sturdy leafy stem and sharp curved thorn vines sweeping outward over dark moss, botanical guardian.', '3:2'),
 'prism_flower': (STYLE+'A crystalline prism flower with translucent amber faceted petals, narrow luminous sun core and elegant emerald leaves, projecting a precise golden beam through greenhouse mist.', '3:2'),
 'shadow_beast': (STYLE+'A threatening charcoal-black wolf-like shadow beast, flowing smoky mane, glowing amber eyes, sharp claws, prowling low through blue-green moonlit greenhouse roots, complete beast silhouette.', '3:2'),
 'erosion_bug': (STYLE+'A sinister large beetle-like erosion insect with dark chitin shell, articulated legs, glowing sickly amber mandibles biting an exposed luminous plant root, complete insect silhouette on dark moss.', '3:2'),
 'specimen_board': ('One horizontal fantasy botanical specimen archive board, 16:9 fills canvas. Refined dark emerald leather interior with subtle grain, slim old brass double rim, tiny botanical corner etchings and clipped corners. Entire center quiet textured low contrast for runtime image and text. No text, symbols, UI divisions, slots, scene, watermark.', '16:9'),
 'background': ('Dark botanical study in ruined greenhouse, landscape 16:9. Dim specimen shelves at far left, old gardening books and faint lantern at far right, moonlit glass above. Center 90 percent quiet dark green blue low contrast for UI overlay. Painterly original fantasy game background, no UI, text, panels or watermark.', '16:9'),
}

def run(item):
 name,(prompt,aspect) = item
 target=OUT/f'{name}.png'
 if target.exists(): return {'asset':name,'status':'existing'}
 prompt_path=OUT/f'{name}.prompt.txt'; prompt_path.write_text(prompt,encoding='utf-8')
 args=[sys.executable,str(ROOT/'aiskill/mm-tools/sprite_gen_gateway.py'),'--sprite-gen-root',str(ENGINE),'--api-base','https://newapi.oairegbox.cc/','--','gen','--provider','openai','--model','gpt-image-2','--aspect-ratio',aspect,'--quality','high','--prompt-file',str(prompt_path),'--out',str(target),'--report',str(OUT/f'{name}.report.json')]
 result=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',env={**os.environ,'PYTHONUTF8':'1'})
 return {'asset':name,'status':'generated' if result.returncode==0 else result.stderr[-500:]}

if __name__=='__main__':
 OUT.mkdir(parents=True,exist_ok=True)
 with ThreadPoolExecutor(max_workers=2) as pool:
  for result in pool.map(run,SPECS.items()): print(json.dumps(result),flush=True)
