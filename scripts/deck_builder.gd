extends Control
class_name DeckBuilder

signal profile_patch_requested(patch: Dictionary)
signal save_deck_requested(deck: Array[String])
signal back_requested

const Model = preload("res://scripts/deck_builder_model.gd")
const CardView = preload("res://scripts/deck_card_view.gd")
const DeckRow = preload("res://scripts/deck_list_item.gd")
const ContentData = preload("res://scripts/content_data.gd")
const Text = preload("res://scripts/deck_builder_text.gd")
const ArtManifest = preload("res://scripts/art_manifest.gd")
const Visual = preload("res://scripts/deck_builder_style.gd")
const ART_MANIFEST_PATH := "res://art_source/manifests/deck_builder.json"
var model: RefCounted
var selected_card_id := ""
var selected_deck_card_id := ""
var phase_filter := "all"
var sort_mode := "default"

func _ready() -> void:
	for warning in ArtManifest.apply_file(ART_MANIFEST_PATH, self):
		push_warning(warning)
	_apply_visuals()
	_setup_drop_targets()
	$Root/TopBar/BackButton.pressed.connect(request_back)
	$Root/BottomBar/ClearButton.pressed.connect(func(): model.clear_draft(); refresh_all())
	$Root/BottomBar/RestoreButton.pressed.connect(func(): model.restore_saved(); refresh_all())
	$Root/BottomBar/AutoFillButton.pressed.connect(func(): model.auto_fill(); refresh_all())
	$Root/BottomBar/SaveButton.pressed.connect(request_save)
	var phases: OptionButton = $Root/MainSplit/LibraryPanel/Library/Tools/PhaseFilter
	for label in ["全部", "白昼", "夜晚", "通用"]: phases.add_item(label)
	phases.item_selected.connect(func(index): set_phase_filter(["all", "day", "night", "any"][index]))
	var sorting: OptionButton = $Root/MainSplit/LibraryPanel/Library/Tools/SortOption
	for label in ["默认排序", "按光能", "按稀有度"]: sorting.add_item(label)
	sorting.item_selected.connect(func(index): set_sort_mode(["default", "cost", "rarity"][index]))
	if model != null: refresh_all()

func setup(profile: Dictionary) -> void:
	model = Model.new(profile)
	var cards: Array = model.get_visible_cards()
	if not cards.is_empty(): selected_card_id = str(cards[0].id)
	if is_node_ready(): refresh_all()

func get_model() -> RefCounted: return model

func select_card(card_id: String) -> void:
	selected_card_id = card_id
	selected_deck_card_id = card_id if model.draft.has(card_id) else ""
	if is_node_ready():
		_refresh_selection()

func request_add(card_id: String) -> void:
	selected_card_id = card_id
	var reason: String = model.can_add(card_id)
	if reason.is_empty(): model.add_card(card_id)
	if is_node_ready(): refresh_all()
	if not reason.is_empty() and is_node_ready(): show_status(reason)

func request_remove(card_id: String) -> void:
	selected_card_id = card_id
	selected_deck_card_id = card_id
	model.remove_card(card_id)
	if is_node_ready(): refresh_all()

func set_phase_filter(value: String) -> void:
	phase_filter = value
	if is_node_ready(): refresh_library()

func set_sort_mode(value: String) -> void:
	sort_mode = value
	if is_node_ready(): refresh_library()

func refresh_all() -> void:
	refresh_top_bar(); refresh_library(); refresh_deck_list(); refresh_cost_curve(); refresh_actions()

func refresh_top_bar() -> void:
	$Root/TopBar/SeedLabel.text = "种子 %d" % model.meta_seeds
	$Root/TopBar/DeckCountLabel.text = "卡组 %d / %d" % [model.draft.size(), ContentData.DECK_SIZE]
	$Root/TopBar/UnsavedLabel.visible = model.is_dirty()

func refresh_library() -> void:
	var scroll: ScrollContainer = $Root/MainSplit/LibraryPanel/Library/CardScroll
	var previous := scroll.scroll_vertical
	var grid: GridContainer = $Root/MainSplit/LibraryPanel/Library/CardScroll/CardGrid
	_clear(grid)
	for card in model.get_visible_cards(phase_filter, sort_mode):
		var view = CardView.new()
		var id := str(card.id)
		view.configure(card, model.unlocked_cards.has(id), model.draft.count(id), int(card.get("copies_allowed", 1)), model.can_add(id) if model.unlocked_cards.has(id) else "")
		view.drag_owner = self
		view.selected.connect(select_card); view.detail_requested.connect(show_card_detail); view.add_requested.connect(func(card_id: String): request_add.call_deferred(card_id)); grid.add_child(view)
		_forward_component_buttons(view, "library")
	scroll.set_deferred("scroll_vertical", previous)
	_refresh_selection()

