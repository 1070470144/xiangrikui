extends Node2D


const ArtLibrary = preload("res://scripts/art_library.gd")
const Balance = preload("res://scripts/balance.gd")
const ContentData = preload("res://scripts/content_data.gd")
const FloatText = preload("res://scripts/combat_float_text.gd")
const MonsterAnimations = preload("res://scripts/monster_animation_library.gd")
const MonsterAttackFX = preload("res://scripts/monster_attack_fx.gd")

signal died(reward: float, at_position: Vector2)
signal split_requested(at_position: Vector2, count: int)
signal area_damage_requested(center: Vector2, radius: float, damage: float)
signal dark_sun_requested(stored_light_loss: float)
signal boss_warning_requested(kind: String, center: Vector2, radius: float, duration: float)
signal boss_zone_requested(kind: String, center: Vector2, radius: float, duration: float)
signal boss_summon_requested(kind: String, center: Vector2, count: int)
signal boss_shield_changed(active: bool)
signal boss_core_exposed(duration: float)
signal boss_special_finished(kind: String)
signal boss_cleanup_requested()

enum Kind { SHADOW_BEAST, EROSION_BUG, ROOT_COLOSSUS, SUN_DEVOURER, HUSK_RAM, SPORE_MOTH, LANTERN_EATER, ROT_CALLER, SPLIT_SHADE, SHELL_SCARAB }
const KIND_IDS := ["shadow_beast", "erosion_bug", "root_crown_colossus", "sun_devourer", "husk_ram", "spore_moth", "lantern_eater", "rot_caller", "split_shade", "shell_scarab"]

@export var kind: Kind = Kind.SHADOW_BEAST
var max_health := 60.0
var health := 60.0
var move_speed := 48.0
var attack_damage := 12.0
var attack_interval := 1.0
var attack_range := 38.0
var light_reward := 12.0
var target: Node2D
var mother_flower: Node2D
var light_nodes: Array[Node] = []
var _attack_cooldown := 0.0
var _death_emitted := false
var _hit_flash := 0.0
var _attack_pose := 0.0
var _spawn_pose := 0.0
var _death_pose := 0.0
var art_sprite: Sprite2D
var animation_frames: SpriteFrames
var _animation_clock := 0.0
var _walk_phase := 0.0
var _was_moving := false
var _moving := false
var enemy_id := "shadow_beast"
var rank := "normal"
var friendly := false
var friendly_time := 0.0
var slow_ratio := 0.0
var slow_time := 0.0
var attack_slow_ratio := 0.0
var attack_slow_time := 0.0
var card_damage_multiplier := 1.0
var card_power_time := 0.0
var move_buff_ratio := 0.0
var attack_buff_ratio := 0.0
var buff_time := 0.0
var charge_time := 0.0
var charge_cooldown := 0.0
var support_cooldown := 5.0
var special_cooldown := 8.0
var _boss_thresholds: Array[float] = []
var burn_dps := 0.0
var burn_time := 0.0
var burn_tick := 0.0
var stun_time := 0.0
var mother_damage_multiplier := 1.0
var mother_mark_time := 0.0
var ability_windup := 0.0
var ability_target: Node = null
var boss_skill := ""
var boss_skill_timer := 0.0
var boss_shield := 0.0
var core_exposed_time := 0.0
var boss_enraged := false
var terrain_map: Node = null
var _decision_clock := 0.0
var _decision_interval := 0.2
var _configured := false
var configuration_count := 0
var _resources: Node
var _values: Dictionary = {}
var _runtime: Dictionary = {}
var _layouts: Dictionary = {}
var _last_art_state := ""
var _last_art_frame := -1
var _speed_frame := -1
var _speed_value := 0.0

func _ready() -> void:
	add_to_group("enemies")
	if not _configured: configure(kind, global_position)
	_setup_art()
	_resources = get_node_or_null("/root/PlantResources")
	if _resources != null:
		_resources.enemy_ready.connect(_on_animation_ready)
		_resources.request_enemy(enemy_id)
		for path in [ArtLibrary.SHADOW_MOVE, ArtLibrary.SHADOW_ATTACK, ArtLibrary.BUG_MOVE, ArtLibrary.BUG_ATTACK]: _resources.request_texture(path)
	set_process(true)

func _setup_art() -> void:
	art_sprite = Sprite2D.new()
	art_sprite.name = "ArtSprite"
	art_sprite.position = Vector2(0, -15)
	add_child(art_sprite)
	_update_art_texture()

func configure(new_kind: Kind, spawn_position: Vector2) -> void:
	kind = new_kind
	configure_by_id(KIND_IDS[int(kind)], spawn_position)

