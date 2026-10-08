extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var background := ColorRect.new()
	background.color = Color("28352e")
	background.size = root.size
	root.add_child(background)
	for kind in range(15):
		var plant := preload("res://scripts/plant.gd").new()
		plant.kind = kind
		plant.position = Vector2(130 + (kind % 5) * 250, 170 + (kind / 5) * 220)
		root.add_child(plant)
		plant.set_process(false)
		plant.animation_sprite.scale = Vector2.ONE
		plant.take_damage(100000.0)
		var label := Label.new()
		label.text = str(preload("res://scripts/content_data.gd").get_flower(plant.get_flower_id()).name)
		label.position = plant.position + Vector2(-45, 55)
		root.add_child(label)
	await create_timer(0.85).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/plant-death-game-preview.png")
	print("PLANT_DEATH_CAPTURE_PASS")
	quit()
