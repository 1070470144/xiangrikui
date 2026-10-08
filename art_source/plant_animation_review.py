"""Review exported canonical animation cells; no generation or extraction."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
IDS=['thorn_flower','prism_flower','lantern_flower','frost_bell','honeydew_flower','storm_flower','gale_flower','sunwell_flower','ember_flower','slumber_flower','spear_bamboo','burst_flower','stone_flower','cleanse_flower','drum_flower']

def main():
 reports=[]
 for name in IDS:
  folder=ROOT/'assets/plants/animations'/name
  manifest=json.loads((folder/'manifest.json').read_text())
  for state in ['idle','attack']:
   spec=manifest['states'][state];images=[Image.open(folder/f'{state}-{i:03d}.png').convert('RGBA') for i in range(spec['frames'])]
   boxes=[im.getchannel('A').getbbox() for im in images]
   arrays=[np.asarray(im) for im in images]
   unique=len(set(hashlib.sha256(a.tobytes()).hexdigest() for a in arrays))
   assert unique>8, (name,state,'motion missing')
   assert all(im.size==(160,160) for im in images)
   assert all(b and b[0]>0 and b[1]>0 and b[2]<160 and b[3]<=139 for b in boxes), (name,state,'edge')
   assert all(np.all(a[a[:,:,3]==0,:3]==0) for a in arrays), (name,state,'hidden matte')
   bottoms=[b[3] for b in boxes]
   foot_x=[]
   for a,b in zip(arrays,boxes):
    alpha=a[max(0,b[3]-12):b[3],:,3].astype(float);weights=alpha.sum(axis=0);foot_x.append(float(np.dot(weights,np.arange(160))/max(1,weights.sum())))
   assert max(foot_x)-min(foot_x)<=6, (name,state,'root x drift')
   assert max(bottoms)-min(bottoms)<=5, (name,state,'root y drift')
   reports.append({'species':name,'state':state,'frames':spec['frames'],'unique_frames':unique,'seconds':spec['frames']/spec['fps'],'ground_y_range':[min(bottoms),max(bottoms)],'root_x_range_px':round(max(foot_x)-min(foot_x),2),'root_y_range_px':max(bottoms)-min(bottoms),'source':spec['source']})
  # Both clips start at the same reference pose. Union fitting must not turn
  # an attack into a miniature plant when the model invents oversized effects.
  poses=[Image.open(folder/f'{state}-000.png').getchannel('A').point(lambda a:255 if a>32 else 0).getbbox() for state in ['idle','attack']]
  for axis in [0,1]:
   ratio=(poses[1][axis+2]-poses[1][axis])/(poses[0][axis+2]-poses[0][axis])
   assert 0.75<=ratio<=1.33, (name,'state size mismatch',axis,ratio)
 out=ROOT/'art_source/generated/plant_video_ark';(out/'runtime-review.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
 for state in ['idle','attack']:
  animation=[]
  for step in range(48):
   sheet=Image.new('RGB',(800,540),'#142131');draw=ImageDraw.Draw(sheet)
   for i,name in enumerate(IDS):
    folder=ROOT/'assets/plants/animations'/name;spec=json.loads((folder/'manifest.json').read_text())['states'][state]
    index=int(step/12*spec['fps'])%spec['frames'];im=Image.open(folder/f'{state}-{index:03d}.png').convert('RGBA')
    x,y=(i%5)*160,(i//5)*180;sheet.paste(im,(x,y),im);draw.text((x+5,y+153),name.replace('_flower',''),fill='#eee1c1')
   animation.append(sheet)
  animation[0].save(out/f'{state}-overview.gif',save_all=True,append_images=animation[1:],duration=83,loop=0,optimize=True)
  animation[12].save(out/f'{state}-overview.png')
 print('Reviewed 30 animation states; saved original-speed motion previews')

if __name__=='__main__':main()