func refresh_deck_list() -> void:
	var list: VBoxContainer = $Root/MainSplit/Sidebar/DeckScroll/DeckList
	_clear(list)
	var unique: Array = model.draft.duplicate(); unique.sort(); var seen := {}
	for id in unique:
		if seen.has(id): continue
		seen[id] = true
		var row = DeckRow.new(); row.configure(ContentData.get_card(id), model.draft.count(id)); row.drag_owner = self; row.selected.connect(select_card); row.detail_requested.connect(show_card_detail); row.remove_requested.connect(func(card_id: String): request_remove.call_deferred(card_id)); list.add_child(row)
		_forward_component_buttons(row, "deck")
	if unique.is_empty():
		var hint := Label.new(); hint.text = "卡组为空\n将左侧卡牌拖到这里"; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; hint.custom_minimum_size.y = 80; hint.modulate = Visual.MUTED; hint.mouse_filter = Control.MOUSE_FILTER_IGNORE; list.add_child(hint)

func refresh_cost_curve() -> void:
	var curve: HBoxContainer = $Root/MainSplit/Sidebar/CostCurve
	_clear(curve)
	var buckets := {}
	for id in model.draft:
		var cost := int(ContentData.get_card(id).get("energy_cost", 0)); buckets[cost] = int(buckets.get(cost, 0)) + 1
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for cost in buckets:
		var index := mini(floori(float(cost) / 5.0), 5)
		counts[index] += int(buckets[cost])
	var peak := maxi(1, counts.max())
	for index in 6:
		var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; curve.add_child(column)
		var value := Label.new(); value.text = str(counts[index]); value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; value.add_theme_font_size_override("font_size", 12); value.modulate = Visual.GOLD; column.add_child(value)
		var bar := ProgressBar.new(); bar.custom_minimum_size = Vector2(28, 20); bar.max_value = peak; bar.value = counts[index]; bar.show_percentage = false; bar.add_theme_stylebox_override("background", Visual.panel(Color("172a27"), Color("172a27"), 0)); bar.add_theme_stylebox_override("fill", Visual.panel(Color("988653"), Color("988653"), 0)); column.add_child(bar)
		var label := Label.new(); label.text = "%d–%d" % [index * 5, index * 5 + 4] if index < 5 else "25+"; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 11); label.modulate = Visual.MUTED; column.add_child(label)

func refresh_actions() -> void:
	var errors: Array[String] = model.validate_draft()
	$Root/MainSplit/Sidebar/ValidationLabel.text = "卡组可用" if errors.is_empty() else errors[0]
	$Root/MainSplit/Sidebar/ValidationLabel.modulate = Color("b6d6a3") if errors.is_empty() else Visual.GOLD
	$Root/BottomBar/SaveButton.disabled = not errors.is_empty()

func show_status(message: String) -> void: $Root/MainSplit/Sidebar/ValidationLabel.text = message

