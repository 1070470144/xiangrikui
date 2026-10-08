import json
import shutil
from refine_monster_gait import TARGET, OUTPUT, engine

run = TARGET / 'erosion_bug'
shutil.copy2(run / 'raw/walk.png', run / 'walk-rejected-extra-claws.png')
request = json.loads((run / 'sprite-request.json').read_text(encoding='utf-8'))
request['states']['walk']['action'] = '''Eight-frame slow insect crawl. STRICT: shell, head, mandibles and thorax remain at identical positions, orientation, dimensions and height in all eight frames, as if traced over a locked layer. Only the existing SIX short jointed legs move. Keep original thick tapered insect legs: NO HANDS, NO FINGERS, NO TALONS, NO BIRD FEET. Never expose extra long spindly legs below the shell. Each leg is a single sturdy bent taper with one pointed tip, same length in every frame. Near-side front and rear legs alternate with near-side middle leg; far-side opposite. Frame phases 0,45,90,135,180,225,270,315 degrees of one cycle. First half: near front/rear tips smoothly sweep backward on ground as middle tip swings forward slightly lifted. Second half reverses which group is planted. Lift no more than one tenth leg length; sweep no more than one fifth body length. No frame with all legs lifted. Last to first is a gradual continuation. Rigid heavy shell absolutely no vertical bounce. Preserve exactly the reference carapace artwork and closed mandibles. No reinterpretation of claw anatomy.'''
recipe = TARGET / 'erosion_bug-retry-request.json'
recipe.write_text(json.dumps(request, indent=2), encoding='utf-8')
engine('prepare', '--out-dir', str(run), '--character-id', 'erosion_bug', '--description', request['character']['description'],
       '--base-image', str(OUTPUT / 'erosion_bug/base-source.png'), '--chroma-key', '#00FF00', '--request', str(recipe), '--force')
engine('gen', '--provider', 'openai', '--model', 'gpt-image-2', '--quality', 'high', '--aspect-ratio', '3:1',
       '--prompt-file', str(run / 'prompts/walk.txt'), '--ref', str(run / 'base-source.png'),
       '--ref', str(run / 'references/layout-guides/walk.png'), '--out', str(run / 'raw/walk.png'),
       '--report', str(run / 'reports/walk-retry-generation.json'))
