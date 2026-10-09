"""New Ark credential trial, with saved task IDs and canonical sprite-gen canvas."""
import re
from pathlib import Path
import sun_boss_redesign
import root_boss_redesign as pipeline

if __name__ == '__main__':
    pipeline.credentials()
    config = Path('C:/Users/mengmenglv/Desktop/秘钥.txt').read_text(encoding='utf-8-sig')
    models = re.findall(r'"model"\s*:\s*"([^"\s]+)"', config)
    if not models:
        raise RuntimeError('No explicit Ark model in configuration')
    pipeline.MODEL = models[0]
    pipeline.OUT = pipeline.ROOT / 'art_source/generated/sun_boss_redesign_20261009/ark-new-animations'
    pipeline.OUT.mkdir(parents=True, exist_ok=True)
    import shutil
    if not (pipeline.OUT / 'original.png').exists():
        shutil.copy2(pipeline.OUT.parent / 'original.png', pipeline.OUT / 'original.png')
    pipeline.MOTIONS = {
        'attack': 'Preserve the exact attached BLACK SOLAR HALO crown and charcoal root armor. One slow right arm strike, windup, single impact, recover. Two planted root feet, full body visible, exact pure green background, no floor or shadows, no zoom.',
        'summon': 'Preserve the exact attached design. Raise both root arms and open a solar portal gesture, pulse chest once, recover. Full body visible, exact pure green background, no floor or shadows, no zoom.',
        'laser_charge': 'Preserve the exact attached design. Brace in place and charge the gold-red chest core for three seconds, arms locked, full body visible, exact pure green background, no floor or shadows, no zoom.',
        'laser': 'Preserve the exact attached design. Hold a rigid laser firing stance for three seconds, chest core bright, no beam in character layer, full body visible, exact pure green background, no floor or shadows, no zoom.'}
    pipeline.videos()
