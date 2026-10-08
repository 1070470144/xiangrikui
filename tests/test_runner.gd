extends SceneTree

const SUITE_PATHS := [
	"res://tests/test_content_data.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_mother_evolution.gd",
	"res://tests/test_combat_deck.gd",
	"res://tests/test_expanded_units.gd",
	"res://tests/test_card_effects.gd",
	"res://tests/test_profile_store.gd",
	"res://tests/test_run_progression.gd",
	"res://tests/test_balance.gd",
	"res://tests/test_core_rules.gd",
	"res://tests/test_game_flow.gd",
	"res://tests/test_fog_reveal.gd",
	"res://tests/test_battle_hud.gd",
	"res://tests/test_art_assets.gd",
	"res://tests/test_art_manifest.gd",
	"res://tests/test_main_menu.gd",
	"res://tests/test_deck_builder_model.gd",
	"res://tests/test_deck_builder_ui.gd",
	"res://tests/test_battlefield_spec.gd",
	"res://tests/test_world_threat_feedback.gd",
	"res://tests/test_mother_danger_feedback.gd",
	"res://tests/test_tilemap_contract.gd",
	"res://tests/test_camera_rules.gd",
	"res://tests/test_radar_rules.gd",
	"res://tests/test_terrain_map.gd",
	"res://tests/test_terrain_events.gd",
]

func _initialize() -> void:
	var failures: Array[String] = []
	for suite_path in SUITE_PATHS:
		var suite_script := ResourceLoader.load(suite_path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
		if suite_script == null or not suite_script.can_instantiate():
			failures.append("suite failed to compile: %s" % suite_path)
			continue
		if suite_path in ["res://tests/test_battle_hud.gd", "res://tests/test_deck_builder_ui.gd"]:
			failures.append_array(await suite_script.new().run())
		else:
			failures.append_array(suite_script.new().run())
	if failures.is_empty():
		print("TESTS PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
