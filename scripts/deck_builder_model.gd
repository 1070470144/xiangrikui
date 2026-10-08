extends RefCounted
class_name DeckBuilderModel

const ContentData = preload("res://scripts/content_data.gd")

var meta_seeds := 0
var unlocked_cards: Array[String] = []
var saved_deck: Array[String] = []
var draft: Array[String] = []

func _init(profile: Dictionary) -> void:
	meta_seeds = maxi(0, int(profile.get("meta_seeds", 0)))
	for value in profile.get("unlocked_cards", ContentData.STARTER_CARD_IDS):
		var id := str(value)
		if not unlocked_cards.has(id) and not ContentData.get_card(id).is_empty(): unlocked_cards.append(id)
	for value in profile.get("selected_deck", []): saved_deck.append(str(value))
	draft = saved_deck.duplicate()

func get_visible_cards(phase_filter := "all", sort_mode := "default") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in ContentData.COMBAT_CARDS:
		var phase := str(source.get("phase", "any"))
		if phase_filter != "all" and phase != phase_filter and phase != "any": continue
		result.append(source.duplicate(true))
	if sort_mode == "cost": result.sort_custom(func(a, b): return [int(a.energy_cost), str(a.id)] < [int(b.energy_cost), str(b.id)])
	elif sort_mode == "rarity":
		var rank := {"common":0, "rare":1, "legendary":2}
		result.sort_custom(func(a, b): return [int(rank.get(a.rarity, 9)), str(a.id)] < [int(rank.get(b.rarity, 9)), str(b.id)])
	return result

func can_add(card_id: String) -> String:
	if draft.size() >= ContentData.DECK_SIZE: return "卡组已满"
	if not unlocked_cards.has(card_id): return "卡牌尚未解锁"
	var card := ContentData.get_card(card_id)
	if card.is_empty(): return "卡牌不存在"
	if draft.count(card_id) >= int(card.get("copies_allowed", 1)): return "已达到携带上限"
	if card.rarity == "rare" and _rarity_count("rare") >= 4: return "稀有卡最多携带 4 张"
	if card.rarity == "legendary" and _rarity_count("legendary") >= 1: return "传奇卡最多携带 1 张"
	return ""

func add_card(card_id: String) -> bool:
	if not can_add(card_id).is_empty(): return false
	draft.append(card_id)
	return true

func remove_card(card_id: String) -> bool:
	var index := draft.find(card_id)
	if index < 0: return false
	draft.remove_at(index)
	return true

func clear_draft() -> void: draft.clear()
func restore_saved() -> void: draft = saved_deck.duplicate()
func is_dirty() -> bool: return draft != saved_deck

func validate_draft() -> Array[String]:
	var errors: Array[String] = []
	if draft.size() != ContentData.DECK_SIZE: errors.append("卡组需要 12 张卡牌")
	var counts := {}
	for id in draft:
		var card := ContentData.get_card(id)
		if card.is_empty() or not unlocked_cards.has(id):
			if not errors.has("卡组包含无效或未解锁卡牌"): errors.append("卡组包含无效或未解锁卡牌")
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] > int(card.get("copies_allowed", 1)):
			var message := "%s 超出携带上限" % card.name
			if not errors.has(message): errors.append(message)
	if _rarity_count("rare") > 4: errors.append("稀有卡最多携带 4 张")
	if _rarity_count("legendary") > 1: errors.append("传奇卡最多携带 1 张")
	return errors

func try_unlock(card_id: String) -> bool:
	if unlocked_cards.has(card_id): return false
	var card := ContentData.get_card(card_id)
	var cost := int(card.get("unlock_cost", -1))
	if card.is_empty() or cost < 0 or meta_seeds < cost: return false
	meta_seeds -= cost
	unlocked_cards.append(card_id)
	return true

func rollback_unlock(card_id: String, prior_seed_count: int) -> void:
	unlocked_cards.erase(card_id)
	meta_seeds = prior_seed_count

func auto_fill() -> bool:
	var candidates := get_visible_cards("all", "cost")
	var changed := false
	while draft.size() < ContentData.DECK_SIZE:
		var added := false
		for card in candidates:
			if add_card(str(card.id)): added = true; changed = true; break
		if not added: break
	return changed and draft.size() == ContentData.DECK_SIZE

func mark_saved() -> void: saved_deck = draft.duplicate()

func export_profile_patch() -> Dictionary:
	return {"meta_seeds":meta_seeds, "unlocked_cards":unlocked_cards.duplicate()}

func _rarity_count(rarity: String) -> int:
	var total := 0
	for id in draft:
		if str(ContentData.get_card(id).get("rarity", "")) == rarity: total += 1
	return total