func configure_by_id(new_id: String, spawn_position: Vector2) -> void:
	_configured = true
	configuration_count += 1
	enemy_id = new_id
	var kind_index := KIND_IDS.find(new_id)
	if kind_index >= 0: kind = kind_index as Kind
	global_position = spawn_position
	var values := ContentData.get_enemy(enemy_id)
	_values = values
	max_health = float(values["health"])
	move_speed = float(values["speed"])
	attack_damage = float(values["damage"])
	attack_interval = float(values["interval"])
	attack_range = float(values["range"])
	light_reward = int(values["reward"])
	rank = str(values.get("rank", "normal"))
	health = max_health
	animation_frames = MonsterAnimations.get_frames(enemy_id)
	_cache_animation_metadata()
	_animation_clock = 0.0
	_walk_phase = 0.0
	_was_moving = false
	_attack_pose = 0.0
	_moving = false
	_spawn_pose = 0.0
	_death_pose = 0.0
	_death_emitted = false
	_boss_thresholds.clear(); move_buff_ratio = 0.0; attack_buff_ratio = 0.0; buff_time = 0.0; charge_time = 0.0; charge_cooldown = 0.0; support_cooldown = 5.0; special_cooldown = 8.0
	burn_dps = 0.0; burn_time = 0.0; burn_tick = 0.0; stun_time = 0.0; mother_damage_multiplier = 1.0; mother_mark_time = 0.0
	ability_windup = 0.0; ability_target = null
	boss_skill = ""; boss_skill_timer = 0.0; boss_shield = 0.0; core_exposed_time = 0.0; boss_enraged = false
	boss_state = "idle"; boss_recovery = 0.0; boss_pending_summons = 0; boss_shield_delay = 0.0
	boss_light_progress = 0.0; boss_light_cooldown = 0.0; boss_animation_elapsed = 0.0
	if enemy_id == "root_crown_colossus": special_cooldown = 7.0
	_decision_interval = 0.15 + fmod(float(get_instance_id() % 11), 11.0) * 0.01
	_decision_clock = fmod(float(get_instance_id() % 17), 17.0) * 0.01
	_update_art_texture()
	queue_redraw()
	_sync_index()

func _cache_animation_metadata() -> void:
	_runtime = animation_frames.get_meta("runtime", {}) if animation_frames != null else {}
	_layouts.clear()
	if animation_frames != null:
		for state in animation_frames.get_animation_names(): _layouts[state] = animation_frames.get_meta(state + "_layout", {})
	_last_art_state = ""; _last_art_frame = -1

func _on_animation_ready(id: String) -> void:
	if id != enemy_id or health <= 0.0 or is_queued_for_deletion(): return
	animation_frames = MonsterAnimations.get_frames(enemy_id)
	_cache_animation_metadata()
	_update_art_texture()
	queue_redraw()

func _sync_index() -> void:
	var host := get_parent()
	if host != null and host.has_method("sync_enemy"): host.sync_enemy(self)

func set_targets(flower: Node2D, nodes: Array[Node]) -> void:
	mother_flower = flower
	light_nodes = nodes
	_retarget()
	_update_facing()

func set_terrain_map(value: Node) -> void:
	terrain_map = value

func begin_spawn() -> void:
	if animation_frames != null and animation_frames.has_animation("spawn"):
		_spawn_pose = _animation_duration("spawn")
		_animation_clock = 0.0
		_update_art_texture()

func get_terrain_speed_multiplier() -> float:
	return terrain_map.get_movement_multiplier(global_position) if is_instance_valid(terrain_map) else 1.0

func get_weather_attack_multiplier() -> float:
	var scene := get_parent()
	return float(scene.get_weather_enemy_attack_multiplier()) if not friendly and scene != null and scene.has_method("get_weather_enemy_attack_multiplier") else 1.0

func get_effective_move_speed(reuse_this_frame := false) -> float:
	var frame := Engine.get_process_frames()
	if reuse_this_frame and _speed_frame == frame: return _speed_value
	var base_speed := 110.0 if charge_time > 0.0 else move_speed
	var weather_multiplier := 1.0
	var scene := get_parent()
	if not friendly and scene != null and scene.has_method("get_weather_enemy_speed_multiplier"):
		weather_multiplier = float(scene.get_weather_enemy_speed_multiplier())
	_speed_value = base_speed * (1.0 + move_buff_ratio) * (1.0 - slow_ratio) * get_terrain_speed_multiplier() * weather_multiplier
	_speed_frame = frame
	return _speed_value

func _retarget() -> void:
	if friendly:
		target = _nearest_hostile_enemy(); return
	if rank != "boss" and is_inside_tree():
		var taunt_target := _nearest_taunt_object()
		if taunt_target != null: target = taunt_target; return
	if bool(_values.get("targets_nodes", false)):
		var nearest: Node2D = null
		var best := INF
		for node in light_nodes:
			if not is_instance_valid(node) or not node.is_connected_to_light:
				continue
			var distance := global_position.distance_to(node.global_position)
			if distance < best:
				best = distance
				nearest = node
		if nearest != null:
			target = nearest
			return
	target = mother_flower