func confirm_unlock(card_id: String) -> void:
	var card := ContentData.get_card(card_id)
	if card.is_empty() or model.unlocked_cards.has(card_id): return
	var cost := int(card.get("unlock_cost", -1))
	if cost < 0 or model.meta_seeds < cost:
		show_status("种子不足，还差 %d" % maxi(0, cost - model.meta_seeds))
		return
	var existing := find_child("UnlockDialog", true, false)
	if existing != null: existing.queue_free()
	var dialog := ConfirmationDialog.new()
	dialog.name = "UnlockDialog"
	dialog.title = "解锁卡牌"
	dialog.dialog_text = "消耗 %d 颗种子解锁「%s」？" % [cost, str(card.name)]
	dialog.ok_button_text = "确认解锁"
	dialog.cancel_button_text = "取消"
	$DialogLayer.add_child(dialog)
	dialog.confirmed.connect(func(): _commit_unlock(card_id); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.call_deferred("popup_centered", Vector2i(420, 190))

func _commit_unlock(card_id: String) -> void:
	var before: int = model.meta_seeds
	if not model.try_unlock(card_id): show_status("种子不足或卡牌不可解锁"); return
	set_meta("pending_unlock", {"card_id":card_id, "before":before})
	profile_patch_requested.emit(model.export_profile_patch())
	refresh_all()

func report_profile_patch_result(success: bool) -> void:
	var pending: Dictionary = get_meta("pending_unlock", {})
	if not success and not pending.is_empty(): model.rollback_unlock(str(pending.card_id), int(pending.before))
	remove_meta("pending_unlock"); refresh_all()

func request_save() -> void:
	if model.validate_draft().is_empty(): save_deck_requested.emit(model.draft.duplicate())

func report_deck_save_result(success: bool) -> void:
	if success: model.mark_saved(); back_requested.emit()
	else: show_status("保存失败，请重试")

func request_back() -> void:
	if model == null or not model.is_dirty(): back_requested.emit(); return
	show_status("卡组尚未保存：请保存、恢复或继续编辑")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed(): return
	var overlay := get_node_or_null("DialogLayer/CardDetailOverlay") as Control
	if overlay != null and overlay.visible:
		if event.keycode == KEY_ESCAPE: overlay.hide(); get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ENTER and not selected_card_id.is_empty(): request_add(selected_card_id)
	elif event.keycode == KEY_DELETE and not selected_deck_card_id.is_empty(): request_remove(selected_deck_card_id)
	elif event.keycode == KEY_ESCAPE: request_back()

func _describe_card(card: Dictionary) -> String:
	return "消耗 %d 光能 · 每组最多 %d 张" % [int(card.energy_cost), int(card.get("copies_allowed", 1))]

func show_card_detail(card_id: String) -> void:
	var card := ContentData.get_card(card_id)
	if card.is_empty() or model == null: return
	select_card(card_id)
	var overlay := get_node_or_null("DialogLayer/CardDetailOverlay") as Control
	if overlay == null:
		overlay = Control.new(); overlay.name = "CardDetailOverlay"; overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); $DialogLayer.add_child(overlay)
		var shade := ColorRect.new(); shade.color = Color(0.015, 0.025, 0.03, 0.84); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
		shade.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: overlay.hide())
		var center := CenterContainer.new(); center.name = "Center"; center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); center.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(center)
	_build_card_turntable(overlay, card_id)
	overlay.show()

func _build_card_turntable(overlay: Control, card_id: String) -> void:
	var card := ContentData.get_card(card_id)
	var center := overlay.get_node("Center") as CenterContainer
	var old := center.get_node_or_null("Turntable")
	if old != null: center.remove_child(old); old.queue_free()
	var table := PanelContainer.new(); table.name = "Turntable"; table.custom_minimum_size = Vector2(380, 520); table.add_theme_stylebox_override("panel", Visual.panel(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 16)); table.theme = Visual.theme(); center.add_child(table)
	var stack := Control.new(); stack.name = "CardStack"; stack.custom_minimum_size = Vector2(350, 480); table.add_child(stack)
	var stage := Control.new(); stage.name = "CardStage"; stage.size = Vector2(350, 430); stage.set_script(preload("res://scripts/card_turntable.gd")); stack.add_child(stage)
	var front := _card_face(card_id, card, false); front.name = "Front"; stage.add_child(front)
	var back := _card_face(card_id, card, true); back.name = "Back"; back.visible = false; stage.add_child(back)
	var flip := Button.new(); flip.name = "RotateButton"; flip.text = "旋转 ↻"; flip.position = Vector2(0, 445); flip.size = Vector2(85, 34); flip.pressed.connect(stage.flip); stack.add_child(flip)
	var close := Button.new(); close.name = "CloseDetail"; close.text = "关闭 ×"; close.position = Vector2(280, 445); close.size = Vector2(70, 34); close.pressed.connect(overlay.hide); stack.add_child(close)
	var action := Button.new(); action.name = "DetailAction"; action.position = Vector2(95, 445); action.size = Vector2(170, 34); stack.add_child(action)
	if model.unlocked_cards.has(card_id):
		action.text = "加入卡组"; action.disabled = not model.can_add(card_id).is_empty(); action.tooltip_text = model.can_add(card_id)
		action.pressed.connect(func(): request_add.call_deferred(card_id); overlay.hide())
	else:
		action.text = "解锁 · %d 种子" % int(card.unlock_cost); action.disabled = model.meta_seeds < int(card.unlock_cost)
		action.pressed.connect(func(): overlay.hide(); confirm_unlock(card_id))
	front.gui_input.connect(stage.handle_input)
	back.gui_input.connect(stage.handle_input)

