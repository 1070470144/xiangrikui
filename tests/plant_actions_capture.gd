extends SceneTree

var plants: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func capture(state: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/plant-" + state + "-game-preview.png")

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
		plant.position = Vector2(130 + (kind % 5) * 250, 140 + (kind / 5) * 220)
		root.add_child(plant)
		plant.set_process(false)
		plant.animation_sprite.scale = Vector2.ONE
		plants.append(plant)
		var label := Label.new()
		label.text = str(preload("res://scripts/content_data.gd").get_flower(plant.get_flower_id()).name)
		label.position = plant.position + Vector2(-45, 72)
		root.add_child(label)
		plant._animate_art(true)
	await create_timer(0.35).timeout
	await capture("attack")
	for plant in plants:
		plant.take_damage(100000.0)
	await create_timer(0.8).timeout
	await capture("death")
	for plant in plants:
		assert(plant.revive())
		plant.set_process(false)
	await create_timer(0.7).timeout
	await capture("revive")
	print("PLANT_ACTIONS_CAPTURE_PASS")
	quit()
