extends CanvasLayer

const ArtLibrary = preload("res://scripts/art_library.gd")
const LightRadarScript = preload("res://scripts/light_radar.gd")
const ThreatCompassScript = preload("res://scripts/threat_compass.gd")
const Balance = preload("res://scripts/balance.gd")
const ContentData = preload("res://scripts/content_data.gd")
const ArtManifest = preload("res://scripts/art_manifest.gd")
const ART_MANIFEST_PATH := "res://art_source/manifests/battle_hud_v3.json"
const ART_DETAIL_MANIFEST_PATH := "res://art_source/manifests/battle_hud_v4.json"

signal thorn_requested
signal prism_requested
signal light_sprout_requested
signal sunburst_requested
signal wave_requested
signal restart_requested
signal radar_focus_requested(world_position: Vector2)
signal mother_card_requested(card_id: String)
signal combat_card_requested(card_id: String)
signal combat_card_drag_started(card_id: String)
signal combat_card_dropped(card_id: String, viewport_position: Vector2)
signal combat_card_drag_finished
signal mulligan_requested(card_id: String)
signal plant_loadout_requested
signal plant_loadout_confirmed(card_ids: Array[String])
signal plant_loadout_cancelled
signal deployment_card_requested(card_id: String)

var health_bar: ProgressBar
var energy_bar: ProgressBar
var wave_label: Label
var phase_label: Label
var timer_label: Label
var seed_label: Label
var message_label: Label
var thorn_button: Button
var prism_button: Button
var light_sprout_button: Button
var repair_button: Button
var sunburst_button: Button
var wave_button: Button
var restart_button: Button
var radar: Control
var threat_compass: Control
var mother_choice_overlay: Control
var mother_choice_panel: PanelContainer
var mother_choice_row: HBoxContainer
var combat_hand_panel: PanelContainer
var combat_hand_row: Control
var day_action_panel: Control
var day_selection_panel: Control
var selection_detail_panel: Control
var selection_title_label: Label
var selection_detail_label: Label
var tactical_instrument_frame: Control
var phase_action_tray: Control
var primary_action_button: Control
var network_radar_frame: Control
var threat_compass_frame: Control
var start_night_button: Control
var notification_banner: Control
var enemy_alert_panel: PanelContainer
var enemy_alert_label: Label
var _enemy_alert_time_left := 0.0
var sunburst_cost_label: Label
var enemy_count_label: Label
var mother_health_value: Label
var energy_value: Label
var _root: Control
var _phase := "day"
var _hand_signature := ""
var _mother_choice_signature := ""
var _message_time_left := 0.0
var _specimen_skin: Dictionary = {}
var _card_drag_active := false
var _drag_card_id := ""
var _pending_hand: Array = []
var _hand_ids: Array[String] = []
var _card_drag_cancelled := false
var plant_loadout_overlay: Control
var plant_loadout_button: Button
var _deployment_row: Control
var _plant_loadout: Array[String] = ["deploy_thorn","deploy_prism","deploy_lantern","deploy_frost","deploy_honeydew"]
var _plant_loadout_layout_applied := false
var hand_tabs: HBoxContainer

func _input(event: InputEvent) -> void:
	if is_plant_loadout_open() and event.is_action_pressed("cancel_action"):
		hide_plant_loadout(); plant_loadout_cancelled.emit(); get_viewport().set_input_as_handled(); return
	if not _card_drag_active: return
	if event.is_action_pressed("cancel_action") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_card_drag_cancelled = true
		if get_viewport().has_method("gui_cancel_drag"): get_viewport().call("gui_cancel_drag")
		get_viewport().set_input_as_handled()

func _ready() -> void:
	_build_ui()
	_apply_battle_hud_v3()
	for warning in ArtManifest.apply_file(ART_MANIFEST_PATH, _root):
		push_warning(warning)
	var detail_file := FileAccess.open(ART_DETAIL_MANIFEST_PATH, FileAccess.READ)
	if detail_file != null:
		var detail: Variant = JSON.parse_string(detail_file.get_as_text())
		if detail is Dictionary:
			for asset: Dictionary in detail.get("assets", []):
				if asset.get("id") == "specimen_card_frame": _specimen_skin = asset
	_apply_battle_hud_v4()
	for warning in ArtManifest.apply_file(ART_DETAIL_MANIFEST_PATH, _root):
		push_warning(warning)
	_setup_collectible_hand()
	_apply_generated_v5_header()
	call_deferred("_compact_battle_readouts")
	set_process(true)

func _compact_battle_readouts() -> void:
	for name in ["MotherStatusPanel","PhaseBanner","ResourcePanel","TacticalInstrumentFrame","PrimaryActionButton"]:
		var control := _root.find_child(name,true,false) as Control
		if control == null: continue
		control.pivot_offset = Vector2(control.size.x * control.anchor_left,control.size.y * control.anchor_top)
		control.scale = Vector2.ONE * 0.82

func _apply_generated_v5_header() -> void:
	var file := FileAccess.open("res://art_source/manifests/battle_ui_v5.json",FileAccess.READ)
	if file == null: return
	var manifest: Variant = JSON.parse_string(file.get_as_text())
	if not manifest is Dictionary: return
	for asset: Dictionary in manifest.get("assets",[]):
		if asset.get("id") != "navy_status_frame": continue
		if not ResourceLoader.exists(str(asset.get("runtime",{}).get("path",""))): return
		for warning in ArtManifest.apply_data({"schema_version":1,"assets":[asset]},_root): push_warning(warning)

func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0 and notification_banner != null:
			notification_banner.visible = false
	if _enemy_alert_time_left > 0.0:
		_enemy_alert_time_left -= delta
		if enemy_alert_panel != null:
			if _enemy_alert_time_left <= 0.0: enemy_alert_panel.visible = false

