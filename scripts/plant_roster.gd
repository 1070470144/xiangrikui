extends RefCounted

# Deployment selections differ from Plant.Kind because light sprouts are a base action.
const MAX_SLOTS := 5
const DEFAULT_IDS := ["deploy_thorn", "deploy_prism", "deploy_lantern", "deploy_frost", "deploy_honeydew"]
const FLOWER_IDS := ["thorn_flower", "prism_flower", "lantern_flower", "frost_bell", "honeydew_flower", "storm_flower", "gale_flower", "sunwell_flower", "ember_flower", "slumber_flower", "spear_bamboo", "burst_flower", "stone_flower", "cleanse_flower", "drum_flower"]
const DEPLOY_IDS := ["deploy_thorn", "deploy_prism", "deploy_lantern", "deploy_frost", "deploy_honeydew", "deploy_storm", "deploy_gale", "deploy_sunwell", "deploy_ember", "deploy_slumber", "deploy_spear", "deploy_burst", "deploy_stone", "deploy_cleanse", "deploy_drum"]
const SELECTIONS := [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const DESCRIPTIONS := ["消耗1种子。攻击周围最多5个敌人。", "射程420，每轮攻击4个目标，每目标85伤害。", "半径200，每4秒补至40护盾，持续6秒。", "半径220内敌人减速35%，持续3秒。", "半径220内所有植物每2秒恢复25生命。", "命中首个敌人后，再传导6个不同敌人。", "攻击并击退普通与精英敌人。", "夜晚每1秒产出1点光能。", "点燃敌人，持续造成灼烧伤害。", "眠孢使敌人短暂眩晕，首领效果减弱。", "长矛贯穿直线上的最多4个敌人。", "爆果伤害目标周围最多8个敌人。", "高生命值，受到伤害减少40%。", "一次恢复全场植物50%最大生命，然后消失。", "鼓舞附近植物，攻击间隔缩短22%，伤害提高25%。"]

static func deploy_map() -> Dictionary:
	var result := {}
	for i in range(DEPLOY_IDS.size()): result[DEPLOY_IDS[i]] = SELECTIONS[i]
	return result

static func kind_for_selection(selection: int) -> int:
	return SELECTIONS.find(selection)

static func flower_for_selection(selection: int) -> String:
	var index := kind_for_selection(selection)
	return FLOWER_IDS[index] if index >= 0 else ""

static func texture_path(kind: int) -> String:
	# Shared by battlefield, deployment previews, slots and the greenhouse codex.
	var generated := "res://assets/plants/generated/plant_expansion/%s.png" % FLOWER_IDS[kind]
	if ResourceLoader.exists(generated): return generated
	return preload("res://scripts/art_library.gd").THORN_POWERED if kind == 0 else preload("res://scripts/art_library.gd").PRISM_POWERED
