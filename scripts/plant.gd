extends Node2D


const ArtLibrary = preload("res://scripts/art_library.gd")
const Balance = preload("res://scripts/balance.gd")
const ContentData = preload("res://scripts/content_data.gd")
const FloatText = preload("res://scripts/combat_float_text.gd")
const Animations = preload("res://scripts/plant_animation_library.gd")
const AttackFx = preload("res://scripts/plant_attack_fx.gd")

signal projectile_requested(origin: Vector2, target: Node, damage: float)
signal status_projectile_requested(origin: Vector2, target: Node, damage: float, status: Dictionary)
signal destroyed(plant: Node)
signal energy_generated(amount: int)

enum Kind { THORN, PRISM, LANTERN, FROST, HONEYDEW, STORM, GALE, SUNWELL, EMBER, SLUMBER, SPEAR, BURST, STONE, CLEANSE, DRUM }
enum PowerState { POWERED, STORED, LOW_LIGHT, DORMANT }

@export var kind: Kind = Kind.THORN
@export var branch_index: int = 0
var powered := true
var power_state: PowerState = PowerState.POWERED
var power_state_time := 0.0
var power_source: Node = null
var max_health := 100.0
var health := 100.0
var environmental_health := 100.0
var attack_range := 112.0
var attack_damage := 14.0
var attack_interval := 0.85
var _cooldown := 0.0
var art_sprite: Sprite2D
var animation_sprite: AnimatedSprite2D
var _animation_species := ""
var attack_fx: Node2D
var card_power_time := 0.0
var card_interval_multiplier := 1.0
var boss_root_interval_multiplier := 1.0
var corrosion_time := 0.0
var corrosion_damage := 0.0
var corrosion_tick := 0.0
var temporary_lifetime := 0.0
var card_expiry_damage := 0.0
var restore_power_on_card_expiry := false
var death_order := 0
var lantern_supported := false
var combat_active := false
var inspiration_time := 0.0
var inspiration_multiplier := 1.0
var dying := false
var reviving := false
var _death_emitted := false
var _configured := false
var _static_texture_path := ""
var _static_refresh_clock := 0.0
var resource_lookup_usec := 0

func _ready() -> void:
	add_to_group("plants")
	_setup_art()
	if not _configured: configure(kind, branch_index)
	else: _update_art_texture()
	var loader := Animations.service()
	if loader != null:
		loader.species_ready.connect(_on_species_ready)
		AttackFx.request_style("frost")
		AttackFx.request_style("pollen")
	set_process(true)

func _setup_art() -> void:
	art_sprite = Sprite2D.new()
	art_sprite.name = "ArtSprite"
	art_sprite.position = Vector2(0, -18)
	art_sprite.scale = Vector2.ONE * 0.58
	add_child(art_sprite)
	animation_sprite = AnimatedSprite2D.new()
	animation_sprite.name = "PlantAnimation"
	animation_sprite.position = art_sprite.position
	animation_sprite.scale = art_sprite.scale
	animation_sprite.hide()
	animation_sprite.animation_finished.connect(func():
		if animation_sprite.animation == "attack":
			animation_sprite.play("idle")
			_update_animation_power()
		elif animation_sprite.animation == "death":
			visible = false
			set_process(false)
			_emit_destroyed_once()
		elif animation_sprite.animation == "revive":
			reviving = false
			animation_sprite.play("idle")
			_update_animation_power()
	)
	add_child(animation_sprite)
	attack_fx = AttackFx.new()
	attack_fx.name = "BotanicalAttackFx"
	attack_fx.z_index = 8
	add_child(attack_fx)

func configure(new_kind: Kind, new_branch_index: int) -> void:
	_configured = true
	kind = new_kind
	branch_index = new_branch_index
	var values := ContentData.get_flower(get_flower_id())
	max_health = float(values.get("health", 100.0)); health = max_health; environmental_health = health
	attack_range = float(values.get("range", 0.0))
	attack_damage = float(values.get("damage", 0.0))
	attack_interval = float(values.get("interval", 1.0))
	_cooldown = attack_interval if kind == Kind.SUNWELL else 0.0
	_update_art_texture()
	queue_redraw()

