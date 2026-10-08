extends RefCounted

const ArtManifest = preload("res://scripts/art_manifest.gd")
const ART_MANIFEST_PATH := "res://art_source/manifests/deck_builder.json"

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	var art_paths: Array[String] = []
	for card in preload("res://scripts/content_data.gd").COMBAT_CARDS:
		var path: String = preload("res://scripts/deck_builder_style.gd").art_path(str(card.id))
		expect("illustrations_v3" in path and ResourceLoader.exists(path), "every card must load its own illustration: %s" % card.id)
		expect(not art_paths.has(path), "card illustrations must be unique: %s" % card.id)
		art_paths.append(path)
	for path in ["res://scripts/deck_card_view.gd", "res://scripts/deck_list_item.gd"]:
		var script := load(path) as Script
		expect(script != null and script.can_instantiate(), "%s must compile" % path)
	var scene := load("res://scenes/deck_builder.tscn") as PackedScene
	expect(scene != null, "deck builder scene must load")
	if scene != null:
		var page := scene.instantiate()
		var library_panel := page.get_node_or_null("Root/MainSplit/LibraryPanel") as PanelContainer
		var sidebar := page.get_node_or_null("Root/MainSplit/Sidebar") as Control
		var tools := page.get_node_or_null("Root/MainSplit/LibraryPanel/Library/Tools") as HBoxContainer
		var card_grid := page.get_node_or_null("Root/MainSplit/LibraryPanel/Library/CardScroll/CardGrid") as GridContainer
		expect(library_panel != null, "deck builder must wrap the library in LibraryPanel")
		expect(tools != null and tools.custom_minimum_size.y == 36.0, "deck builder tools row must stay 36px tall")
		if card_grid != null:
			expect(card_grid.columns == 4, "deck builder card grid must use four columns")
			expect(card_grid.get_theme_constant("h_separation") >= 8, "deck builder card grid must keep at least 8px horizontal spacing")
		else:
			expect(false, "deck builder must expose CardGrid under LibraryPanel/Library/CardScroll")
		expect(sidebar != null and sidebar.custom_minimum_size.x >= 350.0, "deck builder sidebar must stay at least 350px wide")
		expect(page != null and page.has_method("setup"), "deck builder scene controller must instantiate")
		page.setup({"meta_seeds":40, "unlocked_cards":["card_sun_pierce", "card_root_snare"], "selected_deck":[]})
		expect(page.has_method("select_card") and page.has_method("request_add") and page.has_method("request_remove"), "deck builder must expose interaction methods")
		page.select_card("card_sun_pierce")
		page.request_add("card_sun_pierce")
		expect(page.get_model().draft == ["card_sun_pierce"], "adding a card must update the draft")
		page.request_remove("card_sun_pierce")
		expect(page.get_model().draft.is_empty(), "removing a card must update the draft")
		page.free()
		_test_remove_button_does_not_synchronously_free_sender(scene)
		_test_locked_card_unlock_confirmation(scene)
		_test_player_facing_text_is_chinese(scene)
		_test_card_rows_align_for_locked_and_unlocked_cards()
		_test_generated_button_keeps_usable_width(scene)
		await _test_runtime_manifest_contract(scene)
	return failures

func _test_runtime_manifest_contract(scene: PackedScene) -> void:
	var page := scene.instantiate()
	page.setup({"meta_seeds":40, "unlocked_cards":["card_sun_pierce", "card_root_snare"], "selected_deck":[]})
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(page)
	await tree.process_frame
	var warnings := ArtManifest.apply_file(ART_MANIFEST_PATH, page)
	expect(not warnings.any(func(warning: String): return "node missing" in warning), "deck builder runtime manifest must not report missing static nodes: %s" % [warnings])
	var library_panel := page.get_node("Root/MainSplit/LibraryPanel") as PanelContainer
	var panel_style := library_panel.get_theme_stylebox("panel") as StyleBoxFlat
	expect(panel_style != null, "deck builder runtime must apply the quiet native library panel")
	if panel_style != null:
		expect(panel_style.content_margin_left == 16 and panel_style.content_margin_top == 16 and panel_style.content_margin_right == 16 and panel_style.content_margin_bottom == 16, "library panel must preserve compact content safe margins")
	var cards := page.find_children("", "DeckCardView", true, false)
	expect(cards.size() >= 4, "deck builder runtime must render at least four cards for layout verification")
	if cards.size() >= 4:
		var first := cards[0] as Control
		for index in range(4):
			var card := cards[index] as Control
			expect(card.size.x >= 158.0 and is_equal_approx(card.position.y, first.position.y), "library panel safe margins must retain a complete four-card row")
			var artwork := card.find_child("CardArt", true, false) as Control
			expect(card.get_global_rect().encloses(artwork.get_global_rect()), "card artwork must remain inside its card silhouette bounds")
	if cards.size() >= 8:
		var scroll := page.get_node("Root/MainSplit/LibraryPanel/Library/CardScroll") as Control
		expect((cards[7] as Control).get_global_rect().end.y <= scroll.get_global_rect().end.y, "two full card rows must fit the library viewport")
		var selected = cards[1]
		page.select_card(selected.card_id)
		expect(selected.is_selected and not cards[0].is_selected, "selecting a card must move the visible selection state")
		expect(selected.find_child("CardArt", true, false).texture != null, "card artwork must load a real project texture")
	page.queue_free()
	await tree.process_frame

