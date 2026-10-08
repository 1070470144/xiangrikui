extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/hud.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		return ["battle HUD script must compile"]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	Engine.get_main_loop().root.add_child(viewport)
	var hud: CanvasLayer = script.new()
	viewport.add_child(hud)
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	expect(_method_accepts_string(hud, "set_visual_state"), "HUD must expose set_visual_state(state: String)")
	expect(hud.has_method("set_phase_layout"), "HUD must expose a phase layout state machine")
	expect(hud.has_method("update_battle_state"), "HUD must accept structured battle state updates")
	expect(hud.has_method("update_network_radar"), "HUD must update network radar independently")
	expect(hud.has_method("update_threat_compass"), "HUD must update threat compass independently")
	for signal_name in [
		"thorn_requested", "prism_requested", "light_sprout_requested",
		"sunburst_requested", "wave_requested", "restart_requested",
		"radar_focus_requested", "mother_card_requested",
		"combat_card_requested", "mulligan_requested",
	]:
		expect(hud.has_signal(signal_name), "HUD must retain public signal %s" % signal_name)
	for node_name in [
		"BattleUiRoot", "MotherStatusPanel", "PhaseBanner", "ResourcePanel", "NotificationBanner",
		"DayActionPanel", "NightHandPanel", "DaySelectionPanel", "NetworkRadarFrame",
		"ThreatCompassFrame", "StartNightButton", "SunburstButton",
		"TacticalInstrumentFrame", "PhaseActionTray", "SelectionDetailPanel",
		"PrimaryActionButton", "MotherChoiceOverlay", "PauseOverlay", "ResultOverlay",
	]:
		expect(hud.find_child(node_name, true, false) != null, "HUD must create %s" % node_name)
	for button_name in ["StartNightButton", "SunburstButton"]:
		expect(hud.find_child(button_name, true, false) is Button, "HUD must retain public button %s" % button_name)
	expect(not _visible(hud, "SelectionDetailPanel"), "selection detail must start hidden")
	expect(not _visible(hud, "NotificationBanner"), "notification banner must start hidden")
	if hud.has_method("set_visual_state"):
		hud.set_visual_state("day")
		expect(_visible_in_tree(hud, "DayActionPanel"), "day actions visible")
		expect(not _visible_in_tree(hud, "NightHandPanel"), "night hand hidden in day")
		hud.set_visual_state("night")
		expect(_visible_in_tree(hud, "NightHandPanel"), "night hand visible")
		expect(not _visible_in_tree(hud, "DayActionPanel"), "day actions hidden at night")
	if hud.has_method("show_result") and hud.has_method("hide_result"):
		hud.show_result(true)
		var result_overlay := hud.find_child("ResultOverlay", true, false) as Control
		expect(_visible_in_tree(hud, "ResultOverlay"), "result overlay visible")
		expect(result_overlay != null and result_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "result blocks input")
		expect(_covers_viewport(result_overlay, viewport), "result overlay covers the viewport")
		hud.hide_result()
		expect(not _visible_in_tree(hud, "ResultOverlay"), "result overlay hidden")
	else:
		expect(false, "HUD must expose result overlay show and hide methods")
	hud.update_threat_compass(PackedFloat32Array([0,0,0,0,0,0,0,0]), -1)
	var tactical_frame := hud.find_child("TacticalInstrumentFrame", true, false) as Control
	expect(tactical_frame != null and tactical_frame.modulate.a <= 0.45, "idle tactical instrument must recede")
	hud.update_threat_compass(PackedFloat32Array([0,0,0.5,0,0,0,0,0]), 2)
	expect(tactical_frame != null and tactical_frame.modulate.a >= 0.95, "active threat must restore tactical emphasis")
	hud.show_message("普通提示")
	var notification_timeout: float = INF
	if hud.has_method("get_message_time_left"):
		notification_timeout = float(hud.get_message_time_left())
	expect(is_finite(notification_timeout) and notification_timeout > 0.0 and notification_timeout <= 2.6, "ordinary notification must have a finite short timeout")
	if hud.has_method("show_selection_detail") and hud.has_method("hide_selection_detail"):
		hud.set_phase_layout("day")
		hud.show_selection_detail("光脉", "白昼详情")
		expect(_visible_in_tree(hud, "SelectionDetailPanel"), "selection detail must be visible during day when requested")
		hud.set_phase_layout("night")
		hud.show_selection_detail("敌人", "夜间详情")
		expect(_visible_in_tree(hud, "SelectionDetailPanel"), "selection detail must remain available during night")
		hud.hide_selection_detail()
		expect(not _visible_in_tree(hud, "SelectionDetailPanel"), "selection detail must hide only when explicitly dismissed")
	else:
		expect(false, "HUD must expose selection detail show and hide methods")
	var instrument := hud.find_child("TacticalInstrumentFrame", true, false)
	var network_radar := hud.find_child("NetworkRadarFrame", true, false)
	var threat_compass := hud.find_child("ThreatCompassFrame", true, false)
	var primary_action := hud.find_child("PrimaryActionButton", true, false)
	var start_night := hud.find_child("StartNightButton", true, false)
	var sunburst := hud.find_child("SunburstButton", true, false)
	expect(instrument != null and network_radar != null and instrument.is_ancestor_of(network_radar), "network radar must be contained by the tactical instrument")
	expect(instrument != null and threat_compass != null and instrument.is_ancestor_of(threat_compass), "threat compass must be contained by the tactical instrument")
	expect(primary_action != null and start_night != null and primary_action.is_ancestor_of(start_night), "start-night control must be contained by the unified primary action")
	expect(primary_action != null and sunburst != null and primary_action.is_ancestor_of(sunburst), "sunburst control must be contained by the unified primary action")
	if hud.has_method("set_phase_layout"):
		hud.set_phase_layout("day")
		expect(_visible(hud, "DayActionPanel"), "day layout must show deployment cards")
		expect(_visible(hud, "StartNightButton"), "day layout must show start-night control")
		expect(not _visible(hud, "SunburstButton"), "day layout must hide sunburst control")
		expect(not _visible(hud, "NightHandPanel"), "day layout must hide combat hand")
		expect(not _visible(hud, "ThreatCompassFrame"), "day layout must hide threat compass")
		expect(_visible(hud, "PhaseActionTray"), "day layout must keep the phase action tray visible")
		expect(_visible(hud, "PrimaryActionButton"), "day layout must show the unified primary action")
		var day_tray := hud.find_child("PhaseActionTray", true, false) as Control
		var day_tray_rect := day_tray.get_global_rect() if day_tray != null else Rect2()
		hud.set_phase_layout("night")
		expect(not _visible(hud, "DayActionPanel"), "night layout must hide deployment cards")
		expect(_visible(hud, "NightHandPanel"), "night layout must show combat hand")
		expect(_visible(hud, "ThreatCompassFrame"), "night layout must show threat compass")
		expect(_visible(hud, "SunburstButton"), "night layout must show sunburst control")
		expect(not _visible(hud, "StartNightButton"), "night layout must hide start-night control")
		expect(_visible(hud, "PhaseActionTray"), "night layout must keep the phase action tray visible")
		expect(_visible(hud, "PrimaryActionButton"), "night layout must show the unified primary action")
		var night_tray := hud.find_child("PhaseActionTray", true, false) as Control
		var night_tray_rect := night_tray.get_global_rect() if night_tray != null else Rect2()
		expect(day_tray_rect == night_tray_rect, "phase changes must preserve the action tray position")
	if hud.has_method("update_battle_state"):
		hud.update_battle_state({
			"phase": "night", "health": 225.0, "max_health": 300.0,
			"energy": 17, "seeds": 8, "night": 3, "night_total": 7,
			"remaining_enemies": 18, "sunburst_cost": 40, "boss_active": true,
		})
		expect(_text(hud, "MotherHealthValue").contains("225"), "mother health text must use live values")
		expect(_text(hud, "EnergyValue").contains("17"), "energy text must use live values")
		expect(_text(hud, "EnemyCountLabel").contains("18"), "night HUD must show real remaining enemies")
		expect(_text(hud, "SunburstCostLabel").contains("40"), "sunburst control must show its real energy cost")
		await Engine.get_main_loop().process_frame
		var sunburst_control := hud.find_child("SunburstButton", true, false) as Button
		var cost_control := hud.find_child("SunburstCostLabel", true, false) as Label
		if sunburst_control != null and cost_control != null:
			var content_rect := sunburst_control.get_global_rect().grow(-12.0)
			var cost_rect := cost_control.get_global_rect()
			expect(content_rect.encloses(cost_rect), "sunburst cost %s must stay inside primary action content %s" % [cost_rect, content_rect])
			expect(cost_rect.position.y >= content_rect.get_center().y, "sunburst cost %s must occupy the lower half below icon/title content in %s" % [cost_rect, content_rect])
			expect(sunburst_control.get_theme_constant("icon_max_width") <= 36, "primary action icon width must leave room for title and cost")
	if hud.has_method("show_combat_hand"):
		var cards: Array[String] = ["card_emergency_dew", "card_root_wall", "card_sun_mine", "card_sun_pierce"]
		hud.show_combat_hand(cards, "night", 17, false)
		var hand := hud.find_child("NightHandPanel", true, false) as Control
		expect(hand != null and hand.offset_right - hand.offset_left <= 620.0, "four-card combat hand must not reserve five-card width")
	if hud.has_method("show_mother_choices"):
		var choices: Array[String] = ["sun_arrow", "root_heart", "dawn_pulse"]
		hud.show_mother_choices(choices)
		var overlay := hud.find_child("MotherChoiceOverlay", true, false) as Control
		var row := hud.find_child("MotherChoiceRow", true, false) as Container
		expect(overlay != null and overlay.visible, "non-empty mother choices must show the full-screen overlay")
		expect(overlay != null and overlay.anchor_right == 1.0 and overlay.anchor_bottom == 1.0, "mother choice overlay must cover the viewport")
		expect(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "mother choice overlay must block background input")
		expect(row != null and row.get_child_count() == 3, "mother choice overlay must show exactly three cards")
		if row != null and row.get_child_count() == 3:
			var first_control := row.get_child(0) as Control
			expect(first_control != null, "mother choice entries must be controls")
			var first_size := first_control.custom_minimum_size if first_control != null else Vector2.ZERO
			for child in row.get_children():
				var child_control := child as Control
				expect(child_control != null, "mother choice entries must be controls")
				if child_control != null:
					expect(child_control.custom_minimum_size == first_size, "mother buff cards must use equal sizes")
			var first_card := row.get_child(0) as Button
			expect(first_card != null, "mother choice entries must be buttons")
			if first_card != null:
				expect(first_card.custom_minimum_size == Vector2(240, 300), "mother choice cards must use the portrait card size")
				var card_style := first_card.get_theme_stylebox("normal") as StyleBoxTexture
				var atlas := card_style.texture as AtlasTexture if card_style != null else null
				expect(atlas != null, "mother choice cards must use a cropped atlas texture instead of the shared horizontal button skin")
				if atlas != null:
					expect(atlas.region == Rect2(76, 19, 124, 145), "mother choice card atlas must crop transparent source padding")
		hud.hide_mother_choices()
		expect(overlay != null and not overlay.visible, "choosing a mother buff must hide the complete overlay")
		hud.show_mother_choices([] as Array[String])
		expect(overlay != null and not overlay.visible, "empty mother choices must not leave a blank overlay")
	await _validate_viewport_layout(hud)
	viewport.queue_free()
	await Engine.get_main_loop().process_frame
	return failures