func _label(text: String, size := 18, color := Color("f6e4ad")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _ornate_panel(fill := Color("081016e8"), border := Color("a5823f"), width := 2, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _texture_style(path: String, left: float, top: float, right: float, bottom: float, content_margin := 10.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = ArtLibrary.load_texture(path)
	style.set_texture_margin(SIDE_LEFT, left)
	style.set_texture_margin(SIDE_TOP, top)
	style.set_texture_margin(SIDE_RIGHT, right)
	style.set_texture_margin(SIDE_BOTTOM, bottom)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, content_margin)
	return style

func _mother_card_style(tint: Color) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ArtLibrary.load_texture(ArtLibrary.UI_GEN_CARD)
	atlas.region = Rect2(76, 19, 124, 145)
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 22)
		style.set_content_margin(side, 30)
	return style

func _mother_choice_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(240, 300)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f6e4ad"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _mother_card_style(Color.WHITE))
	button.add_theme_stylebox_override("hover", _mother_card_style(Color("fff4c7")))
	button.add_theme_stylebox_override("pressed", _mother_card_style(Color("d6b86f")))
	button.mouse_entered.connect(func(): button.position.y = -6)
	button.mouse_exited.connect(func(): button.position.y = 0)
	return button

func _button(text: String, minimum := Vector2(142, 64)) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("f6e4ad"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	_style_tactical_button(button)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 36)
	return button

func _panel(name_value: String, parent: Control, anchors: Vector4, offsets: Vector4, style: StyleBox) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_value
	panel.anchor_left = anchors.x; panel.anchor_top = anchors.y; panel.anchor_right = anchors.z; panel.anchor_bottom = anchors.w
	panel.offset_left = offsets.x; panel.offset_top = offsets.y; panel.offset_right = offsets.z; panel.offset_bottom = offsets.w
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _build_ui() -> void:
	if _root != null: return
	_root = Control.new(); _root.name = "BattleHudRoot"; _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_root)
	_build_mother_status(); _build_phase_banner(); _build_resources(); _build_notification(); _build_enemy_alert(); _build_day_controls(); _build_radars(); _build_night_controls(); _build_modal_layers(); set_phase_layout("day")

func _style_tactical_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _ornate_panel(Color("13231ff5"), Color("736440"), 1, 7))
	button.add_theme_stylebox_override("hover", _ornate_panel(Color("253b2df8"), Color("d4b96f"), 2, 7))
	button.add_theme_stylebox_override("pressed", _ornate_panel(Color("314431f8"), Color("edce85"), 2, 7))
	button.add_theme_stylebox_override("disabled", _ornate_panel(Color("121b1af0"), Color("45483c"), 1, 7))
	button.add_theme_color_override("font_disabled_color", Color("899080"))
	button.add_theme_color_override("font_pressed_color", Color("fff1bf"))
	button.add_theme_stylebox_override("focus", _ornate_panel(Color("00000000"), Color("edce85"), 2, 7))
	button.add_theme_constant_override("icon_separation", 9)

func _apply_battle_hud_v3() -> void:
	# Native surfaces remain readable if the manifest artwork is unavailable.
	for node_name in ["MotherStatusPanel", "PhaseBanner", "ResourcePanel", "PhaseActionTray"]:
		var panel := _root.find_child(node_name, true, false) as PanelContainer
		panel.add_theme_stylebox_override("panel", _ornate_panel(Color("0c1a18f2"), Color("82724c"), 1, 9))
	var mother := _root.find_child("MotherStatusPanel", true, false) as Control
	mother.offset_right = 322; mother.offset_bottom = 102
	var phase := _root.find_child("PhaseBanner", true, false) as Control
	phase.offset_left = -136; phase.offset_right = 136; phase.offset_top = 14; phase.offset_bottom = 88
	var resources := _root.find_child("ResourcePanel", true, false) as Control
	resources.offset_left = -296; resources.offset_bottom = 88
	phase_label.add_theme_font_size_override("font_size", 21)
	phase_label.add_theme_color_override("font_color", Color("fff0c4"))
	energy_value.add_theme_font_size_override("font_size", 19)
	seed_label.add_theme_font_size_override("font_size", 17)
	health_bar.add_theme_stylebox_override("fill", _ornate_panel(Color("d5b76f"), Color("ead28b"), 0, 3))
	health_bar.add_theme_stylebox_override("background", _ornate_panel(Color("26302a"), Color("5d6044"), 1, 3))
	phase_action_tray.offset_left = -288; phase_action_tray.offset_right = 288
	phase_action_tray.offset_top = -144; phase_action_tray.offset_bottom = -18
	for panel in [day_action_panel, combat_hand_panel]:
		var content_style := _ornate_panel(Color("00000000"), Color("00000000"), 0, 0)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: content_style.set_content_margin(side, 0)
		content_style.shadow_size = 0
		panel.add_theme_stylebox_override("panel", content_style)
	for button in [light_sprout_button, thorn_button, prism_button, repair_button]:
		button.custom_minimum_size = Vector2(130, 90)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_constant_override("icon_max_width", 30)
		button.tooltip_text = "选择后点击供光区域部署" if button != repair_button else "点击受损光脉节点修复"
	primary_action_button.add_theme_stylebox_override("panel", _ornate_panel(Color("0c1a18f2"), Color("b59b59"), 1, 9))
	primary_action_button.offset_left = -178; primary_action_button.offset_top = -144
	for button in [wave_button, sunburst_button]:
		button.icon = null
		button.add_theme_font_size_override("font_size", 20)
		_style_tactical_button(button)
	var cost_overlay := _root.find_child("CostOverlay", true, false) as Control
	cost_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sunburst_cost_label.offset_top = -37; sunburst_cost_label.offset_bottom = -15
	var shortcut := _label("ENTER  /  入夜", 11, Color("b5ab89"))
	shortcut.name = "PrimaryShortcut"; shortcut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shortcut.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shortcut.offset_top = 8; shortcut.offset_bottom = 27
	shortcut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_overlay.add_child(shortcut)
	wave_button.text = "开始守夜"
	wave_button.tooltip_text = "完成部署后进入下一夜"
	sunburst_button.text = "太阳爆闪"
	sunburst_button.tooltip_text = "选择后点击战场释放，消耗光能"
	tactical_instrument_frame.offset_top = 112; tactical_instrument_frame.offset_bottom = 288
	tactical_instrument_frame.add_theme_stylebox_override("panel", _ornate_panel(Color("0b1816ee"), Color("81734d"), 1, 88))
	var radar_art := TextureRect.new(); radar_art.name = "TacticalBezelArt"
	radar_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	radar_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	radar_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tactical_instrument_frame.add_child(radar_art)
	selection_detail_panel.offset_top = -258; selection_detail_panel.offset_bottom = -156
	notification_banner.offset_left = -224; notification_banner.offset_right = 224
	message_label.add_theme_font_size_override("font_size", 16)

