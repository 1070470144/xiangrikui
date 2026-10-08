extends SceneTree

const Battlefield = preload("res://scripts/battlefield.gd")
const MotherFlower = preload("res://scripts/mother_flower.gd")
const Hud = preload("res://scripts/hud.gd")
const WorldThreatFeedback = preload("res://scripts/world_threat_feedback.gd")

var mother: Node2D
var hud: CanvasLayer
var feedback: Node2D

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/imagegen/previews/readability"))
	var battlefield := Battlefield.new(); root.add_child(battlefield)
	feedback = WorldThreatFeedback.new(); feedback.z_index = 18; root.add_child(feedback)
	mother = MotherFlower.new(); mother.position = Battlefield.CENTER; root.add_child(mother)
	var camera := Camera2D.new(); camera.position = Battlefield.CENTER; camera.zoom = Vector2.ONE * 0.72; root.add_child(camera); camera.make_current()
	hud = Hud.new(); root.add_child(hud); hud.hide_mother_choices()
	hud.update_battle_state({"phase":"day", "health":300.0, "max_health":300.0, "energy":55, "seeds":11, "night":2, "night_total":7, "time_left":42.0})
	hud.update_threat_compass(PackedFloat32Array([0,0,0,0,0,0,0,0]), -1)
	await _save("01-day-idle.png")
	hud.update_battle_state({"phase":"night", "health":260.0, "max_health":300.0, "energy":30, "seeds":8, "night":3, "night_total":7, "remaining_enemies":18})
	feedback.update_snapshot(PackedFloat32Array([0,0.18,0,0,0,0,0,0]), -1); hud.update_threat_compass(PackedFloat32Array([0,0.18,0,0,0,0,0,0]), -1)
	await _save("02-night-normal.png")
	feedback.update_snapshot(PackedFloat32Array([0,0,0.65,0,0,0,0,0]), -1); hud.update_threat_compass(PackedFloat32Array([0,0,0.65,0,0,0,0,0]), -1)
	await _save("03-night-severe.png")
	feedback.update_snapshot(PackedFloat32Array([0,0,0.65,0,0,0,0,0]), 2); hud.update_threat_compass(PackedFloat32Array([0,0,0.65,0,0,0,0,0]), 2)
	await _save("04-boss-threat.png")
	mother.take_damage(20.0); await _save("05-mother-hit.png", 1)
	mother.advance_danger_feedback(1.0); mother.health = 60.0; mother.queue_redraw()
	await _save("06-mother-critical.png")
	quit(0)

func _save(file_name: String, frames := 4) -> void:
	for index in range(frames): await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://output/imagegen/previews/readability/%s" % file_name)
