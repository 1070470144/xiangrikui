extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var menu := preload("res://scripts/main_menu.gd").new()
	root.add_child(menu)
	menu.local_profile["level_progress"] = 3
	menu._show_night_records()
	await process_frame
	var page := menu.page_stack.get_node("七夜记录Page")
	assert(page.chapters.size() == 7)
	assert(page.selected == 4 and page.status.text == "下一次守夜")
	assert(page.hero.size == Vector2(390, 258), "hero artwork must fit its detail window")
	for chapter in page.chapters:
		assert(chapter.get_node("ChapterArt").size == Vector2(130, 101), "chapter artwork must fit its thumbnail window")
	for number in range(1, 8):
		page.chapters[number - 1].pressed.emit()
		assert(page.selected == number)
		assert(page.hero.texture.resource_path.ends_with("night_%d.png" % number))
		assert(str(menu.NIGHT_RECORDS[number - 1].name) in page.heading.text)
		assert(page.status.text == ("已守住" if number <= 3 else ("下一次守夜" if number == 4 else "尚未完成")))
		assert(root.get_viewport().get_visible_rect().encloses(page.chapters[number - 1].get_global_rect()))
	for child in page.get_children():
		if child is Button and child.text == "返回": child.pressed.emit(); break
	await process_frame
	assert(menu.page_stack.has_node("HomePage"))
	for progress in [0, 7]:
		menu.local_profile["level_progress"] = progress
		menu._show_night_records()
		page = menu.page_stack.get_node("七夜记录Page")
		assert(page.selected == (1 if progress == 0 else 7))
		assert(page.status.text == ("下一次守夜" if progress == 0 else "已守住"))
	print("NIGHT RECORDS TESTS PASSED")
	quit(0)
