extends HBoxContainer
class_name DeckListItem

signal selected(card_id: String)
signal detail_requested(card_id: String)
signal remove_requested(card_id: String)
var card_id := ""
var drag_owner: Control
var _click_pending := false
const Visual = preload("res://scripts/deck_builder_style.gd")

func configure(card: Dictionary, count: int) -> void:
	card_id = str(card.get("id", ""))
	custom_minimum_size.y = 32
	for child in get_children(): child.queue_free()
	var cost := Label.new(); cost.name = "Cost"; cost.text = str(card.get("energy_cost", 0)); cost.custom_minimum_size.x = 24; cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cost.modulate = Visual.GOLD; add_child(cost)
	var label := Label.new(); label.name = "CardName"; label.text = str(card.get("name", "")); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_child(label)
	var amount := Label.new(); amount.name = "Count"; amount.text = "×%d" % count; add_child(amount)
	var remove := Button.new(); remove.name = "RemoveButton"; remove.text = "－"; remove.custom_minimum_size = Vector2(32, 30); remove.tooltip_text = "移出卡组"; remove.pressed.connect(func(): remove_requested.emit(card_id)); add_child(remove)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var plate := Visual.button_plate(state, false, true)
		plate.texture_margin_left = 0; plate.texture_margin_right = 0
		plate.texture_margin_top = 0; plate.texture_margin_bottom = 0
		remove.add_theme_stylebox_override(state, plate)
	tooltip_text = "点击查看详情；拖回左侧卡库移除一张"
	for child in get_children():
		if not child is Button: child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_pending = true
			selected.emit(card_id)
			if event.double_click:
				_click_pending = false
				remove_requested.emit(card_id)
		elif _click_pending:
			_click_pending = false
			detail_requested.emit(card_id)

func _get_drag_data(_position: Vector2) -> Variant:
	_click_pending = false
	if not is_instance_valid(drag_owner): return null
	return drag_owner.make_card_drag(card_id, "deck", self)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return is_instance_valid(drag_owner) and drag_owner.can_drop_card("deck", data)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if is_instance_valid(drag_owner): drag_owner.drop_card("deck", data)
