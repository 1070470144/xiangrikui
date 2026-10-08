extends RefCounted

const ContentData = preload("res://scripts/content_data.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	var script := load("res://scripts/deck_builder_model.gd") as Script
	if script == null or not script.can_instantiate():
		expect(false, "deck builder model must compile")
		return failures
	var profile := {"meta_seeds":40, "unlocked_cards":ContentData.STARTER_CARD_IDS.duplicate(), "selected_deck":[]}
	var model = script.new(profile)
	var visible: Array = model.get_visible_cards("night", "cost")
	expect(not visible.is_empty(), "night filter must return cards")
	for card in visible:
		expect(str(card.get("phase", "")) in ["night", "any"], "night filter must include night and universal cards only")
	expect(model.try_unlock("card_time_stasis"), "affordable locked card must unlock")
	expect(model.meta_seeds == 5, "unlock must deduct its documented cost")
	expect(not model.try_unlock("card_golden_domain"), "insufficient seeds must reject unlock")
	model.clear_draft()
	expect(model.auto_fill(), "auto-fill must complete a legal deck")
	expect(model.validate_draft().is_empty(), "auto-filled deck must be valid")
	expect(model.draft.size() == ContentData.DECK_SIZE, "auto-fill must create twelve cards")
	var first: String = str(model.draft[0])
	expect(not model.add_card(first), "a complete deck must reject a thirteenth card")
	model.clear_draft()
	expect(model.add_card(first), "an unlocked card must be addable")
	expect(model.is_dirty(), "draft edits must mark the model dirty")
	model.restore_saved()
	expect(not model.is_dirty(), "restoring the saved deck must clear dirty state")
	return failures
