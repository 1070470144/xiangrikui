extends Button

const Present = preload("res://scripts/mother_upgrade_presentation.gd")
const Content = preload("res://scripts/content_data.gd")
const FormVisual = preload("res://scripts/mother_form_visual.gd")
var card_id := ""
const CARD_ART := "res://assets/ui/generated/mother_buff_ui/mother_buff_card_v2.png"

func configure(id: String) -> void:
	card_id = id
	name = "MotherChoiceCard_%s" % id
	custom_minimum_size = Vector2(252, 430)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var data := Content.get_mother_path(id)
	var is_path := not data.is_empty()
	if not is_path: data = Content.get_mother_upgrade(id)
	var body := VBoxContainer.new(); body.name = "Content"; body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); body.offset_left = 20; body.offset_right = -20; body.offset_top = 14; body.offset_bottom = -14; body.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_theme_constant_override("separation",6); add_child(body)
	var branch := str(data.get("branch", ""))
	var badge := _label("选择进化方向" if is_path else "%s · %d → %d 阶" % [Present.BRANCHES.get(branch,branch), int(data.rank)-1, int(data.rank)], 13, Color("c3a77a")); badge.name = "Rank"; body.add_child(badge)
	badge.custom_minimum_size.y = 20
	var art := TextureRect.new(); art.name = "MotherPortrait"; art.custom_minimum_size.y = 190; art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.texture = load(FormVisual.texture_path(id)); art.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_child(art)
	var title := _label(str(data.get("name", id)), 22, Color("eee1c1")); title.name = "Title"; body.add_child(title)
	var paper := PanelContainer.new(); paper.name = "EffectPaper"; paper.mouse_filter = Control.MOUSE_FILTER_IGNORE; paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var paper_style := StyleBoxEmpty.new(); paper_style.set_content_margin_all(10); paper.add_theme_stylebox_override("panel",paper_style); body.add_child(paper)
	var effect := _label(Present.description(id), 16, Color("26303a")); effect.name = "Effect"; effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; paper.add_child(effect)
	var action := _label("选择此进化  ›" if is_path else "获得此强化  ›", 15, Color("e6ca98")); action.name = "ChoiceAction"; action.custom_minimum_size.y = 28; body.add_child(action)
	tooltip_text = Present.description(id)
	mouse_entered.connect(func(): action.text = "点击确认 · 立即生效"; art.modulate = Color(1.12,1.08,1.0))
	mouse_exited.connect(func(): action.text = "选择此进化  ›" if is_path else "获得此强化  ›"; art.modulate = Color.WHITE)
	apply_art()

func apply_art() -> void:
	var texture := load(CARD_ART) as Texture2D if ResourceLoader.exists(CARD_ART) else null
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		if texture == null:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
			continue
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.modulate_color = Color(1.12,1.08,1.0) if state in ["hover","focus"] else (Color(0.83,0.87,0.82) if state == "pressed" else Color.WHITE)
		add_theme_stylebox_override(state,style)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new(); label.text = value; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; return label
