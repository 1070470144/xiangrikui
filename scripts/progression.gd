extends RefCounted

const ContentData = preload("res://scripts/content_data.gd")
var meta_seeds := 0
var unlocked_cards: Array[String] = []
var mother_meta_levels := {"max_health":0, "starting_energy":0, "day_regen":0, "sunburst_damage":0}
var selected_deck: Array[String] = []
var run_seeds := 0
var earned_seeds := 0
var run_settled := false

func _init() -> void:
	for id in ContentData.STARTER_CARD_IDS: unlocked_cards.append(id)

func start_run(starting_seeds: int) -> void:
	run_seeds = maxi(0, starting_seeds); earned_seeds = 0; run_settled = false

func gain_run_seeds(amount: int) -> int:
	var requested := maxi(0, amount); var gained := mini(requested, maxi(0, 12 - run_seeds)); run_seeds += gained; earned_seeds += gained; return gained

func spend_run_seeds(amount: int) -> bool:
	if amount < 0 or run_seeds < amount: return false
	run_seeds -= amount; return true

func get_extractable_seeds() -> int: return mini(run_seeds, earned_seeds)
func settle_retreat() -> int: return _settle(get_extractable_seeds())
func settle_victory() -> int: return _settle(get_extractable_seeds())
func settle_failure() -> int:
	var extractable := get_extractable_seeds(); var result := int(floor(float(extractable) * 0.10))
	if extractable > 0 and result == 0: result = 1
	return _settle(result)
func _settle(amount: int) -> int:
	if run_settled: return 0
	run_settled = true; meta_seeds += maxi(0, amount); return maxi(0, amount)

func unlock_card(card_id: String) -> bool:
	if unlocked_cards.has(card_id): return false
	var card := ContentData.get_card(card_id); var cost := int(card.get("unlock_cost", -1))
	if card.is_empty() or cost < 0 or meta_seeds < cost: return false
	meta_seeds -= cost; unlocked_cards.append(card_id); return true

func upgrade_mother(track_id: String) -> bool:
	for track in ContentData.META_TRACKS:
		if track["id"] != track_id: continue
		var level := int(mother_meta_levels.get(track_id, 0)); var costs: Array = track["costs"]
		if level >= costs.size() or meta_seeds < int(costs[level]): return false
		meta_seeds -= int(costs[level]); mother_meta_levels[track_id] = level + 1; return true
	return false

func get_meta_value(track_id: String) -> Variant:
	for track in ContentData.META_TRACKS:
		if track["id"] == track_id: return track["values"][int(mother_meta_levels.get(track_id, 0))]
	return null

func validate_deck(deck: Array[String]) -> bool:
	if deck.size() != ContentData.DECK_SIZE: return false
	var counts := {}; var legendary := 0; var rare := 0
	for id in deck:
		if not unlocked_cards.has(id): return false
		var card := ContentData.get_card(id)
		if card.is_empty(): return false
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > int(card.get("copies_allowed", 1)): return false
		if card["rarity"] == "legendary": legendary += 1
		elif card["rarity"] == "rare": rare += 1
	return legendary <= 1 and rare <= 4

func export_profile() -> Dictionary:
	return {"meta_seeds":meta_seeds, "unlocked_cards":unlocked_cards.duplicate(), "mother_meta_levels":mother_meta_levels.duplicate(), "selected_deck":selected_deck.duplicate()}

func import_profile(profile: Dictionary) -> void:
	meta_seeds = maxi(0, int(profile.get("meta_seeds", 0))); unlocked_cards.clear()
	for id in profile.get("unlocked_cards", ContentData.STARTER_CARD_IDS):
		if not ContentData.get_card(str(id)).is_empty() and not unlocked_cards.has(str(id)): unlocked_cards.append(str(id))
	for id in ContentData.STARTER_CARD_IDS:
		if not unlocked_cards.has(id): unlocked_cards.append(id)
	var stored: Dictionary = profile.get("mother_meta_levels", {})
	for track in ContentData.META_TRACKS: mother_meta_levels[track["id"]] = clampi(int(stored.get(track["id"], 0)), 0, 5)
	selected_deck.clear(); for id in profile.get("selected_deck", []): selected_deck.append(str(id))
