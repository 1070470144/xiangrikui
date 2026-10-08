extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	var script := ResourceLoader.load("res://scripts/art_manifest.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		failures.append("art manifest loader must compile")
		return failures
	var root := Control.new()
	root.name = "Fixture"
	var image := TextureRect.new()
	image.name = "Image"
	root.add_child(image)
	var action := Button.new()
	action.name = "Action"
	root.add_child(action)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	root.add_child(panel)
	var safe_panel := PanelContainer.new()
	safe_panel.name = "SafePanel"
	root.add_child(safe_panel)
	var warnings: Array[String] = script.apply_file("res://tests/fixtures/art_manifest/runtime.json", root)
	expect(image.texture != null, "manifest must bind a direct texture")
	expect(action.text == "Manifest text", "manifest must bind program-rendered text")
	expect(action.get_theme_font_size("font_size") == 19, "manifest must bind text font size")
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	expect(panel_style != null, "manifest must bind a single nine-patch style texture")
	if panel_style != null:
		expect(panel_style.texture_margin_left == 11 and panel_style.texture_margin_top == 12 and panel_style.texture_margin_right == 13 and panel_style.texture_margin_bottom == 14, "single nine-patch must apply texture margins")
		expect(panel_style.content_margin_left == 0 and panel_style.content_margin_top == 0 and panel_style.content_margin_right == 0 and panel_style.content_margin_bottom == 0, "nine-patch content margins must remain backward compatible by default")
	var safe_panel_style := safe_panel.get_theme_stylebox("panel") as StyleBoxTexture
	expect(safe_panel_style != null, "manifest must bind an opted-in safe panel style")
	if safe_panel_style != null:
		expect(safe_panel_style.content_margin_left == 11 and safe_panel_style.content_margin_top == 12 and safe_panel_style.content_margin_right == 13 and safe_panel_style.content_margin_bottom == 14, "opted-in nine-patch must preserve manifest content safe margins")
	expect(warnings.size() == 1 and "Missing" in warnings[0], "missing nodes must warn without blocking other bindings")
	root.free()
	var unsupported_root := Control.new()
	var unsupported: Array[String] = script.apply_data({"schema_version": 99, "assets": []}, unsupported_root)
	expect(unsupported.size() == 1 and "version" in unsupported[0], "unsupported manifest versions must be rejected safely")
	unsupported_root.free()
	return failures
