extends RefCounted

var failures: Array[String] = []

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/world_camera.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		return ["world camera script must compile"]
	var camera: Node = script.new()
	if camera.clamp_zoom(0.2) != 1.375: failures.append("camera zoom must clamp to scaled near limit")
	if camera.clamp_zoom(5.0) != 3.375: failures.append("camera zoom must clamp to scaled far limit")
	if camera.clamp_position(Vector2(-50, 8000)) != Vector2(0, 2880): failures.append("camera position must remain inside world")
	var viewport_clamped: Vector2 = camera.clamp_position_for_view(Vector2(-50, 4000), Vector2(1152, 648), 2.5)
	if viewport_clamped.x < 0.0 or viewport_clamped.y < 0.0 or viewport_clamped.x > 2880.0 or viewport_clamped.y > 2880.0: failures.append("camera must keep the full viewport inside the world")
	camera.free()
	return failures