func _apply_battle_hud_v4() -> void:
	for name in ["MotherStatusPanel", "PhaseBanner", "ResourcePanel"]:
		var panel := _root.find_child(name, true, false) as PanelContainer
		var style := _ornate_panel(Color("102322e8"), Color("8b7954"), 1, 12)
		style.border_width_bottom = 2
		style.shadow_size = 5
		panel.add_theme_stylebox_override("panel", style)
	phase_label.add_theme_font_size_override("font_size", 23)
	wave_label.add_theme_font_size_override("font_size", 12)
	energy_value.add_theme_font_size_override("font_size", 18)
	seed_label.add_theme_font_size_override("font_size", 15)
	phase_action_tray.add_theme_stylebox_override("panel", _ornate_panel(Color("081815b8"), Color("665c43"), 1, 10))
	var portraits := [ArtLibrary.NODE_HEALTHY, ArtLibrary.THORN_POWERED, ArtLibrary.PRISM_POWERED, ArtLibrary.UI_ICON_REPAIR]
	var buttons := [light_sprout_button, thorn_button, prism_button, repair_button]
	for i in range(buttons.size()):
		_specimen_card(buttons[i], portraits[i])
	_set_specimen_text(light_sprout_button, "光脉芽", "☀ %d" % Balance.DAY_LIGHT_SPROUT_COST)
	_set_specimen_text(thorn_button, "荆棘花", "❧ 1")
	_set_specimen_text(prism_button, "棱镜花", "❧ 2")
	_set_specimen_text(repair_button, "修复", "☀ %d" % Balance.REPAIR_COST)

func _specimen_card(button: Button, art_path: String) -> void:
	button.icon = null
	button.text = ""
	var style := _ornate_panel(Color("182d28f5"), Color("95845c"), 1, 8)
	style.shadow_size = 2
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", _ornate_panel(Color("20332bf8"), Color("e0c378"), 2, 8))
	var art := TextureRect.new()
	art.name = "SpecimenArt"
	art.texture = ArtLibrary.load_texture(art_path)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	art.offset_left = 12; art.offset_right = -12; art.offset_top = 4; art.offset_bottom = 61
	button.add_child(art)
	var title := _label("", 14, Color("f1e2b8"))
	title.name = "SpecimenTitle"; title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_left = 5; title.offset_right = -5; title.offset_top = -47; title.offset_bottom = -25
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(title)
	var cost := _label("", 12, Color("cbbf8f"))
	cost.name = "SpecimenCost"; cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cost.offset_left = 5; cost.offset_right = -5; cost.offset_top = -21; cost.offset_bottom = -3
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(cost)
	if button.disabled:
		art.modulate = Color("809084")
		title.modulate = Color("a5aaa0")
		cost.modulate = Color("a5aaa0")
	if not _specimen_skin.is_empty() and ResourceLoader.exists("res://assets/ui/generated/battle_hud_v4/specimen_card_normal.png"):
		var skin := _specimen_skin.duplicate(true)
		for binding: Dictionary in skin["bindings"]: binding["scope"] = "scene"
		for warning in ArtManifest.apply_data({"schema_version":1,"assets":[skin]}, button): push_warning(warning)
	var selected := Panel.new()
	selected.name = "SpecimenSelection"
	selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var selection_style := _ornate_panel(Color("00000000"), Color("d8bd76"), 2, 6)
	selection_style.shadow_size = 0
	selected.add_theme_stylebox_override("panel", selection_style)
	selected.visible = button.button_pressed
	button.add_child(selected)
	button.toggled.connect(func(active: bool): selected.visible = active)

func _set_specimen_text(button: Button, title: String, cost: String) -> void:
	button.text = ""
	(button.get_node("SpecimenTitle") as Label).text = title
	(button.get_node("SpecimenCost") as Label).text = cost

func _combat_specimen_path(card_id: String) -> String:
	var deck_path := "res://assets/ui/generated/deck_builder/illustrations_v3/%s.png" % card_id
	if ResourceLoader.exists(deck_path): return deck_path
	if card_id.contains("dew") or card_id.contains("rain") or card_id.contains("repair"): return ArtLibrary.NODE_HEALTHY
	if card_id.contains("root") or card_id.contains("wall") or card_id.contains("snare"): return ArtLibrary.THORN_POWERED
	if card_id.contains("pierce") or card_id.contains("focus"): return ArtLibrary.PRISM_POWERED
	return ArtLibrary.MOTHER_HEALTHY

