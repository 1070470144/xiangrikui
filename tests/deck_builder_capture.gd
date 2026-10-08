extends SceneTree

const MANIFEST_PATH := "res://art_source/manifests/deck_builder.json"

func _initialize() -> void:
	var scene := load("res://scenes/deck_builder.tscn") as PackedScene
	var page := scene.instantiate()
	root.add_child(page)
	page.setup({
		"meta_seeds": 40,
		"unlocked_cards": ["card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud"],
		"selected_deck": ["card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud", "card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud"]
	})
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--detail="): page.show_card_detail(argument.trim_prefix("--detail="))
	await process_frame
	await process_frame
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scroll="):
			page.get_node("Root/MainSplit/LibraryPanel/Library/CardScroll").scroll_vertical = int(argument.trim_prefix("--scroll="))
	await process_frame
	if "--back" in OS.get_cmdline_user_args():
		page.find_child("CardStage", true, false).flip()
		await create_timer(0.5).timeout
	var cards := page.find_children("", "DeckCardView", true, false)
	for index in mini(4, cards.size()):
		print("CARD_RECT_%d=" % index, (cards[index] as Control).get_global_rect())
	for node_path in ["Root/MainSplit/LibraryPanel", "Root/MainSplit/Sidebar/DeckScroll", "Root/BottomBar/SaveButton"]:
		print(node_path, "=", (page.get_node(node_path) as Control).get_global_rect())
	var evidence_path := _runtime_evidence_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture=res://tmp/"): evidence_path = argument.trim_prefix("--capture=")
	if evidence_path.is_empty():
		push_error("deck builder manifest must declare a runtime_screenshot evidence path")
		quit(1)
		return
	var absolute_path := ProjectSettings.globalize_path(evidence_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		push_error("failed to create deck builder evidence directory: %s" % error_string(directory_error))
		quit(1)
		return
	var save_error := root.get_viewport().get_texture().get_image().save_png(evidence_path)
	if save_error != OK:
		push_error("failed to save deck builder evidence: %s" % error_string(save_error))
		quit(1)
		return
	print("CAPTURE_PATH=", evidence_path)
	quit(0)

func _runtime_evidence_path() -> String:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return ""
	var manifest: Variant = JSON.parse_string(file.get_as_text())
	if not manifest is Dictionary:
		return ""
	var style: Dictionary = (manifest as Dictionary).get("style", {})
	for value: Variant in style.get("evidence", []):
		if value is Dictionary:
			var evidence := value as Dictionary
			if str(evidence.get("kind", "")) == "runtime_screenshot":
				var source := str(evidence.get("source", ""))
				if source.begins_with("res://"):
					return source
	return ""
