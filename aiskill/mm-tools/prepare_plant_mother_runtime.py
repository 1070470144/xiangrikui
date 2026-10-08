"""Fit verified full-image botanical assets to existing Godot canvas sizes.

This is runtime sizing of standalone images, not sprite row extraction.
Keep the unmodified engine output and report as generation evidence.
"""
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'art_source/generated/plant_mother_static'

def main():
    (EVIDENCE/'.gdignore').write_text('',encoding='utf-8')
    results = []
    for category, size, body in [('plants/generated/plant_expansion',160,136), ('core/generated/mother_forms',256,218)]:
        for path in sorted((ROOT/'assets'/category).glob('*.png')):
            if path.name.endswith('.raw.png'): continue
            source = EVIDENCE / (path.stem + '.source.png')
            if not source.exists(): shutil.copy2(path,source)
            image = Image.open(source).convert('RGBA')
            alpha = image.getchannel('A')
            bbox = alpha.point(lambda a: 255 if a > 16 else 0).getbbox()
            if not bbox: raise ValueError(f'Empty image: {path.name}')
            cropped = image.crop(bbox)
            cropped.thumbnail((body,body), Image.Resampling.LANCZOS)
            canvas = Image.new('RGBA',(size,size))
            x = (size-cropped.width)//2
            y = int(size*0.87)-cropped.height
            canvas.paste(cropped,(x,y))
            # Fully transparent pixels must carry no hidden matte RGB.
            pixels = canvas.load()
            for py in range(size):
                for px in range(size):
                    if pixels[px,py][3] == 0: pixels[px,py] = (0,0,0,0)
            canvas.save(path)
            raw = path.with_name(path.name+'.raw.png')
            if raw.exists(): shutil.move(str(raw),str(EVIDENCE/(path.stem+'.raw.png')))
            raw_import = raw.with_name(raw.name+'.import')
            if raw_import.exists(): raw_import.unlink()
            results.append({'id':path.stem,'canvas':[size,size],'bbox':list(canvas.getchannel('A').getbbox()),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (EVIDENCE/'runtime_sizes.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    frame = ROOT/'assets/ui/generated/mother_buff_ui/mother_buff_card_frame.png'
    frame_raw = frame.with_name(frame.name+'.raw.png')
    if frame_raw.exists(): shutil.move(str(frame_raw),str(EVIDENCE/'mother_buff_card_frame.raw.png'))
    frame_raw_import = frame_raw.with_name(frame_raw.name+'.import')
    if frame_raw_import.exists(): frame_raw_import.unlink()
    manifest = {'contract':'plant_mother_static_runtime','date':'2026-10-02','provider':'sprite-gen/openai-gateway',
                'api_base':'https://newapi.oairegbox.cc/v1','model':'gpt-image-2','kind':'standalone_static_images',
                'counts':{'plant_images':13,'mother_form_images':57,'choice_frame_images':1},
                'runtime_images':results,'frame':'res://assets/ui/generated/mother_buff_ui/mother_buff_card_frame.png',
                'source_evidence':'res://art_source/generated/plant_mother_static/',
                'video_generated':False}
    (ROOT/'art_source/manifests/plant_mother_static_runtime.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    # Contact sheet is review evidence, never a runtime sprite atlas.
    width,cell = 960,160
    sheet = Image.new('RGB',(width,((len(results)+5)//6)*190),'#142131')
    draw = ImageDraw.Draw(sheet)
    for i, entry in enumerate(results):
        category = 'plants/generated/plant_expansion' if not entry['id'].startswith('mother_') and entry['id'] not in ['sun_arrow','root_heart','dawn_pulse'] else 'core/generated/mother_forms'
        image = Image.open(ROOT/'assets'/category/(entry['id']+'.png')).convert('RGBA')
        image.thumbnail((150,150),Image.Resampling.LANCZOS)
        x,y=(i%6)*cell,(i//6)*190
        sheet.paste(image,(x+(cell-image.width)//2,y+5),image)
        draw.text((x+4,y+158),entry['id'],fill='#eee1c1')
    if results: sheet.save(EVIDENCE/'contact_sheet.png')
    print(f'Prepared {len(results)} standalone runtime images')

if __name__ == '__main__': main()