func _test_card_rows_align_for_locked_and_unlocked_cards() -> void:
	var card_script := load("res://scripts/deck_card_view.gd") as Script
	var data := {"id":"test", "name":"测试卡", "energy_cost":3, "phase":"any", "rarity":"common", "unlock_cost":5}
	var unlocked = card_script.new(); unlocked.configure(data, true, 0, 2, "")
	var locked = card_script.new(); locked.configure(data, false, 0, 2, "")
	var unlocked_slot := unlocked.find_child("LockSlot", true, false) as Control
	var locked_slot := locked.find_child("LockSlot", true, false) as Control
	expect(unlocked_slot != null and locked_slot != null, "locked and unlocked cards must reserve the same lock row")
	if unlocked_slot != null and locked_slot != null:
		expect(unlocked_slot.custom_minimum_size.y == locked_slot.custom_minimum_size.y, "lock rows must keep action buttons aligned")
	var fallback := unlocked.find_child("ArtFallback", true, false) as Label
	expect(fallback != null and not fallback.text.contains("测试卡"), "art fallback must not repeat the card name")
	expect(unlocked.custom_minimum_size == Vector2(158, 196), "compact four-column cards must fit two complete rows")
	unlocked.free(); locked.free()

func _test_generated_button_keeps_usable_width(scene: PackedScene) -> void:
	var page := scene.instantiate()
	var save_button := page.get_node("Root/BottomBar/SaveButton") as Button
	expect(save_button.custom_minimum_size.x >= 180.0, "save button must not compress the 220x72 generated frame")
	page.free()

func _test_remove_button_does_not_synchronously_free_sender(scene: PackedScene) -> void:
	var page := scene.instantiate()
	var deck: Array[String] = ["card_sun_pierce", "card_sun_pierce", "card_root_snare", "card_root_snare", "card_emergency_dew", "card_emergency_dew", "card_root_wall", "card_root_wall", "card_sun_mine", "card_sun_mine", "card_lure_bud", "card_lure_bud"]
	page.setup({"meta_seeds":0, "unlocked_cards":["card_sun_pierce","card_root_snare","card_emergency_dew","card_root_wall","card_sun_mine","card_lure_bud"], "selected_deck":deck})
	page.refresh_deck_list()
	var remove_button := page.find_child("RemoveButton", true, false) as Button
	expect(remove_button != null, "populated deck must render a remove button")
	if remove_button != null:
		remove_button.pressed.emit()
		expect(page.get_model().draft.size() == 12, "remove button must defer mutation until its signal callback finishes")
	page.free()

func _test_player_facing_text_is_chinese(scene: PackedScene) -> void:
	var page := scene.instantiate()
	page.setup({"meta_seeds":40, "unlocked_cards":["card_sun_pierce"], "selected_deck":[]})
	page.refresh_all()
	var visible_text := _collect_text(page)
	var english_word := RegEx.new()
	english_word.compile("[A-Za-z]{2,}")
	expect(english_word.search(visible_text) == null, "deck builder must not expose English terms to players: %s" % visible_text)
	page.free()

func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button: result += str(node.text) + " "
	for child in node.get_children(): result += _collect_text(child)
	return result

func _test_locked_card_unlock_confirmation(scene: PackedScene) -> void:
	var page := scene.instantiate()
	page.setup({"meta_seeds":40, "unlocked_cards":["card_sun_pierce"], "selected_deck":[]})
	page.confirm_unlock("card_time_stasis")
	var dialog := page.find_child("UnlockDialog", true, false) as ConfirmationDialog
	expect(dialog != null, "locked card action must open an unlock confirmation")
	expect(not page.get_model().unlocked_cards.has("card_time_stasis"), "opening confirmation must not spend seeds")
	if dialog != null: dialog.confirmed.emit()
	expect(page.get_model().unlocked_cards.has("card_time_stasis"), "confirming unlock must add the card")
	expect(page.get_model().meta_seeds == 5, "confirming unlock must deduct seeds")
	page.free()
