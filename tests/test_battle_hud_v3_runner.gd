extends SceneTree

var failures: Array[String] = []
var received_wave := false
var received_card := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var hud = load("res://scripts/hud.gd").new()
	viewport.add_child(hud)
	await process_frame
	if FileAccess.file_exists("res://assets/ui/generated/battle_hud_v3/primary_action_normal.png"):
		for button in [hud.wave_button,hud.sunburst_button]:
			for state in ["normal","hover","pressed","disabled"]:
				var style := (button as Button).get_theme_stylebox(state) as StyleBoxTexture
				check(style != null and style.texture.resource_path == "res://assets/ui/generated/battle_hud_v3/primary_action_%s.png" % state, "Both primary buttons must bind generated %s texture" % state)
		var bezel := hud.find_child("TacticalBezelArt",true,false) as TextureRect
		check(bezel.texture != null and bezel.texture.resource_path == "res://assets/ui/generated/battle_hud_v3/tactical_bezel.png", "Generated bezel must load at runtime")
	if FileAccess.file_exists("res://assets/ui/generated/battle_hud_v4/status_frame.png"):
		for name in ["MotherStatusPanel", "PhaseBanner", "ResourcePanel", "PhaseActionTray"]:
			var panel := hud.find_child(name,true,false) as PanelContainer
			var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
			var expected := "action_tray_frame" if name == "PhaseActionTray" else "status_frame"
			check(style != null and style.texture.resource_path == "res://assets/ui/generated/battle_hud_v4/%s.png" % expected, "V4 actual panel binding: " + name)
	hud.wave_requested.connect(func(): received_wave = true)
	hud.combat_card_requested.connect(func(id: String): received_card = id)
	hud.wave_button.pressed.emit()
	check(received_wave, "Start night must still emit gameplay action")
	var ids: Array[String] = ["card_emergency_dew", "card_root_wall", "card_sun_mine", "card_sun_pierce", "card_emergency_dew"]
	for resolution in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = resolution
		await process_frame
		for phase in ["day","night"]:
			hud.update_battle_state({"phase":phase,"health":186.0,"energy":17,"night":3,"seeds":8,"remaining_enemies":18,"sunburst_cost":40})
			if phase == "night": hud.show_combat_hand(ids, phase, 17, false)
			await process_frame
			await process_frame
			var boundary := Rect2(Vector2.ZERO,Vector2(resolution))
			for name in ["MotherStatusPanel","PhaseBanner","ResourcePanel","PhaseActionTray","PrimaryActionButton","TacticalInstrumentFrame"]:
				var control := hud.find_child(name,true,false) as Control
				check(boundary.encloses(control.get_global_rect()), "%s %s %s must be within viewport: %s" % [resolution,phase,name,control.get_global_rect()])
			var tray := hud.phase_action_tray.get_global_rect() as Rect2
			check(tray.end.y <= resolution.y - 17, "Tray must preserve bottom clear space")
			check(not tray.intersects(hud.primary_action_button.get_global_rect()), "Five cards must not intersect primary action")
			check(hud.wave_button.visible == (phase == "day"), "Day action visibility")
			check(hud.sunburst_button.visible == (phase == "night"), "Night action visibility")
			var shortcut := hud.find_child("PrimaryShortcut",true,false) as Label
			var button: Button = hud.wave_button if phase == "day" else hud.sunburst_button
			var text_center: float = button.get_global_rect().get_center().y
			check(shortcut.get_global_rect().end.y < text_center - 12, "Shortcut must remain above primary title")
			if phase == "night":
				check(hud.sunburst_button.disabled, "Unaffordable sunburst must be disabled")
				check(hud.sunburst_cost_label.get_global_rect().position.y > text_center + 10, "Energy cost must remain below primary title")
				var previous := Rect2()
				for child in hud.combat_hand_row.get_children():
					var current := (child as Control).get_global_rect()
					check(tray.encloses(current), "Cards must stay within action tray")
					check(not previous.intersects(current), "Cards must not overlap")
					var art := child.get_node_or_null("SpecimenArt") as TextureRect
					var title := child.get_node_or_null("SpecimenTitle") as Label
					var cost := child.get_node_or_null("SpecimenCost") as Label
					if art != null:
						check(art.texture != null, "V4 card category illustration must load")
						check(not art.get_global_rect().intersects(title.get_global_rect()), "Specimen art must not overlap its title")
						check(not title.get_global_rect().intersects(cost.get_global_rect()), "Specimen name and cost must have separate rows")
						if FileAccess.file_exists("res://assets/ui/generated/battle_hud_v4/specimen_card_normal.png"):
							for state in ["normal", "hover", "pressed", "disabled"]:
								var style := (child as Button).get_theme_stylebox(state) as StyleBoxTexture
								check(style != null and style.texture.resource_path == "res://assets/ui/generated/battle_hud_v4/specimen_card_%s.png" % state, "V4 dynamic card actual %s binding" % state)
					previous = current
	var first_card := hud.combat_hand_row.get_child(0) as Button
	var selection_outline := first_card.get_node_or_null("SpecimenSelection") as Control
	if selection_outline != null:
		first_card.button_pressed = true
		check(selection_outline.visible, "Selected specimen must show a clear warm outline")
		first_card.button_pressed = false
		check(not selection_outline.visible, "Deselected specimen must remove its outline")
	first_card.pressed.emit()
	check(received_card == ids[0], "Card identity must reach gameplay signal")
	hud.update_battle_state({"phase":"night","energy":55,"sunburst_cost":40})
	check(not hud.sunburst_button.disabled, "Affordable sunburst must be usable")
	var choices: Array[String] = ["sun_arrow","root_heart","dawn_pulse"]
	hud.show_mother_choices(choices)
	check(hud.mother_choice_overlay.visible and hud.mother_choice_row.get_child_count() == 3,"Mother upgrade choices remain usable")
	hud.hide_mother_choices()
	check(not hud.mother_choice_overlay.visible,"Mother upgrade overlay dismisses")
	hud.show_message("测试")
	hud._process(2.6)
	check(not hud.notification_banner.visible,"Transient notice expires")
	for issue in failures: push_error(issue)
	print("BATTLE HUD V3 CHECKS ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
