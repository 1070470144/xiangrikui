extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var game := preload("res://scripts/game.gd").new(); root.add_child(game)
	for i in range(4): await process_frame
	game.set_process(false); game.mother_choice_pending = false; game.hud.hide_mother_choices()
	game.hud.show_plant_loadout(game.get_carried_plant_ids())
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/plant-expansion-slots-stage12-1280x720.png")
	game.hud.plant_loadout_overlay.get_node("LoadoutPanel").find_child("PlantCatalogue",true,false).scroll_vertical = 500
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/plant-expansion-catalogue-stage12-1280x720.png")
	print("PLANT_SLOTS_CAPTURE_PASS"); quit()
