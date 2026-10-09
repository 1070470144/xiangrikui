extends RefCounted

const DECK_SIZE := 12
const STARTING_HAND_SIZE := 4
const STARTER_CARD_IDS := [
	"card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall",
	"card_sun_mine", "card_lure_bud", "card_emergency_light", "card_focus_mark"
]

const FLOWERS := [
	{"id":"light_sprout", "name":"光脉芽", "health":120.0, "seed_cost":0, "capacity":5, "supply_radius":210.0},
	{"id":"thorn_flower", "name":"荆棘花", "health":115.0, "seed_cost":1, "capacity":1, "range":115.0, "damage":20.0, "interval":0.64, "max_targets":10},
	{"id":"prism_flower", "name":"棱镜花", "health":115.0, "seed_cost":2, "capacity":1, "range":235.0, "damage":30.0, "interval":1.05},
	{"id":"lantern_flower", "name":"守灯花", "health":105.0, "seed_cost":2, "capacity":1, "range":150.0, "stored_duration":11.0},
	{"id":"frost_bell", "name":"霜铃花", "health":100.0, "seed_cost":2, "capacity":1, "range":180.0, "damage":9.0, "interval":1.20, "slow":0.32, "slow_duration":3.0},
	{"id":"honeydew_flower", "name":"蜜露花", "health":125.0, "seed_cost":2, "capacity":1, "range":160.0, "heal":11.0, "interval":2.6},
	{"id":"storm_flower", "name":"雷链花", "health":100.0, "seed_cost":2, "range":185.0, "damage":20.0, "interval":1.55, "chain_range":100.0, "max_targets":4},
	{"id":"gale_flower", "name":"风铃草", "health":110.0, "seed_cost":2, "range":170.0, "damage":8.0, "interval":1.9, "push":48.0},
	{"id":"sunwell_flower", "name":"日泉花", "health":95.0, "seed_cost":2, "range":0.0, "interval":6.5, "energy":3},
	{"id":"ember_flower", "name":"焰蕊花", "health":105.0, "seed_cost":2, "range":180.0, "damage":12.0, "interval":1.45, "burn":6.0, "burn_duration":4.0},
	{"id":"slumber_flower", "name":"眠孢花", "health":95.0, "seed_cost":2, "range":150.0, "damage":6.0, "interval":3.2, "stun":1.1},
	{"id":"spear_bamboo", "name":"穿叶竹", "health":110.0, "seed_cost":2, "range":250.0, "damage":21.0, "interval":1.55, "width":22.0, "max_targets":5},
	{"id":"burst_flower", "name":"爆果花", "health":100.0, "seed_cost":2, "range":200.0, "damage":20.0, "interval":2.0, "radius":78.0, "max_targets":10},
	{"id":"stone_flower", "name":"石盾花", "health":280.0, "seed_cost":2, "range":80.0, "damage":10.0, "interval":1.55, "damage_reduction":0.50},
	{"id":"cleanse_flower", "name":"净露兰", "health":115.0, "seed_cost":2, "range":165.0, "heal":5.0, "interval":3.4},
	{"id":"drum_flower", "name":"鼓舞葵", "health":115.0, "seed_cost":2, "range":155.0, "interval":1.7, "interval_multiplier":0.78}
]