func _process(delta: float) -> void:
	_speed_frame = -1
	if _death_pose > 0.0:
		_death_pose = maxf(0.0, _death_pose - delta)
		_animation_clock += delta
		_update_art_texture()
		if _death_pose <= 0.0:
			queue_free()
		return
	if health <= 0.0:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	advance_statuses(delta)
	if health <= 0.0: return
	if enemy_id == "root_crown_colossus":
		advance_root_light(delta, is_in_boss_light())
	else:
		core_exposed_time = maxf(0.0, core_exposed_time - delta)
	if boss_shield > 0.0:
		boss_shield = maxf(0.0, boss_shield - delta)
		if boss_shield <= 0.0: boss_shield_changed.emit(false)
	_moving = false
	if _spawn_pose > 0.0:
		_spawn_pose = maxf(0.0, _spawn_pose - delta)
		_animate_art(delta)
		return
	if is_controlled():
		if art_sprite != null:
			art_sprite.modulate = Color.WHITE if _hit_flash <= 0.0 else Color(1.35, 1.35, 1.45)
		if art_sprite == null or art_sprite.texture == null: queue_redraw()
		return
	_attack_pose = maxf(0.0, _attack_pose - delta)
	if friendly:
		friendly_time -= delta
		if friendly_time <= 0.0: friendly = false; remove_from_group("friendly_enemies"); add_to_group("enemies"); _sync_index(); _retarget()
	slow_time = maxf(0.0, slow_time - delta); if slow_time <= 0.0: slow_ratio = 0.0
	attack_slow_time = maxf(0.0, attack_slow_time - delta); if attack_slow_time <= 0.0: attack_slow_ratio = 0.0
	card_power_time = maxf(0.0, card_power_time - delta); if card_power_time <= 0.0: card_damage_multiplier = 1.0
	buff_time = maxf(0.0, buff_time - delta); if buff_time <= 0.0: move_buff_ratio = 0.0; attack_buff_ratio = 0.0
	charge_cooldown = maxf(0.0, charge_cooldown - delta); charge_time = maxf(0.0, charge_time - delta)
	_decision_clock -= delta
	if _decision_clock <= 0.0:
		_decision_clock = _decision_interval
		if rank != "boss": _process_special(_decision_interval)
		if not is_instance_valid(target) or ("health" in target and target.health <= 0.0):
			_retarget()
	if rank == "boss":
		advance_special(delta)
		if ability_windup > 0.0 or boss_recovery > 0.0:
			_animate_art(delta)
			return
	if not is_instance_valid(target):
		_animate_art(delta)
		return
	var distance := global_position.distance_to(target.global_position)
	if distance > attack_range:
		_moving = true
		var effective_speed := get_effective_move_speed()
		if enemy_id == "husk_ram" and can_start_charge(distance): charge_time = 1.2; charge_cooldown = 6.0
		global_position = global_position.move_toward(target.global_position, effective_speed * delta)
		_sync_index()
	elif _attack_cooldown <= 0.0:
		_attack_pose = _art_attack_duration() if animation_frames != null else 0.18
		_animation_clock = 0.0
		_update_art_texture()
		var impact_damage := attack_damage
		var charged_impact := enemy_id == "husk_ram" and charge_time > 0.0
		if charged_impact: impact_damage = float(ContentData.get_enemy(enemy_id).get("charge_damage", 24.0))
		impact_damage *= get_weather_attack_multiplier()
		_spawn_attack_fx(target, charged_impact)
		if target.has_method("take_enemy_damage"):
			target.take_enemy_damage(impact_damage, rank, attack_range < 100.0, self)
		else:
			target.take_damage(impact_damage)
		if enemy_id == "spore_moth" and target.has_method("apply_corrosion"): target.apply_corrosion(2.0, 4.0)
		if charged_impact: charge_time = 0.0; apply_stun(0.8)
		_attack_cooldown = attack_interval * (1.0 - attack_buff_ratio) * (1.0 + attack_slow_ratio)
	if art_sprite == null or art_sprite.texture == null: queue_redraw()
	_animate_art(delta)

func _spawn_attack_fx(hit_target: Node, charged_impact: bool) -> void:
	if not is_inside_tree() or not is_instance_valid(hit_target):
		return
	var target_2d := hit_target as Node2D
	if target_2d == null:
		return
	if not MonsterAttackFX.can_spawn():
		return
	var effect := MonsterAttackFX.new()
	var kind := "slash"
	match enemy_id:
		"shadow_beast": kind = "claw"
		"erosion_bug": kind = "pincer"
		"husk_ram": kind = "impact"
		"spore_moth": kind = "corrosion"
		"shell_scarab": kind = "armor"
		_: kind = "slash"
	var host := get_tree().current_scene
	if not is_instance_valid(host):
		host = get_parent()
	if not is_instance_valid(host):
		effect.free()
		return
	host.add_child(effect)
	effect.configure(kind, global_position, target_2d.global_position, charged_impact)

