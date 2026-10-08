extends Control

const Spec = preload("res://scripts/battlefield_spec.gd")
const Director = preload("res://scripts/wave_director.gd")
var markers: Array[Dictionary] = []
var placements: Array[Dictionary] = []
var hud: CanvasLayer
var texture: Texture2D
var pointer: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = load("res://assets/ui/spawn_forecast/claw.png")
	pointer = load("res://assets/ui/spawn_forecast/pointer.png")
	texture = _trimmed(texture)
	pointer = _trimmed(pointer)

func _trimmed(source: Texture2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = source.get_image().get_used_rect()
	return atlas

func update_queue(queue: Array[Dictionary]) -> void:
	var groups: Dictionary = {}
	for entry in queue:
		var point: Vector2 = entry.spawn_position
		var key := Director.sector(point)
		if not groups.has(key): groups[key] = {"sum": Vector2.ZERO, "count": 0}
		groups[key].sum += point
		groups[key].count += 1
	markers.clear()
	for group in groups.values(): markers.append({"position": group.sum / group.count, "count": group.count})
	queue_redraw()

static func edge_point(direction: Vector2, viewport_size: Vector2) -> Vector2:
	var half := (viewport_size * 0.5 - Vector2.ONE * 40.0).max(Vector2.ONE)
	var sx := half.x / absf(direction.x) if absf(direction.x) > 0.0001 else INF
	var sy := half.y / absf(direction.y) if absf(direction.y) > 0.0001 else INF
	return viewport_size * 0.5 + direction * minf(sx, sy)

func _process(_delta: float) -> void:
	if not visible: return
	var view := get_viewport_rect().size
	var transform := get_viewport().get_canvas_transform()
	var blocked: Array[Rect2] = []
	if is_instance_valid(hud):
		for name in ["MotherStatusPanel", "PhaseBanner", "ResourcePanel", "TacticalInstrumentFrame", "PhaseActionTray", "ReturnToMenuButton", "NotificationBanner"]:
			var control := hud.find_child(name, true, false) as Control
			if control != null and control.is_visible_in_tree(): blocked.append(control.get_global_rect().grow(36))
	placements.clear()
	for marker in markers:
		var target: Vector2 = transform * Vector2(marker.position)
		var direction := target - view * 0.5
		if direction.length_squared() < 0.01: direction = Vector2(marker.position) - Spec.CENTER
		if direction.length_squared() < 0.01: direction = Vector2.UP
		var desired := edge_point(direction.normalized(), view)
		var selected := desired
		var best := INF
		for i in range(360):
			var point := edge_point(Vector2.from_angle(float(i) * TAU / 360.0), view)
			var free := true
			for rect in blocked:
				if rect.has_point(point): free = false; break
			for placed in placements:
				if point.distance_to(placed.position) < 52.0: free = false; break
			var distance := point.distance_squared_to(desired)
			if free and distance < best: best = distance; selected = point
		if best == INF: continue
		var facing := target - selected
		if facing.length_squared() < 0.01: facing = direction
		placements.append({"position": selected, "angle": facing.angle()})
	queue_redraw()

func _draw() -> void:
	if texture == null or pointer == null: return
	for placement in placements:
		var point: Vector2 = placement.position
		draw_texture_rect(texture, Rect2(point - Vector2(20, 20), Vector2(40, 40)), false)
		draw_set_transform(point, placement.angle)
		draw_texture_rect(pointer, Rect2(12, -12, 24, 24), false)
		draw_set_transform(Vector2.ZERO)
