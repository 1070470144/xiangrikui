extends Node2D


const ArtLibrary = preload("res://scripts/art_library.gd")
const Balance = preload("res://scripts/balance.gd")
const FloatText = preload("res://scripts/combat_float_text.gd")

signal health_changed(current: float, maximum: float)
signal connection_changed(connected: bool)
signal destroyed

@export var node_index: int = 0
@export var max_health: float = Balance.LIGHT_NODE_MAX_HEALTH
var health: float = Balance.LIGHT_NODE_MAX_HEALTH
var is_connected_to_light := true
var parent_source: Node = null
var connection_range := 245.0
var supply_radius := Balance.LIGHT_NODE_SUPPLY_RADIUS
var capacity := Balance.LIGHT_NODE_CAPACITY
var load := 0
var network_id := 0
var _destroyed_emitted := false
var art_sprite: Sprite2D
var overload_time := 0.0
var _base_supply_radius := Balance.LIGHT_NODE_SUPPLY_RADIUS
var suppression_time := 0.0
var suppression_multiplier := 1.0

func _ready() -> void:
	add_to_group("light_nodes")
	_setup_art()
	reset_state()
	set_process(true)

func _setup_art() -> void:
	var texture := ArtLibrary.load_texture(ArtLibrary.NODE_HEALTHY)
	if texture == null:
		return
	art_sprite = Sprite2D.new()
	art_sprite.name = "ArtSprite"
	art_sprite.texture = texture
	art_sprite.position = Vector2(0, -8)
	art_sprite.scale = Vector2.ONE * 0.72
	add_child(art_sprite)

func reset_state() -> void:
	health = max_health
	is_connected_to_light = true
	_destroyed_emitted = false
	health_changed.emit(health, max_health)
	connection_changed.emit(true)
	queue_redraw()

func set_parent_source(source: Node) -> void:
	parent_source = source
	is_connected_to_light = source != null
	connection_changed.emit(is_connected_to_light)
	queue_redraw()

func set_load(value: int) -> void:
	load = maxi(0, value)
	queue_redraw()

func can_accept(cost: int) -> bool:
	return is_connected_to_light and cost >= 0 and load + cost <= capacity

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	var before := health; health = maxf(0.0, health - amount); _show_float(before - health, false)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_connected_to_light = false
		connection_changed.emit(false)
		if not _destroyed_emitted:
			_destroyed_emitted = true
			destroyed.emit()
	queue_redraw()

func repair(amount: float) -> bool:
	if amount <= 0.0 or health >= max_health:
		return false
	var scene := get_parent()
	if scene != null and scene.has_method("get_weather_heal_multiplier"):
		amount *= float(scene.get_weather_heal_multiplier())
	var was_disconnected := not is_connected_to_light
	var before := health; health = minf(max_health, health + amount); _show_float(health - before, true)
	if health > 0.0:
		is_connected_to_light = true
		_destroyed_emitted = false
	health_changed.emit(health, max_health)
	if was_disconnected and is_connected_to_light:
		connection_changed.emit(true)
	queue_redraw()
	return true

func heal(amount: float) -> bool:
	return repair(amount)

func _show_float(amount: float, healing: bool) -> void:
	if amount <= 0.0 or not is_inside_tree(): return
	var label := FloatText.new(); add_child(label); label.setup(amount, healing)

func _process(_delta: float) -> void:
	advance_effects(_delta)
	if art_sprite != null:
		var glow := 1.0 + sin(Time.get_ticks_msec() * 0.004 + node_index) * 0.035
		art_sprite.scale = Vector2.ONE * 0.72 * glow
	queue_redraw()

func advance_effects(delta: float) -> void:
	if overload_time > 0.0:
		overload_time = maxf(0.0, overload_time - delta)
		if overload_time <= 0.0:
			take_damage(30.0)
	if suppression_time > 0.0:
		suppression_time = maxf(0.0, suppression_time - delta)
		if suppression_time <= 0.0: suppression_multiplier = 1.0
	_refresh_supply_radius()

func apply_overload(duration: float) -> void:
	overload_time = maxf(overload_time, duration)
	_refresh_supply_radius()

func apply_supply_suppression(multiplier: float, duration: float) -> void:
	suppression_multiplier = minf(suppression_multiplier, multiplier); suppression_time = maxf(suppression_time, duration); _refresh_supply_radius()

func _refresh_supply_radius() -> void:
	var active_base := _base_supply_radius + (50.0 if overload_time > 0.0 else 0.0)
	supply_radius = maxf(100.0, active_base * suppression_multiplier)

func _draw() -> void:
	var ratio: float = health / max_health if max_health > 0.0 else 0.0
	_update_art_texture(ratio)
	var base := Color("e5b94b") if is_connected_to_light else Color("4b405e")
	var glow := 1.0 + sin(Time.get_ticks_msec() * 0.004 + node_index) * 0.08
	if material == null: draw_circle(Vector2(0, 7), 22.0, Color(0.02, 0.025, 0.05, 0.55))
	draw_circle(Vector2.ZERO, 17.0 * glow, Color(base, 0.18))
	if art_sprite != null:
		return
	draw_circle(Vector2.ZERO, 11.0, base.lerp(Color("8e3d4a"), 1.0 - ratio))
	draw_circle(Vector2(-3, -3), 4.0, Color("fff0b0") if is_connected_to_light else Color("69705a"))
	for i in range(5):
		var a := TAU * float(i) / 5.0
		draw_line(Vector2(cos(a), sin(a)) * 10.0, Vector2(cos(a), sin(a)) * 22.0, Color(base, 0.8), 3.0)

func _update_art_texture(ratio: float) -> void:
	if art_sprite == null:
		return
	var path := ArtLibrary.NODE_HEALTHY
	if not is_connected_to_light:
		path = ArtLibrary.NODE_BROKEN
	elif ratio < 0.65:
		path = ArtLibrary.NODE_DAMAGED
	var texture := ArtLibrary.load_texture(path)
	if texture != null and art_sprite.texture != texture:
		art_sprite.texture = texture
