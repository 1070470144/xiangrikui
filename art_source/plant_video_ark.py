"""Ark image-to-video followed by canonical sprite-gen frame and loop tools.

Credentials only in ARK_API_KEY. Task IDs are saved before polling; reruns resume
known jobs and never automatically recreate a failed or ambiguous POST.
"""
import argparse
import base64
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import threading
import urllib.request
import urllib.error
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'art_source/generated/plant_video_ark'
SKILL = Path.home()/'.codex/skills/sprite-gen'
PYTHON = SKILL/'.venv/Scripts/python.exe'
RUNNER = ROOT.parent/'tools/video/sprite_video.py'
FFMPEG = next((ROOT.parent/'tools/video').glob('ffmpeg-*/bin/ffmpeg.exe'))
FFPROBE = FFMPEG.with_name('ffprobe.exe')
API = 'https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks'
MODEL = 'doubao-seedance-2-0-mini-260615'
SAMPLE_FPS = 24
REFERENCE_SIZE = 490
MOTION_PROFILE = 'expressive'
IDS = ['thorn_flower','prism_flower','lantern_flower','frost_bell','honeydew_flower','storm_flower','gale_flower','sunwell_flower','ember_flower','slumber_flower','spear_bamboo','burst_flower','stone_flower','cleanse_flower','drum_flower']
LOCKS = {name:threading.Lock() for name in IDS}
MOTION = [
 'Thorn stems pull slightly inward, then extend their existing thorn tips outward in one sharp defensive strike, retract and recover.',
 'Prismatic petals draw inward to focus energy, open sharply once, seed heart brightens briefly in ivory gold then settles. No projectile.',
 'The hanging lantern blossom gently lifts and opens once, warm gold light brightens then returns to its original intensity.',
 'The existing bell flowers nod forward once to release a frost pulse, recoil softly and recover. No particles.',
 'The nectar blossom cups inward, golden nectar brightens once, petals open outward for one healing pulse and recover.',
 'The three existing star blossoms tense inward then open once in coordinated succession, golden veins pulse and settle. No bolts outside body.',
 'The curved stems bend backward slightly then sweep forward together once like a wind chime, settle back to the initial stance.',
 'The golden bowl flower opens wider once, its sun pearl rises only slightly and settles into the same bowl, petals recover.',
 'The orange petals tighten once, flare open for one fiery attack and settle. Existing colors only, no separate flames or smoke.',
 'The violet blossom and existing seed pods compress then expand once for a spore pulse, return to ready pose. No free particles.',
 'The existing bamboo spear leaves bend backward slightly, thrust their tips forward once and recover; stems remain rooted and do not detach.',
 'The existing red fruit pods draw inward, swell slightly once, then relax to initial size. No explosion, no detached fruit.',
 'The overlapping grey-green armor petals brace inward, flex outward once in a short defensive bash and recover, no rock fragments.',
 'The ivory orchid petals cup inward, open once in a cleansing pulse, dew highlights brighten then settle. No extra particles.',
 'The sunflower seed heart compresses slightly once, broad leaves lift and lower together for a single encouraging beat, then recover.',
]
ATTACK_MOTION = [
 'The existing thorn stems curl inward slightly, rotate their tips toward the right in a short compact whip gesture, recoil and return. Never lengthen a stem or thorn.',
 'The existing prism petals cup inward, the flower head nods sharply toward the right, the petals reopen to their original positions and the stalk recoils.',
 'The existing hanging lantern lifts on its flexible stalk, its existing petals open slightly, then close to the initial positions and the stalk lowers.',
 'The existing bell stems lean backward slightly, swing their blue bells forward together once, recoil and return.',
 'The existing nectar petals fold inward, the stalk bows toward the right, then the petals open to their original positions as the stalk rises.',
 'The existing three star flowers bend backward slightly, nod forward in succession, then recoil in succession and settle.',
 'The existing curved wind-chime stems bend slightly backward, sweep forward once with elastic recoil, then settle in their initial positions.',
 'The existing bowl petals fold inward, then open back to their original positions while the broad leaves lift and lower once. The existing pearl stays attached.',
 'The existing orange petals cup inward while the stalk leans backward, then the head nods forward sharply, petals reopen and the stalk recoils.',
 'The existing violet head bows forward as its seed pods tilt inward, then the head rises and the pods tilt back to their initial positions.',
 'The existing bamboo leaves draw backward, then rotate their attached sharp tips toward the right in a short piercing gesture, recoil and return. Leaf lengths stay fixed.',
 'The existing red fruits swing backward on their stems, then swing forward once, recoil and settle. Fruit sizes stay fixed and every fruit stays attached.',
 'The existing armored petals fold inward, the plant leans forward in a compact shield shove, then the plates return to their original overlapping guard.',
 'The existing orchid stalk bows toward the right, its ivory petals cup inward and reopen to their original positions as the stalk rises.',
 'The existing sunflower head nods backward then forward once while its broad leaves beat down, rise back and settle elastically.',
]
DEATH_MOTION = [
 'The thorn flower loses tension, thorn tips soften, leaves droop and the whole rooted plant slowly withers into a collapsed dry pose.',
 'The prismatic petals lose their inner light, fold inward one by one, then gently sag while the prism colors fade to muted glass.',
 'The lantern blossom dims from warm gold to dark amber, its hanging petals close and the stem bows down into a still wilted pose.',
 'The bell flowers stop ringing, frost highlights melt away, blossoms droop forward and the stems settle into a quiet wilt.',
 'The nectar blossom loses its glow, cups inward, petals become heavy and fold down around the center while remaining rooted.',
 'The three star blossoms dim in sequence, their leaves droop and the stems bend softly until the entire plant rests in a wilted pose.',
 'The curved gale stems lose their lift, bend downward with a natural flexible motion and settle into a limp collapsed silhouette.',
 'The golden bowl closes around the sun pearl, the pearl dims, broad petals sag outward and the rooted bowl rests low and still.',
 'The ember petals cool from orange to dark red, curl inward with a faint fading glow and settle into a dry wilted flower.',
 'The violet blossom and seed pods lose color, compress gently, leaves droop and the whole plant settles into a soft defeated wilt.',
 'The bamboo spear leaves lower one after another, their tips lose stiffness and the rooted stems bend into a natural fallen resting pose.',
 'The red fruit pods lose firmness, shrink slightly and hang low as the supporting leaves droop into a still wilted pose.',
 'The grey-green armor petals stop bracing, plates sag and fold inward, losing their sheen while the rooted plant settles heavily.',
 'The ivory orchid petals close slowly, dew highlights fade, the stem bends and the flower rests in a graceful wilted pose.',
 'The sunflower seed heart dims, broad leaves lower together and the flower head bows forward into a natural exhausted pose.',
]
COMMON = ('Fixed locked orthographic 3/4 overhead camera. Animate only this exact single hand-painted rooted game plant. '
 'Preserve its exact species silhouette, petals, leaves, roots, colors, texture and proportions. '
 'Roots remain anchored at exactly the same pixels throughout, no root movement or walking. '
 'Solid uniform pure magenta #FF00FF background for every frame, no floor, no shadow, no scenery. '
 'No camera movement, zoom, cuts, morphing, extra plants, extra limbs, floating objects or motion blur. '
 'Entire plant remains inside the canvas with generous clear margins. ')

