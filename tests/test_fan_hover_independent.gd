extends "res://tests/test_card_drag_integration.gd"

func run() -> void:
	var ids: Array[String] = ["card_root_snare","card_sun_pierce","card_root_wall","card_sun_mine","card_lure_bud"]
	await fixture(ids)
	viewport.size = Vector2i(1152,648)
	await frame()
	game._refresh_card_ui()
	await frame()
	for index in range(5):
		await motion(Vector2(100,200))
		var source := card(index)
		var point: Vector2 = source.get_global_transform() * Vector2(88,70)
		await motion(point)
		check(source.z_index == 20, "Card %d exposed upper area hover reachable" % index)
		var hover_position: Vector2 = source.position
		for count in range(6):
			await motion(point + Vector2(count % 2,0))
			game._refresh_card_ui()
			check(source.position == hover_position and source.z_index == 20, "Card %d upper hover no flicker on motion %d" % [index,count])
		check(source.position == hover_position and source.z_index == 20, "Card %d stationary upper hover stable" % index)
		await motion(Vector2(100,200))
		var low: Vector2 = source.get_global_transform() * Vector2(88,175)
		low.y = minf(low.y, 640)
		await motion(low)
		check(source.z_index == 20, "Card %d visible bottom area hover reachable" % index)
		var raised: Vector2 = source.position
		for count in range(6):
			await motion(low + Vector2(count % 2,0))
			game._refresh_card_ui()
			check(source.position == raised and source.z_index == 20, "Card %d bottom hover no flicker on motion %d" % [index,count])
		check(source.position == raised and source.z_index == 20, "Card %d stationary bottom hover stable" % index)
		await motion(Vector2(100,200))
		await start_control(source)
		await drop(Vector2(580,640))
		untouched(100,ids,"Card %d reachable native drag returns to hand" % index)
		check(not source._hovered and source.z_index == 0, "Card %d release restores rest pose" % index)
	if failures.is_empty(): print("FAN INDEPENDENT HOVER PASSED")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
