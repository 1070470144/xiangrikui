extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run() -> Array[String]:
	var mother_script := load("res://scripts/mother_flower.gd") as Script
	if mother_script == null or not mother_script.can_instantiate():
		return ["mother flower must compile"]
	var mother = mother_script.new()
	mother.max_health = 100.0
	mother.reset_state()
	expect(mother.get_danger_state() == "safe", "healthy mother must start safe")
	mother.set_nearby_enemy_count(2)
	expect(mother.get_danger_state() == "threatened", "nearby enemies must raise a world warning")
	mother.take_damage(10.0)
	expect(mother.get_danger_state() == "hit", "recent damage must briefly override threatened")
	mother.advance_danger_feedback(0.25)
	mother.health = 20.0
	expect(mother.get_danger_state() == "critical", "low health must stay visibly critical")
	mother.free()
	return failures
