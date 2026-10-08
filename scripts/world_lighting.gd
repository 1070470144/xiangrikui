extends Node

const ActorShader = preload("res://assets/tilesets/world_actor_lighting.gdshader")
const MAX_LIGHTS := 32
var daylight_amount := 1.0
var sun_direction := Vector2(0.65, 0.76).normalized()
var sun_color := Color("fff0ce")
var ambient_color := Color.WHITE
var shadow_strength := 0.42
var bounce_strength := 0.08
var _target := 1.0
var _start := 1.0
var _elapsed := 0.0
var _duration := 0.0
var _game: Node2D
var _materials: Dictionary = {}
var _sources: Array[Vector4] = []

func configure(game: Node2D) -> void:
	_game = game
	process_priority = 100

func set_phase(day: bool, transition_seconds := 1.5) -> void:
	_target = 1.0 if day else 0.0
	_start = daylight_amount
	_elapsed = 0.0
	_duration = maxf(0.0, transition_seconds)
	if is_zero_approx(_duration): daylight_amount = _target
	_update_state()

func advance(delta: float) -> void:
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var t := 1.0 if _duration <= 0.0 else _elapsed / _duration
	daylight_amount = lerpf(_start, _target, t * t * (3.0 - 2.0 * t))
	_update_state()

func _update_state() -> void:
	ambient_color = Color(0.34, 0.41, 0.56).lerp(Color(0.96, 0.95, 0.89), daylight_amount)
	sun_color = Color("a7bdd9").lerp(Color("fff0ce"), daylight_amount)
	shadow_strength = lerpf(0.16, 0.42, daylight_amount)
	bounce_strength = lerpf(0.025, 0.08, daylight_amount)

func get_lighting_state() -> Dictionary:
	return {"daylight_amount":daylight_amount, "target_daylight":_target, "sun_direction":sun_direction,
		"sun_color":sun_color, "ambient_color":ambient_color, "shadow_strength":shadow_strength,
		"bounce_strength":bounce_strength}

func _process(delta: float) -> void:
	advance(delta)
	if not is_instance_valid(_game): return
	_sources.clear()
	var actors: Array[Node] = [_game.mother_flower]
	actors.append_array(get_tree().get_nodes_in_group("plants"))
	actors.append_array(get_tree().get_nodes_in_group("light_nodes"))
	actors.append_array(get_tree().get_nodes_in_group("enemies"))
	if is_instance_valid(_game.mother_flower) and _game.mother_flower.health > 0.0:
		_sources.append(Vector4(_game.mother_flower.global_position.x, _game.mother_flower.global_position.y, 260.0, 0.65))
	for node in _game.light_nodes:
		if is_instance_valid(node) and node.health > 0.0 and node.is_connected_to_light and _sources.size() < MAX_LIGHTS:
			_sources.append(Vector4(node.global_position.x, node.global_position.y, node.supply_radius, 0.52))
	for node in _game._temporary_supply_nodes():
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.health > 0.0 and node.is_connected_to_light and _sources.size() < MAX_LIGHTS:
			_sources.append(Vector4(node.global_position.x, node.global_position.y, node.supply_radius, 0.52))
	var alive: Dictionary = {}
	for actor in actors:
		if not is_instance_valid(actor): continue
		var id := actor.get_instance_id()
		alive[id] = true
		if not _materials.has(id):
			var material := ShaderMaterial.new()
			material.shader = ActorShader
			actor.material = material
			# Rebuild cached draw commands so the legacy root shadow is removed.
			actor.queue_redraw()
			_materials[id] = material
			# Tint only the body; health bars, floating text and attack FX stay readable.
			for child in actor.get_children():
				if child is Sprite2D or child is AnimatedSprite2D: child.use_parent_material = true
		var tint := get_surface_tint(actor.global_position)
		if actor == _game.mother_flower: tint = tint.lerp(Color(1.0, 0.91, 0.71), (1.0 - daylight_amount) * 0.5)
		elif actor.is_in_group("light_nodes") and actor.health > 0.0 and actor.is_connected_to_light:
			tint = tint.lerp(Color(1.0, 0.88, 0.66), (1.0 - daylight_amount) * 0.55)
		_materials[id].set_shader_parameter("light_tint", tint)
		_materials[id].set_shader_parameter("daylight_amount", daylight_amount)
		_materials[id].set_shader_parameter("sun_direction", sun_direction)
	for id in _materials.keys():
		if not alive.has(id): _materials.erase(id)
	var terrain: Node2D = _game.battlefield.terrain_map
	var material: ShaderMaterial = terrain.ground_tile_map.material
	for key in ["daylight_amount", "sun_direction", "sun_color", "ambient_color", "shadow_strength", "bounce_strength"]:
		material.set_shader_parameter(key, get_lighting_state()[key])
	var packed := PackedVector4Array(_sources)
	packed.resize(MAX_LIGHTS)
	material.set_shader_parameter("local_lights", packed)
	material.set_shader_parameter("light_count", _sources.size())
	for layer in [terrain.overlay_tile_map, terrain.acid_overlay_tile_map, terrain.acid_preview_tile_map]:
		var alpha: float = layer.modulate.a
		layer.modulate = ambient_color
		layer.modulate.a = alpha
	terrain.update_lighting_shadows(actors, get_lighting_state())
	_game.daylight_glow.set_lighting_state(get_lighting_state())
	_game.night_fog.set_reveal_sources(get_reveal_sources())
	_game.night_fog.set_lighting_state(get_lighting_state())

func get_reveal_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if not is_instance_valid(_game): return sources
	if is_instance_valid(_game.mother_flower) and _game.mother_flower.health > 0.0:
		sources.append({"id":_game.mother_flower.get_instance_id(), "position":_game.mother_flower.global_position, "radius":90.0})
	for plant in _game.plants:
		if is_instance_valid(plant) and plant.health > 0.0 and plant.has_combat_power():
			sources.append({"id":plant.get_instance_id(), "position":plant.global_position, "radius":120.0})
	for node in _game.light_nodes:
		if is_instance_valid(node) and node.health > 0.0 and node.is_connected_to_light:
			sources.append({"id":node.get_instance_id(), "position":node.global_position, "radius":190.0})
	return sources

func get_surface_tint(point: Vector2) -> Color:
	var strength := 0.0
	for source in _sources:
		var distance := point.distance_to(Vector2(source.x, source.y)) / maxf(1.0, source.z)
		strength = maxf(strength, pow(maxf(0.0, 1.0 - distance), 2.0) * source.w)
	return ambient_color.lerp(Color(1.0, 0.85, 0.58), strength * (1.0 - daylight_amount))