const ENEMIES := [
	{"id":"shadow_beast", "name":"影兽", "rank":"normal", "health":72.0, "speed":52.0, "damage":12.0, "interval":1.10, "range":44.0, "reward":5, "first_night":1},
	{"id":"erosion_bug", "name":"蚀芽虫", "rank":"normal", "health":48.0, "speed":70.0, "damage":16.0, "interval":0.90, "range":32.0, "reward":4, "first_night":2, "targets_nodes":true},
	{"id":"husk_ram", "name":"枯壳撞兽", "rank":"elite", "health":105.0, "speed":42.0, "damage":14.0, "interval":1.20, "range":46.0, "reward":7, "first_night":2, "charge_damage":24.0},
	{"id":"spore_moth", "name":"腐孢蛾", "rank":"elite", "health":55.0, "speed":46.0, "damage":8.0, "interval":1.80, "range":150.0, "reward":6, "first_night":3, "corrosion_damage":2.0, "corrosion_duration":4.0},
	{"id":"lantern_eater", "name":"噬灯兽", "rank":"elite", "health":80.0, "speed":58.0, "damage":10.0, "interval":1.00, "range":38.0, "reward":8, "first_night":4, "suppression_radius":110.0, "supply_multiplier":0.70},
	{"id":"rot_caller", "name":"腐根祭虫", "rank":"elite", "health":95.0, "speed":38.0, "damage":9.0, "interval":1.40, "range":115.0, "reward":10, "first_night":4, "support_radius":140.0},
	{"id":"split_shade", "name":"裂影体", "rank":"elite", "health":90.0, "speed":50.0, "damage":13.0, "interval":1.10, "range":42.0, "reward":8, "first_night":5, "splits":2},
	{"id":"shell_scarab", "name":"黑甲育虫", "rank":"elite", "health":190.0, "speed":30.0, "damage":20.0, "interval":1.50, "range":50.0, "reward":12, "first_night":5, "front_reduction":0.40},
	{"id":"root_crown_colossus", "name":"根冠巨像", "rank":"boss", "health":750.0, "speed":24.0, "damage":28.0, "interval":1.50, "range":58.0, "reward":30, "first_night":5, "slow_cap":0.15},
	{"id":"sun_devourer", "name":"太阳吞噬者", "rank":"boss", "health":1300.0, "speed":20.0, "damage":34.0, "interval":1.40, "range":64.0, "reward":50, "first_night":7, "slow_cap":0.10}
]

const MOTHER_PATHS := [
	{"id":"sun_arrow", "name":"日矢母花", "branch_ids":["sunseed","corona","sunburst"]},
	{"id":"root_heart", "name":"根心母花", "branch_ids":["receptacle","sap","counterroot"]},
	{"id":"dawn_pulse", "name":"晨曦母花", "branch_ids":["charge","quelling","morningstar"]}
]

const _UPGRADE_DEFS := {
	"sunseed":[["mother_sunseed_01","锐利日种"],["mother_sunseed_02","追光花序"],["mother_sunseed_03","快速开花"],["mother_sunseed_04","双生花药"],["mother_sunseed_05","穿叶阳矢"],["mother_sunseed_06","黄金准星"]],
	"corona":[["mother_corona_01","灼热花瓣"],["mother_corona_02","爆裂花粉"],["mother_corona_03","光热积蓄"],["mother_corona_04","炽阳烙印"],["mother_corona_05","太阳风"],["mother_corona_06","永昼花冠"]],
	"sunburst":[["mother_sunburst_01","聚光花心"],["mother_sunburst_02","炽烈花盘"],["mother_sunburst_03","扩散日环"],["mother_sunburst_04","光能回流"],["mother_sunburst_05","黄金余辉"],["mother_sunburst_06","双生日轮"]],
	"receptacle":[["mother_receptacle_01","厚实花托"],["mother_receptacle_02","木质花茎"],["mother_receptacle_03","多层苞片"],["mother_receptacle_04","阳光挡片"],["mother_receptacle_05","巨物抗性"],["mother_receptacle_06","黄金花盾"]],
	"sap":[["mother_sap_01","缓流树液"],["mother_sap_02","晨露吸收"],["mother_sap_03","危急循环"],["mother_sap_04","吞暗花蜜"],["mother_sap_05","琥珀汁液"],["mother_sap_06","永生流体"]],
	"counterroot":[["mother_counterroot_01","倒刺表皮"],["mother_counterroot_02","护心根鞭"],["mother_counterroot_03","粗壮根鞭"],["mother_counterroot_04","缠足根须"],["mother_counterroot_05","受创震根"],["mother_counterroot_06","千根护日"]],
	"charge":[["mother_charge_01","饱满光囊"],["mother_charge_02","快速脉动"],["mother_charge_03","黎明预热"],["mother_charge_04","强敌折光"],["mother_charge_05","三重蓄积"],["mother_charge_06","光满成盾"]],
	"quelling":[["mother_quelling_01","镇夜波纹"],["mother_quelling_02","驱散暗咒"],["mother_quelling_03","外推光潮"],["mother_quelling_04","迟缓黑潮"],["mother_quelling_05","破法晨声"],["mother_quelling_06","黎明静滞"]],
	"morningstar":[["mother_morningstar_01","炽亮波心"],["mother_morningstar_02","广域晨光"],["mother_morningstar_03","逐暗之光"],["mother_morningstar_04","回响晨钟"],["mother_morningstar_05","晨曦烙印"],["mother_morningstar_06","超新晨星"]]
}

static var MOTHER_UPGRADES: Array = _build_upgrades()

