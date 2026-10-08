extends RefCounted

var failures: Array[String] = []

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/light_radar.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		return ["light radar script must compile"]
	var radar: Control = script.new()
	if radar.world_to_radar(Vector2(1440, 1440)).distance_to(Vector2(70, 70)) >= 0.1: failures.append("world center must map to radar center")
	if radar.threat_levels.size() != 8: failures.append("radar must expose eight threat directions")
	radar.free()
	return failures
