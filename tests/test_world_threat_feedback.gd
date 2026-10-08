extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run() -> Array[String]:
	var script := load("res://scripts/world_threat_feedback.gd") as Script
	if script == null or not script.can_instantiate():
		return ["world threat feedback must compile"]
	var feedback: Node2D = script.new()
	expect(feedback.get_warning_states().size() == 8, "feedback must expose eight directions")
	feedback.update_snapshot(PackedFloat32Array([0.0, 0.15, 0.4, 0.8]), 2)
	var states: Array[Dictionary] = feedback.get_warning_states()
	expect(states[0]["severity"] == 0, "zero threat must stay idle")
	expect(states[1]["severity"] == 1, "small threat must be normal")
	expect(states[2]["severity"] == 2, "medium threat must be severe")
	expect(states[2]["boss"], "boss direction must be marked without text")
	expect(states[3]["intensity"] > states[1]["intensity"], "larger threat must read stronger")
	expect(states[7]["severity"] == 0, "missing snapshot entries must safely become zero")
	expect(is_equal_approx(script.DISPLAY_RADIUS, 380.0), "world warnings must project inside the active camera view")
	feedback.update_snapshot(PackedFloat32Array(), -1)
	feedback.advance_feedback(0.1)
	var fading_visibility := float(feedback.get_warning_states()[1]["visibility"])
	expect(fading_visibility > 0.0 and fading_visibility < 1.0, "cleared threat must decay instead of popping")
	feedback.advance_feedback(2.0)
	expect(is_zero_approx(float(feedback.get_warning_states()[1]["visibility"])), "cleared threat must fully retire")
	expect(feedback.get_child_count() == 0, "feedback must not create collision or input children")
	feedback.free()
	return failures