const COMBAT_CARDS := [
	{"id":"card_sun_pierce","name":"日光穿刺","rarity":"common","energy_cost":4,"phase":"night","target_type":"ground","unlock_cost":0,"copies_allowed":2,"damage":12.0,"duration":4.0,"tick_interval":0.5,"rect_width":320.0,"rect_height":100.0},
	{"id":"card_root_snare","name":"缠根地带","rarity":"common","energy_cost":5,"phase":"night","target_type":"ground","unlock_cost":0,"copies_allowed":2,"duration":6.0},
	{"id":"card_emergency_dew","name":"甘露急救","rarity":"common","energy_cost":5,"phase":"night","target_type":"ground","unlock_cost":0,"copies_allowed":2,"radius":140.0,"heal":45.0},
	{"id":"card_root_wall","name":"根墙","rarity":"common","energy_cost":7,"phase":"night","target_type":"ground","unlock_cost":0,"copies_allowed":2,"health":120.0,"duration":18.0},
	{"id":"card_sun_mine","name":"太阳地雷","rarity":"common","energy_cost":7,"phase":"night","target_type":"ground","unlock_cost":0,"copies_allowed":2,"damage":65.0,"duration":999.0},
	{"id":"card_lure_bud","name":"诱光花苞","rarity":"common","energy_cost":5,"phase":"night","target_type":"ground","unlock_cost":0,"copies_allowed":2,"health":75.0,"duration":12.0},
	{"id":"card_emergency_light","name":"紧急供光","rarity":"common","energy_cost":5,"phase":"night","target_type":"plant","unlock_cost":0,"copies_allowed":2,"duration":10.0},
	{"id":"card_focus_mark","name":"聚光标记","rarity":"common","energy_cost":6,"phase":"night","target_type":"enemy","unlock_cost":0,"copies_allowed":2,"duration":6.0,"damage_multiplier":0.25},
	{"id":"card_transplant_shovel","name":"移植铲","rarity":"common","energy_cost":3,"phase":"night","target_type":"plant","unlock_cost":5,"copies_allowed":2},
	{"id":"card_frenzy_growth","name":"狂化生长","rarity":"common","energy_cost":4,"phase":"night","target_type":"plant","unlock_cost":6,"copies_allowed":2,"duration":7.0,"interval_multiplier":0.70},
	{"id":"card_local_repair_rain","name":"局部修复雨","rarity":"common","energy_cost":8,"phase":"night","target_type":"ground","unlock_cost":6,"copies_allowed":2,"radius":100.0,"heal":25.0},
	{"id":"card_hex_break_lamp","name":"驱咒灯","rarity":"common","energy_cost":6,"phase":"night","target_type":"ground","unlock_cost":8,"copies_allowed":2,"radius":120.0,"duration":8.0},
	{"id":"card_sun_arrow_rain","name":"日矢雨","rarity":"rare","energy_cost":13,"phase":"night","target_type":"ground","unlock_cost":12,"copies_allowed":1,"damage":18.0,"hits":6,"duration":3.0},
	{"id":"card_root_prison","name":"根牢","rarity":"rare","energy_cost":11,"phase":"night","target_type":"ground","unlock_cost":14,"copies_allowed":1,"radius":90.0,"duration":3.0},
	{"id":"card_golden_rain","name":"黄金甘霖","rarity":"rare","energy_cost":12,"phase":"night","target_type":"ground","unlock_cost":14,"copies_allowed":1,"radius":140.0,"heal":50.0,"duration":5.0},
	{"id":"card_temporary_sprout","name":"临时光芽","rarity":"rare","energy_cost":12,"phase":"night","target_type":"ground","unlock_cost":16,"copies_allowed":1,"health":80.0,"supply_radius":170.0,"capacity":4,"duration":25.0},
	{"id":"card_node_overload","name":"光脉过载","rarity":"rare","energy_cost":9,"phase":"night","target_type":"node","unlock_cost":16,"copies_allowed":1,"duration":10.0},
	{"id":"card_path_beacon","name":"引路灯标","rarity":"rare","energy_cost":10,"phase":"night","target_type":"ground","unlock_cost":18,"copies_allowed":1,"health":120.0,"duration":10.0},
	{"id":"card_phantom_bloom","name":"幻影开花","rarity":"rare","energy_cost":14,"phase":"night","target_type":"plant","unlock_cost":20,"copies_allowed":1,"duration":20.0},
	{"id":"card_weather_seal","name":"天候封印","rarity":"rare","energy_cost":14,"phase":"night","target_type":"global","unlock_cost":22,"copies_allowed":1,"duration":12.0},
	{"id":"card_time_stasis","name":"黎明静止","rarity":"legendary","energy_cost":22,"phase":"night","target_type":"global","unlock_cost":35,"copies_allowed":1,"duration":4.0},
	{"id":"card_golden_domain","name":"黄金领域","rarity":"legendary","energy_cost":20,"phase":"night","target_type":"ground","unlock_cost":40,"copies_allowed":1,"radius":210.0,"duration":15.0},
	{"id":"card_garden_resurrection","name":"花园复生","rarity":"legendary","energy_cost":24,"phase":"night","target_type":"global","unlock_cost":45,"copies_allowed":1},
	{"id":"card_shadow_redemption","name":"阴影归化","rarity":"legendary","energy_cost":18,"phase":"night","target_type":"enemy","unlock_cost":50,"copies_allowed":1,"duration":20.0}
]