def save(path, value):
 path.parent.mkdir(parents=True,exist_ok=True)
 temp=path.with_suffix(path.suffix+'.part'); temp.write_text(json.dumps(value,indent=2),encoding='utf-8');temp.replace(path)

def root_center(image):
 alpha=image.getchannel('A');box=alpha.point(lambda a:255 if a>32 else 0).getbbox()
 pixels=alpha.load()
 columns=[x for y in range(max(box[1],box[3]-8),box[3]) for x in range(box[0],box[2]) if pixels[x,y]>32]
 return sum(columns)/len(columns)-image.width/2

def attack_display_alignment(idle, pose):
 idle_box=idle.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
 pose_box=pose.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
 scale=(idle_box[3]-idle_box[1])/(pose_box[3]-pose_box[1])
 offset=[root_center(idle)/scale-root_center(pose),
         (idle_box[3]-idle.height/2)/scale-(pose_box[3]-pose.height/2)]
 return round(scale,6),[round(value,4) for value in offset]

def prepare(names, states):
 OUT.mkdir(parents=True,exist_ok=True); (OUT/'.gdignore').write_text('')
 for name in names:
  folder=OUT/name;folder.mkdir(exist_ok=True)
  source=ROOT/'assets/plants/generated/plant_expansion'/f'{name}.png'
  if name in IDS[:2]: source=ROOT/'assets/plants'/('ART_PLANT_ThornFlower_Powered.png' if name==IDS[0] else 'ART_PLANT_PrismFlower_Powered.png')
  original=ROOT/'art_source/generated/plant_mother_static'/f'{name}.source.png'
  image=Image.open(original if original.exists() else source).convert('RGBA')
  box=image.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox();image=image.crop(box)
  image.thumbnail((REFERENCE_SIZE,REFERENCE_SIZE),Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(768,768),(255,0,255,255));canvas.alpha_composite(image,((768-image.width)//2,640-image.height));canvas.convert('RGB').save(folder/'input-magenta.png')
  idle=COMMON+'Gentle living idle: very small natural leaf and petal sway, slight stem breathing. One smooth complete sway cycle during four seconds, start and finish with exactly the reference pose. Root system completely still. No flowering or structural changes.'
  attack=COMMON+ATTACK_MOTION[IDS.index(name)]+' Animate the plant anatomy ONLY: every stem and leaf keeps its original length and thickness. No emitted light, rays, beams, blast, energy disk, aura, projectile, particles, magical effects or colored background changes. Effects are added separately by the game. Show a compact readable anticipation, strike, recoil and recovery with a maximum sideways bend of one quarter of the original plant width. Do not enlarge or stretch the plant. Start at the reference ready pose, anticipate during 0.2 to 0.8 seconds, strike during 0.8 to 1.8, recoil during 1.8 to 2.6 and fully recover by 3.6. End at the exact reference pose. Exactly one action.'
  if MOTION_PROFILE=='compact':
   movement='The existing petals fold inward by ten degrees, the flower head rotates toward the right by ten degrees, then every petal and the stem rotate back to the original positions.'
   if name=='spear_bamboo':movement='The existing bamboo leaves rotate backward by ten degrees about their attachments, rotate forward by fifteen degrees, then rotate back to the initial angles. The stalks bend gently by five degrees and return.'
   attack=COMMON+movement+' These are small rotations of the existing plant parts, not stretching or scaling. Every part keeps the exact original shape, size, length, thickness, texture and brightness. The full silhouette stays inside a rectangle only ten percent larger than the reference plant. Perform this once between 0.4 and 3.2 seconds with a clear preparation, quick forward motion and soft recovery. Start and end on the exact reference pose. The background stays uniformly magenta. No additional objects, no beams, no rays, no extra long leaves, no glow or special effects.'
  death=COMMON+DEATH_MOTION[IDS.index(name)]+' This is a clear death animation, not an idle sway: the flower head and upper leaves must visibly bow downward, losing at least one third of the initial upper-body height, becoming desaturated and limp. Hold the exact living pose for 0.15 seconds, perform the irreversible withering once between seconds 0.15 and 2.2, then hold the final dead pose until the end. Never recover to the living pose. The root contact point stays fixed. No particles, smoke, gore, detached parts, transparency fade, or extra objects.'
  revive=COMMON+'Start in the exact wilted dead pose of the first image. Roots stay completely fixed. The existing limp stems slowly regain tension and rotate upright, leaves unfold, petals reopen and the original flower color returns. All stems, vines and leaves retain their original lengths: do not grow, elongate, enlarge or add any plant parts. At every moment the plant fits within the bounding box of the healthy last image. Rise during 0.1 to 2.0 seconds, unfurl petals during 2.0 to 3.4, settle smoothly into the exact healthy pose of the last image by 3.8 seconds. Never collapse again, no particles, glowing rays, aura or scenery.'
  for state,prompt in [('idle',idle),('attack',attack),('death',death),('revive',revive)]:
   if state in states:(folder/f'{state}.prompt.txt').write_text(prompt,encoding='utf-8')
  if 'revive' in states:
   runtime=ROOT/'assets/plants/animations'/name
   manifest=json.loads((runtime/'manifest.json').read_text())
   dead=Image.open(runtime/f"death-{manifest['states']['death']['frames']-1:03d}.png").convert('RGBA')
   alive=Image.open(runtime/'idle-000.png').convert('RGBA')
   alive_box=alive.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
   scale=image.height/(alive_box[3]-alive_box[1])
   for role,pose in [('input',dead),('last',alive)]:
    size=round(160*scale);pose=pose.resize((size,size),Image.Resampling.LANCZOS)
    reference=Image.new('RGBA',(768,768),(255,0,255,255))
    reference.alpha_composite(pose,(round(384-80*scale),round(640-alive_box[3]*scale)))
    reference.convert('RGB').save(folder/f'revive.{role}-magenta.png')

def request(method,url,payload=None):
 data=None if payload is None else json.dumps(payload).encode()
 req=urllib.request.Request(url,data=data,method=method,headers={'Authorization':'Bearer '+os.environ['ARK_API_KEY'],'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=90) as response:return json.load(response)
 except urllib.error.HTTPError as error:
  body=json.loads(error.read().decode());message=str(body.get('error',{}).get('message',''))
  message=message.replace(os.environ['ARK_API_KEY'],'[REDACTED]')
  raise RuntimeError(f'HTTP {error.code}: {message[:400]}') from None

def generate(name,state):
 if not os.environ.get('ARK_API_KEY'):raise RuntimeError('ARK_API_KEY is required before creating a task')
 folder=OUT/name;target=folder/f'{state}.mp4';task=folder/f'{state}.task.json';intent=folder/f'{state}.intent.json'
 if target.exists():return True
 if task.exists():task_id=json.loads(task.read_text())['id']
 else:
  if intent.exists():raise RuntimeError('Unresolved previous creation intent; inspect before resubmitting')
  input_path=folder/f'{state}.input-magenta.png'
  if not input_path.exists():input_path=folder/'input-magenta.png'
  image='data:image/png;base64,'+base64.b64encode(input_path.read_bytes()).decode()
  content=[{'type':'text','text':(folder/f'{state}.prompt.txt').read_text(encoding='utf-8')},{'type':'image_url','image_url':{'url':image},'role':'first_frame'},{'type':'image_url','image_url':{'url':image},'role':'last_frame'}]
  if state=='death':content=content[:-1]
  if state=='revive':
   ending='data:image/png;base64,'+base64.b64encode((folder/'revive.last-magenta.png').read_bytes()).decode()
   content[-1]['image_url']['url']=ending
  size=Image.open(input_path).size;ratio='3:4' if size[1]>size[0] else '1:1'
  payload={'model':MODEL,'content':content,'duration':4,'ratio':ratio,'generate_audio':False,'watermark':False}
  save(intent,{'model':MODEL,'duration':4,'state':state})
  result=request('POST',API,payload);task_id=result['id'];save(task,{'id':task_id,'model':MODEL});print(name,state,'submitted',flush=True)
 for attempt in range(120):
  result=request('GET',API+'/'+task_id);status=result.get('status')
  save(folder/f'{state}.status.json',{k:v for k,v in result.items() if k not in ['content','error']})
  if status=='succeeded':
   with urllib.request.urlopen(result['content']['video_url'],timeout=120) as response:data=response.read()
   if b'ftyp' not in data[:32]:raise RuntimeError('Invalid MP4')
   temp=target.with_suffix('.mp4.part');temp.write_bytes(data);temp.replace(target);print(name,state,'downloaded',flush=True);return True
  if status in ['failed','expired','cancelled']:raise RuntimeError('Ark task '+status+': '+str(result.get('error',{}).get('code','unknown')))
  if attempt%8==0:print(name,state,status,flush=True)
  time.sleep(10)
 raise RuntimeError('Task pending; resume using saved task ID')

def process(name,state):
 folder=OUT/name;frames=folder/f'{state}-frames';loop=folder/f'{state}-loop'
 processing_clip=folder/f'{state}.processing.mp4'
 if not (frames/'frames.report.json').exists() and not processing_clip.exists():
  # Preserve source motion at the requested sampling rate and scale
  # for 160px gameplay before canonical extraction; no synthetic frames.
  source_info=subprocess.check_output([str(FFPROBE),'-v','quiet','-show_entries','stream=width,height,r_frame_rate','-of','json',str(folder/f'{state}.mp4')],text=True)
  save(folder/f'{state}.source-probe.json',json.loads(source_info))
  subprocess.run([str(FFMPEG),'-y','-v','error','-i',str(folder/f'{state}.mp4'),'-vf',f'scale=480:-2:flags=lanczos,fps={SAMPLE_FPS}','-an','-c:v','libx264rgb','-crf','0','-preset','fast',str(processing_clip)],check=True)
 commands=[]
 reference=folder/f'{state}.input-magenta.png'
 if not reference.exists():reference=folder/'input-magenta.png'
 if not (frames/'frames.report.json').exists():commands.append(['video-frames','--clip',str(processing_clip),'--out-dir',str(frames),'--key','magenta','--spill','auto','--reference',str(reference),'--decontam','auto'])
 for args in commands:
  result=subprocess.run([str(PYTHON),str(RUNNER),*args],capture_output=True,text=True,encoding='utf-8',errors='replace');(folder/f'{state}-frames.log').write_text(result.stdout+result.stderr,encoding='utf-8')
  if result.returncode:raise RuntimeError('Sprite-gen frame QA failed; see log')
 fps=json.loads((frames/'frames.report.json').read_text())['fps']
 boxes=[Image.open(p).getchannel('A').point(lambda a:255 if a>16 else 0).getbbox() for p in sorted((frames/'keyed').glob('*.png'))]
 first=boxes[-1] if state=='revive' else boxes[0];first_height=first[3]-first[1]
 max_width=max(b[2]-b[0] for b in boxes);max_height=max(b[3]-b[1] for b in boxes)
 dest=ROOT/'assets/plants/animations'/name
 canvas_size=320 if state in ['attack','revive'] else 160
 baseline=canvas_size//2+59
 alive_box=Image.open(dest/'idle-000.png').getchannel('A').point(lambda a:255 if a>32 else 0).getbbox() if state in ['attack','revive'] else None
 body_height=(alive_box[3]-alive_box[1]) if alive_box else max(1,int(first_height*min(136/first_height,140/max_width,132/max_height)))
 width_limit=canvas_size-2; height_limit=baseline
 existing_meta=json.loads((loop/f'{state}.strip.json').read_text()) if (loop/f'{state}.strip.json').exists() else {}
 if state in ['attack','revive'] or not (loop/f'{state}.loop.report.json').exists() or existing_meta.get('w',0)>width_limit or existing_meta.get('h',0)>height_limit:
  args=['video-loop','--frames-dir',str(frames/'keyed'),'--out-dir',str(loop),'--fps',str(fps),'--state',state,'--cycle','pinned','--anchor','none','--body-height',str(body_height),'--strip-height',str(canvas_size-6),'--gif-fps',str(fps),'--n-out',str(len(boxes)-1),'--name',state]
  if state=='death':
   # A non-looping death has no return seam. Exclude the pinned recovery tail.
   length=min(len(boxes),int(round(fps*2.7)))
   args[args.index('--cycle')+1]='fixed'
   args[args.index('--n-out')+1]=str(length)
   args+=['--start','0','--length',str(length),'--seam-max','1000']
  elif state=='revive':
   args[args.index('--cycle')+1]='fixed'
   args[args.index('--n-out')+1]=str(len(boxes))
   args+=['--start','0','--length',str(len(boxes)),'--seam-max','1000']
   # Scale against the healthy ending, rather than enlarging a collapsed first pose.
   args[args.index('--body-height')+1]=str(max(1,int(body_height*(boxes[0][3]-boxes[0][1])/first_height)))
  result=subprocess.run([str(PYTHON),str(RUNNER),*args],capture_output=True,text=True,encoding='utf-8',errors='replace');(folder/f'{state}-loop.log').write_text(result.stdout+result.stderr,encoding='utf-8')
  if result.returncode:raise RuntimeError('Sprite-gen loop QA failed; see log')
 report=json.loads((loop/f'{state}.loop.report.json').read_text());meta=json.loads((loop/f'{state}.strip.json').read_text())
 if report['status']!='passed':raise RuntimeError('Loop not passed')
 if meta['h']>height_limit or meta['w']>width_limit:
  # Alpha fringes can exceed measured anatomy. Ask the canonical composer to
  # reduce its own scale; do not crop or rescale extracted cells ourselves.
  adjusted=max(1,int(meta['body_h']*min((width_limit-10)/meta['w'],(height_limit-9)/meta['h'])))
  args[args.index('--body-height')+1]=str(adjusted)
  result=subprocess.run([str(PYTHON),str(RUNNER),*args],capture_output=True,text=True,encoding='utf-8',errors='replace')
  (folder/f'{state}-fit.log').write_text(result.stdout+result.stderr,encoding='utf-8')
  if result.returncode:raise RuntimeError('Canonical runtime fit failed')
  meta=json.loads((loop/f'{state}.strip.json').read_text())
  if meta['h']>height_limit or meta['w']>width_limit:raise RuntimeError('Runtime canvas would clip')
 strip=Image.open(loop/f'{state}.strip.png').convert('RGBA');dest=ROOT/'assets/plants/animations'/name;dest.mkdir(parents=True,exist_ok=True)
 if state in ['attack','revive']:
  alive_box=Image.open(dest/'idle-000.png').getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
  endpoint=meta['frames']-1 if state=='revive' else 0
  endpoint_box=strip.crop((endpoint*meta['w'],0,(endpoint+1)*meta['w'],meta['h'])).getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
  ratios=[(endpoint_box[i+2]-endpoint_box[i])/(alive_box[i+2]-alive_box[i]) for i in (0,1)]
  if not all(0.7<=r<=1.4 for r in ratios):raise RuntimeError(f'Action endpoint size mismatch: {ratios}; regenerate compact motion')
 for i in range(meta['frames']):
  cell=strip.crop((i*meta['w'],0,(i+1)*meta['w'],meta['h']));canvas=Image.new('RGBA',(canvas_size,canvas_size));canvas.alpha_composite(cell,((canvas_size-meta['w'])//2,baseline-meta['h']));canvas.save(dest/f'{state}-{i:03d}.png')
 with LOCKS[name]:
  manifest_path=dest/'manifest.json';manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'species':name,'engine':'sprite-gen-video','model':MODEL,'canvas':[160,160],'states':{}}
  manifest['states'][state]={'frames':meta['frames'],'fps':1000.0/meta['delay_ms'],'loop':state=='idle','canvas':[canvas_size,canvas_size],'root_offset':[0,59],'source':str((folder/f'{state}.mp4').relative_to(ROOT)),'report':str((loop/f'{state}.loop.report.json').relative_to(ROOT))}
  endpoint=meta['frames']-1 if state=='revive' else 0
  manifest['states'][state]['draw_offset']=[round(root_center(Image.open(dest/'idle-000.png'))-root_center(Image.open(dest/f'{state}-{endpoint:03d}.png')),2),0]
  if state=='attack':
   display_scale,draw_offset=attack_display_alignment(Image.open(dest/'idle-000.png'),Image.open(dest/'attack-000.png'))
   manifest['states'][state].update(display_scale=display_scale,draw_offset=draw_offset)
  save(manifest_path,manifest)
 print(name,state,'published',meta['frames'],'frames',flush=True)

def main():
 global OUT, SAMPLE_FPS, REFERENCE_SIZE, MOTION_PROFILE
 parser=argparse.ArgumentParser();parser.add_argument('stage',choices=['prepare','videos','process','follow']);parser.add_argument('--names',nargs='+',default=IDS);parser.add_argument('--states',nargs='+',default=['idle','attack','death','revive']);parser.add_argument('--workers',type=int,default=2);parser.add_argument('--out-root',type=Path,default=OUT)
 parser.add_argument('--sample-fps',type=int,default=24)
 parser.add_argument('--reference-size',type=int,default=490)
 parser.add_argument('--motion-profile',choices=['expressive','compact'],default='expressive')
 args=parser.parse_args()
 OUT=args.out_root.resolve(); SAMPLE_FPS=args.sample_fps; REFERENCE_SIZE=args.reference_size; MOTION_PROFILE=args.motion_profile
 if args.stage=='prepare':prepare(args.names,args.states);return
 def run(job):
  try:(generate if args.stage=='videos' else process)(*job);return True
  except Exception as error:print(*job,'FAILED',str(error),flush=True);return False
 jobs=[(n,s) for n in args.names for s in args.states]
 if args.stage=='follow':
  pending=set(jobs);active={};results=[];deadline=time.monotonic()+3600
  with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
   while (pending or active) and time.monotonic()<deadline:
    for job in sorted(pending):
     n,s=job;manifest=ROOT/'assets/plants/animations'/n/'manifest.json'
     expected=str((OUT/n/f'{s}.mp4').relative_to(ROOT))
     if manifest.exists() and json.loads(manifest.read_text())['states'].get(s,{}).get('source')==expected:
      pending.remove(job);results.append(True);continue
     if (OUT/n/f'{s}.mp4').exists() and len(active)<args.workers:
      active[pool.submit(run,job)]=job;pending.remove(job)
    for future in list(active):
     if future.done():results.append(future.result());active.pop(future)
    time.sleep(5)
  if pending:print('Pending videos:',sorted(pending),flush=True);results.append(False)
 else:
  with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:results=list(pool.map(run,jobs))
 if not all(results):raise SystemExit('Some plant jobs incomplete')

if __name__=='__main__':main()
