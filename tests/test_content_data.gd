extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	test_catalog_counts()
	test_catalog_ids_are_unique()
	test_deck_and_progression_contracts()
	return failures

func test_catalog_counts() -> void:
	var data := _load_script("res://scripts/content_data.gd")
	if data == null:
		return
	expect(data.FLOWERS.size() == 16, "catalog must define fifteen slot plants plus the base light sprout")
	expect(data.ENEMIES.size() == 10, "catalog must define ten enemies")
	expect(data.MOTHER_PATHS.size() == 3, "catalog must define three mother paths")
	expect(data.MOTHER_UPGRADES.size() == 54, "catalog must define fifty-four mother upgrades")
	expect(data.COMBAT_CARDS.size() == 24, "catalog must define twenty-four combat cards")

func test_catalog_ids_are_unique() -> void:
	var data := _load_script("res://scripts/content_data.gd")
	if data == null:
		return
	for collection in [data.FLOWERS, data.ENEMIES, data.MOTHER_PATHS, data.MOTHER_UPGRADES, data.COMBAT_CARDS]:
		var ids: Dictionary = {}
		for entry in collection:
			var id := str(entry.get("id", ""))
			expect(not id.is_empty(), "every catalog entry must have an id")
			expect(not ids.has(id), "catalog ids must be unique within each collection: %s" % id)
			ids[id] = true
	expect(data.get_flower("thorn_flower").get("damage") == 14.0, "thorn lookup must return configured data")
	expect(data.get_enemy("sun_devourer").get("health") == 1300.0, "enemy lookup must return boss data")
	expect(data.get_card("card_time_stasis").get("unlock_cost") == 35, "card lookup must return unlock cost")

func test_deck_and_progression_contracts() -> void:
	var data := _load_script("res://scripts/content_data.gd")
	if data == null:
		return
	expect(data.DECK_SIZE == 12, "combat deck must contain twelve cards")
	expect(data.STARTING_HAND_SIZE == 4, "combat deck must start with four cards")
	expect(data.STARTER_CARD_IDS.size() == 8, "eight common cards must be unlocked initially")
	expect(data.META_TRACKS.size() == 4, "four mother meta tracks must exist")
	for track in data.META_TRACKS:
		expect((track.get("values", []) as Array).size() == 6, "meta track must contain level zero plus five upgrades")
		expect((track.get("costs", []) as Array).size() == 5, "meta track must contain five costs")
	var choices: Array[String] = data.get_next_mother_choices("dawn_pulse", {"charge": 0, "quelling": 0, "morningstar": 0})
	expect(choices == ["mother_charge_01", "mother_quelling_01", "mother_morningstar_01"], "dawn path must offer first rank from each branch")

func _load_script(path: String) -> Script:
	var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		failures.append("script failed to compile: %s" % path)
		return null
	return script
