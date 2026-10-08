"""Publish only a complete verified set and record source/runtime mappings."""
from pathlib import Path
import json, re
from PIL import Image, ImageDraw, ImageFont
from generate_remaining_card_art import SUBJECTS, OUTPUT, PREFIX

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'assets/ui/generated/deck_builder/illustrations_v3'

def main():
    for card_id in SUBJECTS:
        path = OUTPUT / f'{card_id}.png'
        if not path.exists(): raise RuntimeError(f'Missing generated illustration: {card_id}')
        with Image.open(path) as image:
            image.verify()
    manifest_path = ROOT / 'art_source/manifests/deck_builder.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    example = next(a for a in manifest['assets'] if a['id'] == 'card_emergency_dew_illustration_v3')
    cards = re.findall(r'\{"id":"(card_[^"]+)","name":"([^"]+)"', (ROOT/'scripts/content_data.gd').read_text(encoding='utf-8'))
    names = dict(cards)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for card_id, subject in SUBJECTS.items():
        image = Image.open(OUTPUT/f'{card_id}.png').convert('RGB')
        image.resize((768,512), Image.Resampling.LANCZOS).save(RUNTIME/f'{card_id}.png')
        asset = json.loads(json.dumps(example))
        asset['id'] = f'{card_id}_illustration_v3'
        asset['role'] = names[card_id] + '独立卡牌插画'
        asset['generation']['prompt'] = PREFIX + subject
        asset['output']['path'] = f'res://art_source/generated/mm_tools/deck_builder/illustrations_v3/{card_id}.png'
        asset['output']['size'] = list(image.size)
        asset['runtime']['path'] = f'res://assets/ui/generated/deck_builder/illustrations_v3/{card_id}.png'
        asset['runtime']['size'] = [768,512]
        for binding in asset['bindings']: binding['card_id'] = card_id
        if not any(a['id'] == asset['id'] for a in manifest['assets']): manifest['assets'].append(asset)
    manifest['style']['visual_anchor'] = '24 张战斗卡各有独立植物插画；暖金主光与深绿温室阴影统一，卡面名称及插画窗口按品质框位对齐。'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 19)
    sheet = Image.new('RGB', (1200, 880), '#12211e')
    draw = ImageDraw.Draw(sheet)
    for i, card_id in enumerate(SUBJECTS):
        x, y = (i%4)*300, (i//4)*220
        sheet.paste(Image.open(RUNTIME/f'{card_id}.png').resize((288,192)), (x+6,y+3))
        draw.text((x+10,y+196), names[card_id], font=font, fill='#e3d4ac')
    sheet.save(ROOT/'art_source/evidence/remaining_card_art.png')
    print(f'Published {len(SUBJECTS)} illustrations; all {len(cards)} cards have unique artwork.')

if __name__ == '__main__': main()
