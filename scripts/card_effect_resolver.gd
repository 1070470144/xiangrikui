extends RefCounted

const ContentData = preload("res://scripts/content_data.gd")
const TemporaryObject = preload("res://scripts/temporary_battle_object.gd")
const PlantScript = preload("res://scripts/plant.gd")

const ROOT_TAUNT_RADIUS := 160.0
const BEACON_TAUNT_RADIUS := 220.0

# Read-only contract shared by live targeting previews and the effect resolver.
func get_target_preview(game: Node, card_id: String, target: Variant) -> Dictionary:
	var card := ContentData.get_card(card_id)
	if card.is_empty(): return {}
	var valid: bool = game.combat_deck.get_hand().has(card_id) and game.combat_deck.validate_card_play(card_id, _phase_name(game.phase), game.light_energy, _target_context(target)) and _validate_runtime_target(game, card, target)
	if target is Node and "health" in target: valid = valid and target.health > 0.0
	if card_id == "card_shadow_redemption" and target is Node: valid = valid and target.get_rank() != "boss"
	var radius := 0.0
	match card_id:
		"card_root_snare", "card_hex_break_lamp", "card_sun_arrow_rain", "card_root_prison", "card_golden_domain": radius = maxf(float(card.get("radius", 0.0)), TemporaryObject.MIN_EFFECT_RADIUS)
		"card_emergency_dew", "card_local_repair_rain", "card_golden_rain": radius = float(card.get("radius", 0.0))
		"card_root_wall", "card_lure_bud": radius = ROOT_TAUNT_RADIUS
		"card_path_beacon": radius = BEACON_TAUNT_RADIUS
		"card_sun_mine": radius = TemporaryObject.MINE_DAMAGE_RADIUS
		"card_temporary_sprout": radius = float(card.get("supply_radius", 170.0))
	var point: Vector2 = _target_position(target) if target != null else Vector2.ZERO
	var global_target := str(card.get("target_type", "")) == "global"
	if card_id == "card_phantom_bloom" and target is Node:
		point = find_phantom_position(game, target)
		valid = valid and point != Vector2.INF
		if not valid: point = target.global_position
	if global_target: point = game.mother_flower.global_position
	return {"valid":valid, "radius":radius, "point":point, "global":global_target, "name":str(card.get("name", "")), "shape":"rectangle" if card_id == "card_sun_pierce" else "circle", "rect_size":Vector2(float(card.get("rect_width", 0.0)), float(card.get("rect_height", 0.0)))}

const SUPPORTED_CARD_IDS := [
	"card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud", "card_emergency_light", "card_focus_mark",
	"card_transplant_shovel", "card_frenzy_growth", "card_local_repair_rain", "card_hex_break_lamp", "card_sun_arrow_rain", "card_root_prison", "card_golden_rain", "card_temporary_sprout", "card_node_overload", "card_path_beacon", "card_phantom_bloom", "card_weather_seal", "card_time_stasis", "card_golden_domain", "card_garden_resurrection", "card_shadow_redemption"
]

func get_supported_card_ids() -> Array[String]:
	var result: Array[String] = []
	for id in SUPPORTED_CARD_IDS: result.append(id)
	return result

func get_stasis_duration(rank: String) -> float: return 0.6 if rank == "boss" else (2.0 if rank == "elite" else 4.0)
func get_root_prison_duration(rank: String) -> float: return 0.0 if rank == "boss" else (1.2 if rank == "elite" else 3.0)
func get_redemption_duration(rank: String) -> float: return 12.0 if rank == "elite" else (0.0 if rank == "boss" else 20.0)

func resolve(game: Node, card_id: String, target: Variant) -> Dictionary:
	var card := ContentData.get_card(card_id)
	if card.is_empty(): return {"ok":false, "reason":"unknown_card"}
	if not game.combat_deck.get_hand().has(card_id): return {"ok":false, "reason":"not_in_hand"}
	if not game.combat_deck.validate_card_play(card_id, _phase_name(game.phase), game.light_energy, _target_context(target)): return {"ok":false, "reason":"invalid_play"}
	if not _validate_runtime_target(game, card, target): return {"ok":false, "reason":"invalid_target"}
	if not game.spend_energy(int(card["energy_cost"])): return {"ok":false, "reason":"energy"}
	var result := _apply(game, card, target)
	if not result.get("ok", false): game.light_energy += int(card["energy_cost"]); return result
	game.combat_deck.consume(card_id); return result

