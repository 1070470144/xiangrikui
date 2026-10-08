class_name ArtManifest
extends RefCounted

const SUPPORTED_VERSION := 1

static func apply_file(path: String, scene_root: Node) -> Array[String]:
	var warnings: Array[String] = []
	if not FileAccess.file_exists(path):
		warnings.append("manifest file missing: %s" % path)
		return warnings
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		warnings.append("manifest file cannot be opened: %s" % path)
		return warnings
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		warnings.append("manifest JSON root must be an object: %s" % path)
		return warnings
	return apply_data(parsed as Dictionary, scene_root)

static func apply_data(manifest: Dictionary, scene_root: Node) -> Array[String]:
	var warnings: Array[String] = []
	if int(manifest.get("schema_version", -1)) != SUPPORTED_VERSION:
		warnings.append("unsupported manifest version: %s" % manifest.get("schema_version", "missing"))
		return warnings
	for value: Variant in manifest.get("assets", []):
		if not value is Dictionary:
			warnings.append("manifest asset must be an object")
			continue
		_apply_asset(value as Dictionary, scene_root, warnings)
	return warnings

static func _apply_asset(asset: Dictionary, scene_root: Node, warnings: Array[String]) -> void:
	var asset_id := str(asset.get("id", "unknown"))
	var generation: Dictionary = asset.get("generation", {})
	var output: Dictionary = asset.get("output", {})
	var runtime: Dictionary = asset.get("runtime", {})
	for binding_value: Variant in asset.get("bindings", []):
		if not binding_value is Dictionary:
			warnings.append("asset %s has an invalid binding" % asset_id)
			continue
		var binding := binding_value as Dictionary
		var scope := str(binding.get("scope", "scene"))
		if scope == "component":
			continue
		if scope != "scene":
			warnings.append("asset %s binding has unsupported scope: %s" % [asset_id, scope])
			continue
		var node_path := str(binding.get("node", ""))
		var target := scene_root.get_node_or_null(NodePath(node_path))
		if target == null:
			warnings.append("asset %s node missing: %s" % [asset_id, node_path])
			continue
		if not bool(generation.get("enabled", false)):
			_apply_runtime(asset_id, target, binding, runtime, warnings)
		elif binding.has("property_map"):
			_apply_state_textures(asset_id, target, binding, asset, warnings)
		else:
			_apply_texture(asset_id, target, binding, runtime if not runtime.is_empty() else output, warnings)

static func _apply_runtime(asset_id: String, target: Node, binding: Dictionary, runtime: Dictionary, warnings: Array[String]) -> void:
	var property_name := str(binding.get("property", ""))
	if property_name.is_empty() or not _has_property(target, property_name):
		warnings.append("asset %s incompatible runtime property: %s" % [asset_id, property_name])
		return
	if runtime.has(property_name):
		target.set(property_name, runtime[property_name])
	elif property_name == "text" and runtime.has("text"):
		target.set("text", runtime["text"])
	if target is Control:
		var control := target as Control
		if runtime.has("font_size"):
			control.add_theme_font_size_override("font_size", int(runtime["font_size"]))
		if runtime.has("color"):
			control.add_theme_color_override("font_color", Color.from_string(str(runtime["color"]), Color.WHITE))

static func _apply_texture(asset_id: String, target: Node, binding: Dictionary, output: Dictionary, warnings: Array[String]) -> void:
	var path := str(output.get("path", ""))
	path = _runtime_texture_path(path)
	var property_name := str(binding.get("property", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		warnings.append("asset %s texture missing: %s" % [asset_id, path])
		return
	var texture := load(path) as Texture2D
	if texture == null:
		warnings.append("asset %s failed to load texture: %s" % [asset_id, path])
		return
	if property_name.begins_with("theme_override_styles/") and target is Control:
		var style_name := property_name.get_slice("/", 1)
		var style := StyleBoxTexture.new()
		style.texture = texture
		if str(output.get("mode", "")) == "nine_patch":
			var margins: Array = output.get("patch_margin", [0, 0, 0, 0])
			if margins.size() == 4:
				_apply_nine_patch_margins(style, margins, [])
		var content_margins: Array = output.get("content_margin", [])
		if content_margins.size() == 4:
			style.set_content_margin(SIDE_LEFT, float(content_margins[0]))
			style.set_content_margin(SIDE_TOP, float(content_margins[1]))
			style.set_content_margin(SIDE_RIGHT, float(content_margins[2]))
			style.set_content_margin(SIDE_BOTTOM, float(content_margins[3]))
		(target as Control).add_theme_stylebox_override(style_name, style)
		return
	if not _has_property(target, property_name):
		warnings.append("asset %s incompatible texture property: %s" % [asset_id, property_name])
		return
	target.set(property_name, texture)

static func _apply_state_textures(asset_id: String, target: Node, binding: Dictionary, asset: Dictionary, warnings: Array[String]) -> void:
	if not target is Control:
		warnings.append("asset %s state target must be Control" % asset_id)
		return
	var output: Dictionary = asset.get("runtime", asset.get("output", {}))
	var pattern := str(output.get("path_pattern", ""))
	var margins: Array = output.get("patch_margin", [0, 0, 0, 0])
	for state_value: Variant in asset.get("states", []):
		var state := str(state_value)
		var path := _runtime_texture_path(pattern.replace("{state}", state))
		if not ResourceLoader.exists(path):
			warnings.append("asset %s texture missing: %s" % [asset_id, path])
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			warnings.append("asset %s failed to load texture: %s" % [asset_id, path])
			continue
		var style := StyleBoxTexture.new()
		style.texture = texture
		if margins.size() == 4:
			_apply_nine_patch_margins(style, margins, output.get("content_margin", [0, 0, 0, 0]))
		(target as Control).add_theme_stylebox_override(state, style)

static func _apply_nine_patch_margins(style: StyleBoxTexture, margins: Array, content_margins: Array) -> void:
	style.texture_margin_left = float(margins[0])
	style.texture_margin_top = float(margins[1])
	style.texture_margin_right = float(margins[2])
	style.texture_margin_bottom = float(margins[3])
	if content_margins.size() == 4:
		style.set_content_margin(SIDE_LEFT, float(content_margins[0]))
		style.set_content_margin(SIDE_TOP, float(content_margins[1]))
		style.set_content_margin(SIDE_RIGHT, float(content_margins[2]))
		style.set_content_margin(SIDE_BOTTOM, float(content_margins[3]))

static func _runtime_texture_path(path: String) -> String:
	const SOURCE_PREFIX := "res://art_source/generated/mm_tools/"
	const RUNTIME_PREFIX := "res://assets/ui/generated/"
	return RUNTIME_PREFIX + path.trim_prefix(SOURCE_PREFIX) if path.begins_with(SOURCE_PREFIX) else path

static func _has_property(target: Object, property_name: String) -> bool:
	for info: Dictionary in target.get_property_list():
		if str(info.get("name", "")) == property_name:
			return true
	return false