func _card_face(card_id: String, card: Dictionary, back: bool) -> PanelContainer:
	var face := PanelContainer.new()
	face.set_script(preload("res://scripts/card_material.gd"))
	face.setup(str(card.get("rarity", "common")), back)
	face.custom_minimum_size = Vector2(350, 430)
	face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	face.mouse_filter = Control.MOUSE_FILTER_PASS
	face.tooltip_text = "左右拖动旋转；点击查看卡背"
	if back: return face
	var content := Control.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE; face.add_child(content)
	var rarity := str(card.rarity)
	var layout := preload("res://scripts/card_face_layout.gd")
	var title := Label.new(); title.name = "DetailTitle"; title.text = str(card.name); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 20); title.modulate = Color("302e24"); content.add_child(title); layout.place(title, rarity, "title")
	var cost := Label.new(); cost.name = "DetailCost"; cost.text = "%d 光能" % int(card.energy_cost); cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; cost.add_theme_font_size_override("font_size", 11); cost.modulate = Color("302e24") if rarity == "rare" else Visual.GOLD; content.add_child(cost); layout.place(cost, rarity, "cost")
	var art := Visual.art(card_id, 0); art.name = "CardArt"; content.add_child(art); layout.place(art, rarity, "art")
	var meta := Label.new(); meta.text = "%s · %s · %s" % [Text.rarity(card.rarity), Text.phase(card.phase), Text.target(card.target_type)]; meta.position = Vector2(32, 238); meta.size = Vector2(286, 25); meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; meta.add_theme_font_size_override("font_size", 12); meta.modulate = Color("3f453a"); content.add_child(meta)
	var scroll := ScrollContainer.new(); scroll.name = "EffectScroll"; scroll.position = Vector2(34, 270); scroll.size = Vector2(282, 82); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content.add_child(scroll)
	var description := Label.new(); description.name = "DetailDescription"; description.text = Text.description(card); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; description.size_flags_horizontal = Control.SIZE_EXPAND_FILL; description.add_theme_font_size_override("font_size", 16); description.modulate = Color("302e24"); scroll.add_child(description)
	var unlock := Label.new(); unlock.name = "DetailUnlockCost"; unlock.text = "上限 %d 张 · 已编入 %d · 解锁 %d 种子" % [int(card.get("copies_allowed", 1)), model.draft.count(card_id), int(card.get("unlock_cost", 0))]; unlock.position = Vector2(30, 357); unlock.size = Vector2(290, 25); unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; unlock.add_theme_font_size_override("font_size", 11); unlock.modulate = Color("5d5946"); content.add_child(unlock)
	for label in content.find_children("", "Label", true, false): label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face

func _setup_drop_targets() -> void:
	for path in ["Root/MainSplit/LibraryPanel", "Root/MainSplit/LibraryPanel/Library", "Root/MainSplit/LibraryPanel/Library/CardScroll", "Root/MainSplit/LibraryPanel/Library/CardScroll/CardGrid"]:
		_forward_drop(get_node(path), "library")
	for path in ["Root/MainSplit/Sidebar", "Root/MainSplit/Sidebar/DeckScroll", "Root/MainSplit/Sidebar/DeckScroll/DeckList", "Root/MainSplit/Sidebar/DeckTitle"]:
		_forward_drop(get_node(path), "deck")
	$Root/MainSplit/LibraryPanel/Library/Tools/LibraryTitle.tooltip_text = "点击查看详情；拖入右侧卡组；卡组卡牌拖回这里移除"
	$Root/MainSplit/Sidebar/DeckTitle.text = "当前卡组 · 拖入添加 / 拖回移除"

func _forward_drop(control: Control, destination: String) -> void:
	control.set_drag_forwarding(Callable(), func(_pos: Vector2, data: Variant): return can_drop_card(destination, data), func(_pos: Vector2, data: Variant): drop_card(destination, data))

func _forward_component_buttons(component: Control, destination: String) -> void:
	for button in component.find_children("", "Button", true, false):
		button.set_drag_forwarding(component._get_drag_data, func(_pos: Vector2, data: Variant): return can_drop_card(destination, data), func(_pos: Vector2, data: Variant): drop_card(destination, data))