const META_TRACKS := [
	{"id":"max_health", "values":[300.0,310.0,320.0,330.0,340.0,350.0], "costs":[5,10,18,28,40]},
	{"id":"starting_energy", "values":[55,58,61,64,67,70], "costs":[6,12,20,30,42]},
	{"id":"day_regen", "values":[1.0,1.05,1.10,1.15,1.20,1.25], "costs":[8,15,24,35,48]},
	{"id":"sunburst_damage", "values":[90.0,94.0,98.0,102.0,106.0,110.0], "costs":[8,15,24,35,48]}
]

static func _build_upgrades() -> Array:
	var result: Array = []
	for branch in _UPGRADE_DEFS.keys():
		var rank := 1
		for pair in _UPGRADE_DEFS[branch]:
			result.append({"id":pair[0], "name":pair[1], "branch":branch, "rank":rank, "path":_path_for_branch(branch), "prerequisite":("" if rank == 1 else _UPGRADE_DEFS[branch][rank - 2][0])})
			rank += 1
	return result

static func _path_for_branch(branch: String) -> String:
	if branch in ["sunseed", "corona", "sunburst"]: return "sun_arrow"
	if branch in ["receptacle", "sap", "counterroot"]: return "root_heart"
	return "dawn_pulse"

static func get_flower(id: String) -> Dictionary:
	var values := _find(FLOWERS, id)
	if values.is_empty() or id == "light_sprout": return values
	# Campaign tuning is shared by combat, deployment previews and the codex.
	values.health = roundf(float(values.get("health", 100.0)) * 1.5)
	if values.has("damage"): values.damage = roundf(float(values.damage) * 1.6)
	if values.has("interval"): values.interval = float(values.interval) * 0.8
	if values.has("heal"): values.heal = roundf(float(values.heal) * 1.5)
	if values.has("burn"): values.burn = float(values.burn) * 1.5
	match id:
		"thorn_flower": values.range = 150.0; values.max_targets = 16
		"prism_flower": values.range = 280.0
		"storm_flower": values.max_targets = 8; values.chain_range = 135.0
		"spear_bamboo": values.max_targets = 10; values.width = 32.0
		"burst_flower": values.max_targets = 20; values.radius = 110.0
		"honeydew_flower", "cleanse_flower": values.range = 200.0
		"sunwell_flower": values.energy = 4
	return values

static func get_enemy(id: String) -> Dictionary:
	return _find(ENEMIES, id)

static func get_card(id: String) -> Dictionary:
	return _find(COMBAT_CARDS, id)

static func get_mother_path(id: String) -> Dictionary:
	return _find(MOTHER_PATHS, id)

static func get_mother_upgrade(id: String) -> Dictionary:
	return _find(MOTHER_UPGRADES, id)

static func get_next_mother_choices(path_id: String, branch_ranks: Dictionary) -> Array[String]:
	var path := get_mother_path(path_id)
	var choices: Array[String] = []
	for branch in path.get("branch_ids", []):
		var next_rank := int(branch_ranks.get(branch, 0)) + 1
		if next_rank > 6: continue
		for upgrade in MOTHER_UPGRADES:
			if upgrade["path"] == path_id and upgrade["branch"] == branch and int(upgrade["rank"]) == next_rank:
				choices.append(str(upgrade["id"]))
	return choices

static func _find(collection: Array, id: String) -> Dictionary:
	for entry in collection:
		if str(entry.get("id", "")) == id: return (entry as Dictionary).duplicate(true)
	return {}
