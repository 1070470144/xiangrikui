extends RefCounted

const CombatDeck = preload("res://scripts/combat_deck.gd")
const ContentData = preload("res://scripts/content_data.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	test_consumable_deck_flow()
	test_play_validation()
	return failures

func _deck() -> Array[String]:
	return ["card_sun_pierce","card_sun_pierce","card_root_snare","card_root_snare","card_emergency_dew","card_emergency_dew","card_root_wall","card_root_wall","card_sun_mine","card_sun_mine","card_lure_bud","card_lure_bud"]

func test_consumable_deck_flow() -> void:
	var deck := CombatDeck.new()
	expect(deck.start_run(_deck(), 7), "valid twelve-card deck must start")
	expect(deck.get_hand().is_empty() and deck.remaining_count() == 12, "run must keep full pile until the first night")
	deck.begin_next_night()
	expect(deck.hand.size() == 4 and deck.draw_pile.size() == 8, "first night draws four")
	expect(not deck.mulligan(deck.hand[0]), "fixed night allotments do not allow replacement draws")
	var played := deck.get_hand()[0]
	expect(deck.consume(played), "held card must be consumed")
	expect(deck.get_hand().size() == 3 and deck.remaining_count() == 11, "consumed card permanently leaves without a replacement draw")
	var across_night := deck.get_hand()
	deck.begin_next_night()
	expect(deck.get_hand().slice(0, 3) == across_night and deck.hand.size() == 5, "next night keeps existing cards and adds two")
	for _i in range(10): deck.begin_next_night()
	expect(deck.draw_pile.is_empty() and deck.hand.size() == 11, "pile exhaustion never recycles consumed cards")

func test_play_validation() -> void:
	var deck := CombatDeck.new(); deck.start_run(_deck(), 2)
	expect(CombatDeck.validate_card_play("card_sun_pierce", "night", 4, {"type":"ground"}), "matching target and energy must validate")
	expect(not CombatDeck.validate_card_play("card_sun_pierce", "day", 4, {"type":"enemy"}), "night card must fail during day")
	expect(not CombatDeck.validate_card_play("card_sun_pierce", "night", 3, {"type":"enemy"}), "insufficient energy must fail")
	expect(not CombatDeck.validate_card_play("card_sun_pierce", "night", 4, {"type":"enemy"}), "wrong target must fail")
