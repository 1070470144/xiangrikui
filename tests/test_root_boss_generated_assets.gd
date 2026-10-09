extends SceneTree

var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var library = load("res://scripts/monster_animation_library.gd")
	var loader := root.get_node("PlantResources")
	library.request_species("root_crown_colossus")
	for i in range(2400):
		if library.get_frames("root_crown_colossus") != null: break
		await process_frame
	var frames: SpriteFrames = library.get_frames("root_crown_colossus")
	check(frames != null, "Generated boss frames must finish loading")
	if frames != null:
		for state in ["idle", "walk", "attack", "slam", "summon", "spawn", "death", "exposed", "enraged"]:
			check(frames.has_animation(state) and frames.get_frame_count(state) >= 100, "Missing full-rate state " + state)
	var enemy: Node = load("res://scripts/enemy.gd").new()
	root.add_child(enemy)
	enemy.configure(enemy.Kind.ROOT_COLOSSUS, Vector2.ZERO)
	enemy.set_process(false)
	var hits: Array = []
	enemy.area_damage_requested.connect(func(_p, _r, _d): hits.append(1))
	enemy.start_boss_skill("slam", Vector2.ZERO, 1.2)
	enemy.advance_boss(1.2)
	enemy._update_art_texture()
	check(hits.size() == 1, "Slam damage must happen exactly once")
	check(enemy._last_art_state == "slam" and abs(enemy._last_art_frame - 50) <= 1, "Logical impact must display measured source impact frame")
	enemy.advance_boss(0.1)
	check(hits.size() == 1, "Animation recovery must not repeat damage")
	var effect: Node = load("res://scripts/root_boss_video_effect.gd").new()
	root.add_child(effect)
	check(effect.configure("impact", Vector2.ZERO, 112, 0.5, enemy.get_instance_id()), "Generated impact must load")
	effect._process(0.5)
	check(effect.is_queued_for_deletion(), "Effect must expire at its logical lifetime")
	var game: Node = load("res://scripts/game.gd").new()
	root.add_child(game)
	var feedback: Node = load("res://scripts/boss_battle_feedback.gd").new()
	game.add_child(feedback)
	feedback.configure(game)
	game.set_process(false)
	feedback._video("summon_fx", Vector2.ZERO, 100, 1, enemy)
	check(not feedback.video_effects.is_empty(), "Boss event must create video effect")
	feedback.clear_owner(enemy)
	for fx in feedback.video_effects:
		check(not is_instance_valid(fx) or fx.is_queued_for_deletion(), "Owner cleanup must remove generated effects")
	game.queue_free()
	enemy.queue_free()
	await process_frame
	for message in failures: push_error(message)
	print("ROOT BOSS GENERATED ASSETS ", "PASSED" if failures.is_empty() else "FAILED", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
