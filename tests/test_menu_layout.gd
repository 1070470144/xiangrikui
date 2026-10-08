extends SceneTree

func _initialize() -> void:
	call_deferred("verify_layout")

func verify_layout() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	for _frame in range(4):
		await process_frame
	var start_button := _find_button(main, "继续守夜")
	var account_button := _find_button_containing(main, "本地存档")
	var record_button := _find_button(main, "七夜记录")
	if start_button == null or account_button == null or record_button == null:
		push_error("home page must expose start, account and seven-night controls")
		quit(1)
		return
	var viewport_rect := root.get_viewport().get_visible_rect()
	for control in [start_button, account_button, record_button]:
		if not viewport_rect.encloses(control.get_global_rect()):
			push_error("home control is clipped: %s" % control.text)
			quit(1)
			return
	start_button.grab_focus()
	if root.get_viewport().gui_get_focus_owner() != start_button:
		push_error("primary action must accept keyboard focus")
		quit(1)
		return
	record_button.emit_signal("pressed")
	await process_frame
	if _find_label(main, "七夜记录") == null or _find_button(main, "返回") == null:
		push_error("seven-night record page must open and expose a return action")
		quit(1)
		return
	_find_button(main, "返回").emit_signal("pressed")
	await process_frame
	account_button = _find_button_containing(main, "本地存档")
	account_button.emit_signal("pressed")
	await process_frame
	if _find_label(main, "园丁档案") == null or _find_button(main, "返回") == null:
		push_error("account page must use the shared garden journal shell")
		quit(1)
		return
	var cancel := InputEventAction.new()
	cancel.action = "cancel_action"
	cancel.pressed = true
	main.current_screen._unhandled_input(cancel)
	await process_frame
	if _find_button(main, "继续守夜") == null:
		push_error("Escape must return modal pages to the home page")
		quit(1)
		return
	_find_button(main, "温室图鉴").emit_signal("pressed")
	await process_frame
	if _find_label(main, "温室图鉴") == null or _find_button(main, "返回") == null:
		push_error("codex page must use the shared garden journal shell")
		quit(1)
		return
	_find_button(main, "返回").emit_signal("pressed")
	await process_frame
	_find_button(main, "设置").emit_signal("pressed")
	await process_frame
	if _find_label(main, "设置") == null or _find_button(main, "返回") == null or _find_button(main, "减少动态效果") == null:
		push_error("settings page must expose shared navigation and reduced motion")
		quit(1)
		return
	print("MENU LAYOUT PASSED")
	quit(0)

func _find_button(node: Node, button_text: String) -> Button:
	if node is Button and node.text == button_text:
		return node
	for child in node.get_children():
		var found := _find_button(child, button_text)
		if found != null:
			return found
	return null

func _find_button_containing(node: Node, fragment: String) -> Button:
	if node is Button and fragment in node.text:
		return node
	for child in node.get_children():
		var found := _find_button_containing(child, fragment)
		if found != null:
			return found
	return null

func _find_label(node: Node, label_text: String) -> Label:
	if node is Label and node.text == label_text:
		return node
	for child in node.get_children():
		var found := _find_label(child, label_text)
		if found != null:
			return found
	return null
