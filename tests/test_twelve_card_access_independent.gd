extends "res://tests/test_card_drag_integration.gd"

# Exact instances are checked, including the two copies of each card ID.
func run() -> void:
	var ids: Array[String]=["card_sun_pierce","card_sun_pierce","card_root_snare","card_root_snare","card_emergency_dew","card_emergency_dew","card_root_wall","card_root_wall","card_sun_mine","card_sun_mine","card_lure_bud","card_lure_bud"]
	await fixture(ids)
	viewport.size=Vector2i(1152,648); await frame(); game._refresh_card_ui(); await frame()
	var instances: Array[Control]=[]
	for index in range(12): instances.append(card(index))
	for index in range(12):
		var source: Control=instances[index]
		var found:=false
		var reach:=Vector2.ZERO
		for y in [20,40,60,90,120,150,180]:
			if found: break
			for x in [12,24,40,70,100,140,165]:
				await motion(Vector2(50,200))
				var point: Vector2=source.get_global_transform()*Vector2(x,y)
				if not Rect2(Vector2.ZERO,Vector2(1152,648)).has_point(point): continue
				await motion(point)
				if source._hovered and viewport.gui_get_hovered_control()==source:
					found=true; reach=point; break
		check(found,"Twelve-card exact instance %d has exposed pointer access"%index)
		if not found: continue
		var raised: Vector2=source.position
		for jitter in range(3):
			await motion(reach+Vector2(jitter%2,0)); game._refresh_card_ui()
			check(source._hovered and source.position==raised,"Exact instance %d hover remains stable %d"%[index,jitter])
		# Press an interior position of the raised exact instance, then cross
		# the native Godot drag threshold without calling any card signal.
		await motion(source.get_global_transform()*Vector2(88,70))
		check(viewport.gui_get_hovered_control()==source,"Exact instance %d remains pointer target after lift"%index)
		await button(true); await motion(mouse+Vector2(0,-40),true)
		check(source._dragging and viewport.gui_is_dragging(),"Exact instance %d starts native drag"%index)
		for other in instances:
			if other!=source: check(not other._dragging,"Exact instance %d does not drag another copy"%index)
		await drop(Vector2(580,640))
		untouched(100,ids,"Exact instance %d hand return"%index)
		check(game.hud.combat_hand_row.get_child(index)==source,"Exact instance %d survives return"%index)
		check(not source._dragging and source.z_index==0,"Exact instance %d returns to fan pose"%index)
	if failures.is_empty(): print("TWELVE_CARD_ACCESS_INDEPENDENT instances=12 failures=0")
	else:
		for failure in failures: push_error(failure)
		print("TWELVE_CARD_ACCESS_INDEPENDENT instances=12 failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
