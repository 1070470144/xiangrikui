extends Node2D

const ArtLibrary = preload("res://scripts/art_library.gd")
const Balance = preload("res://scripts/balance.gd")
const MotherEvolution = preload("res://scripts/mother_evolution.gd")
const FloatText = preload("res://scripts/combat_float_text.gd")
const FormVisual = preload("res://scripts/mother_form_visual.gd")
const MotherAnimation = preload("res://scripts/mother_animation_library.gd")

signal health_changed(current: float, maximum: float)
signal destroyed
signal attack_requested(origin: Vector2, target: Node, damage: float)
signal pulse_requested(center: Vector2, radius: float, damage: float, energy: int)
signal root_whip_requested(center: Vector2, radius: float, damage: float)
signal secondary_damage_requested(center: Vector2, radius: float, damage: float)
signal reflected_damage_requested(attacker: Node, damage: float)
signal pulse_echo_requested(center: Vector2, radius: float, damage: float, delay: float)

@export var max_health: float = Balance.MOTHER_MAX_HEALTH
var health: float = Balance.MOTHER_MAX_HEALTH
var is_connected_to_light := true
var _destroyed_emitted := false
var _hit_flash := 0.0
var art_sprite: Sprite2D
var motion_sprite: AnimatedSprite2D
var _transform_time := 0.0
var evolution := MotherEvolution.new()
var shield := 0.0
var damage_reduction := 0.0
var attack_cooldown := 0.0
var pulse_cooldown := 0.0
var root_whip_cooldown := 0.0
var base_max_health := Balance.MOTHER_MAX_HEALTH
var combat_night := false
var damage_block_cooldown := 0.0
var time_since_damage := 999.0
var night_kill_heals := 0
var recent_damage := 0.0
var recent_damage_time := 0.0
var damage_burst_cooldown := 0.0
var solar_wind_cooldown := 10.0
var _nearby_enemy_count := 0
var _animation_id := ""

const DANGER_LOW_HEALTH_RATIO := 0.34

func _ready() -> void:
	z_index = 0
	_setup_art()
	reset_state()
	set_process(true)

func _setup_art() -> void:
	var texture := ArtLibrary.load_texture(ArtLibrary.MOTHER_HEALTHY)
	if texture == null:
		return
	art_sprite = Sprite2D.new()
	art_sprite.name = "ArtSprite"
	art_sprite.texture = texture
	art_sprite.position = Vector2(0, -24)
	art_sprite.scale = Vector2.ONE * 0.56
	add_child(art_sprite)
	motion_sprite = AnimatedSprite2D.new()
	motion_sprite.name = "PlantMotion"
	motion_sprite.position = Vector2(0, -24)
	motion_sprite.scale = Vector2.ONE * 0.56
	add_child(motion_sprite)

func reset_state() -> void:
	base_max_health = max_health
	health = max_health; shield = 0.0; damage_reduction = 0.0; attack_cooldown = 0.0; pulse_cooldown = 0.0; root_whip_cooldown = 0.0
	combat_night = false; damage_block_cooldown = 0.0; time_since_damage = 999.0; night_kill_heals = 0
	recent_damage = 0.0; recent_damage_time = 0.0; damage_burst_cooldown = 0.0; solar_wind_cooldown = 10.0
	evolution.reset()
	_animation_id = ""
	_refresh_form(false)
	_destroyed_emitted = false
	_hit_flash = 0.0
	_nearby_enemy_count = 0
	health_changed.emit(health, max_health)

func set_nearby_enemy_count(value: int) -> void:
	_nearby_enemy_count = maxi(0, value)

func advance_danger_feedback(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)

func get_danger_state() -> String:
	if _hit_flash > 0.0:
		return "hit"
	if max_health > 0.0 and health / max_health <= DANGER_LOW_HEALTH_RATIO:
		return "critical"
	if _nearby_enemy_count > 0:
		return "threatened"
	return "safe"

func take_damage(amount: float) -> void:
	take_enemy_damage(amount, "normal", false)