func _build_mother_status() -> void:
	var panel := _panel("MotherStatusPanel", _root, Vector4(0, 0, 0, 0), Vector4(18, 14, 318, 96), _texture_style(ArtLibrary.UI_GEN_PANEL_TOP, 34, 24, 34, 24, 8))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); panel.add_child(row)
	var portrait := TextureRect.new(); portrait.custom_minimum_size = Vector2(66, 66); portrait.texture = ArtLibrary.load_texture(ArtLibrary.MOTHER_HEALTHY); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(portrait)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(box)
	var title_row := HBoxContainer.new(); box.add_child(title_row); title_row.add_child(_label("母花", 20))
	mother_health_value = _label("300 / 300", 14, Color("e7d7b0")); mother_health_value.name = "MotherHealthValue"; mother_health_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mother_health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; title_row.add_child(mother_health_value)
	health_bar = ProgressBar.new(); health_bar.max_value = Balance.MOTHER_MAX_HEALTH; health_bar.value = Balance.MOTHER_MAX_HEALTH; health_bar.show_percentage = false; health_bar.custom_minimum_size = Vector2(190, 16); health_bar.add_theme_stylebox_override("background", _ornate_panel(Color("111821"), Color("604d2f"), 1, 4)); health_bar.add_theme_stylebox_override("fill", _texture_style(ArtLibrary.UI_BAR_HEALTH, 10, 4, 10, 4, 1)); box.add_child(health_bar)
	box.add_child(_label("光根稳定", 12, Color("9fbd8e")))

func _build_phase_banner() -> void:
	var panel := _panel("PhaseBanner", _root, Vector4(0.5, 0, 0.5, 0), Vector4(-160, 10, 160, 86), _ornate_panel(Color("070d13ed"), Color("9a793a"), 2, 4))
	var box := VBoxContainer.new(); box.name = "PhaseContent"; box.alignment = BoxContainer.ALIGNMENT_CENTER; panel.add_child(box)
	phase_label = _label("第一夜  白昼", 22); phase_label.name = "PhaseLabel"; phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(phase_label)
	var detail_row := HBoxContainer.new(); detail_row.name = "PhaseDetailRow"; detail_row.alignment = BoxContainer.ALIGNMENT_CENTER; detail_row.add_theme_constant_override("separation", 12); box.add_child(detail_row)
	wave_label = _label("准备防线", 14, Color("b6a77d")); wave_label.name = "WaveLabel"; wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; detail_row.add_child(wave_label)
	timer_label = _label("☀  00:30", 16); timer_label.name = "TimerLabel"; timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; detail_row.add_child(timer_label)
	enemy_count_label = _label("", 14, Color("d5c295")); enemy_count_label.name = "EnemyCountLabel"; enemy_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; detail_row.add_child(enemy_count_label)

func _build_resources() -> void:
	var panel := _panel("ResourcePanel", _root, Vector4(1, 0, 1, 0), Vector4(-310, 14, -18, 72), _ornate_panel())
	var row := HBoxContainer.new(); row.name = "ResourceRow"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 12); panel.add_child(row)
	energy_value = _label("☀  光能 55", 18); energy_value.name = "EnergyValue"; row.add_child(energy_value)
	seed_label = _label("❧  种子 5", 18); seed_label.name = "SeedLabel"; row.add_child(seed_label)
	energy_bar = ProgressBar.new(); energy_bar.visible = false; panel.add_child(energy_bar)

func _build_notification() -> void:
	notification_banner = _panel("NotificationBanner", _root, Vector4(0.5, 0, 0.5, 0), Vector4(-180, 92, 180, 128), _ornate_panel(Color("240e11ed"), Color("9d4139"), 2, 3))
	message_label = _label("", 18, Color("f3c6a0")); message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; notification_banner.add_child(message_label); notification_banner.visible = false

func _build_enemy_alert() -> void:
	enemy_alert_panel = _panel("EnemyAlertPanel", _root, Vector4(1, 0, 1, 0), Vector4(-306, 276, -18, 328), _ornate_panel(Color("2a1514ee"), Color("d66b52"), 2, 6))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8); enemy_alert_panel.add_child(row)
	var marker := _label("!", 24, Color("f5c16b")); marker.custom_minimum_size = Vector2(24, 30); marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; row.add_child(marker)
	enemy_alert_label = _label("来袭", 15, Color("ffe0b0")); enemy_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.add_child(enemy_alert_label)
	enemy_alert_panel.visible = false

func _build_day_controls() -> void:
	day_selection_panel = Control.new(); day_selection_panel.name = "DaySelectionPanel"; day_selection_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); day_selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; _root.add_child(day_selection_panel)
	selection_detail_panel = _panel("SelectionDetailPanel", _root, Vector4(0, 1, 0, 1), Vector4(18, -122, 250, -20), _ornate_panel(Color("071016e8"), Color("87713d"), 2, 5)); selection_detail_panel.visible = false
	var legacy_selection := Control.new(); legacy_selection.name = "SelectionPanel"; legacy_selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); legacy_selection.mouse_filter = Control.MOUSE_FILTER_IGNORE; selection_detail_panel.add_child(legacy_selection)
	var select_box := VBoxContainer.new(); select_box.name = "SelectionContent"; selection_detail_panel.add_child(select_box); selection_title_label = _label("当前选择", 14, Color("a9c49e")); selection_title_label.name = "SelectionTitle"; select_box.add_child(selection_title_label); selection_detail_label = _label("光脉与植物部署", 18); selection_detail_label.name = "SelectionValue"; selection_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; select_box.add_child(selection_detail_label)
	phase_action_tray = _panel("PhaseActionTray", _root, Vector4(0.5, 1, 0.5, 1), Vector4(-310, -132, 310, -18), _texture_style(ArtLibrary.UI_GEN_PANEL_ACTION, 34, 24, 34, 24, 0))
	day_action_panel = _panel("DayActionPanel", phase_action_tray, Vector4(0, 0, 1, 1), Vector4(0, 0, 0, 0), _texture_style(ArtLibrary.UI_GEN_PANEL_ACTION, 34, 24, 34, 24, 12))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8); day_action_panel.add_child(row)
	light_sprout_button = _button("光脉芽\n☀ %d" % Balance.DAY_LIGHT_SPROUT_COST, Vector2(142, 94)); light_sprout_button.icon = ArtLibrary.load_texture(ArtLibrary.NODE_HEALTHY); thorn_button = _button("荆棘花\n❧ 1", Vector2(142, 94)); thorn_button.icon = ArtLibrary.load_texture(ArtLibrary.UI_ICON_THORN); prism_button = _button("棱镜花\n❧ 2", Vector2(142, 94)); prism_button.icon = ArtLibrary.load_texture(ArtLibrary.UI_ICON_PRISM); repair_button = _button("修复\n☀ %d" % Balance.REPAIR_COST, Vector2(142, 94)); repair_button.icon = ArtLibrary.load_texture(ArtLibrary.UI_ICON_REPAIR)
	for button in [light_sprout_button, thorn_button, prism_button, repair_button]: row.add_child(button)
	light_sprout_button.pressed.connect(func(): light_sprout_requested.emit()); thorn_button.pressed.connect(func(): thorn_requested.emit()); prism_button.pressed.connect(func(): prism_requested.emit()); repair_button.pressed.connect(func(): show_message("点击受损光脉节点进行修复"))
	primary_action_button = _panel("PrimaryActionButton", _root, Vector4(1, 1, 1, 1), Vector4(-180, -138, -18, -18), _ornate_panel(Color("050a12f4"), Color("a5823f"), 2, 8))
	wave_button = _button("开始守夜", Vector2.ZERO); wave_button.name = "StartNightButton"; wave_button.icon = ArtLibrary.load_texture(ArtLibrary.UI_ICON_SUNBURST); wave_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); wave_button.add_theme_font_size_override("font_size", 21); wave_button.pressed.connect(func(): wave_requested.emit()); primary_action_button.add_child(wave_button); start_night_button = wave_button