func _validate_viewport_layout(hud: CanvasLayer) -> void:
	if not hud.has_method("set_phase_layout"):
		expect(false, "viewport phase geometry requires set_phase_layout")
		return
	var viewport := hud.get_viewport() as SubViewport
	if viewport == null:
		expect(false, "battle HUD geometry requires a real SubViewport")
		return
	for viewport_size in [Vector2(1152, 648), Vector2(1280, 720), Vector2(1920, 1080)]:
		viewport.size = Vector2i(viewport_size)
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		hud.set_phase_layout("day")
		hud.show_selection_detail("光脉", "白昼详情需要在紧凑面板内自动换行")
		await Engine.get_main_loop().process_frame
		_expect_nodes_in_viewport(hud, ["MotherStatusPanel", "PhaseBanner", "ResourcePanel", "TacticalInstrumentFrame", "PhaseActionTray", "PrimaryActionButton", "DayActionPanel", "DaySelectionPanel", "NetworkRadarFrame", "StartNightButton"], "day")
		_expect_no_overlap(hud, "MotherStatusPanel", "PhaseBanner")
		_expect_no_overlap(hud, "PhaseBanner", "ResourcePanel")
		_expect_no_overlap(hud, "MotherStatusPanel", "ResourcePanel")
		_expect_no_overlap(hud, "TacticalInstrumentFrame", "ResourcePanel")
		_expect_no_overlap(hud, "PhaseActionTray", "PrimaryActionButton")
		_expect_no_overlap(hud, "SelectionDetailPanel", "PhaseActionTray")
		hud.set_phase_layout("night")
		hud.show_selection_detail("敌人", "夜间详情需要在紧凑面板内自动换行")
		await Engine.get_main_loop().process_frame
		_expect_nodes_in_viewport(hud, ["MotherStatusPanel", "PhaseBanner", "ResourcePanel", "TacticalInstrumentFrame", "PhaseActionTray", "PrimaryActionButton", "NightHandPanel", "ThreatCompassFrame", "SunburstButton"], "night")
		_expect_no_overlap(hud, "TacticalInstrumentFrame", "ResourcePanel")
		_expect_no_overlap(hud, "PhaseActionTray", "PrimaryActionButton")
		_expect_no_overlap(hud, "SelectionDetailPanel", "PhaseActionTray")
		hud.hide_selection_detail()