func _apply(game: Node, card: Dictionary, target: Variant) -> Dictionary:
	var id := str(card["id"]); var affected := 0; var created: Array = []
	match id:
		"card_sun_pierce": created.append(_spawn_zone(game, id, target, card, {"periodic_damage":float(card.damage),"hits":8})); affected = 1
		"card_focus_mark": target.card_damage_multiplier = 1.12 if target.get_rank() == "boss" else 1.25; target.card_power_time = float(card["duration"]); affected = 1
		"card_emergency_dew": affected = _heal_plants(game, _target_position(target), float(card.get("radius", 140.0)), float(card["heal"]))
		"card_emergency_light": target.set_powered(true); target.card_power_time = float(card["duration"]); target.restore_power_on_card_expiry = true; affected = 1
		"card_transplant_shovel": affected = _transplant(game, target)
		"card_frenzy_growth": target.card_interval_multiplier = float(card["interval_multiplier"]); target.card_power_time = float(card["duration"]); target.card_expiry_damage = 15.0; affected = 1
		"card_root_snare": created.append(_spawn_zone(game, id, target, card, {"slow_ratio":0.30})); affected = 1
		"card_root_wall": created.append(_spawn_zone(game, id, target, card, {"health":120.0,"taunt":true,"radius":ROOT_TAUNT_RADIUS})); affected = 1
		"card_sun_mine": created.append(_spawn_zone(game, id, target, card, {"health":1.0,"trigger_damage":65.0})); affected = 1
		"card_lure_bud": created.append(_spawn_zone(game, id, target, card, {"health":75.0,"taunt":true,"radius":ROOT_TAUNT_RADIUS})); affected = 1
		"card_hex_break_lamp": created.append(_spawn_zone(game, id, target, card, {"purge":true})); affected = 1
		"card_sun_arrow_rain": created.append(_spawn_zone(game, id, target, card, {"periodic_damage":18.0,"hits":6})); affected = 1
		"card_root_prison": created.append(_spawn_zone(game, id, target, card, {"ranked_prison":true})); affected = 1
		"card_temporary_sprout":
			var sprout := _spawn_zone(game, id, target, card, {"health":80.0,"supply_radius":170.0,"capacity":4})
			if sprout != null: created.append(sprout); affected = 1
		"card_node_overload": target.apply_overload(float(card["duration"])); affected = 1
		"card_path_beacon": created.append(_spawn_zone(game, id, target, card, {"health":120.0,"taunt":true,"radius":BEACON_TAUNT_RADIUS})); affected = 1
		"card_phantom_bloom":
			var phantom := _spawn_phantom(game, target, float(card["duration"]))
			if phantom != null: created.append(phantom); affected = 1
		"card_local_repair_rain": affected = _heal_area(game, _target_position(target), float(card.get("radius", 100.0)), float(card["heal"]))
		"card_golden_rain": created.append(_spawn_zone(game, id, target, card, {"periodic_heal":10.0,"cleanse_corrosion":true,"tick_interval":1.0,"start_delay":1.0})); affected = 1
		"card_weather_seal": game.weather_seal_time = float(card["duration"]); affected = 1
		"card_time_stasis": _apply_enemy_stasis(game, float(card["duration"])); affected = 1
		"card_golden_domain": created.append(_spawn_zone(game, id, target, card, {"domain":true})); affected = 1
		"card_garden_resurrection": affected = _resurrect_plants(game)
		"card_shadow_redemption": affected = 1 if target.convert_to_friendly(get_redemption_duration(target.get_rank())) else 0
		_:
			var object := TemporaryObject.new(); game.add_child(object); object.configure(id, _target_position(target), card); created.append(object); affected = 1
	return {"ok":affected > 0, "energy_spent":int(card["energy_cost"]), "created":created, "affected":affected}

func _spawn_zone(game: Node, id: String, target: Variant, card: Dictionary, extra: Dictionary) -> Node:
	var values := card.duplicate(true); for key in extra.keys(): values[key] = extra[key]
	if id in ["card_root_snare", "card_hex_break_lamp", "card_sun_arrow_rain", "card_root_prison", "card_golden_rain", "card_golden_domain"]:
		for child in game.get_children():
			if "object_id" in child and child.object_id == id:
				child.global_position = _target_position(target); child.remaining_time = float(values.get("duration", child.remaining_time)); return child
	var object := TemporaryObject.new(); game.add_child(object); object.configure(id, _target_position(target), values)
	if id == "card_temporary_sprout":
		var parent: Node = game.find_best_parent_excluding(object.global_position, 0, object, false)
		if parent == null: object.free(); return null
		object.set_parent_source(parent)
	return object

func _apply_enemy_stasis(game: Node, duration: float) -> int:
	var count := 0
	if not game.is_inside_tree(): return count
	for enemy in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if enemy.enemy_id == "root_crown_colossus" and enemy.ability_windup > 0.0: enemy.interrupt_ability()
			enemy.apply_stun(get_stasis_duration(enemy.get_rank()))
			count += 1
	return count

