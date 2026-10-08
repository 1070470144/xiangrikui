extends SceneTree

const Battlefield = preload("res://scripts/battlefield.gd")
const MotherFlower = preload("res://scripts/mother_flower.gd")
const Hud = preload("res://scripts/hud.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	var mother := MotherFlower.new()
	mother.position = battlefield.CENTER
	root.add_child(mother)
	var camera := Camera2D.new()
	camera.position = battlefield.CENTER
	camera.zoom = Vector2.ONE * 0.72
	root.add_child(camera)
	camera.make_current()
	var hud := Hud.new()
	root.add_child(hud)
	hud.hide_mother_choices()
	hud.update_network_radar([
		{"position": battlefield.CENTER, "connected": true},
		{"position": battlefield.CENTER + Vector2(520, 210), "connected": true},
		{"position": battlefield.CENTER + Vector2(-430, 360), "connected": true},
	], [
		{"from": battlefield.CENTER, "to": battlefield.CENTER + Vector2(520, 210), "connected": true},
		{"from": battlefield.CENTER, "to": battlefield.CENTER + Vector2(-430, 360), "connected": true},
	])
	hud.update_battle_state({"phase":"day", "health":268.0, "max_health":300.0, "energy":55, "seeds":11, "night":2, "night_total":7, "time_left":42.0, "remaining_enemies":0, "sunburst_cost":40, "light_sprout_cost":15})
	hud.show_message("自由种植：光脉连接范围内均可部署")
	for i in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://tmp/battle-ui-v3-layout/hud-day-runtime.png")
	root.get_viewport().get_texture().get_image().save_png("res://tmp/battle-ui-v3-layout/battle-hud-day-final.png")
	var mother_choices: Array[String] = ["sun_arrow", "root_heart", "dawn_pulse"]
	hud.show_mother_choices(mother_choices)
	for i in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://tmp/battle-ui-v3-layout/hud-mother-choice-runtime.png")
	hud.hide_mother_choices()
	hud.update_battle_state({"phase":"night", "health":186.0, "max_health":300.0, "energy":17, "seeds":8, "night":3, "night_total":7, "remaining_enemies":18, "sunburst_cost":40, "boss_active":true, "boss_direction":1})
	hud.update_threat_compass(PackedFloat32Array([0.4, 1.0, 0.2, 0.0, 0.7, 0.0, 0.3, 0.8]), 1)
	var cards: Array[String] = ["card_emergency_dew", "card_root_wall", "card_sun_mine", "card_sun_pierce"]
	hud.show_combat_hand(cards, "night", 17, false, "card_sun_mine")
	hud.show_message("光脉节点受损")
	for i in range(4): await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://tmp/battle-ui-v3-layout/hud-night-runtime.png")
	root.get_viewport().get_texture().get_image().save_png("res://tmp/battle-ui-v3-layout/battle-hud-night-final.png")
	var button := hud.find_child("SunburstButton", true, false) as Button
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.disabled = false
		button.add_theme_stylebox_override("normal", button.get_theme_stylebox(state))
		if state == "disabled": button.disabled = true
		for i in range(2): await process_frame
		root.get_viewport().get_texture().get_image().save_png("res://tmp/battle-ui-v3-layout/battle-hud-primary-%s.png" % state)
	quit(0)


