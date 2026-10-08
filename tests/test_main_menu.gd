extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	test_menu_contract()
	test_local_profile_contract()
	test_account_switch_contract()
	test_account_delete_contract()
	test_account_scroll_contract()
	test_home_menu_contract()
	test_home_button_visual_hierarchy()
	test_seven_night_contract()
	test_game_start_flow()
	return failures

func test_menu_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	expect(menu.has_signal("start_requested"), "main menu must expose a single campaign start signal")
	expect(menu.get_plant_entries().size() >= 2, "encyclopedia must contain plant entries")
	expect(menu.get_monster_entries().size() >= 2, "encyclopedia must contain monster entries")
	menu.free()

func test_local_profile_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	var profile: Dictionary = menu.get_local_profile()
	expect(profile.get("account_type", "") == "本地账号", "main menu must identify the profile as local-only")
	expect(profile.has("level_progress"), "local profile must expose level progress")
	expect(profile.has("meta_seeds") and profile.has("unlocked_cards") and profile.has("mother_meta_levels") and profile.has("selected_deck"), "local profile must persist all meta-progression fields")
	expect(menu.has_method("apply_progression_profile"), "main menu must accept progression updates from a completed run")
	expect(menu.has_method("set_selected_deck") and menu.has_method("get_deck_options"), "main menu must expose deck configuration")
	var starter_deck: Array[String] = []
	for id in ["card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud"]:
		starter_deck.append(id)
		starter_deck.append(id)
	var original_deck: Array = profile.get("selected_deck", []).duplicate()
	expect(menu.set_selected_deck(starter_deck), "main menu must save a valid twelve-card deck")
	expect(menu.get_local_profile().get("selected_deck", []) == starter_deck, "saved deck must be exposed by the active profile")
	menu.local_profile["selected_deck"] = original_deck
	menu.call("_save_local_profile")
	expect(menu.decode_profile_field("selected_deck", JSON.stringify(["card_sun_pierce"])) is Array, "main menu must decode profile arrays saved by the profile store")
	expect(not menu.has_method("_show_modes"), "main menu must not expose a mode selection page")
	expect(menu.get_settings_entries().size() >= 2, "settings page must expose audio and display options")
	menu.free()

func test_account_switch_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	expect(menu.get_local_accounts().size() >= 1, "local account list must contain at least one account")
	var account_name := "测试%d" % (Time.get_ticks_msec() % 1000000)
	var created: bool = menu.create_local_account(account_name)
	expect(created, "new local account must be creatable")
	expect(menu.switch_local_account(account_name), "local account must be switchable")
	expect(menu.get_local_profile().get("player_name", "") == account_name, "switched account must become active")
	menu.free()

func test_account_delete_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	if not menu.has_method("delete_local_account"):
		expect(false, "local accounts must support safe deletion")
		menu.free()
		return
	var original_accounts: Array[Dictionary] = menu.local_accounts.duplicate(true)
	var original_profile: Dictionary = menu.local_profile.duplicate(true)
	var suffix := str(Time.get_ticks_usec()).right(8)
	var first_name := "删A" + suffix
	var second_name := "删B" + suffix
	expect(menu.create_local_account(first_name), "first deletion fixture account must be creatable")
	expect(menu.create_local_account(second_name), "second deletion fixture account must be creatable")
	expect(menu.switch_local_account(first_name), "deletion fixture account must become active")
	expect(menu.delete_local_account(second_name), "a non-current local account must be deletable")
	expect(menu.get_local_profile().get("player_name", "") == first_name, "deleting a non-current account must preserve the active account")
	expect(menu.delete_local_account(first_name), "the current account must be deletable when another account remains")
	expect(menu.get_local_profile().get("player_name", "") != first_name, "deleting the current account must switch to a remaining account")
	expect(not menu.delete_local_account("不存在的存档"), "deleting a missing account must fail without changing data")
	while menu.get_local_accounts().size() > 1:
		var removable_name := str(menu.get_local_accounts().back().get("player_name", ""))
		expect(menu.delete_local_account(removable_name), "test cleanup must be able to remove extra accounts")
	var last_name := str(menu.get_local_accounts()[0].get("player_name", ""))
	expect(not menu.delete_local_account(last_name), "the final local account must not be deletable")
	menu.local_accounts = original_accounts
	menu.local_profile = original_profile
	menu.call("_save_local_profile")
	menu.free()

