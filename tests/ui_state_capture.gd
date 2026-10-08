extends SceneTree

func _initialize() -> void:
	call_deferred("capture_state")

func capture_state() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	var state := "day"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--state="):
			state = argument.trim_prefix("--state=")
	match state:
		"night":
			game._place_plant(0, 0)
			game._place_plant(2, 1)
			game.begin_night()
			game.light_energy = 20
		"failure":
			game.mother_flower.take_damage(999.0)
		"victory":
			game.wave_index = 3
			game.phase = game.Phase.NIGHT
			game._finish_wave()
		_:
			game.light_energy = 50
	for _frame in range(4):
		await process_frame
	quit(0)
