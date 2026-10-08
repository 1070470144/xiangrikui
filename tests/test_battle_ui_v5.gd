extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var viewport := SubViewport.new(); root.add_child(viewport)
	var hud := preload("res://scripts/hud.gd").new(); viewport.add_child(hud)
	var ids: Array[String] = ["card_emergency_dew","card_root_wall","card_sun_mine","card_sun_pierce","card_emergency_dew"]
	for resolution in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		viewport.size = resolution
		for phase in ["day","night"]:
			hud.update_battle_state({"phase":phase,"energy":50,"seeds":10})
			hud.show_combat_hand(ids,phase,50,false)
			await process_frame; await process_frame
			var boundary := Rect2(Vector2.ZERO,Vector2(resolution))
			for name in ["MotherStatusPanel","PhaseBanner","ResourcePanel","PrimaryActionButton","TacticalInstrumentFrame"]:
				var control := hud.find_child(name,true,false) as Control
				check(boundary.encloses(control.get_global_rect()),"Within viewport: %s %s %s" % [resolution,phase,name])
			check(not hud.phase_action_tray.get_global_rect().intersects(hud.primary_action_button.get_global_rect()),"Hand/action overlap")
			check(hud.combat_hand_panel.visible == (phase == "night"),"Phase default visibility")
			if phase == "day":
				(hud.hand_tabs.get_node("TacticsTab") as Button).pressed.emit()
				check(hud.combat_hand_panel.visible and not hud.day_action_panel.visible,"Reachable day tactical hand")
			for card in hud.combat_hand_row.get_children():
				check(card.position.y >= 0 and absf(card.rotation) <= 0.23,"Bottom fan remains usable")
				card._hover()
				check(boundary.encloses(card.get_global_rect()),"Hovered card fully exposed")
				card._unhover()
				check(card.has_node("EffectDescription") and card.has_node("TargetLabel"),"Card core rules and target label")
				var face := card.get_theme_stylebox("normal") as StyleBoxTexture
				check(face != null and "deck_builder/faces_v5" in face.texture.resource_path,"Deck face bound")
				check(card.get_node("DescriptionPaper").get_theme_stylebox("panel") is StyleBoxEmpty,"Reused face paper unobscured")
	if FileAccess.file_exists("res://assets/ui/generated/battle_ui_v5/navy_status_frame.png"):
		for name in ["MotherStatusPanel","PhaseBanner","ResourcePanel"]:
			check(hud.find_child(name,true,false).get_theme_stylebox("panel") is StyleBoxTexture,"Generated shared header bound")
	for failure in failures: push_error(failure)
	print("BATTLE UI V5 CHECK: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
