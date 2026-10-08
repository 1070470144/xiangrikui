extends RefCounted

const ContentData = preload("res://scripts/content_data.gd")
var path_id := ""
var branch_ranks := {}
var selected_upgrades: Array[String] = []

func reset() -> void: path_id = ""; branch_ranks.clear(); selected_upgrades.clear()
func get_choices() -> Array[String]:
	if path_id.is_empty(): return ["sun_arrow", "root_heart", "dawn_pulse"]
	if selected_upgrades.size() >= 6: return []
	return ContentData.get_next_mother_choices(path_id, branch_ranks)
func choose_path(new_path: String) -> bool:
	if not path_id.is_empty() or ContentData.get_mother_path(new_path).is_empty(): return false
	path_id = new_path
	for branch in ContentData.get_mother_path(path_id).get("branch_ids", []): branch_ranks[branch] = 0
	return true
func choose_upgrade(upgrade_id: String) -> bool:
	if selected_upgrades.size() >= 6 or not get_choices().has(upgrade_id): return false
	var upgrade := ContentData.get_mother_upgrade(upgrade_id); selected_upgrades.append(upgrade_id); branch_ranks[upgrade["branch"]] = int(upgrade["rank"]); return true
func has_upgrade(id: String) -> bool: return selected_upgrades.has(id)
func get_upgrade_effects(id: String) -> Dictionary:
	match id:
		"mother_sunseed_01": return {"attack_damage_add":5.0}
		"mother_sunseed_02": return {"attack_range_add":35.0}
		"mother_sunseed_03": return {"attack_interval_multiplier":0.88}
		"mother_sunseed_04": return {"attack_extra_every":4, "attack_extra_same_ratio":0.50}
		"mother_sunseed_05": return {"attack_pierce_ratio":0.65}
		"mother_sunseed_06": return {"attack_prioritize_strong":true, "attack_strong_multiplier":1.25}
		"mother_corona_01": return {"attack_burn_dps":3.0, "attack_burn_duration":3.0}
		"mother_corona_02": return {"attack_splash_radius":45.0, "attack_splash_damage":7.0}
		"mother_corona_03": return {"attack_chain_add":2.0, "attack_chain_cap":10.0}
		"mother_corona_04": return {"attack_explosion_every":6, "attack_explosion_radius":70.0, "attack_explosion_damage":28.0}
		"mother_corona_05": return {"solar_wind_interval":10.0, "solar_wind_radius":180.0, "solar_wind_damage":20.0, "solar_wind_slow":0.20, "solar_wind_slow_duration":2.0}
		"mother_corona_06": return {"secondary_damage_multiplier":1.50}
		"mother_sunburst_01": return {"sunburst_cost_add":-5}
		"mother_sunburst_02": return {"sunburst_damage_add":25.0}
		"mother_sunburst_03": return {"sunburst_radius_add":20.0}
		"mother_sunburst_04": return {"sunburst_kill_energy":2, "sunburst_refund_cap":10}
		"mother_sunburst_05": return {"sunburst_afterglow_duration":5.0, "sunburst_afterglow_dps":6.0}
		"mother_sunburst_06": return {"sunburst_echo_delay":1.5, "sunburst_echo_damage_ratio":0.55, "sunburst_echo_radius_ratio":0.85}
		"mother_receptacle_01": return {"max_health_bonus":40.0, "upgrade_heal":40.0}
		"mother_receptacle_02": return {"damage_reduction_add":0.08}
		"mother_receptacle_03": return {"max_health_bonus":50.0, "upgrade_heal":50.0}
		"mother_receptacle_04": return {"damage_block_interval":6.0, "damage_block_amount":12.0}
		"mother_receptacle_05": return {"boss_damage_reduction":0.12}
		"mother_receptacle_06": return {"night_shield":60.0}
		"mother_sap_01": return {"night_regen":0.4}
		"mother_sap_02": return {"day_start_heal":40.0}
		"mother_sap_03": return {"low_health_regen":0.6, "low_health_threshold":0.50}
		"mother_sap_04": return {"nearby_kill_heal":1.0, "nearby_kill_radius":180.0, "nearby_kill_cap":12}
		"mother_sap_05": return {"overheal_shield_cap":30.0}
		"mother_sap_06": return {"out_of_combat_delay":6.0, "out_of_combat_regen":2.0}
		"mother_counterroot_01": return {"melee_reflect_damage":6.0}
		"mother_counterroot_02": return {"root_whip_interval":3.0, "root_whip_radius":160.0, "root_whip_damage":14.0, "root_whip_targets":1}
		"mother_counterroot_03": return {"root_whip_damage":22.0}
		"mother_counterroot_04": return {"root_normal_root":0.7, "root_elite_slow":0.30, "root_elite_slow_duration":1.5}
		"mother_counterroot_05": return {"damage_burst_window":3.0, "damage_burst_threshold":30.0, "damage_burst_radius":130.0, "damage_burst_damage":30.0, "damage_burst_cooldown":8.0}
		"mother_counterroot_06": return {"root_whip_radius":190.0, "root_whip_targets":3}
		"mother_charge_01": return {"pulse_energy_add":1}
		"mother_charge_02": return {"pulse_interval":10.5}
		"mother_charge_03": return {"night_start_pulse":true}
		"mother_charge_04": return {"pulse_strong_energy":2, "pulse_strong_energy_cap":4}
		"mother_charge_05": return {"pulse_third_energy":6}
		"mother_charge_06": return {"pulse_overflow_shield_ratio":0.50, "pulse_overflow_shield_each_cap":10.0, "pulse_overflow_shield_cap":40.0}
		"mother_quelling_01": return {"pulse_slow_ratio":0.15, "pulse_slow_duration":2.0}
		"mother_quelling_02": return {"pulse_dispel":true}
		"mother_quelling_03": return {"pulse_push_normal":30.0}
		"mother_quelling_04": return {"pulse_attack_slow":0.20, "pulse_attack_slow_duration":3.0}
		"mother_quelling_05": return {"pulse_interrupt":true}
		"mother_quelling_06": return {"pulse_stun_normal":1.0, "pulse_stun_elite":0.4}
		"mother_morningstar_01": return {"pulse_damage_add":6.0}
		"mother_morningstar_02": return {"pulse_radius_add":25.0}
		"mother_morningstar_03": return {"pulse_low_health_threshold":0.30, "pulse_low_health_multiplier":1.50}
		"mother_morningstar_04": return {"pulse_echo_delay":1.5, "pulse_echo_ratio":0.50}
		"mother_morningstar_05": return {"pulse_mother_mark_multiplier":1.15, "pulse_mother_mark_duration":3.0}
		"mother_morningstar_06": return {"pulse_super_every":4, "pulse_super_multiplier":2.50, "pulse_super_radius_add":50.0}
	return {}

