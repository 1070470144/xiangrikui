"""Compare published game PNGs at runtime scale and attack cadence (2x display)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'art_source/generated/monster_video_batch'
SPECS = [('shadow_beast','影兽',1.10),('erosion_bug','蚀芽虫',0.90),('husk_ram','枯壳撞兽',1.20),('spore_moth','腐孢蛾',1.80),('shell_scarab','黑甲育虫',1.50)]
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
cache = {}
for name,label,interval in SPECS:
    folder = ROOT/'assets/enemies/animations'/name
    manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
    cache[name]=(manifest,{s:[Image.open(folder/f'{s}-frame-{i}.png').convert('RGBA') for i in range(spec['frames'])] for s,spec in manifest['animation']['rows'].items()})

frames=[]
for tick in range(96):
    t=tick/24
    out=Image.new('RGB',(800,1190),(25,32,43))
    draw=ImageDraw.Draw(out)
    draw.text((20,8),'移动循环',font=font,fill=(211,198,173))
    draw.text((420,8),'攻击 → 恢复（按游戏攻速）',font=font,fill=(211,198,173))
    for row,(name,label,interval) in enumerate(SPECS):
        manifest,images=cache[name]
        runtime=manifest['runtime']
        for col,state in enumerate(['walk','attack']):
            spec=manifest['animation']['rows'][state]
            duration=min(len(images['attack'])/manifest['animation']['rows']['attack']['fps'],interval*0.8)
            attack_t=(t%2)-0.2
            active=state=='walk' or 0<=attack_t<duration
            use=state if active else 'walk'
            layout=manifest['animation']['rows'][use]
            index=int(t*spec['fps'])%spec['frames'] if state=='walk' else min(spec['frames']-1,int(attack_t/duration*spec['frames'])) if active else 0
            im=images[use][index]
            scale=runtime['scale']*2
            im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
            floor=225+row*230
            x=col*400+200-im.width//2
            y=round(floor+runtime['ground_offset']*2-layout['ground_y']*scale)
            out.paste(im,(x,y),im)
            draw.line((col*400+20,floor,col*400+380,floor),fill=(53,61,69))
            if col==0: draw.text((col*400+15,34+row*230),label,font=font,fill=(186,197,201))
    frames.append(out)
frames[0].save(OUT/'game-preview.png')
frames[0].save(OUT/'game-preview.gif',save_all=True,append_images=frames[1:],duration=42,loop=0,optimize=True)
print(OUT/'game-preview.gif')
