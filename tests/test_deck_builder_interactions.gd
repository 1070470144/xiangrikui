extends RefCounted

const Scene = preload("res://scenes/deck_builder.tscn")
const Content = preload("res://scripts/content_data.gd")
const Text = preload("res://scripts/deck_builder_text.gd")
var failures: Array[String] = []
var tree: SceneTree
var page: Control

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	tree = Engine.get_main_loop() as SceneTree
	page = Scene.instantiate()
	page.setup({"meta_seeds":40, "unlocked_cards":Content.STARTER_CARD_IDS, "selected_deck":[]})
	tree.root.add_child(page)
	await tree.process_frame
	await tree.process_frame
	if DisplayServer.get_name() == "headless":
		await _test_drop_contract()
		page.queue_free()
		await tree.process_frame
		return failures
	var card := _card("card_sun_pierce")
	var start := card.get_global_rect().get_center() - Vector2(0, 25)
	await _click(start)
	var overlay := page.get_node_or_null("DialogLayer/CardDetailOverlay") as Control
	expect(overlay != null and overlay.visible, "a real card click must open the detail panel")
	if overlay != null:
		expect(overlay.find_child("DetailCost", true, false).text.contains("4 光能"), "detail panel must show use energy cost")
		expect(overlay.find_child("DetailDescription", true, false).text.contains("42 点伤害"), "detail panel must describe actual effects")
		expect(overlay.find_child("DetailUnlockCost", true, false).text.contains("0 种子"), "detail panel must distinguish seed unlock cost")
		var stage := overlay.find_child("CardStage", true, false) as Control
		var face := stage.get_node("Front") as Control
		expect(face.find_child("DetailDescription", true, false) != null, "effect description must be on the card front")
		expect(stage.get_node("Back").find_child("DetailDescription", true, false) == null, "card back must contain artwork only")
		var back_texture: Texture2D = stage.get_node("Back").frame
		expect(back_texture != null and back_texture != face.frame, "card back must use a dedicated texture")
		if back_texture != null:
			var pixels := back_texture.get_image()
			expect(pixels.get_pixel(0, 0).a < 0.05 and pixels.get_pixel(pixels.get_width() / 2, pixels.get_height() / 2).a > 0.9, "card back must have transparent exterior and opaque designed interior")
		await _click(face.get_global_rect().get_center())
		await tree.create_timer(0.5).timeout
		expect(stage.get_node("Back").visible and not face.visible, "clicking the card must animate a turn to its designed back")
		await _click((stage.get_node("Back") as Control).get_global_rect().position + Vector2(150, 30))
		await tree.create_timer(0.5).timeout
		expect(face.visible, "clicking the card back must turn back to the illustration")
		var turn_start := face.get_global_rect().position + Vector2(40, 45)
		await _motion(turn_start, Vector2.ZERO, false)
		await _button(turn_start, true)
		await _motion(turn_start + Vector2(120, 0), Vector2(120, 0), true)
		expect(stage.scale.x < 0.3, "mouse drag must rotate the card to show its edge")
		await _motion(turn_start + Vector2(225, 0), Vector2(105, 0), true)
		await _button(turn_start + Vector2(225, 0), false)
		await tree.create_timer(0.3).timeout
		expect(stage.get_node("Back").visible and is_equal_approx(stage.scale.x, 1.0), "releasing card rotation must settle on the readable back")
		overlay.hide()
	var deck := page.get_node("Root/MainSplit/Sidebar/DeckScroll") as Control
	await _drag(start, deck.get_global_rect().get_center())
	expect(page.get_model().draft.count("card_sun_pierce") == 1, "native pointer drag must add a library card to an empty deck")
	expect(overlay == null or not overlay.visible, "dragging must not open the detail panel")
	card = _card("card_sun_pierce")
	await _drag(card.get_global_rect().get_center() - Vector2(0, 25), deck.get_global_rect().get_center())
	expect(page.get_model().draft.count("card_sun_pierce") == 2, "dragging must support the second allowed copy")
	card = _card("card_sun_pierce")
	await _drag(card.get_global_rect().get_center() - Vector2(0, 25), deck.get_global_rect().get_center())
	expect(page.get_model().draft.count("card_sun_pierce") == 2, "dragging must enforce per-card copy limits")
	var row := page.find_child("CardName", true, false) as Control
	if row == null:
		expect(false, "native drag did not produce a deck row: %s" % [page.get_model().draft])
		page.queue_free()
		await tree.process_frame
		return failures
	await _drag(row.get_global_rect().get_center(), _card("card_root_snare").get_global_rect().get_center())
	expect(page.get_model().draft.count("card_sun_pierce") == 1, "dragging a deck row onto a library card must remove exactly one copy")
	row = page.find_child("CardName", true, false) as Control
	await _drag(row.get_global_rect().get_center(), Vector2(1100, 610))
	expect(page.get_model().draft.count("card_sun_pierce") == 1, "dropping outside a destination must preserve the deck")
	var data := {"type":"deck_builder_card", "card_id":"card_time_stasis", "source":"library", "owner_id":page.get_instance_id()}
	expect(not page.can_drop_card("deck", data), "locked cards must be rejected")
	data.card_id = "card_sun_pierce"; data.owner_id = 0
	expect(not page.can_drop_card("deck", data), "foreign drag payloads must be rejected")
	expect(not page.can_drop_card("deck", "bad payload"), "unrelated drag payloads must be rejected")
	for content_card in Content.COMBAT_CARDS:
		expect(not Text.description(content_card).begins_with("对"), "every combat card must have a specific effect description: %s" % content_card.id)
	page.queue_free()
	await tree.process_frame
	return failures