func set_powered(value: bool) -> void:
	powered = value
	if value:
		power_state = PowerState.POWERED
		power_state_time = 0.0
	else:
		power_state = PowerState.STORED
		power_state_time = 8.0 if lantern_supported else Balance.STORED_LIGHT_DURATION
	_update_art_texture()
	queue_redraw()

func set_power_source(source: Node) -> void:
	power_source = source
	set_powered(source != null and bool(source.is_connected_to_light))

func take_environment_damage(amount: float) -> void:
	take_damage(amount)

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0 or dying: return
	if kind == Kind.STONE: amount *= 1.0 - float(ContentData.get_flower(get_flower_id()).get("damage_reduction", 0.4))
	var before := health; health = maxf(0.0, health - amount); environmental_health = health; _show_float(before - health, false)
	if health <= 0.0:
		death_order = Time.get_ticks_msec()
		reviving = false
		dying = true
		set_powered(false)
		if animation_sprite != null and animation_sprite.visible and animation_sprite.sprite_frames.has_animation("death"):
			animation_sprite.stop()
			animation_sprite.play("death")
			_update_animation_power()
		else:
			visible = false
			set_process(false)
			_emit_destroyed_once()

func heal(amount: float) -> bool:
	if amount <= 0.0 or health <= 0.0 or health >= max_health: return false
	var scene := get_parent()
	if scene != null and scene.has_method("get_weather_heal_multiplier"):
		amount *= float(scene.get_weather_heal_multiplier())
	var before := health; health = minf(max_health, health + amount); environmental_health = health; _show_float(health - before, true); return true

func _show_float(amount: float, healing: bool) -> void:
	if amount <= 0.0 or not is_inside_tree(): return
	var label := FloatText.new(); add_child(label); label.setup(amount, healing)

func revive(ratio: float = 0.5) -> bool:
	if health > 0.0: return false
	dying = false
	_death_emitted = false
	health = max_health * clampf(ratio, 0.01, 1.0); environmental_health = health; visible = true; set_process(true); set_powered(power_source != null)
	_setup_species_animation()
	if animation_sprite != null and animation_sprite.visible:
		reviving = animation_sprite.sprite_frames.has_animation("revive")
		animation_sprite.stop()
		animation_sprite.play("revive" if reviving else "idle")
	_update_animation_power()
	return true

func _emit_destroyed_once() -> void:
	if _death_emitted: return
	_death_emitted = true
	destroyed.emit(self)

func has_combat_power() -> bool:
	return power_state != PowerState.DORMANT

func advance_power_state(delta: float) -> void:
	if power_state in [PowerState.POWERED, PowerState.DORMANT] or delta <= 0.0:
		return
	power_state_time -= delta
	if power_state == PowerState.STORED and power_state_time <= 0.0:
		power_state = PowerState.LOW_LIGHT
		power_state_time += Balance.LOW_LIGHT_DURATION
	if power_state == PowerState.LOW_LIGHT and power_state_time <= 0.0:
		power_state = PowerState.DORMANT
		power_state_time = 0.0
	powered = has_combat_power()
	_update_art_texture()
	queue_redraw()

func can_attack() -> bool:
	return health > 0.0 and not reviving and has_combat_power() and is_inside_tree()