func _start_death() -> void:
	if _death_emitted:
		return
	_death_emitted = true
	var host := get_parent()
	if host != null and host.has_method("unregister_enemy"): host.unregister_enemy(self)
	if rank == "boss":
		ability_windup = 0.0; boss_shield = 0.0; core_exposed_time = 0.0; boss_pending_summons = 0
		boss_skill = ""; boss_recovery = 0.0; boss_skill_timer = 0.0; boss_light_progress = 0.0; boss_light_cooldown = 0.0
		boss_cleanup_requested.emit()
	if enemy_id == "split_shade": split_requested.emit(global_position, 2)
	died.emit(light_reward, global_position)
	if animation_frames != null and animation_frames.has_animation("death") and is_inside_tree():
		_death_pose = _animation_duration("death")
		_animation_clock = 0.0
		_moving = false
		_attack_pose = 0.0
		_update_art_texture()
	else:
		if is_inside_tree(): queue_free()

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	var before := health
	var dealt := calculate_incoming_damage(amount * card_damage_multiplier, true, false)
	health = maxf(0.0, health - dealt)
	_show_float(before - health, false)
	_process_boss_thresholds(before, health)
	_hit_flash = 0.12
	queue_redraw()
	if health <= 0.0: _start_death()

func is_frontal_source(source_position: Vector2) -> bool:
	if not is_instance_valid(target): return true
	var facing := global_position.direction_to(target.global_position)
	var incoming := global_position.direction_to(source_position)
	return facing.dot(incoming) >= 0.0

func take_directional_damage(amount: float, source_position: Vector2) -> void:
	if amount <= 0.0 or health <= 0.0: return
	var before := health
	health = maxf(0.0, health - calculate_incoming_damage(amount * card_damage_multiplier, is_frontal_source(source_position), false))
	_show_float(before - health, false)
	_process_boss_thresholds(before, health); _hit_flash = 0.12; queue_redraw()
	if health <= 0.0: _start_death()

func take_mother_damage(amount: float, source_position: Vector2 = Vector2.INF) -> void:
	if source_position == Vector2.INF: take_damage(amount * mother_damage_multiplier)
	else: take_directional_damage(amount * mother_damage_multiplier, source_position)

func _show_float(amount: float, healing: bool) -> void:
	if amount <= 0.0 or not is_inside_tree(): return
	if not FloatText.can_spawn(): return
	var label := FloatText.new(); add_child(label); label.setup(amount, healing)

func apply_burn(damage_per_second: float, duration: float) -> void:
	burn_dps = maxf(burn_dps, damage_per_second); burn_time = maxf(burn_time, duration)

func apply_stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)

func apply_mother_mark(multiplier: float, duration: float) -> void:
	mother_damage_multiplier = maxf(mother_damage_multiplier, multiplier); mother_mark_time = maxf(mother_mark_time, duration)

func is_controlled() -> bool: return stun_time > 0.0

func push_from(origin: Vector2, distance: float) -> void:
	var direction := origin.direction_to(global_position)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	global_position += direction * maxf(0.0, distance)
	_sync_index()
	_speed_frame = -1

func advance_statuses(delta: float) -> void:
	if delta <= 0.0: return
	stun_time = maxf(0.0, stun_time - delta)
	if mother_mark_time > 0.0:
		mother_mark_time = maxf(0.0, mother_mark_time - delta)
		if mother_mark_time <= 0.0: mother_damage_multiplier = 1.0
	if burn_time > 0.0:
		var active_delta := minf(delta, burn_time); burn_time = maxf(0.0, burn_time - delta); burn_tick += active_delta
		while burn_tick >= 1.0 and health > 0.0:
			burn_tick -= 1.0; take_area_damage(burn_dps)
		if burn_time <= 0.0: burn_dps = 0.0

func apply_slow(_source_id: String, ratio: float, duration: float) -> void:
	var cap := float(ContentData.get_enemy(enemy_id).get("slow_cap", 0.50))
	slow_ratio = minf(cap, maxf(slow_ratio, ratio)); slow_time = maxf(slow_time, duration)
	_speed_frame = -1 # A card can change movement after this frame's cached speed was read.

func apply_attack_slow(_source_id: String, ratio: float, duration: float) -> void:
	attack_slow_ratio = maxf(attack_slow_ratio, ratio); attack_slow_time = maxf(attack_slow_time, duration)

func take_area_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0: return
	var dealt := calculate_incoming_damage(amount * card_damage_multiplier, false, true)
	var before := health; health = maxf(0.0, health - dealt); _process_boss_thresholds(before, health)
	if health <= 0.0: _start_death()

func remove_positive_buffs() -> void: move_buff_ratio = 0.0; attack_buff_ratio = 0.0; buff_time = 0.0
func interrupt_ability() -> bool:
	var interrupted := charge_time > 0.0 or ability_windup > 0.0
	if not interrupted: return false
	charge_time = 0.0; ability_windup = 0.0; ability_target = null; boss_skill = ""; boss_skill_timer = 0.0
	special_cooldown = maxf(special_cooldown, 2.0)
	if interrupted and rank == "boss":
		boss_recovery = 0.0
		boss_special_finished.emit("interrupted")
		if enemy_id == "root_crown_colossus": expose_core(2.0)
		else: core_exposed_time = 2.0; boss_core_exposed.emit(2.0)
	return interrupted
