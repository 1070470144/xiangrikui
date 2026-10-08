extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var capture_size := Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var dimensions := arg.trim_prefix("--size=").split("x")
			capture_size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	root.size = capture_size
	var suffix := "-%dx%d" % [capture_size.x,capture_size.y]
	var game := load("res://scripts/game.gd").new() as Node2D
	root.add_child(game)
	for i in range(4): await process_frame
	game.set_process(false); game.mother_choice_pending = false; game.hud.hide_mother_choices()
	game.hud.set_phase_layout("day")
	var ids: Array[String] = ["deploy_thorn","deploy_prism","deploy_lantern","deploy_frost","deploy_honeydew"]
	game.hud.set_plant_loadout(ids)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/battle-flow-v7-day"+suffix+".png")
	game.hud.show_plant_loadout(ids)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/battle-flow-v7-loadout"+suffix+".png")
	game.hud.plant_loadout_overlay.choices[2].button_pressed = false
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/battle-flow-v7-loadout-selection"+suffix+".png")
	game.hud.hide_plant_loadout()
	game.hud.update_battle_state({"phase":"night","night":1,"health":300,"max_health":300,"energy":100,"seeds":5})
	game.hud.show_message("")
	var cards: Array[String] = []
	for entry in preload("res://scripts/content_data.gd").COMBAT_CARDS: cards.append(entry.id)
	cards.resize(12)
	game.hud.show_combat_hand(cards,"night",100,false)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/battle-flow-v7-night-12"+suffix+".png")
	print("FLOW_UI_CAPTURE_PASS")
	quit()

