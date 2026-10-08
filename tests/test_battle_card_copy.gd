extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures := 0
	for card in preload("res://scripts/content_data.gd").COMBAT_CARDS:
		var view := preload("res://scripts/battle_hand_card.gd").new()
		view.configure(card.id,null,card.name,preload("res://scripts/battle_card_presentation.gd").describe(card.id),str(card.energy_cost))
		root.add_child(view)
		await process_frame
		var label := view.get_node("EffectDescription") as Label
		var font := label.get_theme_font("font")
		var extent := font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_CENTER,label.size.x,12,-1,TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
		if extent.y > label.size.y:
			push_error("Effect caption overflows: %s (%s)" % [card.id,extent]); failures += 1
		view.queue_free()
	print("BATTLE CARD COPY CHECK: %d failures" % failures)
	quit(1 if failures else 0)
