extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world_camera.set_process(false)
	game.mother_choice_pending = false
	game.spawn_queue.assign([{"time":99999.0, "kind":"shadow", "direction":0}])
	var fx = game.thunderstorm_fx
	expect(game.get_night_rule(4).weather == "thunderstorm", "night four must remain thunderstorm")
	expect(fx != null and fx.frame_fps > 0.0, "thunderstorm fx must initialize")
	game.phase = game.Phase.NIGHT
	game.weather = "thunderstorm"
	game.weather_seal_time = 0.0
	game._process(0.01)
	expect(game.acid_rain_fx.active, "fourth night includes third-night rain")
	expect(fx.active and fx.visible, "thunderstorm must activate at night")
	var offset: float = fx.cloud_offset
	for i in range(20): fx._process(0.5)
	expect(fx.cloud_offset != offset, "cloud layer must move over time")
	var old_trigger: int = fx.trigger_count
	fx.lightning_wait = 0.0
	fx._process(0.01)
	expect(fx.trigger_count > old_trigger and fx.lightning_playing, "lightning must trigger independently")
	fx._process(0.05)
	expect(fx.lightning_phase > 0.0, "lightning playback advances")
	# Use existing accepted textures as a loader fixture, not as storm artwork.
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/weather/acid_rain_realism_v2/acid_rain.strip.json"))
	fixture["trigger_seconds"] = 4.0
	fx._apply_manifest(fixture)
	expect(fx.qa_passed and fx.frame_textures.size() == 48 and fx.frame_size == Vector2(960, 960), "manifest loads complete cached frame list")
	fx.lightning_playing = true
	fx.lightning_phase = 0.0
	fx._process(0.1)
	var previous_frame: int = fx.lightning_frame
	fx._process(0.1)
	expect(fx.lightning_frame > previous_frame, "loaded frames advance with manifest timing")
	fixture["frame_paths"] = ["res://assets/effects/weather/missing.png"]
	fx._apply_manifest(fixture)
	expect(not fx.qa_passed and fx.frame_textures.is_empty(), "incomplete animation uses fallback")
	fx._load_manifest("res://assets/effects/weather/missing.json")
	expect(not fx.qa_passed and fx.frame_textures.is_empty(), "missing manifest enables procedural fallback")
	game.weather_seal_time = 4.0
	game._process(0.01)
	expect(not fx.active, "weather seal must hide thunderstorm")
	game.weather_seal_time = 0.0
	game.weather = "acid_rain"
	game._process(0.01)
	expect(not fx.active, "acid rain must not show thunderstorm")
	game.weather = "thunderstorm"
	game.phase = game.Phase.DAY
	game._process(0.01)
	expect(not fx.active, "day must hide thunderstorm")
	for phase in [game.Phase.VICTORY, game.Phase.FAILURE, game.Phase.RETREATED]:
		game.phase = phase
		game._process(0.01)
		expect(not fx.active and not game.acid_rain_fx.active, "terminal states stop both layers")
	game.reset_model()
	expect(not fx.active, "reset must clear thunderstorm")
	if failures.is_empty():
		print("THUNDERSTORM_FX_TESTS_PASSED")
		quit(0)
		return
	for failure in failures: push_error(failure)
	quit(1)
