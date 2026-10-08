extends SceneTree

## Rendered benchmark only. Fixture health prevents early failure; production stats are untouched.
const Game = preload("res://scripts/game.gd")
const Plant = preload("res://scripts/plant.gd")
const Balance = preload("res://scripts/balance.gd")
const Spec = preload("res://scripts/battlefield_spec.gd")
const LOADOUT := ["deploy_thorn", "deploy_prism", "deploy_storm", "deploy_spear", "deploy_burst"]
const KINDS := [Plant.Kind.THORN, Plant.Kind.PRISM, Plant.Kind.STORM, Plant.Kind.SPEAR, Plant.Kind.BURST]
const OUTPUT := "res://output/performance/"

class PressureGame extends "res://scripts/game.gd":
	func _spawn_enemy(kind: int, direction: int, entry: Dictionary = {}) -> void:
		super._spawn_enemy(kind, direction, entry)
		# Keep the full crowd alive through the stable interval; fixture only.
		if not active_enemies.is_empty():
			var enemy: Node = active_enemies.back()
			enemy.max_health = 1000000000.0
			enemy.health = enemy.max_health

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a rendered Godot run for frame-time and shadow acceptance")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for pass_name in ["cold", "cached"]:
		var game := PressureGame.new()
		game.set_starting_night(7)
		game.set_run_seed(777)
		root.add_child(game)
		current_scene = game
		game.set_carried_plant_ids(LOADOUT)
		game.choose_mother_card("sun_arrow")
		game.world_camera.position_smoothing_enabled = false
		game.world_camera.position = Spec.CENTER
		game.world_camera.zoom = Vector2.ONE * 0.8
		game.mother_flower.max_health = 1000000000.0
		game.mother_flower.health = game.mother_flower.max_health
		for i in KINDS.size():
			var plant := Plant.new()
			plant.position = Spec.CENTER + Vector2.from_angle(float(i) * TAU / KINDS.size()) * 150.0
			plant.configure(KINDS[i], 0)
			plant.max_health = 1000000000.0; plant.health = plant.max_health
			plant.projectile_requested.connect(game._on_projectile_requested)
			plant.status_projectile_requested.connect(game._on_status_projectile_requested)
			game.add_child(plant)
			game.plants.append(plant)
			plant.set_power_source(game.mother_flower)
		game.begin_night()
		var records: Array[Dictionary] = []
		var stable: Array[int] = []
		var peak := 0
		var duration := float(Balance.NIGHT_CONFIGS[6].duration)
		var last := Time.get_ticks_usec()
		var screenshot_taken := false
		while game.spawn_clock < duration + 60.0:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			var sample := game.get_latest_performance_sample()
			if sample.is_empty(): last = now; continue
			sample["wall_frame_usec"] = now - last
			sample["clock"] = game.spawn_clock
			last = now
			peak = maxi(peak, int(sample.alive))
			records.append(sample)
			if game.spawn_clock >= duration: stable.append(int(sample.wall_frame_usec))
			if game.spawn_clock >= duration and not screenshot_taken:
				root.get_texture().get_image().save_png(OUTPUT + pass_name + "-shadows.png")
				screenshot_taken = true
				last = Time.get_ticks_usec()
			if game.phase != Game.Phase.NIGHT:
				push_error("Benchmark ended before completing its stable interval")
				quit(1); return
		var file := FileAccess.open(OUTPUT + pass_name + ".csv", FileAccess.WRITE)
		assert(file != null)
		var keys := ["clock", "wall_frame_usec", "frame_usec", "alive", "spawned", "spawn_usec", "query_usec", "query_candidates", "shadow_usec", "ui_usec"]
		file.store_csv_line(PackedStringArray(keys))
		for sample in records:
			var fields := PackedStringArray()
			for key in keys: fields.append(str(sample[key]))
			file.store_csv_line(fields)
		file.close()
		stable.sort()
		var p95 := float(stable[ceili(stable.size() * 0.95) - 1]) / 1000.0
		print("MONSTER_PRESSURE %s peak_alive=%d stable_P95_ms=%.3f target_met=%s" % [pass_name, peak, p95, str(p95 <= 16.7)])
		game.queue_free()
		current_scene = null
		await process_frame
	quit()