func _build_radars() -> void:
	tactical_instrument_frame = _panel("TacticalInstrumentFrame", _root, Vector4(1, 0, 1, 0), Vector4(-194, 84, -18, 260), _ornate_panel(Color("030a11e8"), Color("90723b"), 2, 88))
	network_radar_frame = _panel("NetworkRadarFrame", tactical_instrument_frame, Vector4(0, 0, 1, 1), Vector4(0, 0, 0, 0), _ornate_panel(Color("030a1100"), Color("90723b00"), 0, 88))
	var legacy := Control.new(); legacy.name = "RadarFrame"; legacy.mouse_filter = Control.MOUSE_FILTER_IGNORE; network_radar_frame.add_child(legacy)
	radar = LightRadarScript.new(); radar.name = "NetworkRadar"; radar.set_anchors_and_offsets_preset(Control.PRESET_CENTER); radar.position = Vector2(-70, -70); radar.focus_requested.connect(func(point: Vector2): radar_focus_requested.emit(point)); network_radar_frame.add_child(radar)
	threat_compass_frame = _panel("ThreatCompassFrame", tactical_instrument_frame, Vector4(0, 0, 1, 1), Vector4(0, 0, 0, 0), _ornate_panel(Color("03071100"), Color("90723b00"), 0, 88)); threat_compass_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; threat_compass = ThreatCompassScript.new(); threat_compass.name = "ThreatCompass"; threat_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER); threat_compass.position = Vector2(-70, -70); threat_compass_frame.add_child(threat_compass)

func _build_night_controls() -> void:
	combat_hand_panel = _panel("NightHandPanel", phase_action_tray, Vector4(0, 0, 1, 1), Vector4(0, 0, 0, 0), _ornate_panel(Color("050a12f4"), Color("8e713d"), 2, 4)); var legacy_hand := Control.new(); legacy_hand.name = "CombatHandPanel"; legacy_hand.position = Vector2(0, 500); legacy_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE; combat_hand_panel.add_child(legacy_hand); combat_hand_row = Control.new(); combat_hand_row.name = "CombatHandRow"; combat_hand_panel.add_child(combat_hand_row)
	sunburst_button = _button("爆闪", Vector2.ZERO); sunburst_button.name = "SunburstButton"; sunburst_button.icon = ArtLibrary.load_texture(ArtLibrary.UI_ICON_SUNBURST); sunburst_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); sunburst_button.add_theme_font_size_override("font_size", 17); sunburst_button.add_theme_constant_override("icon_max_width", 36); sunburst_button.add_theme_constant_override("icon_separation", 5); sunburst_button.pressed.connect(func(): sunburst_requested.emit()); primary_action_button.add_child(sunburst_button)
	var cost_overlay := Control.new(); cost_overlay.name = "CostOverlay"; cost_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; primary_action_button.add_child(cost_overlay)
	sunburst_cost_label = _label("☀ %d" % Balance.SUNBURST_COST, 14); sunburst_cost_label.name = "SunburstCostLabel"; sunburst_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; sunburst_cost_label.anchor_left = 0; sunburst_cost_label.anchor_top = 1; sunburst_cost_label.anchor_right = 1; sunburst_cost_label.anchor_bottom = 1; sunburst_cost_label.offset_left = 16; sunburst_cost_label.offset_top = -34; sunburst_cost_label.offset_right = -16; sunburst_cost_label.offset_bottom = -14; sunburst_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sunburst_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; cost_overlay.add_child(sunburst_cost_label)

