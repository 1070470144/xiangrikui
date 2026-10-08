extends RefCounted

const ContentData = preload("res://scripts/content_data.gd")
var path := "user://local_profile.cfg"
const ACCOUNTS_PATH := "user://local_accounts.cfg"

func _init(file_path: String = "user://local_profile.cfg") -> void: path = file_path

func save_profile(profile: Dictionary) -> Error:
	var config := ConfigFile.new()
	for key in profile.keys():
		var value: Variant = profile[key]
		if value is Dictionary or value is Array: value = JSON.stringify(value)
		config.set_value("profile", str(key), value)
	return config.save(path)

func load_profile() -> Dictionary:
	var result := {"account_type":"本地账号", "player_name":"温室守护者", "level_progress":0, "highest_wave":0, "play_time_minutes":0, "meta_seeds":0, "unlocked_cards":ContentData.STARTER_CARD_IDS.duplicate(), "mother_meta_levels":{"max_health":0, "starting_energy":0, "day_regen":0, "sunburst_damage":0}, "selected_deck":[]}
	var config := ConfigFile.new()
	if config.load(path) != OK: return result
	for key in result.keys():
		if config.has_section_key("profile", key):
			var value: Variant = config.get_value("profile", key, result[key])
			if key in ["unlocked_cards", "mother_meta_levels", "selected_deck"] and value is String:
				var parsed: Variant = JSON.parse_string(value)
				if parsed != null: value = parsed
			result[key] = value
	return result

func save_account_progress(profile: Dictionary) -> Error:
	var config := ConfigFile.new(); config.load(ACCOUNTS_PATH)
	var accounts: Array = config.get_value("accounts", "list", [])
	var found := false
	for account in accounts:
		if account is Dictionary and str(account.get("player_name", "")) == str(profile.get("player_name", "")):
			for key in ["meta_seeds", "unlocked_cards", "mother_meta_levels", "selected_deck"]:
				if profile.has(key): account[key] = profile[key]
			found = true; break
	if not found: accounts.append(profile.duplicate(true))
	config.set_value("accounts", "list", accounts)
	return config.save(ACCOUNTS_PATH)