func get_effect_value(key: String, default_value: Variant = 0.0) -> Variant:
	var result: Variant = default_value
	var additive_keys := ["attack_damage_add", "attack_range_add", "sunburst_cost_add", "sunburst_damage_add", "sunburst_radius_add", "max_health_bonus", "damage_reduction_add", "pulse_energy_add", "pulse_damage_add", "pulse_radius_add"]
	var found := false
	for id in selected_upgrades:
		var effects := get_upgrade_effects(id)
		if not effects.has(key): continue
		if key in additive_keys:
			if not found: result = 0
			result += effects[key]
		else:
			result = effects[key]
		found = true
	return result

func get_mother_attack_damage() -> float: return 18.0 + float(get_effect_value("attack_damage_add", 0.0))
func get_mother_attack_range() -> float: return 230.0 + float(get_effect_value("attack_range_add", 0.0))
func get_mother_attack_interval() -> float: return 1.5 * float(get_effect_value("attack_interval_multiplier", 1.0))
func get_sunburst_cost(base: int) -> int: return maxi(10, base + int(get_effect_value("sunburst_cost_add", 0)))
func get_sunburst_damage(base: float) -> float: return base + float(get_effect_value("sunburst_damage_add", 0.0))
func get_sunburst_radius(base: float) -> float: return base + float(get_effect_value("sunburst_radius_add", 0.0))
func get_mother_max_health(base: float) -> float:
	var result := base + (60.0 if path_id == "root_heart" else 0.0)
	result += float(get_effect_value("max_health_bonus", 0.0))
	return result
func get_damage_reduction() -> float:
	return (0.05 if path_id == "root_heart" else 0.0) + float(get_effect_value("damage_reduction_add", 0.0))
func get_pulse_energy() -> int: return 3 + int(get_effect_value("pulse_energy_add", 0))
func get_pulse_damage() -> float: return 10.0 + float(get_effect_value("pulse_damage_add", 0.0))
func get_pulse_radius() -> float: return 200.0 + float(get_effect_value("pulse_radius_add", 0.0))
func get_pulse_interval() -> float: return float(get_effect_value("pulse_interval", 12.0))
func export_state() -> Dictionary: return {"path_id":path_id, "branch_ranks":branch_ranks.duplicate(), "selected_upgrades":selected_upgrades.duplicate()}