func _build_modal_layers() -> void:
	mother_choice_overlay = ColorRect.new()
	mother_choice_overlay.name = "MotherChoiceOverlay"
	mother_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mother_choice_overlay.color = Color(0.015, 0.02, 0.025, 0.78)
	mother_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	mother_choice_overlay.visible = false
	_root.add_child(mother_choice_overlay)
	var choice_spacing := StyleBoxEmpty.new()
	choice_spacing.set_content_margin_all(10)
	mother_choice_panel = _panel("MotherChoicePanel", mother_choice_overlay, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-452, -278, 452, 278), choice_spacing)
	var choice_box := VBoxContainer.new()
	choice_box.name = "MotherChoiceBox"
	choice_box.add_theme_constant_override("separation", 12)
	mother_choice_panel.add_child(choice_box)
	var choice_title := _label("选择今日的母花强化", 28)
	choice_title.name = "MotherChoiceTitle"
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box.add_child(choice_title)
	var choice_note := _label("三选一 · 强化立即生效 · 母花获得新的形态", 14, Color("b8bba4"))
	choice_note.name = "MotherChoiceNote"
	choice_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_box.add_child(choice_note)
	mother_choice_row = HBoxContainer.new()
	mother_choice_row.name = "MotherChoiceRow"
	mother_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mother_choice_row.add_theme_constant_override("separation", 18)
	choice_box.add_child(mother_choice_row)
	var result_panel := _panel("ResultPanel", _root, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-230, -112, 230, 112), _texture_style(ArtLibrary.UI_PANEL_RESULT, 140, 42, 140, 42, 24)); result_panel.visible = false; var result_box := VBoxContainer.new(); result_box.alignment = BoxContainer.ALIGNMENT_CENTER; result_panel.add_child(result_box); var result_label := _label("", 32); result_label.name = "ResultLabel"; result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result_box.add_child(result_label); result_box.add_child(_label("最后的光仍在等待下一次守护", 16)); restart_button = _button("[R] 重新开始", Vector2(210, 56)); restart_button.pressed.connect(func(): restart_requested.emit()); result_box.add_child(restart_button)

func set_phase_layout(phase_name: String) -> void:
	_phase = phase_name
	var is_day := phase_name == "day"
	day_action_panel.visible = is_day; day_selection_panel.visible = is_day; wave_button.visible = is_day
	combat_hand_panel.visible = phase_name == "night"; sunburst_button.visible = phase_name == "night"
	sunburst_cost_label.visible = phase_name == "night"; threat_compass_frame.visible = phase_name == "night"
	if hand_tabs != null: hand_tabs.visible = false
	if plant_loadout_button != null: plant_loadout_button.visible = is_day
	if not is_day: hide_plant_loadout()
	var shortcut := _root.find_child("PrimaryShortcut", true, false) as Label
	if shortcut != null: shortcut.text = "ENTER  /  入夜" if is_day else "SPACE  /  施放"

func update_battle_state(state: Dictionary) -> void:
	var phase_name := str(state.get("phase", _phase)); set_phase_layout(phase_name); var health := float(state.get("health", health_bar.value)); var max_health := float(state.get("max_health", health_bar.max_value)); health_bar.max_value = max_health; health_bar.value = health; mother_health_value.text = "%d / %d" % [roundi(health), roundi(max_health)]; var energy := int(state.get("energy", 0)); var seeds := int(state.get("seeds", 0)); energy_value.text = "☀  光能 %d" % energy; seed_label.text = "❧  种子 %d" % seeds; var night := int(state.get("night", 0)); var night_total := int(state.get("night_total", 7))
	if phase_name == "day": phase_label.text = "第%d夜  白昼" % maxi(1, night + 1); wave_label.text = "准备防线"; timer_label.visible = true; var time_left := int(state.get("time_left", 0)); timer_label.text = "☀  %02d:%02d" % [time_left / 60, time_left % 60]; enemy_count_label.text = ""
	else: phase_label.text = "第%d夜  夜战" % night; var batch_current := int(state.get("batch_current", 0)); var batch_total := int(state.get("batch_total", 0)); wave_label.text = "守夜 %d / %d" % [night, night_total] + ("  ·  第%d波" % (batch_current + 1) if batch_total > 0 else ""); timer_label.visible = false; enemy_count_label.text = "剩余敌人 %d" % int(state.get("remaining_enemies", 0))
	var cost := int(state.get("sunburst_cost", Balance.SUNBURST_COST)); var lacks_energy := energy < cost; sunburst_cost_label.text = "☀ %d" % cost; sunburst_cost_label.add_theme_color_override("font_color", Color("7c2f35") if lacks_energy else Color("f6e4ad")); sunburst_button.disabled = lacks_energy; light_sprout_button.text = ""; if threat_compass != null: threat_compass.set_boss_active(bool(state.get("boss_active", false)))
	(light_sprout_button.get_node("CostValue") as Label).text = str(state.get("light_sprout_cost", Balance.DAY_LIGHT_SPROUT_COST))
	

func update_status(health: float, energy: int, wave: int, phase_text: String, time_left: float, seeds: int) -> void:
	update_battle_state({"phase":"day" if phase_text.begins_with("白昼") else "night", "health":health, "max_health":Balance.MOTHER_MAX_HEALTH, "energy":energy, "night":wave, "night_total":7, "time_left":time_left, "seeds":seeds, "sunburst_cost":Balance.SUNBURST_COST})

func update_network_radar(nodes: Array, lines: Array) -> void:
	if radar != null: radar.update_snapshot(nodes, lines, PackedFloat32Array([0,0,0,0,0,0,0,0]))

func update_threat_compass(threats: PackedFloat32Array, boss_direction := -1) -> void:
	var has_threat := false
	for index in range(mini(8, threats.size())):
		if threats[index] > 0.01:
			has_threat = true
			break
	_set_tactical_emphasis(has_threat or boss_direction >= 0)
	if threat_compass != null: threat_compass.update_threats(threats, boss_direction)

func _set_tactical_emphasis(active: bool) -> void:
	if tactical_instrument_frame != null:
		tactical_instrument_frame.modulate.a = 1.0 if active else 0.38

func update_radar(nodes: Array, lines: Array, threats: PackedFloat32Array) -> void:
	update_network_radar(nodes, lines); update_threat_compass(threats)

func show_mother_choices(choice_ids: Array[String]) -> void:
	if choice_ids.is_empty():
		hide_mother_choices()
		return
	var signature := ",".join(choice_ids)
	if signature == _mother_choice_signature and mother_choice_overlay.visible:
		return
	_mother_choice_signature = signature
	for child in mother_choice_row.get_children():
		child.free()
	var title := mother_choice_panel.find_child("MotherChoiceTitle", true, false) as Label
	title.text = "选择母花的进化方向" if not ContentData.get_mother_path(choice_ids[0]).is_empty() else "选择今日的母花强化"
	for card_id in choice_ids:
		var button := preload("res://scripts/mother_upgrade_choice_card.gd").new()
		button.configure(card_id)
		button.pressed.connect(func():
			mother_card_requested.emit(card_id)
		)
		mother_choice_row.add_child(button)
	mother_choice_overlay.visible = true
	mother_choice_overlay.move_to_front()

