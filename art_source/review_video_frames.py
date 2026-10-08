"""Contact sheet only: visual inspection of keyed source frames, no asset extraction."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument('folder', type=Path)
args = parser.parse_args()
files = sorted((args.folder/'keyed').glob('*.png'))
indices = [round(i*(len(files)-1)/11) for i in range(12)]
images = [Image.open(files[i]).convert('RGBA') for i in indices]
boxes = [im.getbbox() for im in images]
box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
out = Image.new('RGB', (1000,600),(45,48,57))
draw = ImageDraw.Draw(out)
for k,(index,im) in enumerate(zip(indices,images)):
    im = im.crop(box)
    im.thumbnail((250,175))
    pos=((k%4)*250,(k//4)*200)
    out.paste(im,pos,im)
    draw.text((pos[0]+5,pos[1]+175),str(index),fill='white')
out.save(args.folder/'source-contact.png')