func _resurrect_plants(game: Node) -> int:
	var count := 0; var dead: Array[Node] = []
	for plant in game.plants:
		if is_instance_valid(plant) and plant.health <= 0.0: dead.append(plant)
	dead.sort_custom(func(a: Node, b: Node): return a.death_order > b.death_order)
	for plant in dead:
		var occupied := false
		for other in game.plants:
			if other != plant and is_instance_valid(other) and other.health > 0.0 and other.global_position.distance_to(plant.global_position) < 48.0: occupied = true; break
		if occupied: continue
		if plant.revive(0.5): count += 1
		if count >= 3: break
	return count

func _transplant(game: Node, target: Variant) -> int:
	if not (target is Dictionary): return 0
	var plant: Node = target.get("plant")
	var destination: Vector2 = target.get("position", Vector2.ZERO)
	if not is_instance_valid(plant) or not game.battlefield.is_inside_plantable_area(destination): return 0
	if not game.battlefield.is_position_clear(destination, 24.0, game._occupied_positions(plant)) or game.find_best_parent(destination, int(ContentData.get_flower(plant.get_flower_id()).get("seed_cost", 2))) == null: return 0
	plant.global_position = destination; game._rebuild_network(); return 1

func _spawn_phantom(game: Node, target: Variant, duration: float) -> Node:
	if not (target is Node) or not target.is_in_group("plants"): return null
	var position := find_phantom_position(game, target)
	if position == Vector2.INF: return null
	var phantom := PlantScript.new(); phantom.global_position = position; game.add_child(phantom); phantom.configure(target.kind, 0)
	phantom.max_health *= 0.60; phantom.health = phantom.max_health; phantom.attack_damage *= 0.60; phantom.card_power_time = duration; phantom.set_powered(true); game.plants.append(phantom)
	phantom.temporary_lifetime = duration
	return phantom

func find_phantom_position(game: Node, source: Node) -> Vector2:
	if not is_instance_valid(source) or not is_instance_valid(game.battlefield): return Vector2.INF
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var candidate: Vector2 = source.global_position + Vector2(cos(angle), sin(angle)) * 58.0
		if game.battlefield.is_inside_plantable_area(candidate) and game.battlefield.is_position_clear(candidate, 24.0, game._occupied_positions(source)): return candidate
	return Vector2.INF

func _heal_area(game: Node, center: Vector2, radius: float, amount: float) -> int:
	var count := 0
	if not game.is_inside_tree(): return count
	for group_name in ["plants", "light_nodes"]:
		for unit in game.get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(unit) and unit.global_position.distance_to(center) <= radius and unit.has_method("heal") and unit.heal(amount): count += 1
	return count

func _heal_plants(game: Node, center: Vector2, radius: float, amount: float) -> int:
	var count := 0
	for plant in game.plants:
		if is_instance_valid(plant) and plant.health > 0.0 and plant.health < plant.max_health and plant.global_position.distance_to(center) <= radius and plant.has_method("heal") and plant.heal(amount):
			count += 1
	return count

func _target_context(target: Variant) -> Dictionary:
	if target is Dictionary: return {"type":"plant" if target.has("plant") else "ground"}
	if target is Node:
		if target.is_in_group("enemies"): return {"type":"enemy"}
		if target.is_in_group("plants"): return {"type":"plant"}
		if target.is_in_group("light_nodes"): return {"type":"node"}
	return {"type":"ground"}

func _validate_runtime_target(game: Node, card: Dictionary, target: Variant) -> bool:
	var target_type := str(card.get("target_type", ""))
	if target_type == "ground":
		if not is_instance_valid(game.battlefield): return false
		var point := _target_position(target)
		if not game.battlefield.is_inside_plantable_area(point): return false
		if str(card["id"]) == "card_temporary_sprout" and game.find_best_parent_excluding(point, 0, null, false) == null: return false
		if str(card["id"]) == "card_emergency_dew" and not _has_wounded_plant_in_radius(game, point, float(card.get("radius", 140.0))): return false
	return true

func _has_wounded_plant_in_radius(game: Node, center: Vector2, radius: float) -> bool:
	for plant in game.plants:
		if is_instance_valid(plant) and plant.health > 0.0 and plant.health < plant.max_health and plant.global_position.distance_to(center) <= radius:
			return true
	return false

func _target_position(target: Variant) -> Vector2:
	if target is Dictionary: return target.get("position", Vector2.ZERO)
	return target.global_position if target is Node2D else target

func _phase_name(phase: int) -> String: return "day" if phase == 0 else "night"
