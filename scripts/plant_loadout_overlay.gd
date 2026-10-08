extends ColorRect

signal confirmed(ids: Array[String])
signal cancelled
const Art = preload("res://scripts/art_library.gd")
const Roster = preload("res://scripts/plant_roster.gd")
const Content = preload("res://scripts/content_data.gd")
const IDS = Roster.DEPLOY_IDS
var slot_labels: Array[Label] = []
var choices: Array[Button] = []
var count_label: Label
var confirm_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.015,0.025,0.035,0.88)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.name = "LoadoutPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -495; panel.offset_right = 495; panel.offset_top = -310; panel.offset_bottom = 310
	panel.add_theme_stylebox_override("panel",preload("res://scripts/battle_palette.gd").surface_style())
	add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); panel.add_child(box)
	var title := _label("今日携带的植物卡",24); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	var note := _label("每个白昼可重新调整 · 默认5个植物槽 · 光脉芽与修复不占槽 · 已种下植物保持不变",15)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(note)
	var slots := HBoxContainer.new(); slots.alignment = BoxContainer.ALIGNMENT_CENTER; slots.add_theme_constant_override("separation",8); box.add_child(slots)
	for i in range(Roster.MAX_SLOTS):
		var slot_panel := PanelContainer.new(); slot_panel.name = "SlotFrame%d" % (i+1); slot_panel.custom_minimum_size = Vector2(175,40)
		var style := StyleBoxFlat.new(); style.bg_color = Color("172536"); style.border_color = Color("a98656"); style.set_border_width_all(1); style.set_corner_radius_all(5); slot_panel.add_theme_stylebox_override("panel",style); slots.add_child(slot_panel)
		var slot := _label("",15); slot.name = "PlantSlot%d" % (i+1); slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; slot_panel.add_child(slot); slot_labels.append(slot)
	var scroll := ScrollContainer.new(); scroll.name = "PlantCatalogue"; scroll.custom_minimum_size = Vector2(950,380); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	var row := GridContainer.new(); row.columns = 5; row.add_theme_constant_override("h_separation",10); row.add_theme_constant_override("v_separation",12); scroll.add_child(row)
	for i in range(IDS.size()):
		var card := preload("res://scripts/battle_hand_card.gd").new()
		var flower := Content.get_flower(Roster.FLOWER_IDS[i])
		card.configure(IDS[i],Art.load_texture(Roster.texture_path(i)),str(flower.name),Roster.DESCRIPTIONS[i],str(flower.seed_cost))
		card.name = "LoadoutCard_"+IDS[i]; card.drag_allowed = false
		card.mouse_entered.disconnect(card._hover)
		card.mouse_exited.disconnect(card._unhover)
		card.toggled.connect(func(pressed: bool):
			if pressed and _selected().size() > Roster.MAX_SLOTS: card.set_pressed_no_signal(false)
			_update_selection()
		)
		var state := _label("",13); state.name = "CarryState"; state.position = Vector2(12,195); state.size = Vector2(153,18); state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; state.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(state)
		row.add_child(card); choices.append(card)
	count_label = _label("",16); count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(count_label)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER; actions.add_theme_constant_override("separation",24); box.add_child(actions)
	var cancel := Button.new(); cancel.name = "CancelLoadout"; cancel.text = "取消"; cancel.custom_minimum_size = Vector2(160,40); cancel.pressed.connect(func(): cancelled.emit()); actions.add_child(cancel)
	confirm_button = Button.new(); confirm_button.name = "ConfirmLoadout"; confirm_button.text = "确认携带"; confirm_button.custom_minimum_size = Vector2(180,40); confirm_button.pressed.connect(func(): confirmed.emit(_selected())); actions.add_child(confirm_button)
	hide()

func _label(value: String, font_size: int) -> Label:
	var label := Label.new(); label.text = value; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",Color("ead9b5")); return label

func _selected() -> Array[String]:
	var ids: Array[String] = []
	for i in range(choices.size()):
		if choices[i].button_pressed: ids.append(IDS[i])
	return ids

func _update_selection() -> void:
	var count := _selected().size()
	count_label.text = "已携带 %d / 5 种植物 · 至少选择一种" % count
	confirm_button.disabled = count == 0 or count > Roster.MAX_SLOTS
	var selected := _selected()
	for i in range(slot_labels.size()):
		var name_text := "空槽"
		if i < selected.size(): name_text = str(Content.get_flower(Roster.FLOWER_IDS[IDS.find(selected[i])]).name)
		slot_labels[i].text = "槽 %d  %s" % [i+1,name_text]
	for card in choices:
		card.modulate = Color.WHITE if card.button_pressed else Color(0.82,0.84,0.86)
		(card.get_node("CarryState") as Label).text = "已携带" if card.button_pressed else "未携带"

func open(ids: Array[String]) -> void:
	for i in range(choices.size()): choices[i].set_pressed_no_signal(ids.has(IDS[i]))
	_update_selection(); show()
