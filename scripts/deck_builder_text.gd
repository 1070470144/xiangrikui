extends RefCounted
class_name DeckBuilderText

const PHASES := {"day":"白昼", "night":"夜晚", "any":"通用"}
const RARITIES := {"common":"普通", "rare":"稀有", "legendary":"传奇"}
const TARGETS := {
	"enemy":"敌人", "ground":"地面区域", "plant":"植物", "node":"光脉节点",
	"plant_or_node":"植物或光脉节点", "global":"全场"
}
const EFFECTS := {
	"damage":"伤害", "heal":"治疗", "duration":"持续时间", "radius":"作用半径",
	"health":"生命值", "hits":"命中次数", "damage_multiplier":"伤害增幅",
	"interval_multiplier":"攻击间隔倍率", "supply_radius":"供光半径", "capacity":"供光容量"
}

static func phase(value: Variant) -> String: return str(PHASES.get(str(value), "通用"))
static func rarity(value: Variant) -> String: return str(RARITIES.get(str(value), "普通"))
static func target(value: Variant) -> String: return str(TARGETS.get(str(value), "指定目标"))
static func effect(value: Variant) -> String: return str(EFFECTS.get(str(value), "效果"))

static func description(card: Dictionary) -> String:
	match str(card.get("id", "")):
		"card_sun_pierce": return "以凝聚的日光穿刺一名敌人，立即造成 %s 点伤害。" % _number(card.get("damage", 0))
		"card_root_snare": return "在选定地面生成缠根区域，持续 %s 秒。区域内普通及精英敌人减速 30%%，首领减速 10%%；作用半径为 70。" % _number(card.get("duration", 0))
		"card_emergency_dew": return "立即为选定位置 %s 半径内的植物恢复 %s 点生命。" % [_number(card.get("radius", 140)), _number(card.get("heal", 0))]
		"card_root_wall": return "在选定位置召唤根墙，拥有 %s 点生命，持续 %s 秒。吸引附近普通敌人的攻击；精英和首领不受其嘲讽影响。" % [_number(card.get("health", 0)), _number(card.get("duration", 0))]
		"card_sun_mine": return "在地面埋下太阳地雷。敌人进入 45 半径内时引爆，对 65 半径内的敌人造成 %s 点伤害，随后消失。未触发时最多存在 %s 秒。" % [_number(card.get("damage", 0)), _number(card.get("duration", 0))]
		"card_lure_bud": return "召唤诱光花苞吸引附近敌人的攻击。花苞拥有 %s 点生命，持续 %s 秒，吸引范围为 160。" % [_number(card.get("health", 0)), _number(card.get("duration", 0))]
		"card_emergency_light": return "为一株植物临时供光，使其恢复供能状态，持续 %s 秒。效果结束后按光脉连接情况恢复供能状态。" % _number(card.get("duration", 0))
		"card_focus_mark": return "标记一名敌人，持续 %s 秒。普通及精英目标受到的伤害提高 25%%；首领受到的伤害提高 12%%。" % _number(card.get("duration", 0))
		"card_transplant_shovel": return "白昼时将一株植物迁移到新的可种植位置。目的地必须空闲，并能接入满足其负载需求的光脉网络；迁移后重新计算光脉连接。"
		"card_frenzy_growth": return "使一株植物的攻击间隔缩短为原来的 70%%，持续 %s 秒。效果结束后植物受到 15 点伤害。" % _number(card.get("duration", 0))
		"card_local_repair_rain": return "立即为选定位置 %s 半径内的植物和光脉节点恢复 %s 点生命。" % [_number(card.get("radius", 0)), _number(card.get("heal", 0))]
		"card_hex_break_lamp": return "在选定位置布置驱咒区域，持续 %s 秒。在 %s 半径内持续移除敌人的正面增益。" % [_number(card.get("duration", 0)), _number(card.get("radius", 0))]
		"card_sun_arrow_rain": return "在选定区域降下 %s 波日矢，每波造成 %s 点范围伤害，持续 %s 秒。单名敌人最多受到 4 次命中；作用半径为 70。" % [_number(card.get("hits", 0)), _number(card.get("damage", 0)), _number(card.get("duration", 0))]
		"card_root_prison": return "在 %s 半径内生成根牢。普通敌人眩晕 3 秒，精英眩晕 1.2 秒；首领不会被眩晕，而是减速 12%%，持续 3 秒。" % _number(card.get("radius", 0))
		"card_golden_rain": return "在选定位置生成黄金甘霖，持续 %s 秒，为 %s 半径内的植物和光脉节点持续恢复生命并清除腐蚀。每 0.5 秒治疗一次，每次恢复 10 点生命。" % [_number(card.get("duration", 0)), _number(card.get("radius", 0))]
		"card_temporary_sprout": return "召唤临时光芽，拥有 %s 点生命，持续 %s 秒。供光半径为 %s，负载容量为 %s；放置位置必须能接入现有光脉网络。" % [_number(card.get("health", 0)), _number(card.get("duration", 0)), _number(card.get("supply_radius", 0)), _number(card.get("capacity", 0))]
		"card_node_overload": return "让一个光脉节点进入过载状态，持续 %s 秒，临时将其供光半径增加 50。" % _number(card.get("duration", 0))
		"card_path_beacon": return "布置引路灯标，拥有 %s 点生命，持续 %s 秒，在 220 半径内吸引普通敌人。精英和首领不受其嘲讽影响。" % [_number(card.get("health", 0)), _number(card.get("duration", 0))]
		"card_phantom_bloom": return "在一株植物附近的空闲位置生成同类幻影，持续 %s 秒。幻影生命和攻击伤害为原类型的 60%%，自带临时供光；周围无空位时无法使用。" % _number(card.get("duration", 0))
		"card_weather_seal": return "封印天气影响，持续 %s 秒，在此期间暂停夜间天气效果的处理。" % _number(card.get("duration", 0))
		"card_time_stasis": return "使全场敌人陷入静止：普通敌人眩晕 4 秒、精英 2 秒、首领 0.6 秒。"
		"card_golden_domain": return "生成黄金领域，持续 %s 秒。%s 半径内的植物临时获得供光，敌人减速 15%%。" % [_number(card.get("duration", 0)), _number(card.get("radius", 0))]
		"card_garden_resurrection": return "按阵亡顺序优先复活最近阵亡的植物，最多复活 3 株，每株恢复 50% 最大生命。原位置被占用的植物无法复活。"
		"card_shadow_redemption": return "暂时将一名敌人转化为友方：普通敌人持续 20 秒，精英持续 12 秒。首领无法被转化。"
	return "对%s施放此卡牌。" % target(card.get("target_type", ""))

static func stats(card: Dictionary) -> String:
	var lines: Array[String] = []
	for key in EFFECTS:
		if not card.has(key): continue
		if str(card.get("id", "")) == "card_golden_rain" and key == "heal": continue
		var value := _number(card[key])
		if key == "duration": value += " 秒"
		elif key == "damage_multiplier": value = "%s%%" % _number(float(card[key]) * 100.0)
		elif key == "interval_multiplier": value = "原来的 %s%%" % _number(float(card[key]) * 100.0)
		lines.append("%s：%s" % [effect(key), value])
	return "\n".join(lines)

static func _number(value: Variant) -> String:
	return str(int(value)) if is_equal_approx(float(value), roundf(float(value))) else str(value)
