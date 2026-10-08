"""Complete the remaining sixteen unique card illustrations with sprite-gen."""
from pathlib import Path
import concurrent.futures, json
from generate_deck_art_v3 import generate, OUTPUT, PREFIX

SUBJECTS = {
 'card_transplant_shovel': 'An antique brass gardening spade gently lifting a healthy young flowering plant with its intact ball of soil and luminous roots, preparing to transplant it; warm daytime greenhouse light, clear spade and root-ball silhouette.',
 'card_frenzy_growth': 'A fierce thorn flower rapidly unfurling vibrant leaves and sharp branching vines, glowing amber sap rushing through its stem, dynamic spiraling growth burst at night; energetic organic motion, dominant flower at center.',
 'card_local_repair_rain': 'A gentle localized shower of luminous turquoise dewdrops over a small cluster of torn leaves and damaged botanical lanterns, wounds closing into healthy foliage beneath the rain; focused restorative garden scene.',
 'card_hex_break_lamp': 'A living brass-and-leaf garden lantern releasing a radiant warm halo that breaks smoky violet curse tendrils into drifting harmless particles; prominent luminous lantern surrounded by freed healthy leaves.',
 'card_sun_arrow_rain': 'Several bright golden sunflower-tipped arrows raining diagonally from above onto a dark garden path, trails of radiant pollen in midnight mist; distinct repeated arrow silhouettes and powerful concentrated solar volley.',
 'card_root_prison': 'An imposing cage of curved woody roots arching around a trapped dark shadow beast, moss-covered living bars and a faint amber root pulse; clear closed prison silhouette with bound creature at center.',
 'card_golden_rain': 'Warm shimmering golden rain falling across a lush cluster of flowers and broad leaves, damaged plants recovering under the amber droplets; golden restorative cascade distinct from cool single-drop healing.',
 'card_temporary_sprout': 'A fresh luminous emerald sprout emerging from dark soil, its translucent leaves enclosing a bright solar seed and spreading a network of glowing root connections to nearby seedlings; temporary botanical light source.',
 'card_node_overload': 'A botanical light node bursting with concentrated amber energy, glowing leaf veins and roots sending intense branching luminous pulses into the surrounding network; energized seed bulb under controlled overload.',
 'card_path_beacon': 'A tall living beacon flower with a golden lantern-like seed head above a winding moonlit garden path, a trail of tiny fireflies converging toward the bright bud; tall guiding silhouette and readable curved path.',
 'card_phantom_bloom': 'A solid emerald fighting flower next to its translucent ghostly teal duplicate blooming from swirling golden pollen, clearly two mirrored organic blossoms with one spectral silhouette; magical botanical echo.',
 'card_weather_seal': 'A protective dome woven from interlocking luminous leaves above a greenhouse garden, holding back storm clouds, wind and cold rain outside; calm clear plants inside the sealed botanical canopy.',
 'card_time_stasis': 'An immense radiant sunflower sun disk rising at dawn over a garden where dewdrops, fallen petals and dark shadow beasts hang motionless in midair, concentric amber light ripples freezing the moment; legendary serene solar time magic.',
 'card_golden_domain': 'A majestic mature sunflower surrounded by a wide circular sanctuary of golden roots and glowing pollen, smaller garden flowers flourishing within the warm dome while darkness stays beyond; legendary golden protective domain.',
 'card_garden_resurrection': 'Several wilted fallen garden flowers rising back into life from richly glowing golden roots, an enormous radiant sunflower behind them illuminating fresh green shoots emerging from cracked soil; legendary botanical resurrection, unmistakable rebirth.',
 'card_shadow_redemption': 'A powerful dark wolf-like shadow creature being transformed by golden living vines and sunflower light, one half smoky charcoal and the other half emerald leaves and warm amber fur, peaceful glowing eyes; legendary conversion from shadow into a garden ally.',
}

if __name__ == '__main__':
 OUTPUT.mkdir(parents=True, exist_ok=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  for card_id, status in pool.map(generate, SUBJECTS.items()):
   print(json.dumps({'card': card_id, 'status': status}), flush=True)
