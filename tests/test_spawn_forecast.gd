extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var script = load("res://scripts/spawn_forecast.gd")
	assert(script.edge_point(Vector2.RIGHT, Vector2(1000, 700)) == Vector2(960, 350))
	var forecast = script.new()
	root.add_child(forecast)
	var queue: Array[Dictionary] = []
	for i in range(8):
		queue.append({"spawn_position": Vector2(1440,1440) + Vector2.from_angle(i * TAU / 8.0) * 600})
	forecast.update_queue(queue)
	assert(forecast.markers.size() == 8)
	var original := root.get_canvas_transform()
	for scale_value in [0.5, 1.0, 2.0]:
		for offset in [Vector2.ZERO, Vector2(-1400,-1400), Vector2(-2000,-800)]:
			root.set_canvas_transform(Transform2D(0, Vector2.ONE * scale_value, 0, offset))
			forecast._process(0)
			assert(forecast.placements.size() == 8)
			for a in range(8):
				var point: Vector2 = forecast.placements[a].position
				assert(point.is_finite())
				for b in range(a): assert(point.distance_to(forecast.placements[b].position) >= 52)
	root.set_canvas_transform(original)
	assert(forecast.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	queue.clear()
	forecast.update_queue(queue)
	forecast._process(0)
	assert(forecast.placements.is_empty())
	forecast.queue_free()
	print("SPAWN FORECAST TESTS PASSED")
	quit()