func get_rank() -> String: return rank
func can_start_charge(distance: float) -> bool: return enemy_id == "husk_ram" and charge_cooldown <= 0.0 and distance >= 120.0 and distance <= 260.0
func get_corrosion_profile() -> Dictionary: return {"damage":2.0,"duration":4.0} if enemy_id == "spore_moth" else {}
func get_supply_multiplier() -> float: return 0.70 if enemy_id == "lantern_eater" else 1.0
func get_split_count() -> int: return 2 if enemy_id == "split_shade" else 0
func calculate_incoming_damage(amount: float, frontal: bool, area: bool) -> float:
	var result := amount * 0.60 if enemy_id == "shell_scarab" and frontal and not area else amount
	if rank == "boss":
		if core_exposed_time > 0.0: result *= 1.35
		elif boss_shield > 0.0: result *= 0.35
	return result

func apply_support_buff(ally: Node) -> bool:
	if enemy_id != "rot_caller" or not is_instance_valid(ally) or ally.get_rank() == "boss": return false
	ally.move_buff_ratio = maxf(ally.move_buff_ratio, 0.20); ally.attack_buff_ratio = maxf(ally.attack_buff_ratio, 0.15); ally.buff_time = maxf(ally.buff_time, 4.0); return true

func convert_to_friendly(duration: float) -> bool:
	if rank == "boss" or duration <= 0.0: return false
	friendly = true; friendly_time = duration; remove_from_group("enemies"); add_to_group("friendly_enemies"); _sync_index(); _retarget(); return true

func _nearest_hostile_enemy() -> Node2D:
	var host := get_parent()
	if host != null and host.has_method("nearest_hostile_enemy"): return host.nearest_hostile_enemy(global_position, self)
	var nearest: Node2D = null; var best := INF
	var candidates: Array = get_parent().get_active_enemies() if is_instance_valid(get_parent()) and get_parent().has_method("get_active_enemies") else get_tree().get_nodes_in_group("enemies")
	for candidate in candidates:
		if candidate == self or not is_instance_valid(candidate): continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best: best = distance; nearest = candidate
	return nearest

func _nearest_taunt_object() -> Node2D:
	var nearest: Node2D = null; var best := INF
	for object in get_tree().get_nodes_in_group("temporary_battle_objects"):
		if not is_instance_valid(object) or not object.taunt: continue
		if rank == "boss": continue
		if object.object_id in ["card_root_wall", "card_path_beacon"] and rank != "normal": continue
		var distance := global_position.distance_to(object.global_position)
		if distance <= maxf(160.0, object.radius) and distance < best: best = distance; nearest = object
	return nearest

func _process_special(delta: float) -> void:
	if not is_inside_tree(): return
	advance_special(delta)

func advance_special(delta: float) -> void:
	if health <= 0.0: return
	if rank == "boss":
		advance_boss(delta)
		return
	if enemy_id == "rot_caller":
		support_cooldown -= delta
		if support_cooldown <= 0.0 and is_inside_tree():
			support_cooldown = 5.0
			var host := get_parent()
			var allies: Array = host.query_enemies_in_radius(global_position, 140.0) if host != null and host.has_method("query_enemies_in_radius") else get_tree().get_nodes_in_group("enemies")
			for ally in allies:
				if ally != self and is_instance_valid(ally) and ally.global_position.distance_to(global_position) <= 140.0: apply_support_buff(ally)
	elif enemy_id == "lantern_eater" and is_inside_tree():
		for node in get_tree().get_nodes_in_group("light_nodes"):
			if is_instance_valid(node) and node.global_position.distance_to(global_position) <= 110.0: node.apply_supply_suppression(0.70, 0.2)

var boss_state := "idle"
var boss_recovery := 0.0
var boss_pending_summons := 0
var boss_cast_position := Vector2.ZERO
var boss_shield_delay := 0.0
var boss_light_progress := 0.0
var boss_light_cooldown := 0.0
var boss_animation_elapsed := 0.0

func is_in_boss_light() -> bool:
	if is_instance_valid(mother_flower) and mother_flower.health > 0.0 and global_position.distance_to(mother_flower.global_position) <= 260.0: return true
	for node in light_nodes:
		if is_instance_valid(node) and node.health > 0.0 and node.is_connected_to_light and global_position.distance_to(node.global_position) <= node.supply_radius: return true
	var host := get_parent()
	if host != null and host.has_method("_temporary_supply_nodes"):
		for node in host._temporary_supply_nodes():
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.health > 0.0 and node.is_connected_to_light and global_position.distance_to(node.global_position) <= node.supply_radius: return true
	return false

func expose_core(duration: float) -> void:
	if core_exposed_time > 0.0 or health <= 0.0: return
	core_exposed_time = duration
	boss_light_progress = 0.0
	boss_core_exposed.emit(duration)