func _process(delta: float) -> void:
	if dying: return
	_static_refresh_clock -= delta
	if art_sprite != null and art_sprite.visible and _static_refresh_clock <= 0.0:
		_static_refresh_clock = 0.1
		var loader := Animations.service()
		if loader != null:
			var texture: Texture2D = loader.get_texture(_static_texture_path)
			if texture != null: art_sprite.texture = texture
			if art_sprite.texture != null: queue_redraw()
	_update_animation_power()
	if reviving: return
	inspiration_time = maxf(0.0, inspiration_time - delta)
	if inspiration_time <= 0.0: inspiration_multiplier = 1.0
	if temporary_lifetime > 0.0:
		temporary_lifetime = maxf(0.0, temporary_lifetime - delta)
		if temporary_lifetime <= 0.0: queue_free(); return
	if corrosion_time > 0.0:
		corrosion_time = maxf(0.0, corrosion_time - delta); corrosion_tick += delta
		if corrosion_tick >= 1.0: corrosion_tick -= 1.0; take_damage(corrosion_damage)
	if card_power_time > 0.0:
		card_power_time = maxf(0.0, card_power_time - delta)
		if card_power_time <= 0.0:
			card_interval_multiplier = 1.0
			if card_expiry_damage > 0.0: take_environment_damage(card_expiry_damage); card_expiry_damage = 0.0
			if restore_power_on_card_expiry:
				restore_power_on_card_expiry = false; set_powered(is_instance_valid(power_source) and bool(power_source.is_connected_to_light))
	advance_power_state(delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if not can_attack() or _cooldown > 0.0:
		_animate_art()
		queue_redraw()
		return
	if kind == Kind.LANTERN:
		for ally in get_tree().get_nodes_in_group("plants"):
			if ally != self and is_instance_valid(ally) and ally.health > 0.0 and global_position.distance_to(ally.global_position) <= attack_range:
				_reset_attack_cooldown()
				_animate_art(true)
				break
		return
	if kind in [Kind.SUNWELL, Kind.CLEANSE, Kind.DRUM]:
		if _activate_support():
			_reset_attack_cooldown()
			_trigger_attack_fx(Vector2(0, -28), "pollen")
			_animate_art(true)
		return
	if kind == Kind.HONEYDEW:
		var healing_target := _find_healing_target()
		if healing_target != null:
			healing_target.heal(float(ContentData.get_flower("honeydew_flower").get("heal", 8.0)) * (Balance.LOW_LIGHT_DAMAGE_MULTIPLIER if power_state == PowerState.LOW_LIGHT else 1.0))
			_cooldown = attack_interval * get_effective_interval_multiplier() * (Balance.LOW_LIGHT_INTERVAL_MULTIPLIER if power_state == PowerState.LOW_LIGHT else 1.0)
			_trigger_attack_fx(healing_target.global_position - global_position, "pollen")
			_animate_art(true)
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	if kind == Kind.THORN:
		_attack_thorn()
	elif kind == Kind.FROST:
		status_projectile_requested.emit(global_position, target, attack_damage, {"type":"slow", "ratio":0.25, "duration":2.5, "source":"frost_bell"})
		_trigger_attack_fx(target.global_position - global_position, "frost")
	elif kind in [Kind.STORM, Kind.GALE, Kind.EMBER, Kind.SLUMBER, Kind.SPEAR, Kind.BURST]:
		_attack_special(target)
		if kind in [Kind.STORM, Kind.EMBER]:
			_trigger_attack_fx(target.global_position - global_position, "frost" if kind == Kind.STORM else "pollen")
	else:
		projectile_requested.emit(global_position, target, attack_damage * (Balance.LOW_LIGHT_DAMAGE_MULTIPLIER if power_state == PowerState.LOW_LIGHT else 1.0))
		_trigger_attack_fx(target.global_position - global_position, "frost")
	_cooldown = attack_interval * get_effective_interval_multiplier() * (Balance.LOW_LIGHT_INTERVAL_MULTIPLIER if power_state == PowerState.LOW_LIGHT else 1.0)
	_animate_art(true)
	queue_redraw()

func apply_corrosion(damage_per_second: float, duration: float) -> void:
	corrosion_damage = maxf(corrosion_damage, damage_per_second); corrosion_time = maxf(corrosion_time, duration)

func get_effective_interval_multiplier() -> float:
	var overload_multiplier := 0.8 if is_instance_valid(power_source) and "overload_time" in power_source and power_source.overload_time > 0.0 else 1.0
	var weather_multiplier := 1.0
	var scene := get_parent()
	if scene != null and scene.has_method("get_weather_plant_interval_multiplier"):
		weather_multiplier = float(scene.get_weather_plant_interval_multiplier())
	return card_interval_multiplier * boss_root_interval_multiplier * overload_multiplier * inspiration_multiplier * weather_multiplier

func _reset_attack_cooldown() -> void:
	_cooldown = attack_interval * get_effective_interval_multiplier() * (Balance.LOW_LIGHT_INTERVAL_MULTIPLIER if power_state == PowerState.LOW_LIGHT else 1.0)

func _activate_support() -> bool:
	var values := ContentData.get_flower(get_flower_id())
	if kind == Kind.SUNWELL:
		if not combat_active: return false
		energy_generated.emit(1 if power_state == PowerState.LOW_LIGHT else int(values.get("energy", 2)))
		return true
	var applied := false
	for candidate in get_tree().get_nodes_in_group("plants"):
		if candidate == self or not is_instance_valid(candidate) or candidate.health <= 0.0 or global_position.distance_to(candidate.global_position) > attack_range: continue
		if kind == Kind.CLEANSE:
			if candidate.corrosion_time > 0.0:
				candidate.corrosion_time = 0.0; candidate.corrosion_damage = 0.0; candidate.corrosion_tick = 0.0; applied = true
			applied = candidate.heal(float(values.get("heal", 3.0))) or applied
		elif kind == Kind.DRUM:
			candidate.inspiration_time = maxf(candidate.inspiration_time, 2.5)
			candidate.inspiration_multiplier = minf(candidate.inspiration_multiplier, float(values.get("interval_multiplier", 0.85)))
			applied = true
	return applied

func _attack_special(target: Node2D) -> void:
	var values := ContentData.get_flower(get_flower_id())
	var damage := attack_damage * (Balance.LOW_LIGHT_DAMAGE_MULTIPLIER if power_state == PowerState.LOW_LIGHT else 1.0)
	if kind == Kind.STORM:
		var visited: Array[Node] = []; var current: Node2D = target
		for hop in range(int(values.get("max_targets", 3))):
			if current == null: break
			current.take_damage(damage * pow(0.8, hop)); visited.append(current)
			var next: Node2D = null; var nearest := float(values.get("chain_range", 85.0))
			for enemy in _nearby_enemies(current.global_position, nearest):
				if not is_instance_valid(enemy) or enemy in visited or enemy.health <= 0.0 or enemy.friendly_time > 0.0: continue
				var distance: float = current.global_position.distance_to(enemy.global_position)
				if distance <= nearest: nearest = distance; next = enemy
			current = next
	elif kind in [Kind.SPEAR, Kind.BURST]:
		var hits := 0; var direction := global_position.direction_to(target.global_position)
		var candidates: Array
		if kind == Kind.BURST:
			candidates = _nearby_enemies(target.global_position, float(values.get("radius", 65.0)))
		else:
			var end := global_position + direction * attack_range
			var width := float(values.get("width", 18.0))
			var side := Vector2(-direction.y, direction.x) * width
			var bounds := Rect2(global_position + side, Vector2.ZERO)
			for corner in [global_position - side, end + side, end - side]: bounds = bounds.expand(corner)
			var host := get_parent()
			candidates = host.query_enemies_in_rect(bounds) if host != null and host.has_method("query_enemies_in_rect") else get_tree().get_nodes_in_group("enemies")
		for enemy in candidates:
			if not is_instance_valid(enemy) or enemy.health <= 0.0 or enemy.friendly_time > 0.0: continue
			var relative: Vector2 = enemy.global_position - global_position
			var affected: bool = target.global_position.distance_to(enemy.global_position) <= float(values.get("radius", 65.0)) if kind == Kind.BURST else relative.dot(direction) >= 0.0 and relative.dot(direction) <= attack_range and absf(relative.cross(direction)) <= float(values.get("width", 18.0))
			if affected:
				if kind == Kind.BURST: enemy.take_area_damage(damage)
				else: enemy.take_directional_damage(damage, global_position)
				hits += 1
				if hits >= int(values.get("max_targets", 4)): break
	else:
		target.take_damage(damage)
		if kind == Kind.GALE and target.get_rank() != "boss": target.push_from(global_position, float(values.get("push", 35.0)))
		elif kind == Kind.EMBER: target.apply_burn(float(values.get("burn", 4.0)), float(values.get("burn_duration", 3.0)))
		elif kind == Kind.SLUMBER: target.apply_stun(float(values.get("stun", 0.8)) * (0.25 if target.get_rank() == "boss" else 1.0))

func set_lantern_supported(value: bool) -> void:
	lantern_supported = value
	if value and power_state == PowerState.STORED: power_state_time = maxf(power_state_time, 8.0)

func _find_nearest_enemy() -> Node2D:
	return select_target(_nearby_enemies(global_position, attack_range))

func _nearby_enemies(center: Vector2, radius: float) -> Array:
	var host := get_parent()
	return host.query_enemies_in_radius(center, radius) if host != null and host.has_method("query_enemies_in_radius") else get_tree().get_nodes_in_group("enemies")

func select_target(candidates: Array) -> Node2D:
	var nearest: Node2D = null; var best := attack_range; var best_priority := -1
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.health <= 0.0 or ("friendly_time" in candidate and candidate.friendly_time > 0.0): continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance > attack_range: continue
		var priority := 0
		if kind == Kind.PRISM:
			priority = 2 if candidate.get_rank() == "boss" else (1 if candidate.get_rank() == "elite" else 0)
		if priority > best_priority or priority == best_priority and distance <= best:
			best_priority = priority; best = distance; nearest = candidate
	return nearest

func _attack_thorn() -> void:
	var hits := 0
	for candidate in _nearby_enemies(global_position, attack_range):
		if is_instance_valid(candidate) and candidate.health > 0.0 and candidate.friendly_time <= 0.0 and global_position.distance_to(candidate.global_position) <= attack_range:
			candidate.take_damage(attack_damage)
			hits += 1
			if hits >= 5: break

func _find_healing_target() -> Node:
	var best: Node = null; var ratio := 1.0
	for group_name in ["plants", "light_nodes"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if candidate == self or not is_instance_valid(candidate) or not ("health" in candidate) or not ("max_health" in candidate): continue
			var candidate_ratio: float = float(candidate.health) / maxf(1.0, float(candidate.max_health))
			if global_position.distance_to(candidate.global_position) <= attack_range and candidate_ratio < ratio:
				ratio = candidate_ratio; best = candidate
	return best

func get_flower_id() -> String:
	return preload("res://scripts/plant_roster.gd").FLOWER_IDS[int(kind)]

func get_stored_duration() -> float:
	return float(ContentData.get_flower("lantern_flower").get("stored_duration", 8.0)) if kind == Kind.LANTERN else Balance.STORED_LIGHT_DURATION

func _draw() -> void:
	var dim := 1.0 if powered else 0.38
	if material == null: draw_circle(Vector2(0, 10), 23.0, Color(0.02, 0.03, 0.05, 0.58))
	if (animation_sprite != null and animation_sprite.visible) or (art_sprite != null and art_sprite.texture != null):
		return
	if kind == Kind.THORN:
		for i in range(8):
			var a := TAU * float(i) / 8.0
			var tip := Vector2(cos(a) * 28.0, sin(a) * 19.0)
			draw_line(Vector2.ZERO, tip, Color("7c8d58") * dim, 5.0)
			draw_circle(tip * 0.72, 7.0, Color("8e3d4a") * dim)
		draw_circle(Vector2.ZERO, 12.0, Color("e5b94b") * dim)
	elif kind == Kind.PRISM:
		for i in range(6):
			var a := TAU * float(i) / 6.0
			var p1 := Vector2(cos(a) * 8.0, sin(a) * 8.0)
			var p2 := Vector2(cos(a - 0.26) * 28.0, sin(a - 0.26) * 21.0)
			var p3 := Vector2(cos(a + 0.26) * 28.0, sin(a + 0.26) * 21.0)
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color("6fa1a8") * dim)
		draw_circle(Vector2.ZERO, 11.0, Color("fff0b0") * dim)
	else:
		draw_circle(Vector2.ZERO, 15.0, Color("e5b94b") * dim)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 20, Color("6fa1a8") * dim, 4.0)