func _test_drop_contract() -> void:
	page.show_card_detail("card_sun_pierce")
	expect(page.get_node_or_null("Root/MainSplit/Sidebar/DetailPanel") == null, "sidebar must not retain a duplicate detail panel")
	var overlay := page.get_node("DialogLayer/CardDetailOverlay") as Control
	expect(overlay.visible and overlay.find_child("DetailDescription", true, false).text.contains("42 点伤害"), "detail panel must describe actual effects")
	expect(overlay.find_child("DetailCost", true, false).text.contains("4 光能"), "detail panel must show energy consumption")
	var stage := overlay.find_child("CardStage", true, false)
	stage.flip()
	await tree.create_timer(0.5).timeout
	expect(stage.get_node("Back").visible and is_equal_approx(stage.scale.x, 1.0), "flip must finish on the readable effect face")
	stage.angle = 270.0
	expect(stage.scale.x < 0.1, "rotation must visually show the card edge")
	page.show_card_detail("card_emergency_dew")
	expect(overlay.find_child("DetailTitle", true, false).text == "甘露急救", "reopening a card must replace the previous turntable")
	overlay.hide()
	var data := {"type":"deck_builder_card", "card_id":"card_sun_pierce", "source":"library", "owner_id":page.get_instance_id()}
	expect(page.can_drop_card("deck", data), "unlocked card must be accepted by empty deck")
	page.drop_card("deck", data)
	await tree.process_frame
	expect(page.get_model().draft.count("card_sun_pierce") == 1, "accepted drop must add one copy")
	page.drop_card("deck", data)
	await tree.process_frame
	expect(not page.can_drop_card("deck", data), "copy limit must reject another drop")
	data.source = "deck"
	page.drop_card("library", data)
	await tree.process_frame
	expect(page.get_model().draft.count("card_sun_pierce") == 1, "outbound drop must remove exactly one copy")
	data.source = "library"; data.card_id = "card_time_stasis"
	expect(not page.can_drop_card("deck", data), "locked card must be rejected")
	data.card_id = "card_sun_pierce"; data.owner_id = 0
	expect(not page.can_drop_card("deck", data), "foreign payload must be rejected")
	expect(not page.can_drop_card("deck", "bad payload"), "unrelated payload must be rejected")
	page.get_model().auto_fill()
	data.owner_id = page.get_instance_id(); data.card_id = "card_emergency_light"
	expect(not page.can_drop_card("deck", data), "full deck must reject an otherwise addable card")
	page.get_model().draft.clear()
	page.get_model().unlocked_cards.append("card_sun_arrow_rain")
	page.get_model().unlocked_cards.append("card_golden_domain")
	page.get_model().unlocked_cards.append("card_time_stasis")
	page.get_model().draft.assign(["card_sun_arrow_rain", "card_root_prison", "card_golden_rain", "card_temporary_sprout"])
	data.card_id = "card_node_overload"
	page.get_model().unlocked_cards.append("card_node_overload")
	expect(not page.can_drop_card("deck", data), "rare quota must apply to drag and drop")
	page.get_model().draft.assign(["card_golden_domain"])
	data.card_id = "card_time_stasis"
	expect(not page.can_drop_card("deck", data), "legendary quota must apply to drag and drop")
	for card in Content.COMBAT_CARDS:
		expect(not Text.description(card).begins_with("对"), "all cards need specific descriptions: %s" % card.id)

func _card(card_id: String) -> Control:
	for view in page.get_node("Root/MainSplit/LibraryPanel/Library/CardScroll/CardGrid").get_children():
		if view.card_id == card_id: return view
	return null

func _click(position: Vector2) -> void:
	await _motion(position, Vector2.ZERO, false)
	await _button(position, true)
	await _button(position, false)

func _drag(from: Vector2, to: Vector2) -> void:
	await _motion(from, Vector2.ZERO, false)
	await _button(from, true)
	await _motion(from + Vector2(30, 0), Vector2(30, 0), true)
	expect(tree.root.gui_is_dragging(), "pointer movement with the button down must start a native drag")
	await _motion(to, to - from - Vector2(30, 0), true)
	await _button(to, false)
	await tree.process_frame
	await tree.process_frame

func _motion(position: Vector2, relative: Vector2, pressed: bool) -> void:
	var event := InputEventMouseMotion.new(); event.position = position; event.global_position = position; event.relative = relative; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	tree.root.push_input(event)
	await tree.process_frame

func _button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.position = position; event.global_position = position; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	tree.root.push_input(event)
	await tree.process_frame
