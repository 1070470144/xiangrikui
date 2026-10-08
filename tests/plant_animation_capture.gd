extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var background := ColorRect.new(); background.color = Color("142131"); background.size = Vector2(1280,720); root.add_child(background)
	var title := Label.new(); title.text = "十五种植物 · Seedance 视频动画"; title.position = Vector2(34,20); title.add_theme_font_size_override("font_size",26); root.add_child(title)
	for kind in range(15):
		var plant := preload("res://scripts/plant.gd").new(); plant.kind = kind; plant.position = Vector2(130+(kind%5)*250,190+(kind/5)*195); root.add_child(plant); plant.set_process(false)
		plant.animation_sprite.scale = Vector2.ONE
		var label := Label.new(); label.text = str(preload("res://scripts/content_data.gd").get_flower(plant.get_flower_id()).name); label.position = plant.position + Vector2(-45,55); label.add_theme_font_size_override("font_size",19); root.add_child(label)
	await create_timer(0.75).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/previews/plant-video-animations-1280x720.png")
	print("PLANT_ANIMATION_CAPTURE_PASS")
	quit(0)
