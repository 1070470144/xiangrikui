extends SceneTree

const Battlefield = preload("res://scripts/battlefield.gd")
const MotherFlower = preload("res://scripts/mother_flower.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	var mother := MotherFlower.new()
	mother.position = battlefield.CENTER
	root.add_child(mother)
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.make_current()
	camera.position = battlefield.CENTER + Vector2(80, 10)
	camera.zoom = Vector2.ONE * 2.05
	for i in range(5): await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("res://output/imagegen/tilesets/battlefield-tilemap-near.png")
	camera.position = battlefield.CENTER
	camera.zoom = Vector2.ONE * 0.42
	for i in range(5): await process_frame
	image = root.get_viewport().get_texture().get_image()
	image.save_png("res://output/imagegen/tilesets/battlefield-tilemap-overview.png")
	camera.zoom = Vector2.ONE * 2.05
	var cells: Array[Vector2i] = []
	for y in range(33, 38):
		for x in range(38, 44):
			cells.append(Vector2i(x, y))
	battlefield.terrain_map.apply_terrain_patch(cells, "swamp")
	for i in range(5): await process_frame
	image = root.get_viewport().get_texture().get_image()
	image.save_png("res://output/imagegen/tilesets/battlefield-tilemap-acid.png")
	quit(0)
