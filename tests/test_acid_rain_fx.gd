extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world_camera.set_process(false)
	game.mother_choice_pending = false
	game.hud.hide_mother_choices()
	game.spawn_queue.clear()
	game.spawn_queue.append({"time": 99999.0, "kind": "shadow", "direction": 0})
	var fx = game.acid_rain_fx
	expect((fx.cycle_texture != null or fx.frame_textures.size() > 0) and fx.frame_count > 10, "generated animation frames and metadata must load")
	var realism_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/weather/acid_rain_realism_v2/acid_rain.strip.json"))
	expect(realism_meta is Dictionary and int(realism_meta.get("delivery_fps", 0)) == 12, "realism manifest must declare 12fps delivery")
	expect(realism_meta is Dictionary and bool(realism_meta.get("loop", false)), "realism manifest must be looped")
	if realism_meta is Dictionary and realism_meta.get("qa_passed", false):
		expect(fx.frame_textures.size() == 48, "approved realism frame list must be active")
		expect(fx.frame_size == Vector2(960, 960), "realism frame dimensions must load from manifest")
	expect(is_equal_approx(fx.cycle_seconds, 4.0), "realism animation must retain four-second cycle")
	if realism_meta is Dictionary and not realism_meta.get("qa_passed", false):
		expect(fx.cycle_texture.resource_path == "res://assets/effects/weather/acid_rain.strip.png", "failed realism QA must fall back to legacy strip")
	expect(game.get_night_rule(3).weather == "acid_rain", "third night must remain acid rain")
	game.phase = game.Phase.DAY
	game.weather = "acid_rain"
	game._process(0.01)
	expect(not fx.active, "rain must be hidden during day")
	game.phase = game.Phase.NIGHT
	game._process(0.01)
	expect(fx.active and fx.visible, "acid rain night must show rain and impacts")
	expect(fx.frame_count == 48 and fx.elapsed >= 0.0, "direct third-night entry must activate the 48-frame animation")
	var health_before: float = game.mother_flower.health
	game.environmental_tick = 1.0
	game._process_weather(0.01)
	expect(game.mother_flower.health < health_before, "acid damage must remain functional")
	game.weather_seal_time = 5.0
	game._process(0.01)
	expect(not fx.active, "weather seal must suppress rain")
	game.weather_seal_time = 0.0
	game._process(0.01)
	expect(fx.active, "rain must resume when seal expires")
	game.weather = "thunderstorm"
	game._process(0.01)
	expect(fx.active and game.thunderstorm_fx.active, "fourth night must play both weather layers")
	health_before = game.mother_flower.health
	game.environmental_tick = 1.0
	game._process_weather(0.01)
	expect(is_equal_approx(health_before - game.mother_flower.health, 1.0), "fourth night applies one acid damage tick")
	game.weather_seal_time = 5.0
	game._process(0.01)
	expect(not fx.active and not game.thunderstorm_fx.active, "seal closes both layers")
	game.weather_seal_time = 0.0
	game.weather = "fog"
	game._process(0.01)
	expect(not fx.active and not game.thunderstorm_fx.active, "fifth night has no rain layers")
	game.weather = "acid_rain"
	for phase in [game.Phase.VICTORY, game.Phase.FAILURE, game.Phase.RETREATED]:
		game.phase = phase
		game._process(0.01)
		expect(not fx.active, "rain must stop after battle")
	game.reset_model()
	game._process(0.01)
	expect(not fx.active, "restart must clear rain")
	if failures.is_empty():
		print("ACID_RAIN_FX_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
