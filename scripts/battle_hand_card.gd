extends Button

const Presentation = preload("res://scripts/battle_card_presentation.gd")
const Content = preload("res://scripts/content_data.gd")

signal card_drag_started(card_id: String)
signal card_drag_finished

var card_id := ""
var drag_allowed := true
var _dragging := false
var _rest_position := Vector2.ZERO
var _rest_rotation := 0.0
var _rarity := "common"
var _hovered := false

func configure(id: String, illustration: Texture2D, title: String, description: String, cost: String) -> void:
	card_id = id
	_rarity = str(Content.get_card(id).get("rarity", "common")) if not id.begins_with("deploy_") else "common"
	if _rarity not in ["common","rare","legendary"]: _rarity = "common"
	custom_minimum_size = Vector2(177, 218)
	size = custom_minimum_size
	text = ""
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("182637") if state != "disabled" else Color("202933")
		style.border_color = Color("b98b55") if state == "normal" else Color("e3b66b")
		style.set_border_width_all(2 if state in ["hover", "pressed"] else 1)
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0,0,0,0.65); style.shadow_size = 7
		add_theme_stylebox_override(state, style)
	var art := TextureRect.new()
	art.name = "Illustration"; art.texture = illustration
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(12,28); art.size = Vector2(118,68)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var paper := Panel.new()
	paper.name = "DescriptionPaper"; paper.position = Vector2(9,121); paper.size = Vector2(124,85)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color("cfc1a3"); paper_style.set_corner_radius_all(6)
	paper.add_theme_stylebox_override("panel", paper_style); add_child(paper)
	_add_text("CardTitle",title,Vector2(6,98),Vector2(130,23),14,Color("f2e6cf"))
	var description_label := _add_text("EffectDescription","",Vector2(14,126),Vector2(114,73),12,Color("282c33"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size = Vector2(114,73)
	description_label.clip_text = true
	description_label.text = description
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var gem := Panel.new()
	gem.name = "CostGem"; gem.position = Vector2(-5,-5); gem.size = Vector2(33,33)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem_style := StyleBoxFlat.new(); gem_style.bg_color = Color("355b79"); gem_style.border_color = Color("caa566")
	gem_style.set_border_width_all(2); gem_style.set_corner_radius_all(17)
	gem.add_theme_stylebox_override("panel",gem_style); add_child(gem)
	_add_text("CostValue",cost,Vector2(-5,-5),Vector2(33,33),19,Color("fff0cf"))
	tooltip_text = title + "\n" + description
	if not id.begins_with("deploy_"):
		_add_text("TargetLabel",Presentation.target_text(id),Vector2(40,4),Vector2(90,20),12,Color("cfc1a3"))
	pivot_offset = size * 0.5
	mouse_entered.connect(_hover)
	mouse_exited.connect(_unhover)
	_apply_deck_face()

func _apply_deck_face() -> void:
	var path := "res://assets/ui/generated/deck_builder/faces_v5/card_face_%s_v5.png" % _rarity
	if not ResourceLoader.exists(path): return
	for state in ["normal","hover","pressed","disabled"]:
		var face := StyleBoxTexture.new(); face.texture = load(path) as Texture2D
		face.texture_margin_left = 0; face.texture_margin_top = 0; face.texture_margin_right = 0; face.texture_margin_bottom = 0
		face.content_margin_left = 0; face.content_margin_right = 0; face.content_margin_top = 0; face.content_margin_bottom = 0
		if state == "hover": face.modulate_color = Color(1.12,1.08,0.93,1)
		elif state == "pressed": face.modulate_color = Color(1.16,1.1,0.82,1)
		elif state == "disabled": face.modulate_color = Color(0.58,0.62,0.58,1)
		add_theme_stylebox_override(state,face)
	# The face texture owns the parchment area and copper rails.
	pivot_offset = size * 0.5
	(get_node("DescriptionPaper") as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	(get_node("CostGem") as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var layout := preload("res://scripts/card_face_layout.gd")
	layout.place(get_node("Illustration"),_rarity,"art")
	layout.place(get_node("CardTitle"),_rarity,"title")
	layout.place(get_node("CostValue"),_rarity,"cost")
	var title := get_node("CardTitle") as Label
	title.add_theme_font_size_override("font_size",11); title.add_theme_color_override("font_color",Color("302e24"))
	var cost := get_node("CostValue") as Label
	cost.add_theme_font_size_override("font_size",13); cost.add_theme_color_override("font_color",Color("302e24") if _rarity == "rare" else Color("ddc58d"))
	var art := get_node("Illustration") as TextureRect
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if art.texture != null and "illustrations_v3" in art.texture.resource_path else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.clip_contents = true
	var effect := get_node("EffectDescription") as Label
	effect.position = Vector2(23,117); effect.size = Vector2(131,74)
	if has_node("TargetLabel"):
		var target := get_node("TargetLabel") as Label
		target.position = Vector2(23,194); target.size = Vector2(131,15)
		target.add_theme_font_size_override("font_size",11); target.add_theme_color_override("font_color",Color("302e24") if _rarity in ["rare","legendary"] else Color("ddc58d"))
		target.size = Vector2(131,16)
		if _rarity == "legendary":
			var badge := Panel.new(); badge.position = Vector2(63,197); badge.size = Vector2(51,17)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var plate := StyleBoxFlat.new(); plate.bg_color = Color("dac89d"); plate.set_corner_radius_all(3)
			badge.add_theme_stylebox_override("panel",plate); add_child(badge); move_child(badge,target.get_index())

func _add_text(node_name: String, value: String, at: Vector2, extent: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new(); label.name = node_name; label.text = value
	label.position = at; label.size = extent; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func set_rest_transform(at: Vector2, angle: float) -> void:
	_rest_position = at; _rest_rotation = angle
	if not _dragging:
		if _hovered: _hover()
		else: position = at; rotation = angle

func _has_point(point: Vector2) -> bool:
	var bounds := Rect2(Vector2.ZERO,size)
	if bounds.has_point(point): return true
	if not _hovered: return false
	var rest := Transform2D(_rest_rotation,Vector2.ZERO)
	rest.origin = _rest_position + pivot_offset - rest.basis_xform(pivot_offset)
	return bounds.has_point(rest.affine_inverse() * (get_transform() * point))

func _hover() -> void:
	if _dragging: return
	_hovered = true
	position = _rest_position + Vector2(0,-95); rotation = 0; scale = Vector2.ONE * 1.06; z_index = 20

func _unhover() -> void:
	if _dragging: return
	_hovered = false
	position = _rest_position; rotation = _rest_rotation; scale = Vector2.ONE; z_index = 0

func _get_drag_data(_at: Vector2) -> Variant:
	if disabled or not drag_allowed or card_id.is_empty(): return null
	_unhover()
	_dragging = true
	if card_id in ["deploy_light","deploy_thorn","deploy_prism","deploy_lantern","deploy_frost","deploy_honeydew","card_temporary_sprout","card_phantom_bloom"]:
		var world_preview_placeholder := Control.new()
		world_preview_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_drag_preview(world_preview_placeholder)
		modulate.a = 0.25
		card_drag_started.emit(card_id)
		return {"type":"battle_combat_card","card_id":card_id}
	var preview = get_script().new()
	preview.configure(card_id, get_node("Illustration").texture, get_node("CardTitle").text, get_node("EffectDescription").text, get_node("CostValue").text)
	preview.scale = Vector2.ONE * 0.45
	preview.position = Vector2(30,-120); preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	modulate.a = 0.25
	card_drag_started.emit(card_id)
	return {"type":"battle_combat_card", "card_id":card_id}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false; modulate.a = 1.0
		_unhover()
		card_drag_finished.emit()

