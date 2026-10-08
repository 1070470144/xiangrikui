extends RefCounted

const Progression = preload("res://scripts/progression.gd")
const ContentData = preload("res://scripts/content_data.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	test_seed_extraction()
	test_unlocks_and_upgrades()
	test_deck_validation_and_profile_round_trip()
	return failures

func test_seed_extraction() -> void:
	var p := Progression.new()
	p.start_run(5)
	expect(p.run_seeds == 5 and p.get_extractable_seeds() == 0, "initial seeds must not be extractable")
	p.gain_run_seeds(3)
	expect(p.get_extractable_seeds() == 3, "earned held seeds must be extractable")
	expect(p.spend_run_seeds(6), "run seed spend must succeed")
	expect(p.run_seeds == 2 and p.get_extractable_seeds() == 2, "initial seed portion must be spent first")
	expect(p.settle_failure() == 1, "failure must return ten percent with minimum one")
	p.start_run(5); p.gain_run_seeds(7)
	expect(p.settle_retreat() == 7, "retreat must return all extractable seeds")
	p.start_run(5); p.gain_run_seeds(4)
	expect(p.settle_victory() == 4, "victory must return all extractable seeds")
	expect(p.settle_victory() == 0 and p.meta_seeds == 12, "a run must not be settled twice")
	p.start_run(11)
	expect(p.gain_run_seeds(5) == 1 and p.run_seeds == 12 and p.earned_seeds == 1, "seed rewards must count only room below the run cap")

func test_unlocks_and_upgrades() -> void:
	var p := Progression.new()
	p.meta_seeds = 100
	expect(p.unlock_card("card_time_stasis"), "affordable locked card must unlock")
	expect(p.meta_seeds == 65 and p.unlocked_cards.has("card_time_stasis"), "unlock must spend documented cost")
	expect(not p.unlock_card("card_time_stasis"), "card cannot unlock twice")
	expect(p.upgrade_mother("max_health"), "mother track must upgrade")
	expect(p.get_meta_value("max_health") == 310.0, "level one mother health must match catalog")
	p.meta_seeds = 999
	for i in range(4): expect(p.upgrade_mother("max_health"), "track must reach level five")
	expect(not p.upgrade_mother("max_health"), "mother track must stop at level five")

func test_deck_validation_and_profile_round_trip() -> void:
	var p := Progression.new()
	var deck: Array[String] = []
	for id in ContentData.STARTER_CARD_IDS:
		deck.append(id); if deck.size() < 5: deck.append(id)
	while deck.size() < 12: deck.append(ContentData.STARTER_CARD_IDS[deck.size() % ContentData.STARTER_CARD_IDS.size()])
	expect(p.validate_deck(deck), "twelve-card starter deck respecting copy limits must validate")
	expect(not p.validate_deck(deck.slice(0, 10)), "deck with wrong size must fail")
	p.meta_seeds = 17; p.selected_deck = deck.duplicate(); p.mother_meta_levels["starting_energy"] = 2
	var restored := Progression.new(); restored.import_profile(p.export_profile())
	expect(restored.meta_seeds == 17 and restored.selected_deck == deck, "profile round trip must preserve seeds and deck")
	expect(restored.get_meta_value("starting_energy") == 61, "profile round trip must preserve mother level")
