extends Node2D

const ProjectedTexture = preload("res://assets/effects/shadows/projected.png")
const ContactTexture = preload("res://assets/effects/shadows/contact.png")
const ShadowShader = preload("res://assets/effects/shadows/soft_shadow.gdshader")
var bodies: Array[Dictionary] = []
var daylight := 1.0
var direction := Vector2(0.65, 0.76).normalized()
var strength := 0.42
var update_usec := 0
var _projection: Node2D
var _projection_material: ShaderMaterial

func _ready() -> void:
	_projection = Node2D.new()
	_projection_material = ShaderMaterial.new()
	_projection_material.shader = ShadowShader
	_projection.material = _projection_material
	_projection.show_behind_parent = true
	add_child(_projection)
	_projection.draw.connect(_draw_projection)

func update_bodies(actors: Array[Node], state: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	bodies.clear()
	daylight = state.daylight_amount
	direction = state.sun_direction
	strength = state.shadow_strength
	var visible_rect: Rect2 = (get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()).grow(160.0)
	for actor in actors:
		if not is_instance_valid(actor) or not actor.is_visible_in_tree() or actor.health <= 0.0: continue
		var point := to_local(actor.global_position) + Vector2(0, 7)
		if not visible_rect.has_point(point): continue
		var radius := 24.0
		var height := 40.0
		if actor.is_in_group("enemies"):
			radius = 38.0 if actor.rank == "boss" else 21.0
			height = 70.0 if actor.rank == "boss" else 30.0
		elif actor.is_in_group("light_nodes"):
			radius = 18.0
			height = 22.0
		elif not actor.is_in_group("plants"):
			radius = 55.0
			height = 100.0
		bodies.append({"position": point, "radius": radius, "height": height})
	queue_redraw()
	if is_instance_valid(_projection): _projection.queue_redraw()
	update_usec = Time.get_ticks_usec() - started

func _draw_projection() -> void:
	for body in bodies:
		var radius: float = body.radius
		var offset: Vector2 = direction * float(body.height) * 0.65 * daylight
		_projection.draw_set_transform(body.position + offset * 0.5, direction.angle(), Vector2(1.0 + offset.length() / radius * 0.35, 0.4))
		_projection.draw_texture_rect(ProjectedTexture, Rect2(Vector2.ONE * -2.0 * radius, Vector2.ONE * 4.0 * radius), false, Color(0.035, 0.05, 0.095, strength))
	_projection.draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	for body in bodies:
		var radius: float = body.radius * 0.55
		draw_set_transform(body.position, 0.0, Vector2(1.0, 0.38))
		draw_texture_rect(ContactTexture, Rect2(Vector2.ONE * -2.0 * radius, Vector2.ONE * 4.0 * radius), false, Color(0.025, 0.035, 0.065))
	draw_set_transform(Vector2.ZERO)