func make_card_drag(card_id: String, source: String, control: Control) -> Variant:
	if model == null or ContentData.get_card(card_id).is_empty(): return null
	if source == "library" and not model.unlocked_cards.has(card_id): show_status("卡牌尚未解锁，请点击查看详情"); return null
	if source == "deck" and not model.draft.has(card_id): return null
	select_card(card_id)
	var card := ContentData.get_card(card_id)
	var preview := PanelContainer.new(); preview.custom_minimum_size = Vector2(160, 130); preview.mouse_filter = Control.MOUSE_FILTER_IGNORE; preview.add_theme_stylebox_override("panel", Visual.panel(Visual.INK, Visual.GOLD, 8))
	preview.theme = Visual.theme()
	var box := VBoxContainer.new(); preview.add_child(box); box.add_child(Visual.art(card_id, 70))
	var label := Label.new(); label.text = "%s · %d 光能" % [card.name, card.energy_cost]; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(label)
	var hint := Label.new(); hint.text = "拖入卡组添加" if source == "library" else "拖回卡库移除一张"; hint.add_theme_font_size_override("font_size", 12); hint.modulate = Visual.GOLD; box.add_child(hint)
	control.set_drag_preview(preview)
	return {"type":"deck_builder_card", "card_id":card_id, "source":source, "owner_id":get_instance_id()}

func can_drop_card(destination: String, data: Variant) -> bool:
	if model == null or not data is Dictionary: return false
	if data.get("type") != "deck_builder_card" or data.get("owner_id") != get_instance_id(): return false
	if not data.get("card_id") is String or ContentData.get_card(data.card_id).is_empty(): return false
	if destination == "deck" and data.get("source") == "library":
		var reason: String = model.can_add(data.card_id)
		if not reason.is_empty(): show_status(reason)
		return reason.is_empty()
	return destination == "library" and data.get("source") == "deck" and model.draft.has(data.card_id)

func drop_card(destination: String, data: Variant) -> void:
	if not can_drop_card(destination, data): return
	_commit_card_drop.call_deferred(destination, str(data.card_id))

func _commit_card_drop(destination: String, card_id: String) -> void:
	if destination == "deck": request_add(card_id)
	else: request_remove(card_id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and is_node_ready():
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and data.get("owner_id") == get_instance_id():
			var path := "Root/MainSplit/Sidebar/DeckScroll" if data.get("source") == "library" else "Root/MainSplit/LibraryPanel"
			var margin := 12 if data.get("source") == "library" else 16
			get_node(path).add_theme_stylebox_override("panel", Visual.panel(Color("20352c"), Visual.GOLD, margin))
	elif what == NOTIFICATION_DRAG_END and is_node_ready():
		$Root/MainSplit/Sidebar/DeckScroll.add_theme_stylebox_override("panel", Visual.panel())
		$Root/MainSplit/LibraryPanel.add_theme_stylebox_override("panel", Visual.panel(Color(0.045, 0.1, 0.1, 0.96), Color("536454"), 16))
		if model != null: refresh_actions()

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _refresh_selection() -> void:
	for view in $Root/MainSplit/LibraryPanel/Library/CardScroll/CardGrid.get_children():
		view.set_selected(view.card_id == selected_card_id)

func _apply_visuals() -> void:
	theme = Visual.theme()
	var shade := ColorRect.new(); shade.name = "BackgroundShade"; shade.color = Color(0.025, 0.07, 0.075, 0.5); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(shade); move_child(shade, 1)
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_theme_constant_override("separation", 12)
	$Root/TopBar.add_theme_constant_override("separation", 20)
	$Root/MainSplit.add_theme_constant_override("separation", 16)
	$Root/MainSplit.dragger_visibility = SplitContainer.DRAGGER_HIDDEN
	$Root/MainSplit/Sidebar.add_theme_constant_override("separation", 8)
	$Root/MainSplit/Sidebar/DeckScroll.add_theme_stylebox_override("panel", Visual.panel())
	$Root/MainSplit/Sidebar/CostCurveArt.visible = false
	$Root/MainSplit/LibraryPanel.add_theme_stylebox_override("panel", Visual.panel(Color(0.045, 0.1, 0.1, 0.96), Color("536454"), 16))
	$Root/TopBar/DeckCountLabel.add_theme_color_override("font_color", Visual.GOLD)
	$Root/TopBar/SeedLabel.add_theme_color_override("font_color", Visual.GOLD)
	$Root/TopBar/UnsavedLabel.add_theme_font_size_override("font_size", 12)
	$Root/TopBar/UnsavedLabel.modulate = Visual.MUTED
	$Root/BottomBar/SaveButton.add_theme_font_size_override("font_size", 17)
	$Root/TopBar/BackButton.custom_minimum_size.x = 68
	$Root/BottomBar/ClearButton.custom_minimum_size.x = 76
	$Root/BottomBar/RestoreButton.custom_minimum_size.x = 76
	$Root/BottomBar/AutoFillButton.custom_minimum_size.x = 108
	for state in ["normal", "hover", "pressed", "disabled"]:
		$Root/BottomBar/SaveButton.add_theme_stylebox_override(state, Visual.button_plate(state, true))