func test_account_scroll_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	menu.call("_build_background")
	menu.call("_show_account_switcher")
	var scroll := menu.find_child("AccountScroll", true, false)
	expect(scroll is ScrollContainer, "account selector must place saves inside a scroll container")
	var list := menu.find_child("AccountList", true, false)
	expect(list is VBoxContainer and list.get_parent() == scroll, "account rows must be direct content of the save scroll container")
	menu.free()

func test_home_menu_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	if not menu.has_method("get_home_action_labels") or not menu.has_method("get_home_tagline"):
		expect(false, "main menu must expose home action labels and tagline")
		menu.free()
		return
	var labels: Array = menu.get_home_action_labels()
	expect(labels == ["继续守夜", "卡组配置", "七夜记录", "温室图鉴", "设置"], "home menu must expose the approved action hierarchy")
	expect(menu.get_home_tagline() == "太阳已经熄灭，而守夜仍将继续。", "home menu must expose the approved narrative tagline")
	expect(menu.has_signal("start_requested"), "home menu must preserve the single-campaign start signal")
	menu.free()

func test_home_button_visual_hierarchy() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	menu.call("_build_background")
	menu.call("_show_home")
	var primary := menu.find_child("PrimaryStartButton", true, false) as Button
	var secondary := _find_button(menu, "七夜记录")
	var journal := menu.find_child("MenuJournal", true, false) as PanelContainer
	var archive_divider := menu.find_child("ArchiveDivider", true, false)
	var gardener_badge := menu.find_child("GardenerBadge", true, false)
	expect(primary != null and primary.get_meta("menu_button_variant", "") == "primary", "continue action must use the primary menu frame")
	expect(secondary != null and secondary.get_meta("menu_button_variant", "") == "secondary", "secondary actions must use the restrained row frame")
	expect(journal != null and journal.get_meta("visual_direction", "") == "greenhouse_gardener_record", "right menu must use the greenhouse gardener record direction")
	expect(menu.find_child("GardenerRecordHeader", true, false) != null, "gardener record must expose its archive header")
	expect(archive_divider != null, "gardener record must expose its botanical divider")
	expect(gardener_badge != null, "gardener record must expose its greenhouse badge")
	if primary != null:
		var normal_style := primary.get_theme_stylebox("normal")
		var hover_style := primary.get_theme_stylebox("hover")
		expect(normal_style is StyleBoxTexture or normal_style is StyleBoxFlat, "primary menu must use generated art or retain its readable fallback")
		expect((hover_style is StyleBoxTexture or hover_style is StyleBoxFlat) and hover_style != normal_style, "primary menu hover must remain visually distinct")
	menu.free()

func test_seven_night_contract() -> void:
	var script := _load_script("res://scripts/main_menu.gd")
	if script == null:
		return
	var menu: Control = script.new()
	if not menu.has_method("get_night_records"):
		expect(false, "main menu must expose seven-night record data")
		menu.free()
		return
	var nights: Array = menu.get_night_records()
	expect(nights.size() == 7, "night record must expose exactly seven nights")
	expect(str(nights[2].get("name", "")) == "酸雨", "third night must be named Acid Rain")
	expect(str(nights[3].get("name", "")) == "雷雨", "fourth night must be named Thunderstorm")
	expect(str(nights[4].get("name", "")) == "根冠巨像", "fifth night must name the first boss")
	menu.free()

func test_game_start_flow() -> void:
	var script := _load_script("res://scripts/game.gd")
	if script == null:
		return
	var game: Node = script.new()
	expect(game.get_target_wave_count() == 7, "level flow must use seven nights")
	expect(game.waves.size() == 7, "level flow must define seven night waves")
	expect(game.has_method("import_profile") and game.has_method("export_profile"), "game must exchange progression with the active local account")
	game.import_profile({"meta_seeds":9,"unlocked_cards":[],"mother_meta_levels":{"max_health":2},"selected_deck":[]})
	expect(game.export_profile().get("meta_seeds", 0) == 9, "game must preserve imported meta seeds")
	game.free()

func _load_script(path: String) -> Script:
	var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		failures.append("script failed to compile: %s" % path)
		return null
	return script

func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and node.text == text_value:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text_value)
		if found != null:
			return found
	return null
