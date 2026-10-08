extends SceneTree

# Deterministic mechanism fixture, not a claim of generated artwork approval.
var game: Node2D
var boss: Node
const OUT := "res://output/root-boss"

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.choose_mother_card("sun_arrow")
	game.hud.hide_mother_choices()
	game.mother_choice_pending = false
	var center: Vector2 = game.battlefield.CENTER
	game.light_energy = 200
	game.seeds = 50
	game._place_light_node(center + Vector2(170, 0))
	game._place_light_node(center + Vector2(320, 60))
	for entry in [[Vector2(240, -70), game.Selection.THORN], [Vector2(320, 150), game.Selection.PRISM], [Vector2(80, -110), game.Selection.THORN], [Vector2(-40, 100), game.Selection.FROST]]:
		game.light_energy = 200
		game._place_plant_at(center + entry[0], entry[1])
	game.wave_index = 5
	game.phase = game.Phase.NIGHT
	game.weather = "fog"
	game.boss_active = true
	game.world_lighting.set_phase(false, 0)
	game.night_fog.set_active(true)
	game.night_fog._process(30)
	game.mother_flower.on_night_started()
	game.world_camera.set_process(false)
	game.world_camera.position_smoothing_enabled = false
	game.world_camera.zoom = Vector2.ONE
	game.world_camera.position = center + Vector2(130, 0)
	game.world_camera.force_update_scroll()
	game._spawn_enemy(game.EnemyScript.Kind.ROOT_COLOSSUS, 0, {"spawn_position":center + Vector2(370, -10)})
	boss = game.get_active_enemies().back()
	game.hud.show_message("第五关机制验证 · 当前为占位造型，写实素材接口待恢复")
	for i in range(90): await process_frame
	game.hud.update_battle_state(game.get_hud_battle_state())
	if "--fight" in OS.get_cmdline_user_args():
		await fight()
	else:
		await scenes()
	game.queue_free()
	await process_frame
	quit()

func scenes() -> void:
	boss.set_process(false)
	game.mother_flower.set_process(false)
	for plant in game.plants: plant.set_process(false)
	game.boss_feedback.set_process(false)
	boss.boss_light_progress = 0
	game.boss_feedback._process(0)
	await view("normal")
	boss.start_boss_skill("slam", game.plants[0].global_position, 1.2)
	for i in range(36):
		boss.advance_boss(1.0 / 30)
		boss._animate_art(1.0 / 30)
		game.boss_feedback._process(1.0 / 30)
		if i == 18: await view("slam")
		await process_frame
	boss.advance_boss(0.01)
	game.boss_feedback._process(0)
	await view("impact")
	boss.expose_core(3)
	boss.boss_state = "exposed"
	boss.queue_redraw()
	game.boss_feedback._process(0)
	await view("exposed")
	boss.core_exposed_time = 0
	boss.health = boss.max_health * 0.24
	boss.boss_enraged = true
	boss.queue_redraw()
	game.boss_feedback._process(0)
	await view("enraged")
	for i in range(60): await process_frame

func fight() -> void:
	for plant in game.plants: plant.combat_active = true
	var elapsed := 0.0
	var events: Array[Dictionary] = []
	boss.boss_special_finished.connect(func(kind: String) -> void: events.append({"kind":kind, "health":boss.health}))
	while elapsed < 150 and is_instance_valid(boss) and boss.health > 0 and game.mother_flower.health > 0:
		await process_frame
		elapsed += 1.0 / 30
		if int(elapsed * 30) % 30 == 0:
			game._rebuild_network()
			game.hud.update_battle_state(game.get_hud_battle_state())
	var result := {"duration_seconds":elapsed, "result":"boss_defeated" if not is_instance_valid(boss) or boss.health <= 0 else ("mother_defeated" if game.mother_flower.health <= 0 else "timeout"), "generated_art":false, "events":events}
	var file := FileAccess.open(OUT + "/fight-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("BOSS FIGHT: ", result.result, " at ", elapsed, "s")
	await view("fight-end")
	for i in range(60): await process_frame

func view(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + label + ".png")