func take_enemy_damage(amount: float, attacker_rank: String = "normal", is_melee: bool = true, attacker: Node = null) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	var reduction := damage_reduction + (float(evolution.get_effect_value("boss_damage_reduction", 0.0)) if attacker_rank == "boss" else 0.0)
	var reduced := amount * (1.0 - clampf(reduction, 0.0, 0.80))
	if evolution.has_upgrade("mother_receptacle_04") and damage_block_cooldown <= 0.0:
		reduced = maxf(0.0, reduced - float(evolution.get_effect_value("damage_block_amount", 0.0)))
		damage_block_cooldown = float(evolution.get_effect_value("damage_block_interval", 6.0))
	var absorbed := minf(shield, reduced); shield -= absorbed; reduced -= absorbed
	var before := health; health = maxf(0.0, health - reduced); _show_float(before - health, false)
	time_since_damage = 0.0
	if is_melee and is_instance_valid(attacker) and evolution.has_upgrade("mother_counterroot_01"):
		reflected_damage_requested.emit(attacker, float(evolution.get_effect_value("melee_reflect_damage", 6.0)))
	if evolution.has_upgrade("mother_counterroot_05"):
		if recent_damage_time <= 0.0: recent_damage = 0.0; recent_damage_time = float(evolution.get_effect_value("damage_burst_window", 3.0))
		recent_damage += reduced
		if recent_damage >= float(evolution.get_effect_value("damage_burst_threshold", 30.0)) and damage_burst_cooldown <= 0.0:
			secondary_damage_requested.emit(global_position, float(evolution.get_effect_value("damage_burst_radius", 130.0)), float(evolution.get_effect_value("damage_burst_damage", 30.0)))
			damage_burst_cooldown = float(evolution.get_effect_value("damage_burst_cooldown", 8.0)); recent_damage = 0.0; recent_damage_time = 0.0
	_hit_flash = 0.16
	health_changed.emit(health, max_health)
	if health <= 0.0 and not _destroyed_emitted:
		_destroyed_emitted = true
		destroyed.emit()

func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	var scene := get_parent()
	if scene != null and scene.has_method("get_weather_heal_multiplier"):
		amount *= float(scene.get_weather_heal_multiplier())
	var missing := maxf(0.0, max_health - health)
	var before := health; health = minf(max_health, health + amount); _show_float(health - before, true)
	var overflow := maxf(0.0, amount - missing)
	if overflow > 0.0 and evolution.has_upgrade("mother_sap_05"):
		shield = minf(float(evolution.get_effect_value("overheal_shield_cap", 30.0)), shield + overflow)
	health_changed.emit(health, max_health)

func _show_float(amount: float, healing: bool) -> void:
	if amount <= 0.0 or not is_inside_tree(): return
	var label := FloatText.new(); add_child(label); label.setup(amount, healing)

func choose_path(path_id: String) -> bool:
	var changed := evolution.choose_path(path_id)
	if changed:
		if path_id == "root_heart": max_health = base_max_health + 60.0; heal(60.0); damage_reduction = 0.05
		elif path_id == "sun_arrow": pass
		elif path_id == "dawn_pulse": pulse_cooldown = 0.0
		health_changed.emit(health, max_health)
		_refresh_form()
	return changed

func choose_evolution(upgrade_id: String) -> bool:
	var changed := evolution.choose_upgrade(upgrade_id)
	if not changed: return false
	max_health = evolution.get_mother_max_health(base_max_health)
	damage_reduction = evolution.get_damage_reduction()
	if upgrade_id == "mother_receptacle_01": heal(40.0)
	if upgrade_id == "mother_receptacle_03": heal(50.0)
	_refresh_form()
	return true

func get_form_id() -> String:
	return evolution.selected_upgrades[-1] if not evolution.selected_upgrades.is_empty() else evolution.path_id

func _refresh_form(animate := true) -> void:
	_update_art_texture(health / maxf(1.0, max_health))
	_transform_time = 0.65 if animate else 0.0

func on_day_started() -> void:
	combat_night = false
	if evolution.has_upgrade("mother_sap_02"): heal(float(evolution.get_effect_value("day_start_heal", 40.0)))

func on_night_started() -> void:
	combat_night = true; night_kill_heals = 0
	if evolution.has_upgrade("mother_receptacle_06"):
		shield = maxf(shield, float(evolution.get_effect_value("night_shield", 60.0)))
	if evolution.has_upgrade("mother_charge_03"): pulse_cooldown = 0.0

func on_nearby_enemy_killed(distance: float) -> void:
	if not evolution.has_upgrade("mother_sap_04") or night_kill_heals >= int(evolution.get_effect_value("nearby_kill_cap", 12)): return
	if distance <= float(evolution.get_effect_value("nearby_kill_radius", 180.0)):
		night_kill_heals += 1; heal(float(evolution.get_effect_value("nearby_kill_heal", 1.0)))

func get_evolution_choices() -> Array[String]: return evolution.get_choices()
func get_evolution_state() -> Dictionary: return evolution.export_state()

