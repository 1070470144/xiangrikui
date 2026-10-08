extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	var content := preload("res://scripts/content_data.gd")
	var presentation := preload("res://scripts/battle_card_presentation.gd")
	var visual := preload("res://scripts/deck_builder_style.gd")
	var card_script := preload("res://scripts/battle_hand_card.gd")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152,648)
	root.add_child(viewport)
	var cards: Array[Control] = []
	for data in content.COMBAT_CARDS:
		var card := card_script.new()
		card.configure(data.id, load(visual.art_path(data.id)), data.name, presentation.describe(data.id), str(data.energy_cost))
		viewport.add_child(card)
		cards.append(card)
	await process_frame
	await process_frame
	for card in cards:
		var name := str(card.card_id)
		var rarity := str(content.get_card(name).rarity)
		var frame := card.get_theme_stylebox("normal") as StyleBoxTexture
		check(frame != null and frame.texture.resource_path.ends_with("card_face_%s_v5.png" % rarity), name + " correct deck rarity face")
		var illustration := card.get_node("Illustration") as TextureRect
		var title := card.get_node("CardTitle") as Label
		var cost := card.get_node("CostValue") as Label
		var effect := card.get_node("EffectDescription") as Label
		var target := card.get_node("TargetLabel") as Label
		check(illustration.texture != null and illustration.texture.resource_path.contains("illustrations_v3"), name + " actual deck illustration")
		for node in [illustration,title,cost,effect,target]:
			check(Rect2(Vector2.ZERO,card.size).encloses(node.get_rect()), name + " safe card bounds " + node.name)
		check(not title.get_rect().intersects(illustration.get_rect()), name + " title separates from art")
		check(not effect.get_rect().intersects(illustration.get_rect()), name + " effect separates from art")
		check(effect.get_visible_line_count() >= effect.get_line_count(), name + " complete effect fits: %d/%d" % [effect.get_visible_line_count(),effect.get_line_count()])
		check(not effect.text.is_empty(), name + " effect description present")
	for issue in failures: push_error(issue)
	print("BATTLE DECK FACE REVIEW ", "PASSED" if failures.is_empty() else "FAILED", " (",failures.size()," failures)")
	viewport.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