func advance_root_light(delta: float, covered: bool) -> void:
	# Consume timer boundaries separately: a long frame must not skip cooldown.
	var remaining := maxf(0.0, delta)
	if core_exposed_time > 0.0:
		var used := minf(remaining, core_exposed_time)
		core_exposed_time = maxf(0.0, core_exposed_time - used)
		remaining -= used
		if core_exposed_time <= 0.0: boss_light_cooldown = 8.0
		else: return
	if boss_light_cooldown > 0.0:
		var used := minf(remaining, boss_light_cooldown)
		boss_light_cooldown = maxf(0.0, boss_light_cooldown - used)
		remaining -= used
	if not covered:
		boss_light_progress = 0.0
		return
	if boss_light_cooldown > 0.0: return
	boss_light_progress += remaining
	if boss_light_progress >= 3.0:
		var excess := boss_light_progress - 3.0
		expose_core(3.0)
		if excess > 0.0: advance_root_light(excess, covered)

func get_boss_state() -> Dictionary:
	return {"state":boss_state, "skill":boss_skill, "shield":boss_shield, "exposed":core_exposed_time, "enraged":boss_enraged, "windup":ability_windup, "light_progress":boss_light_progress, "light_cooldown":boss_light_cooldown}

func start_boss_skill(skill: String, center: Vector2, duration: float) -> void:
	boss_skill = skill; boss_state = "windup"; boss_cast_position = center
	ability_windup = duration; boss_skill_timer = duration; _animation_clock = 0.0
	boss_animation_elapsed = 0.0
	boss_warning_requested.emit(skill, center, 112.0 if skill == "slam" else 85.0, duration)

func advance_boss(delta: float) -> void:
	if health <= 0.0: return
	if ability_windup > 0.0:
		boss_animation_elapsed += minf(delta, ability_windup)
		var overshoot := maxf(0.0, delta - ability_windup)
		ability_windup = maxf(0.0, ability_windup - delta); boss_skill_timer = ability_windup
		if ability_windup <= 0.0:
			boss_state = "execute"
			match boss_skill:
				"slam":
					area_damage_requested.emit(boss_cast_position, 112.0, 22.0)
					boss_zone_requested.emit("root_lock", boss_cast_position, 125.0, 3.5)
				"devour":
					if is_instance_valid(ability_target) and ability_target.health > 0.0 and ability_target.is_connected_to_light:
						ability_target.take_damage(35.0 * get_weather_attack_multiplier())
						ability_target.apply_supply_suppression(0.55, 4.0)
						boss_shield = 2.5; boss_shield_changed.emit(true); boss_shield_delay = 2.5
					else:
						core_exposed_time = 2.0; boss_core_exposed.emit(2.0)
				"summon":
					boss_summon_requested.emit("root_guard", boss_cast_position, 2)
					if enemy_id == "sun_devourer": core_exposed_time = 3.0; boss_core_exposed.emit(3.0)
			boss_special_finished.emit(boss_skill); ability_target = null
			boss_recovery = 0.65
			if boss_skill == "slam" and animation_frames != null and animation_frames.has_animation("slam"):
				boss_recovery = maxf(0.65, _animation_duration("slam") - float(_layouts.get("slam", {}).get("impact_time", 1.2)))
			boss_recovery = maxf(0.0, boss_recovery - overshoot)
			boss_animation_elapsed += overshoot
		return
	if boss_recovery > 0.0:
		boss_animation_elapsed += minf(delta, boss_recovery)
		boss_state = "recovery"; boss_recovery = maxf(0.0, boss_recovery - delta)
		return
	if boss_shield_delay > 0.0:
		boss_shield_delay = maxf(0.0, boss_shield_delay - delta)
		if boss_shield_delay <= 0.0: core_exposed_time = 3.0; boss_core_exposed.emit(3.0)
	if enemy_id == "root_crown_colossus" and core_exposed_time > 0.0:
		boss_state = "exposed"
		return
	if boss_pending_summons > 0:
		boss_pending_summons -= 1; start_boss_skill("summon", global_position, 1.0)
		return
	boss_state = "exposed" if core_exposed_time > 0.0 else ("enraged" if boss_enraged else "idle")
	special_cooldown -= delta
	if special_cooldown > 0.0: return
	special_cooldown = (4.5 if boss_enraged else 7.0) if enemy_id == "root_crown_colossus" else (6.0 if boss_enraged else 8.0)
	if enemy_id == "root_crown_colossus":
		var point := mother_flower.global_position if is_instance_valid(mother_flower) else global_position
		if is_inside_tree():
			var nearest := INF
			for plant in get_tree().get_nodes_in_group("plants"):
				if plant.health > 0.0 and global_position.distance_squared_to(plant.global_position) < nearest:
					nearest = global_position.distance_squared_to(plant.global_position); point = plant.global_position
		start_boss_skill("slam", point, 1.2)
	else:
		var best := INF
		for node in light_nodes:
			if not is_instance_valid(node) or node.health <= 0.0 or not node.is_connected_to_light: continue
			var distance := global_position.distance_squared_to(node.global_position)
			if distance < best: best = distance; ability_target = node
		if is_instance_valid(ability_target): start_boss_skill("devour", ability_target.global_position, 1.2)