func _update_art_texture() -> void:
	if art_sprite == null:
		return
	_setup_species_animation()
	_update_animation_power()
	queue_redraw()
	var path := ArtLibrary.THORN_POWERED if kind == Kind.THORN else ArtLibrary.PRISM_POWERED
	var species_path: String = preload("res://scripts/plant_roster.gd").texture_path(int(kind))
	if species_path.contains("/plant_expansion/"):
		_set_cached_static_texture(species_path)
		art_sprite.modulate = Color.WHITE if powered else Color("7a847d")
		return
	art_sprite.modulate = Color.WHITE
	if not powered:
		path = ArtLibrary.THORN_UNPOWERED if kind == Kind.THORN else ArtLibrary.PRISM_UNPOWERED
	_set_cached_static_texture(path)

func _set_cached_static_texture(path: String) -> void:
	_static_texture_path = path
	art_sprite.texture = ArtLibrary.get_cached_texture(path)
	var loader := Animations.service()
	if loader != null:
		loader.request_texture(path)
		var texture: Texture2D = loader.get_texture(path)
		if texture != null: art_sprite.texture = texture

func _on_species_ready(species: String) -> void:
	if species != get_flower_id() or dying or health <= 0.0 or reviving or is_queued_for_deletion(): return
	_setup_species_animation()
	_update_animation_power()
	queue_redraw()