func _expect_nodes_in_viewport(root: Node, node_names: Array[String], phase_name: String) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size)
	for node_name in node_names:
		var control := root.find_child(node_name, true, false) as Control
		if control == null:
			expect(false, "%s must exist for %s viewport geometry checks" % [node_name, phase_name])
			continue
		var rect := control.get_global_rect()
		expect(viewport_rect.encloses(rect), "%s rect %s must fit inside %s during %s" % [node_name, rect, viewport_rect, phase_name])

func _expect_no_overlap(root: Node, first_name: String, second_name: String) -> void:
	var first := root.find_child(first_name, true, false) as Control
	var second := root.find_child(second_name, true, false) as Control
	if first == null or second == null:
		expect(false, "cannot compare %s and %s because a node is missing" % [first_name, second_name])
		return
	var first_rect := first.get_global_rect()
	var second_rect := second.get_global_rect()
	expect(not first_rect.intersects(second_rect), "%s %s must not overlap %s %s" % [first_name, first_rect, second_name, second_rect])

func _visible(root: Node, node_name: String) -> bool:
	var node := root.find_child(node_name, true, false) as CanvasItem
	return node != null and node.visible

func _visible_in_tree(root: Node, node_name: String) -> bool:
	var node := root.find_child(node_name, true, false) as CanvasItem
	return node != null and node.is_visible_in_tree()

func _covers_viewport(control: Control, viewport: SubViewport) -> bool:
	if control == null or viewport == null:
		return false
	var full_rect_anchors := (
		control.anchor_left == 0.0 and control.anchor_top == 0.0
		and control.anchor_right == 1.0 and control.anchor_bottom == 1.0
	)
	return full_rect_anchors and control.get_global_rect().encloses(viewport.get_visible_rect())

func _text(root: Node, node_name: String) -> String:
	var node := root.find_child(node_name, true, false) as Label
	return node.text if node != null else ""

func _method_accepts_string(root: Object, method_name: String) -> bool:
	for method in root.get_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var arguments: Array = method.get("args", [])
		return arguments.size() == 1 and int(arguments[0].get("type", TYPE_NIL)) == TYPE_STRING
	return false