func _process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta); pulse_cooldown = maxf(0.0, pulse_cooldown - delta); root_whip_cooldown = maxf(0.0, root_whip_cooldown - delta)
	damage_block_cooldown = maxf(0.0, damage_block_cooldown - delta); time_since_damage += delta
	damage_burst_cooldown = maxf(0.0, damage_burst_cooldown - delta); recent_damage_time = maxf(0.0, recent_damage_time - delta)
	if recent_damage_time <= 0.0: recent_damage = 0.0
	if combat_night and evolution.has_upgrade("mother_corona_05"):
		solar_wind_cooldown -= delta
		if solar_wind_cooldown <= 0.0:
			solar_wind_cooldown = float(evolution.get_effect_value("solar_wind_interval", 10.0)); secondary_damage_requested.emit(global_position, float(evolution.get_effect_value("solar_wind_radius", 180.0)), float(evolution.get_effect_value("solar_wind_damage", 20.0)))
	if evolution.path_id == "sun_arrow" and attack_cooldown <= 0.0: _mother_attack(); attack_cooldown = evolution.get_mother_attack_interval()
	if combat_night and evolution.path_id == "dawn_pulse" and pulse_cooldown <= 0.0: _dawn_pulse(); pulse_cooldown = evolution.get_pulse_interval()
	if evolution.path_id == "root_heart" and evolution.has_upgrade("mother_counterroot_02") and root_whip_cooldown <= 0.0: _root_whip(); root_whip_cooldown = 3.0
	if combat_night and evolution.path_id == "root_heart" and evolution.has_upgrade("mother_sap_01"): heal(float(evolution.get_effect_value("night_regen", 0.4)) * delta)
	if combat_night and evolution.has_upgrade("mother_sap_03") and health < max_health * float(evolution.get_effect_value("low_health_threshold", 0.5)): heal(float(evolution.get_effect_value("low_health_regen", 0.6)) * delta)
	if combat_night and evolution.has_upgrade("mother_sap_06") and time_since_damage >= float(evolution.get_effect_value("out_of_combat_delay", 6.0)): heal(float(evolution.get_effect_value("out_of_combat_regen", 2.0)) * delta)
	advance_danger_feedback(delta)
	_transform_time = maxf(0.0, _transform_time - delta)
	_update_art_texture(health / maxf(1.0, max_health))
	var pulse := 1.0 + (sin((1.0 - _transform_time / 0.65) * PI) * 0.12 if _transform_time > 0.0 else 0.0)
	var health_tint := Color.WHITE if health / max_health > 0.68 else (Color("bfa990") if health / max_health > 0.34 else Color("927d85"))
	var tint := health_tint if _hit_flash <= 0.0 else Color(1.35, 1.25, 1.1)
	for sprite in [art_sprite, motion_sprite]:
		if sprite != null:
			sprite.scale = Vector2.ONE * 0.56 * pulse
			sprite.modulate = tint
			sprite.rotation = 0.0

func _mother_attack() -> void:
	var nearest: Node = null; var distance := evolution.get_mother_attack_range()
	var host := get_parent()
	var candidates: Array = host.query_enemies_in_radius(global_position, distance) if host != null and host.has_method("query_enemies_in_radius") else get_tree().get_nodes_in_group("enemies")
	for enemy in candidates:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= distance:
			var candidate_distance: float = enemy.global_position.distance_to(global_position)
			if evolution.has_upgrade("mother_sunseed_06") and enemy.get_rank() in ["elite", "boss"] and (nearest == null or nearest.get_rank() == "normal"): nearest = enemy; distance = candidate_distance
			elif nearest == null or enemy.get_rank() == nearest.get_rank() and candidate_distance <= distance: distance = candidate_distance; nearest = enemy
	if nearest != null: attack_requested.emit(global_position, nearest, evolution.get_mother_attack_damage())

func _dawn_pulse() -> void:
	pulse_requested.emit(global_position, evolution.get_pulse_radius(), evolution.get_pulse_damage(), evolution.get_pulse_energy())
	if evolution.has_upgrade("mother_morningstar_04"):
		pulse_echo_requested.emit(global_position, evolution.get_pulse_radius(), evolution.get_pulse_damage() * float(evolution.get_effect_value("pulse_echo_ratio", 0.5)), float(evolution.get_effect_value("pulse_echo_delay", 1.5)))

func _root_whip() -> void:
	root_whip_requested.emit(global_position, float(evolution.get_effect_value("root_whip_radius", 160.0)), float(evolution.get_effect_value("root_whip_damage", 14.0)))

func _update_art_texture(ratio: float) -> void:
	if art_sprite == null: return
	var id: String = evolution.path_id if not evolution.path_id.is_empty() else "base"
	if id != _animation_id:
		_animation_id = id
		var frames := MotherAnimation.load_frames(id)
		motion_sprite.sprite_frames = frames
		motion_sprite.visible = frames != null
		if frames != null: motion_sprite.play("idle")
	art_sprite.visible = not motion_sprite.visible
	var path := FormVisual.texture_path(id) if id != "base" else ArtLibrary.MOTHER_HEALTHY
	if id == "base" and not motion_sprite.visible:
		if ratio <= 0.34: path = ArtLibrary.MOTHER_CRITICAL
		elif ratio <= 0.68: path = ArtLibrary.MOTHER_DAMAGED
	var texture := ArtLibrary.load_texture(path)
	if texture != null and art_sprite.texture != texture: art_sprite.texture = texture