func _animate_art(attacking := false) -> void:
	if art_sprite == null or dying or reviving:
		return
	if animation_sprite != null and animation_sprite.visible:
		if attacking and animation_sprite.sprite_frames.has_animation("attack"):
			animation_sprite.stop()
			animation_sprite.play("attack")
			_update_animation_power()
		return
	var sway := sin(Time.get_ticks_msec() * 0.0025 + branch_index) * 0.018
	art_sprite.rotation = sway
	var squash := 0.92 if attacking else 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.018
	art_sprite.scale = Vector2(0.58 / squash, 0.58 * squash)

func _trigger_attack_fx(offset: Vector2, style: String) -> void:
	if attack_fx != null and is_instance_valid(attack_fx): attack_fx.trigger(offset, style)

func _setup_species_animation() -> void:
	if animation_sprite == null: return
	var species := get_flower_id()
	if _animation_species == species and animation_sprite.sprite_frames == Animations.get_cached_frames(species): return
	_animation_species = species
	var lookup_started := Time.get_ticks_usec()
	Animations.request_species(species)
	var frames := Animations.get_cached_frames(species)
	resource_lookup_usec = Time.get_ticks_usec() - lookup_started
	animation_sprite.visible = frames != null
	art_sprite.visible = frames == null
	if frames != null:
		animation_sprite.sprite_frames = frames
		animation_sprite.play("idle")

func _update_animation_power() -> void:
	if animation_sprite == null or not animation_sprite.visible: return
	animation_sprite.offset = Animations.get_offset(_animation_species, str(animation_sprite.animation))
	animation_sprite.scale = art_sprite.scale * Animations.get_display_scale(_animation_species, str(animation_sprite.animation))
	if dying or reviving:
		animation_sprite.modulate = Color.WHITE
		var action_frames := animation_sprite.sprite_frames
		var state := "death" if dying else "revive"
		if action_frames.has_animation(state):
			animation_sprite.speed_scale = float(action_frames.get_frame_count(state)) / maxf(0.01, action_frames.get_animation_speed(state)) / (1.1 if dying else 1.2)
		return
	animation_sprite.modulate = Color.WHITE if powered else Color("7a847d")
	var rate := 1.0
	if animation_sprite.animation == "attack":
		var frames := animation_sprite.sprite_frames
		var duration := float(frames.get_frame_count("attack")) / frames.get_animation_speed("attack")
		rate = duration / clampf(attack_interval * 0.8, 0.4, 0.9)
	animation_sprite.speed_scale = 0.0 if power_state == PowerState.DORMANT else rate * (0.65 if power_state == PowerState.LOW_LIGHT else 1.0)
