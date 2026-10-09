"""Sun boss production via the existing authenticated sprite-gen pipeline."""
import argparse
from pathlib import Path
import root_boss_redesign as pipeline

pipeline.OUT = pipeline.ROOT / 'art_source/generated/sun_boss_redesign_20261009'
pipeline.DESIGN = ('One colossal dark botanical eclipse deity, SUN DEVOURER, black solar halo crown, '
    'exactly two massive root legs and two root arms, cracked charcoal bark armor, glowing gold-red '
    'solar chest core. Monumental unique silhouette, far larger and more regal than a tree colossus. '
    'Elevated orthographic three quarter game view facing RIGHT. Entire body including crown and feet '
    'occupies only 45 percent of image height, generous empty margins. Pure green #00FF00 background, '
    'no floor, shadow, scenery, text or green reflections. One character, not a sprite sheet.')
pipeline.MOTIONS = {
    'idle': 'Three identical slow breathing cycles; planted feet, first and last pose match.',
    'walk': 'Three heavy walking-in-place cycles, stable root feet and grounded weight transfer.',
    'attack': 'One massive root arm strike to the right, anticipation, impact, recover.',
    'devour': 'One chest core charging and swallowing sunlight gesture, recover original stance.',
    'summon': 'One ritual: raise root arms, open palms, pulse solar core at 1 second, recover.',
    'laser_charge': 'Chest core charges for 3 seconds, arms brace, hold aimed pose.',
    'laser': 'Hold a braced chest laser firing pose for 3 seconds, recover. No beam in character layer.',
    'exposed': 'Three identical cycles of exposed gold-red core pulsing, stationary body.',
    'enraged': 'Three fierce gold-red core pulsing cycles, braced stationary body.',
    'death': 'One death collapse, halo breaks and chest extinguishes, remain dead at end.',
    'spawn': 'One slow emergence from root crouch into full ready stance, hold at end.',
}
pipeline.FX = {
    'devour_fx': 'A gold-red solar energy vortex flowing into an empty central core.',
    'summon_fx': 'A black and gold-red botanical summoning portal, roots part then retract.',
    'laser_fx': 'One straight narrow gold-red laser beam pointing horizontally right, steady bright core, no branches.',
    'impact': 'A small sharp gold-red laser impact spark burst, then disappear.',
    'exposed_fx': 'Gold-red solar core exposure aura, three full pulse cycles.',
    'enraged_fx': 'Jagged gold-red solar corona aura, three full pulse cycles.',
}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['image', 'videos', 'effects', 'effect_videos', 'process'])
    args = parser.parse_args()
    pipeline.credentials()
    getattr(pipeline, args.stage)()