func hide_mother_choices() -> void:
	mother_choice_overlay.visible = false
	_mother_choice_signature = ""

func _mother_path_description(card_id: String) -> String:
	match card_id:
		"sun_arrow": return "攻击进化\n日种 · 花冠 · 爆闪"
		"root_heart": return "生存进化\n花托 · 树液 · 反击根"
		"dawn_pulse": return "脉冲进化\n蓄能 · 镇夜 · 晨星"
		_: return "选择母花进化方向"

func _mother_branch_name(branch: String) -> String:
	var names := {
		"sunseed":"日种", "corona":"花冠", "sunburst":"爆闪",
		"receptacle":"花托", "sap":"树液", "counterroot":"反击根",
		"charge":"蓄能", "quelling":"镇夜", "morningstar":"晨星",
	}
	return str(names.get(branch, branch))

func _setup_collectible_hand() -> void:
	var surface := preload("res://scripts/battle_card_drop_surface.gd").new()
	surface.name = "WorldDropSurface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.card_dropped.connect(_on_card_drop)
	_root.add_child(surface)
	_root.move_child(surface, 0)
	phase_action_tray.offset_top = -170
	phase_action_tray.offset_bottom = 48
	phase_action_tray.offset_left = -355.5; phase_action_tray.offset_right = 355.5
	phase_action_tray.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	combat_hand_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	combat_hand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_action_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_action_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	day_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plant_loadout_button = _button("调整植物卡", Vector2(150,30))
	plant_loadout_button.name = "PlantLoadoutButton"
	plant_loadout_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	plant_loadout_button.offset_left = -75; plant_loadout_button.offset_right = 75
	plant_loadout_button.offset_top = -210; plant_loadout_button.offset_bottom = -180
	plant_loadout_button.add_theme_font_size_override("font_size",14)
	plant_loadout_button.pressed.connect(func():
		if _phase == "day" and not _card_drag_active: plant_loadout_requested.emit()
	)
	_root.add_child(plant_loadout_button)
	plant_loadout_overlay = preload("res://scripts/plant_loadout_overlay.gd").new()
	plant_loadout_overlay.name = "PlantLoadoutOverlay"
	plant_loadout_overlay.confirmed.connect(func(ids: Array[String]): hide_plant_loadout(); plant_loadout_confirmed.emit(ids))
	plant_loadout_overlay.cancelled.connect(func(): hide_plant_loadout(); plant_loadout_cancelled.emit())
	_root.add_child(plant_loadout_overlay)
	var palette := preload("res://scripts/battle_palette.gd")
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = ArtLibrary.load_texture("res://assets/ui/generated/battle_ui_v5/primary_action_%s.png" % state)
		style.texture_margin_left = 28; style.texture_margin_right = 28
		style.texture_margin_top = 26; style.texture_margin_bottom = 26
		wave_button.add_theme_stylebox_override(state,style)
		sunburst_button.add_theme_stylebox_override(state,style)
	var bezel := _root.find_child("TacticalBezelArt",true,false) as TextureRect
	if bezel != null: bezel.texture = ArtLibrary.load_texture("res://assets/ui/generated/battle_ui_v5/tactical_bezel.png")
	for name in ["MotherStatusPanel", "PhaseBanner", "ResourcePanel"]:
		(_root.find_child(name,true,false) as PanelContainer).add_theme_stylebox_override("panel",palette.surface_style())
	selection_detail_panel.offset_top = -350; selection_detail_panel.offset_bottom = -246
	var old_row := day_action_panel.get_child(0)
	day_action_panel.remove_child(old_row); old_row.queue_free()
	var row := Control.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_action_panel.add_child(row)
	_deployment_row = row
	for child in row.get_children(): row.remove_child(child); child.queue_free()
	var roster := preload("res://scripts/plant_roster.gd")
	var specifications := [["光脉芽",ArtLibrary.NODE_HEALTHY,"建立光脉节点，扩大供光范围。",str(Balance.DAY_LIGHT_SPROUT_COST)]]
	var deploy_ids := ["deploy_light"]
	for i in range(roster.DEPLOY_IDS.size()):
		var flower := preload("res://scripts/content_data.gd").get_flower(roster.FLOWER_IDS[i])
		specifications.append([flower.name,roster.texture_path(i),roster.DESCRIPTIONS[i],str(flower.seed_cost)])
		deploy_ids.append(roster.DEPLOY_IDS[i])
	specifications.append(["修复",ArtLibrary.UI_ICON_REPAIR,"修复受损光脉，恢复%d生命。" % Balance.REPAIR_AMOUNT,str(Balance.REPAIR_COST)])
	deploy_ids.append("deploy_repair")
	var cards: Array[Button] = []
	for index in range(specifications.size()):
		var item = specifications[index]
		var card := preload("res://scripts/battle_hand_card.gd").new()
		card.configure(deploy_ids[index],ArtLibrary.load_texture(item[1]),item[0],item[2],item[3])
		card.card_drag_started.connect(_on_card_drag_started)
		card.card_drag_finished.connect(_on_card_drag_finished)
		row.add_child(card); card.set_rest_transform(Vector2(index*145+49,absf(index-1.5)*10),0.105*(index-1.5)); cards.append(card)
	light_sprout_button = cards[0]; thorn_button = cards[1]; prism_button = cards[2]; repair_button = cards[cards.size()-1]
	for i in range(3,cards.size()-1):
		var id: String = cards[i].card_id
		cards[i].pressed.connect(func(): deployment_card_requested.emit(id))
	set_plant_loadout(_plant_loadout.duplicate())
	light_sprout_button.pressed.connect(func(): light_sprout_requested.emit())
	thorn_button.pressed.connect(func(): thorn_requested.emit())
	prism_button.pressed.connect(func(): prism_requested.emit())
	repair_button.pressed.connect(func(): show_message("点击受损光脉节点进行修复"))