func _process_boss_thresholds(before: float, after: float) -> void:
	if after <= 0.0: return
	var thresholds := [0.75, 0.50, 0.25] if enemy_id == "root_crown_colossus" else [0.65, 0.30]
	if rank != "boss": return
	for threshold in thresholds:
		if before > max_health * threshold and after <= max_health * threshold and not _boss_thresholds.has(threshold):
			_boss_thresholds.append(threshold); boss_pending_summons += 1
			if enemy_id == "sun_devourer" and threshold == 0.65: dark_sun_requested.emit(2.0)
			if threshold == (0.25 if enemy_id == "root_crown_colossus" else 0.30):
				boss_enraged = true
				if enemy_id == "sun_devourer": move_speed *= 1.25; attack_interval *= 0.85

func _draw() -> void:
	var flash := Color.WHITE if _hit_flash > 0.0 else Color("4c8490")
	if art_sprite != null and art_sprite.texture != null:
		return
	if rank == "boss":
		_draw_boss_fallback()
		return
	if kind == Kind.SHADOW_BEAST:
		draw_colored_polygon(PackedVector2Array([Vector2(-25, 10), Vector2(-17, -13), Vector2(0, -22), Vector2(22, -8), Vector2(27, 14), Vector2(4, 20)]), Color("211c32"))
		draw_circle(Vector2(10, -7), 5.0, flash)
		draw_circle(Vector2(12, -8), 2.0, Color("b7e7e4"))
	else:
		for i in range(4):
			draw_circle(Vector2(-16 + i * 10, 0), 10.0 - i, Color("30243f"))
		draw_line(Vector2(-12, 6), Vector2(-20, 16), flash, 3.0)
		draw_line(Vector2(5, 6), Vector2(13, 16), flash, 3.0)
		draw_circle(Vector2(13, -3), 3.0, flash)

func _update_art_texture() -> void:
	if art_sprite == null:
		return
	if animation_frames != null:
		var state := "walk" if animation_frames.has_animation("walk") else "idle"
		if _death_pose > 0.0: state = "death"
		elif _spawn_pose > 0.0: state = "spawn"
		elif _attack_pose > 0.0: state = "attack"
		elif rank == "boss":
			if (ability_windup > 0.0 or boss_recovery > 0.0) and animation_frames.has_animation(boss_skill): state = boss_skill
			elif core_exposed_time > 0.0 and animation_frames.has_animation("exposed"): state = "exposed"
			elif boss_enraged and animation_frames.has_animation("enraged"): state = "enraged"
			elif not _moving and animation_frames.has_animation("idle"): state = "idle"
		if not animation_frames.has_animation(state): state = "idle" if animation_frames.has_animation("idle") else "walk"
		var runtime: Dictionary = _runtime
		var frame_count := animation_frames.get_frame_count(state)
		if frame_count <= 0: return
		var index := 0
		if state == "slam":
			# Map the measured source impact to logical 1.2s; hit timing is never frame-driven.
			var source_impact := float(_layouts.get(state, {}).get("impact_time", 1.2))
			var source_time := boss_animation_elapsed * source_impact / 1.2 if ability_windup > 0.0 else source_impact + maxf(0.0, boss_animation_elapsed - 1.2)
			index = mini(frame_count - 1, int(source_time * animation_frames.get_animation_speed(state)))
		elif state == "summon":
			index = mini(frame_count - 1, int(boss_animation_elapsed * animation_frames.get_animation_speed(state)))
		elif state in ["attack", "spawn", "death"]:
			var duration := _art_attack_duration()
			if state != "attack": duration = _animation_duration(state)
			index = mini(frame_count - 1, int(_animation_clock / maxf(0.001, duration) * frame_count))
		elif state in ["idle", "exposed", "enraged"]:
			index = int(_animation_clock * animation_frames.get_animation_speed(state)) % frame_count
		elif _moving or bool(runtime.get("idle_walk", false)):
			index = int(_walk_phase) % frame_count
		elif _was_moving:
			# Keep the current grounded pose for one render step when stopping.
			index = int(_walk_phase) % frame_count
		if _last_art_state == state and _last_art_frame == index: return
		_last_art_state = state; _last_art_frame = index
		art_sprite.texture = animation_frames.get_frame_texture(state, index)
		var layout: Dictionary = _layouts.get(state, {})
		if layout.has("ground_y"):
			var ground_offset := float(runtime.get("ground_offset", 8.0 - 28.0 * _art_scale()))
			art_sprite.position = Vector2(0, ground_offset - (float(layout["ground_y"]) - art_sprite.texture.get_height() * 0.5) * _art_scale())
		else:
			art_sprite.position = Vector2(0, 8.0 - 110.0 * _art_scale())
		art_sprite.scale = Vector2.ONE * _art_scale()
		return
	var attacking := _attack_pose > 0.0
	if rank == "boss":
		art_sprite.texture = null; queue_redraw(); return
	var path := ArtLibrary.SHADOW_ATTACK if attacking else ArtLibrary.SHADOW_MOVE
	if kind == Kind.EROSION_BUG or kind in [Kind.HUSK_RAM, Kind.SPORE_MOTH, Kind.LANTERN_EATER, Kind.ROT_CALLER, Kind.SPLIT_SHADE, Kind.SHELL_SCARAB]:
		path = ArtLibrary.BUG_ATTACK if attacking else ArtLibrary.BUG_MOVE
	var texture: Texture2D = ArtLibrary.get_cached_texture(path)
	if texture == null and _resources != null: texture = _resources.get_texture(path)
	if art_sprite.texture != texture: art_sprite.texture = texture
	art_sprite.scale = Vector2.ONE * _art_scale()

