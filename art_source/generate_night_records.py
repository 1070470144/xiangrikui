"""Original seven-night journal assets via the installed sprite-gen engine."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os, subprocess, sys, json

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path.home()/'.codex/skills/sprite-gen'
OUT = ROOT/'art_source/generated/mm_tools/night_records'
STYLE = ('Premium painterly botanical dark fantasy game illustration for The Last Sunflower. '
         'Post-apocalyptic greenhouse, forest green and petrol blue shadows, restrained amber sunlight, '
         'fine organic engraved details, one clearly readable focal subject in center, landscape composition. '
         'Edge-to-edge finished artwork. No text, lettering, numbers, logos, watermark, UI or frame. ')
SUBJECTS = {
 'night_1': 'The first night: a small glowing sunflower lantern standing bravely at the center of an overgrown moonlit greenhouse, two dark shadow beasts cautiously approaching through mist; fragile hopeful first defense.',
 'night_2': 'Attacks from all directions: a radiant sunflower garden at the center, multiple dark beast silhouettes approaching along branching root paths from all edges, tense encirclement but central warm light remains strong.',
 'night_3': 'Acid rain: luminous sickly green rain falling through a cracked greenhouse roof onto battered leaves, protective amber botanical lantern at center, corrosive mist and wet emerald surfaces; distinct toxic weather.',
 'night_4': 'Thunderstorm: blue-white lightning splitting a stormy sky above shattered greenhouse windows, rain swept green foliage and a golden sunflower lantern resisting the wind; dramatic electric storm.',
 'night_5': 'Root-crown colossus: an enormous hulking monster made of twisted dead roots and bark with a thorn crown looming over tiny sunflowers, amber cracks and dark moss, imposing readable boss silhouette.',
 'night_6': 'A breathing space: tranquil damaged greenhouse garden at predawn, a healthy sunflower and fresh shoots growing around a repaired botanical lantern, drifting golden pollen, hopeful quiet recovery after battle.',
 'night_7': 'Sun devourer: a colossal black shadow creature with a gaping maw and thorned silhouette eclipsing a radiant sunflower sun disk, tiny garden in foreground resisting with amber roots; grand final-night confrontation.',
}
SPECS = {key:(STYLE+value,'3:2') for key,value in SUBJECTS.items()}
SPECS['background'] = ('A premium painterly dark botanical archive room background, landscape 16:9. Old greenhouse at midnight, dim shelves and hanging roots only at far outer edges, warm amber lantern far left, cool blue-green glass at far right. Center 90 percent very dark quiet low contrast, soft tactile shadows. Original fantasy game journal atmosphere. No UI, panels, frames, text, numbers, logos, watermark.','16:9')
SPECS['journal_panel'] = ('One large rectangular horizontal fantasy game journal panel, 16:9 nearly fills canvas. Opaque midnight emerald worn leather center with subtle paper fibers, slim antique brass double rim, clipped corners, tiny embossed sunflower and root engravings only in outer 4 percent corners. Center 90 percent completely quiet dark textured leather for runtime UI. Orthographic front view, original botanical archive design, refined mature game interface craftsmanship. No text, letters, icons, numbers, dividers, slots, buttons, illustrations, watermark, shadows outside panel.','16:9')

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
