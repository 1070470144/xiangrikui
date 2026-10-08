extends Node2D

const MIN_EFFECT_RADIUS := 70.0
const MINE_TRIGGER_RADIUS := 45.0
const MINE_DAMAGE_RADIUS := 65.0

var object_id := ""
var health := 1.0
var max_health := 1.0
var remaining_time := 0.0
var radius := 0.0
var supply_radius := 0.0
var capacity := 0
var taunt := false
var slow_ratio := 0.0
var trigger_damage := 0.0
var periodic_damage := 0.0
var hits_left := 0
var periodic_heal := 0.0
var cleanse_corrosion := false
var hit_counts := {}
var tick_interval := 0.5
var start_delay := 0.0
var control_applied := {}
var _tick := 0.0
var is_connected_to_light := true
var load := 0
var parent_source: Node = null

func configure(new_id: String, position_value: Vector2, values: Dictionary) -> void:
	object_id = new_id; global_position = position_value
	max_health = float(values.get("health", 1.0)); health = max_health; remaining_time = float(values.get("duration", 0.0))
	radius = float(values.get("radius", 0.0)); supply_radius = float(values.get("supply_radius", 0.0)); capacity = int(values.get("capacity", 0)); taunt = bool(values.get("taunt", false))
	slow_ratio = float(values.get("slow_ratio", 0.0)); trigger_damage = float(values.get("trigger_damage", 0.0)); periodic_damage = float(values.get("periodic_damage", 0.0)); hits_left = int(values.get("hits", 0))
	periodic_heal = float(values.get("periodic_heal", 0.0)); cleanse_corrosion = bool(values.get("cleanse_corrosion", false)); hit_counts.clear()
	control_applied.clear()
	add_to_group("temporary_battle_objects")

func _process(delta: float) -> void:
	_apply_area_effects(delta)
	if remaining_time <= 0.0: return
	remaining_time -= delta
	if remaining_time <= 0.0: queue_free()

func take_damage(amount: float) -> void:
	if amount <= 0.0: return
	health = maxf(0.0, health - amount)
	if health <= 0.0: queue_free()

func can_accept(cost: int) -> bool: return is_connected_to_light and supply_radius > 0.0 and load + cost <= capacity
func set_load(value: int) -> void: load = maxi(0, value)
func set_parent_source(source: Node) -> void: parent_source = source; is_connected_to_light = source != null

func get_slow_for_rank(rank: String) -> float:
	if object_id == "card_root_snare": return 0.10 if rank == "boss" else 0.30
	return slow_ratio

func get_ranked_control(rank: String) -> Dictionary:
	if object_id != "card_root_prison": return {}
	if rank == "boss": return {"slow":0.12,"duration":3.0}
	return {"stun":1.2 if rank == "elite" else 3.0}

func _apply_area_effects(delta: float) -> void:
	if not is_inside_tree(): return
	_tick -= delta
	if object_id == "card_sun_mine":
		for enemy in _nearby_enemies(MINE_TRIGGER_RADIUS):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= MINE_TRIGGER_RADIUS:
				for victim in _nearby_enemies(MINE_DAMAGE_RADIUS):
					if is_instance_valid(victim) and victim.global_position.distance_to(global_position) <= MINE_DAMAGE_RADIUS: victim.take_damage(trigger_damage)
				queue_free(); return
	if object_id == "card_golden_domain":
		for plant in get_tree().get_nodes_in_group("plants"):
			if is_instance_valid(plant) and plant.global_position.distance_to(global_position) <= radius: plant.set_powered(true); plant.card_power_time = maxf(plant.card_power_time, 0.2); plant.restore_power_on_card_expiry = true
	if _tick > 0.0: return
	_tick = maxf(0.01, tick_interval)
	for enemy in _nearby_enemies(maxf(radius, MIN_EFFECT_RADIUS)):
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(global_position) > maxf(radius, MIN_EFFECT_RADIUS): continue
		if object_id == "card_root_snare": enemy.apply_slow(object_id, get_slow_for_rank(enemy.get_rank()), 0.7)
		elif slow_ratio > 0.0: enemy.apply_slow(object_id, slow_ratio, 0.7)
		if object_id == "card_golden_domain": enemy.apply_slow(object_id, 0.15, 0.7)
		if object_id == "card_root_prison":
			var enemy_key: int = enemy.get_instance_id()
			if not control_applied.has(enemy_key):
				var control := get_ranked_control(enemy.get_rank())
				if control.has("stun"): enemy.apply_stun(float(control["stun"]))
				else: enemy.apply_slow(object_id, float(control["slow"]), float(control["duration"]))
				control_applied[enemy_key] = true
		if object_id == "card_hex_break_lamp": enemy.remove_positive_buffs()
		if periodic_damage > 0.0 and hits_left > 0:
			var enemy_key: int = enemy.get_instance_id(); var count := int(hit_counts.get(enemy_key, 0))
			if object_id != "card_sun_arrow_rain" or count < 4: enemy.take_area_damage(periodic_damage); hit_counts[enemy_key] = count + 1
	if periodic_damage > 0.0 and hits_left > 0: hits_left -= 1
	if periodic_heal > 0.0:
		for group_name in ["plants", "light_nodes"]:
			for unit in get_tree().get_nodes_in_group(group_name):
				if not is_instance_valid(unit) or unit.global_position.distance_to(global_position) > radius: continue
				if unit.has_method("heal"): unit.heal(periodic_heal)
				if cleanse_corrosion and "corrosion_time" in unit: unit.corrosion_time = 0.0; unit.corrosion_damage = 0.0

func _nearby_enemies(search_radius: float) -> Array:
	var host := get_parent()
	return host.query_enemies_in_radius(global_position, search_radius) if host != null and host.has_method("query_enemies_in_radius") else get_tree().get_nodes_in_group("enemies")
