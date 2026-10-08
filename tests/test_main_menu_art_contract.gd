extends SceneTree

func _initialize() -> void:
	call_deferred("verify_contract")

func verify_contract() -> void:
	var menu_script := load("res://scripts/main_menu.gd") as Script
	var menu := menu_script.new() as Control
	root.add_child(menu)
	menu.call("_show_home")
	var primary := menu.find_child("PrimaryStartButton", true, false) as Button
	if primary == null or primary.custom_minimum_size != Vector2(290, 64):
		push_error("primary menu button must preserve the approved 290x64 ratio")
		quit(1)
		return
	for node_name in ["DeckBuilderButton", "NightRecordsButton", "CodexButton", "SettingsButton"]:
		var secondary := menu.find_child(node_name, true, false) as Button
		if secondary == null or secondary.custom_minimum_size != Vector2(290, 52):
			push_error("%s must preserve the approved 290x52 ratio" % node_name)
			quit(1)
			return
	if not primary.get_theme_stylebox("normal") is StyleBoxTexture:
		push_error("primary menu button must receive its v2 texture binding")
		quit(1)
		return
	var journal := menu.find_child("MenuJournal", true, false) as PanelContainer
	if journal == null or not journal.get_theme_stylebox("panel") is StyleBoxTexture:
		push_error("menu journal must receive its v2 texture binding")
		quit(1)
		return
	var account_entry := menu.find_child("AccountEntry", true, false) as Button
	if account_entry == null or not account_entry.get_theme_stylebox("normal") is StyleBoxTexture:
		push_error("account entry must receive its v2 texture binding")
		quit(1)
		return
	menu.free()
	var file := FileAccess.open("res://art_source/manifests/main_menu.json", FileAccess.READ)
	if file == null:
		push_error("main menu manifest must exist")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	var assets_by_id := {}
	for asset: Dictionary in manifest.get("assets", []):
		assets_by_id[str(asset.get("id", ""))] = asset
	for asset_id in ["greenhouse_primary_states", "greenhouse_secondary_states"]:
		var output: Dictionary = assets_by_id.get(asset_id, {}).get("output", {})
		var patch_margin: Array = output.get("patch_margin", [])
		if patch_margin.size() != 4 or patch_margin.any(func(value: Variant): return float(value) != 0.0):
			push_error("%s must scale as one complete button image" % asset_id)
			quit(1)
			return
	var panel: Dictionary = assets_by_id.get("greenhouse_record_panel", {})
	if panel.get("bindings", []).size() != 1 or not str(panel.get("output", {}).get("path", "")).ends_with("_v2.png"):
		push_error("menu journal must bind the v2 greenhouse panel")
		quit(1)
		return
	var account: Dictionary = assets_by_id.get("greenhouse_account_plate", {})
	var account_margins: Array = account.get("output", {}).get("content_margin", [])
	var account_margin_values := [56.0, 7.0, 14.0, 7.0]
	var account_margins_valid := account_margins.size() == 4
	for index in account_margins.size():
		account_margins_valid = account_margins_valid and float(account_margins[index]) == account_margin_values[index]
	if account.get("bindings", []).size() != 3 or not account_margins_valid:
		push_error("account entry must bind the designed v2 plate in all interactive states")
		quit(1)
		return
	var expected_sizes := {
		"res://assets/ui/generated/mm_greenhouse_primary_v2_normal.png": Vector2i(580, 128),
		"res://assets/ui/generated/mm_greenhouse_primary_v2_hover.png": Vector2i(580, 128),
		"res://assets/ui/generated/mm_greenhouse_primary_v2_pressed.png": Vector2i(580, 128),
		"res://assets/ui/generated/mm_greenhouse_primary_v2_disabled.png": Vector2i(580, 128),
		"res://assets/ui/generated/mm_greenhouse_secondary_v2_normal.png": Vector2i(580, 104),
		"res://assets/ui/generated/mm_greenhouse_secondary_v2_hover.png": Vector2i(580, 104),
		"res://assets/ui/generated/mm_greenhouse_secondary_v2_pressed.png": Vector2i(580, 104),
		"res://assets/ui/generated/mm_greenhouse_secondary_v2_disabled.png": Vector2i(580, 104),
		"res://assets/ui/generated/mm_greenhouse_record_panel_v2.png": Vector2i(692, 1012),
		"res://assets/ui/generated/mm_greenhouse_account_plate_v2.png": Vector2i(556, 116),
	}
	for path: String in expected_sizes:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.get_size() != expected_sizes[path] or image.get_format() not in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH]:
			push_error("invalid v2 menu art: %s" % path)
			quit(1)
			return
	print("MAIN MENU ART CONTRACT PASSED")
	quit(0)
