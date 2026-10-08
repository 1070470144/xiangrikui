extends PanelContainer
class_name DeckCardView

const FaceLayout = preload("res://scripts/card_face_layout.gd")
const Text = preload("res://scripts/deck_builder_text.gd")
const Visual = preload("res://scripts/deck_builder_style.gd")

signal selected(card_id: String)
signal detail_requested(card_id: String)
signal add_requested(card_id: String)
var card_id := ""
var frame_prefix := "common"
var blocked := false
var is_selected := false
var drag_owner: Control
var _click_pending := false

func _ready() -> void:
	mouse_entered.connect(func(): _apply_frame("hover" if not blocked else "disabled"))
	mouse_exited.connect(func(): _apply_frame("selected" if is_selected else ("normal" if not blocked else "disabled")))

func configure(card: Dictionary, unlocked: bool, count: int, limit: int, blocked_reason := "") -> void:
	card_id = str(card.get("id", ""))
	frame_prefix = str(card.get("rarity", "common"))
	if frame_prefix not in ["common", "rare", "legendary"]: frame_prefix = "common"
	blocked = not unlocked or not blocked_reason.is_empty()
	_apply_frame("disabled" if blocked else "normal")
	custom_minimum_size = Vector2(158, 196)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = blocked_reason
	for child in get_children(): child.queue_free()
	var box := Control.new(); box.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(box)
	var cost := Label.new(); cost.name = "Cost"; cost.text = str(int(card.get("energy_cost", 0))); cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; cost.add_theme_font_size_override("font_size", 14); cost.modulate = Color("302e24") if frame_prefix == "rare" else Visual.GOLD; box.add_child(cost); FaceLayout.place(cost, frame_prefix, "cost")
	var name_label := Label.new(); name_label.name = "Name"; name_label.text = str(card.get("name", "")); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; name_label.add_theme_font_size_override("font_size", 12); name_label.modulate = Color("302e24"); box.add_child(name_label); FaceLayout.place(name_label, frame_prefix, "title")
	var art := Visual.art(card_id, 0); art.name = "CardArt"; box.add_child(art); FaceLayout.place(art, frame_prefix, "art")
	var fallback := Label.new(); fallback.name = "ArtFallback"; fallback.text = ""; fallback.visible = false; box.add_child(fallback)
	var meta := Label.new(); meta.name = "Phase"; meta.text = "%s · %s" % [Text.rarity(card.get("rarity", "common")), Text.phase(card.get("phase", "any"))]; meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; meta.add_theme_font_size_override("font_size", 11); meta.modulate = Color("3f453a"); box.add_child(meta); _place(meta, 0.09, 0.55, 0.91, 0.65)
	var count_label := Label.new(); count_label.text = "已编入 %d/%d · 点击查看" % [count, limit] if unlocked else "解锁 %d 种子 · 点击查看" % int(card.get("unlock_cost", 0)); count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; count_label.add_theme_font_size_override("font_size", 10); count_label.modulate = Color("3f453a"); box.add_child(count_label); _place(count_label, 0.08, 0.67, 0.92, 0.78)
	var lock_row := HBoxContainer.new(); lock_row.name = "LockSlot"; lock_row.custom_minimum_size.y = 24; lock_row.visible = false; box.add_child(lock_row)
	var add := Button.new(); add.name = "AddButton"; add.text = "+ 加入" if blocked_reason.is_empty() else blocked_reason; add.custom_minimum_size.y = 28; add.add_theme_font_size_override("font_size", 12); add.disabled = not unlocked or not blocked_reason.is_empty(); add.pressed.connect(func(): add_requested.emit(card_id)); box.add_child(add); _place(add, 0.1, 0.82, 0.9, 0.97)
	if not unlocked:
		add.text = "未解锁 · 查看"
		add.disabled = false
		for connection in add.pressed.get_connections(): add.pressed.disconnect(connection.callable)
		add.pressed.connect(func(): detail_requested.emit(card_id))
	for state in ["normal", "hover", "pressed", "disabled"]:
		add.add_theme_stylebox_override(state, Visual.button_plate(state, false, true))
	for child in box.get_children():
		if not child is Button: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(0.7, 0.75, 0.7) if not unlocked else Color.WHITE

func set_selected(value: bool) -> void:
	is_selected = value
	_apply_frame("selected" if value else ("disabled" if blocked else "normal"))

func _apply_frame(state: String) -> void:
	var frame_path := "res://assets/ui/generated/deck_builder/faces_v5/card_face_%s_v5.png" % frame_prefix
	if not ResourceLoader.exists(frame_path): return
	var style := StyleBoxTexture.new()
	style.texture = load(frame_path) as Texture2D
	style.texture_margin_left = 0
	style.texture_margin_top = 0
	style.texture_margin_right = 0
	style.texture_margin_bottom = 0
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	style.modulate_color = Color.WHITE
	if state == "hover": style.modulate_color = Color(1.12, 1.08, 0.9, 1.0)
	elif state == "selected": style.modulate_color = Color(1.18, 1.12, 0.78, 1.0)
	elif state == "disabled": style.modulate_color = Color(0.88, 0.9, 0.86, 1.0)
	add_theme_stylebox_override("panel", style)
	queue_redraw()

func _place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = left; node.anchor_top = top; node.anchor_right = right; node.anchor_bottom = bottom
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE if not node is Button else Control.MOUSE_FILTER_STOP

func _draw() -> void:
	if not is_selected: return
	var line := Visual.GOLD if is_selected else Color(0, 0, 0, 0)
	line.a = 0.65
	for corner in [Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(4, size.y - 4), Vector2(size.x - 4, size.y - 4)]:
		var direction := Vector2(1 if corner.x < size.x / 2 else -1, 1 if corner.y < size.y / 2 else -1)
		draw_line(corner, corner + Vector2(direction.x * 10, 0), line, 1)
		draw_line(corner, corner + Vector2(0, direction.y * 10), line, 1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_pending = true
			selected.emit(card_id)
			if event.double_click:
				_click_pending = false
				add_requested.emit(card_id)
		elif _click_pending:
			_click_pending = false
			detail_requested.emit(card_id)

func _get_drag_data(_position: Vector2) -> Variant:
	_click_pending = false
	if not is_instance_valid(drag_owner): return null
	return drag_owner.make_card_drag(card_id, "library", self)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return is_instance_valid(drag_owner) and drag_owner.can_drop_card("library", data)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if is_instance_valid(drag_owner): drag_owner.drop_card("library", data)
