extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var menu := preload("res://scripts/main_menu.gd").new()
	root.add_child(menu)
	menu._show_codex()
	await process_frame
	var view := menu.page_stack.get_node("温室图鉴Page")
	for category in 2:
		view.tabs[category].pressed.emit()
		assert(view.category == category and view.list.get_child_count() == (15 if category == 0 else 5))
		for index in view.groups[category].size():
			view.list.get_child(index).pressed.emit()
			assert(view.title.text == view.groups[category][index].name)
			assert(view.hero.texture != null)
			assert(view.description.text == view.groups[category][index].description)
			assert("生命" in view.stats.text)
			assert(view.hero.size == Vector2(451, 369))
			assert(view.hero_animation.visible and not view.hero.visible)
			assert(view.animation_choice.item_count == 4)
			for action in view.animation_choice.item_count:
				view.animation_choice.select(action)
				view.animation_choice.item_selected.emit(action)
				var state := str(view.animation_choice.get_item_metadata(action))
				assert(view.hero_animation.animation == state and view.hero_animation.is_playing())
				assert(view.hero_animation.frame == 0)
				if category == 0:
					var calibration := preload("res://scripts/plant_animation_library.gd").get_display_scale(view.groups[category][index].id, state)
					assert(is_equal_approx(view.hero_animation.scale.x, view._preview_scale * calibration))
				await create_timer(0.12).timeout
				assert(view.hero_animation.frame > 0, "Codex animation must advance")
				var duration: float = view.hero_animation.sprite_frames.get_frame_count(state) / view.hero_animation.sprite_frames.get_animation_speed(state)
				view.hero_animation.frame = view.hero_animation.sprite_frames.get_frame_count(state) - 1
				await create_timer(duration / view.hero_animation.sprite_frames.get_frame_count(state) * 2.0).timeout
				assert(view.hero_animation.is_playing(), "One-shot previews must replay")
	for child in view.get_children():
		if child is Button and child.text == "返回": child.pressed.emit(); break
	await process_frame
	assert(menu.page_stack.has_node("HomePage"))
	print("GREENHOUSE CODEX TESTS PASSED")
	quit(0)
