extends RefCounted

const Content = preload("res://scripts/content_data.gd")

static func describe(id: String) -> String:
	var c := Content.get_card(id)
	var duration := int(c.get("duration", 0))
	match id:
		"card_sun_pierce": return "矩形光带持续4秒，每0.5秒造成12伤害。"
		"card_root_snare": return "区域敌人减速30%%，持续%d秒。" % duration
		"card_emergency_dew": return "范围内植物恢复%d生命。" % int(c.heal)
		"card_root_wall": return "建立%d生命根墙，吸引敌人%d秒。" % [int(c.health),duration]
		"card_sun_mine": return "埋下地雷，触发时造成%d伤害。" % int(c.damage)
		"card_lure_bud": return "生成花苞，吸引所有怪物12秒。"
		"card_emergency_light": return "植物获得供光，持续%d秒。" % duration
		"card_focus_mark": return "敌人受伤提高25%%，持续%d秒。首领提高12%%。" % duration
		"card_transplant_shovel": return "先选植物，再选供光空地。移植保留生命。"
		"card_frenzy_growth": return "攻击间隔降至70%%，持续%d秒。结束损失15生命。" % duration
		"card_local_repair_rain": return "半径%d内植物与光脉恢复%d生命。" % [int(c.radius),int(c.heal)]
		"card_hex_break_lamp": return "半径%d内驱散腐化，持续%d秒。" % [int(c.radius),duration]
		"card_sun_arrow_rain": return "落下%d道光矢，每次%d伤害；每敌最多命中4次。" % [int(c.hits),int(c.damage)]
		"card_root_prison": return "困住普通敌人3秒，精英1.2秒；首领减速12%%。"
		"card_golden_rain": return "区域每秒恢复10生命并净化腐化，持续%d秒。" % duration
		"card_temporary_sprout": return "召唤%d生命光芽，供光容量%d，持续%d秒。" % [int(c.health),int(c.capacity),duration]
		"card_node_overload": return "供光半径+50，供光植物攻击间隔降至80%%，持续%d秒。" % duration
		"card_path_beacon": return "建立%d生命灯标，吸引区域敌人%d秒。" % [int(c.health),duration]
		"card_phantom_bloom": return "复制植物，生命与伤害为60%%，持续%d秒。" % duration
		"card_weather_seal": return "封印本夜天气影响，持续%d秒。" % duration
		"card_time_stasis": return "全场敌人静止4秒；精英2秒，首领0.6秒。"
		"card_golden_domain": return "半径%d内植物获供光，敌人减速15%%，持续%d秒。" % [int(c.radius),duration]
		"card_garden_resurrection": return "复活最多3株植物，恢复50%生命。"
		"card_shadow_redemption": return "敌人转为友军20秒；精英12秒，首领免疫。"
	return ""

static func target_text(id: String) -> String:
	var targets := {"enemy":"敌人", "ground":"地面", "plant":"植物", "node":"光脉", "plant_or_node":"植物 / 光脉", "global":"全场"}
	return str(targets.get(str(Content.get_card(id).get("target_type", "ground")), "地面"))
