extends RefCounted

const ContentData = preload("res://scripts/content_data.gd")
var draw_pile: Array[String] = []
var hand: Array[String] = []
var consumed: Array[String] = []
var mulligan_used := false
var nights_drawn := 0

func start_run(deck_ids: Array[String], seed_value: int = 0) -> bool:
	if deck_ids.size() != ContentData.DECK_SIZE: return false
	draw_pile = deck_ids.duplicate(); hand.clear(); consumed.clear(); mulligan_used = false; nights_drawn = 0
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i); var tmp := draw_pile[i]; draw_pile[i] = draw_pile[j]; draw_pile[j] = tmp
	return true
func get_hand() -> Array[String]: return hand.duplicate()
func remaining_count() -> int: return draw_pile.size() + hand.size()
func mulligan(_card_id: String) -> bool:
	return false
func consume(card_id: String) -> bool:
	if not hand.has(card_id): return false
	hand.erase(card_id); consumed.append(card_id); return true
## Draws the fixed night allotment. Unplayed cards remain in hand and are never
## replaced; the pile is consumed permanently when exhausted.
func begin_next_night() -> void:
	var amount := 4 if nights_drawn == 0 else 2
	nights_drawn += 1
	for _i in range(amount):
		if draw_pile.is_empty(): break
		hand.append(draw_pile.pop_front())

static func validate_card_play(card_id: String, phase: String, energy: int, target_context: Dictionary) -> bool:
	var card := ContentData.get_card(card_id)
	if card.is_empty() or energy < int(card["energy_cost"]): return false
	if card["phase"] != "any" and card["phase"] != phase: return false
	var required := str(card["target_type"]); var actual := str(target_context.get("type", ""))
	return required == "global" or actual == required or (required == "plant_or_node" and actual in ["plant", "node"])