func _animate_art(delta: float = 0.0) -> void:
	if art_sprite == null:
		return
	if animation_frames != null:
		var runtime: Dictionary = _runtime
		if rank == "boss" or _moving or _attack_pose > 0.0 or _spawn_pose > 0.0 or _death_pose > 0.0:
			_animation_clock += delta
		if animation_frames.has_animation("walk") and (_moving or bool(runtime.get("idle_walk", false))) and _attack_pose <= 0.0:
			var fps := animation_frames.get_animation_speed("walk")
			var gait_rate := get_effective_move_speed(true) / maxf(1.0, move_speed) if _moving else 1.0
			_walk_phase = fmod(_walk_phase + delta * fps * gait_rate, float(animation_frames.get_frame_count("walk")))
		_update_art_texture()
		_was_moving = _moving
		_update_facing()
		art_sprite.modulate = Color.WHITE if _hit_flash <= 0.0 else Color(1.35, 1.35, 1.45)
		return
	if _attack_pose <= 0.0:
		_update_art_texture()
	var base_scale := _art_scale()
	var bob := sin(Time.get_ticks_msec() * 0.008 + get_instance_id() % 11) * 0.025
	var lunge := 1.10 if _attack_pose > 0.0 else 1.0
	art_sprite.scale = Vector2(base_scale * lunge, base_scale * (1.0 - bob))
	art_sprite.modulate = Color.WHITE if _hit_flash <= 0.0 else Color(1.35, 1.35, 1.45)
	_update_facing()

func _update_facing() -> void:
	if art_sprite == null or not is_instance_valid(target):
		return
	var delta := target.global_position - global_position
	if absf(delta.x) > 2.0:
		art_sprite.flip_h = delta.x < 0.0

func _art_attack_duration() -> float:
	if animation_frames == null or not animation_frames.has_animation("attack"):
		return 0.18
	var duration := float(animation_frames.get_frame_count("attack")) / animation_frames.get_animation_speed("attack")
	return minf(duration, attack_interval * 0.8)

func _animation_duration(state: String) -> float:
	if animation_frames == null or not animation_frames.has_animation(state):
		return 0.0
	return float(animation_frames.get_frame_count(state)) / maxf(1.0, animation_frames.get_animation_speed(state))

func _art_scale() -> float:
	if animation_frames != null:
		var runtime: Dictionary = _runtime
		if runtime.has("scale"):
			return float(runtime["scale"])
		return 0.36 if kind == Kind.SHADOW_BEAST else 0.32
	if kind == Kind.SHADOW_BEAST: return 0.50
	if kind == Kind.EROSION_BUG: return 0.56
	if kind == Kind.ROOT_COLOSSUS: return 0.90
	if kind in [Kind.HUSK_RAM, Kind.SHELL_SCARAB]: return 0.70
	return 1.08

func _draw_boss_fallback() -> void:
	# Clearly marked procedural fallback until the video asset is published.
	var size := 1.3 if enemy_id == "sun_devourer" else 1.0
	var tint := Color("504138")
	for i in range(7):
		var x := (float(i) - 3.0) * 15.0 * size
		draw_line(Vector2(x * 0.35, -60.0 * size), Vector2(x, 6), Color("28252b"), 13.0 * size)
		draw_line(Vector2(x * 0.35, -60.0 * size), Vector2(x, -100.0 * size - absf(x) * 0.30), tint, 8.0 * size)
	draw_circle(Vector2(0, -50) * size, 35 * size, Color("302c30"))
	for i in range(5): draw_arc(Vector2(0, -52) * size, (23.0 + i * 3.0) * size, 0.3, 2.8, 16, Color("8e8070"), 3.0 * size)
	var core := Color("ffe5a5") if core_exposed_time > 0.0 else Color("b04c38")
	draw_circle(Vector2(0, -55) * size, 13.0 * size, core)
	draw_circle(Vector2(0, -55) * size, 9.0 * size, Color("211d25"))
	if boss_shield > 0.0: draw_arc(Vector2(0, -50) * size, 45.0 * size, 0, TAU, 40, Color("9ca1cb"), 3.0)
