extends RefCounted

const ProfileStore = preload("res://scripts/profile_store.gd")
var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	var path := "res://tests/.test_content_profile.cfg"
	var store := ProfileStore.new(path)
	var old_profile := {"player_name":"旧园丁", "highest_wave":9}
	expect(store.save_profile(old_profile) == OK, "profile store must save dictionaries")
	var loaded := store.load_profile()
	expect(loaded["player_name"] == "旧园丁", "existing fields must survive migration")
	expect(loaded["meta_seeds"] == 0, "old profile must receive meta seed default")
	expect((loaded["unlocked_cards"] as Array).size() == 8, "old profile must receive starter card unlocks")
	expect((loaded["mother_meta_levels"] as Dictionary).size() == 4, "old profile must receive mother track defaults")
	expect(loaded.has("highest_wave"), "obsolete highest wave must remain compatible on disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return failures