func is_card_drag_active() -> bool:
	return _card_drag_active

func _on_card_drag_started(id: String) -> void:
	_card_drag_active = true; _card_drag_cancelled = false; _drag_card_id = id
	(_root.get_node("WorldDropSurface") as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	combat_card_drag_started.emit(id)

func _on_card_drop(id: String, point: Vector2) -> void:
	if _card_drag_active and not _card_drag_cancelled and id == _drag_card_id and not is_point_over_battle_ui(point):
		combat_card_dropped.emit(id,point)

func is_point_over_battle_ui(point: Vector2) -> bool:
	for name in ["MotherStatusPanel","PhaseBanner","ResourcePanel","PhaseActionTray","HandTabs","PrimaryActionButton","TacticalInstrumentFrame","SelectionDetailPanel","NotificationBanner","MotherChoiceOverlay","PlantLoadoutOverlay","PlantLoadoutButton","ResultPanel"]:
		var control := _root.find_child(name,true,false) as Control
		if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false

func _on_card_drag_finished() -> void:
	_card_drag_active = false; _drag_card_id = ""
	(_root.get_node("WorldDropSurface") as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_card_drag_finished.emit()
	if not _pending_hand.is_empty():
		var args := _pending_hand; _pending_hand = []
		show_combat_hand(args[0],args[1],args[2],args[3],args[4])

func show_combat_hand(card_ids: Array[String], phase_name: String, energy: int, allow_mulligan: bool, selected_card: String = "") -> void:
	if _card_drag_active:
		_pending_hand = [card_ids.duplicate(),phase_name,energy,allow_mulligan,selected_card]
		return
	if _hand_ids != card_ids:
		for child in combat_hand_row.get_children():
			combat_hand_row.remove_child(child); child.queue_free()
		_hand_ids = card_ids.duplicate()
		for id in card_ids:
			var card := ContentData.get_card(id)
			var view := preload("res://scripts/battle_hand_card.gd").new()
			view.configure(id,ArtLibrary.load_texture(_combat_specimen_path(id)),str(card.get("name",id)),preload("res://scripts/battle_card_presentation.gd").describe(id),str(card.get("energy_cost",0)))
			view.pressed.connect(func():
				if not _card_drag_active: combat_card_requested.emit(id)
			)
			view.card_drag_started.connect(_on_card_drag_started)
			view.card_drag_finished.connect(_on_card_drag_finished)
			combat_hand_row.add_child(view)
	var width := maxf(711.0,minf(750.0,float(card_ids.size())*178.0))
	phase_action_tray.offset_left = -width*0.5; phase_action_tray.offset_right = width*0.5
	combat_hand_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(combat_hand_row.get_child_count()):
		var view := combat_hand_row.get_child(i) as Button
		var card := ContentData.get_card(card_ids[i])
		view.disabled = energy < int(card.get("energy_cost",0)) or str(card.get("phase","any")) not in ["any",phase_name]
		view.button_pressed = card_ids[i] == selected_card
		var middle := (card_ids.size()-1)*0.5
		var step := minf(145.0,(width-177.0)/maxf(1,card_ids.size()-1))
		view.set_rest_transform(Vector2((width-177.0)*0.5+(i-middle)*step,absf(i-middle)*10.0),clampf(0.105*(i-middle),-0.22,0.22))

func show_message(text: String) -> void:
	message_label.text = text; notification_banner.visible = not text.is_empty(); _message_time_left = 2.5

func show_spawn_alert(enemy_name: String) -> void:
	if enemy_alert_panel == null: return
	enemy_alert_label.text = "%s · 来袭" % enemy_name
	enemy_alert_panel.visible = true
	_enemy_alert_time_left = 1.8

func get_message_time_left() -> float:
	return _message_time_left

func show_selection_detail(title: String, detail: String) -> void:
	selection_title_label.text = title
	selection_detail_label.text = detail
	selection_detail_panel.visible = true

func hide_selection_detail() -> void:
	selection_detail_panel.visible = false

func show_result(victory: bool) -> void:
	var panel := _root.find_child("ResultPanel", true, false) as Control; panel.visible = true; var label := panel.find_child("ResultLabel", true, false) as Label; label.text = "黎明降临" if victory else "太阳熄灭"

func hide_result() -> void:
	var panel := _root.find_child("ResultPanel", true, false) as Control; if panel != null: panel.visible = false


func set_plant_loadout(ids: Array[String]) -> void:
	if _plant_loadout_layout_applied and ids == _plant_loadout: return
	_plant_loadout = ids.duplicate()
	if _deployment_row == null: return
	_plant_loadout_layout_applied = true
	var cards: Array[Control] = []
	for card in _deployment_row.get_children():
		card.visible = card.card_id in ["deploy_light","deploy_repair"] or ids.has(card.card_id)
		if card.visible: cards.append(card)
	var width := 711.0
	var step := minf(145.0,(width-177.0)/maxf(1,cards.size()-1))
	for i in range(cards.size()):
		var middle := (cards.size()-1)*0.5
		cards[i].set_rest_transform(Vector2((width-177.0)*0.5+(i-middle)*step,absf(i-middle)*10),clampf(0.105*(i-middle),-0.22,0.22))

func show_plant_loadout(ids: Array[String]) -> void:
	if _phase != "day" or _card_drag_active: return
	plant_loadout_overlay.open(ids); plant_loadout_overlay.move_to_front()

func hide_plant_loadout() -> void:
	if plant_loadout_overlay != null: plant_loadout_overlay.hide()

func is_plant_loadout_open() -> bool:
	return plant_loadout_overlay != null and plant_loadout_overlay.visible

