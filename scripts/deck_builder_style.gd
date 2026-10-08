extends RefCounted

const INK := Color("101f23")
const GOLD := Color("ddc58d")
const PAPER := Color("e5e9db")
const MUTED := Color("9aafa5")

static func panel(fill := INK, edge := Color("536454"), margin := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(margin)
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	result.set_color("font_color", "Label", PAPER)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			result.set_stylebox(state, type, button_plate(state))
		result.set_stylebox("focus", type, panel(Color(0, 0, 0, 0), GOLD, 0))
		result.set_color("font_color", type, PAPER)
		result.set_color("font_disabled_color", type, Color("81948a"))
	result.set_constant("separation", "VBoxContainer", 6)
	result.set_constant("separation", "HBoxContainer", 10)
	return result

static func button_plate(state := "normal", primary := false, compact := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var path := "res://assets/ui/generated/deck_builder/buttons_v6/button_%s_v6.png" % ("primary" if primary else "secondary")
	if ResourceLoader.exists(path): style.texture = load(path) as Texture2D
	style.texture_margin_left = 14 if compact else 20
	style.texture_margin_right = 14 if compact else 20
	style.texture_margin_top = 12
	style.texture_margin_bottom = 12
	style.content_margin_left = 4 if compact else 10
	style.content_margin_right = 4 if compact else 10
	style.content_margin_top = 4 if compact else 8
	style.content_margin_bottom = 4 if compact else 8
	if state == "hover": style.modulate_color = Color(1.22, 1.16, 1.03)
	elif state == "pressed": style.modulate_color = Color(0.7, 0.76, 0.69)
	elif state == "disabled": style.modulate_color = Color(0.55, 0.62, 0.58)
	return style

static func art_path(card_id: String) -> String:
	var illustration := "res://assets/ui/generated/deck_builder/illustrations_v3/%s.png" % card_id
	if ResourceLoader.exists(illustration): return illustration
	match card_id:
		"card_sun_pierce", "card_sun_arrow_rain", "card_focus_mark": return "res://assets/ui/UI_ICON_PrismFlower.png"
		"card_root_snare", "card_root_wall", "card_root_prison", "card_frenzy_growth": return "res://assets/plants/ART_PLANT_ThornFlower_Powered.png"
		"card_emergency_dew", "card_local_repair_rain", "card_golden_rain", "card_transplant_shovel": return "res://assets/ui/UI_ICON_Repair.png"
		"card_lure_bud", "card_temporary_sprout", "card_path_beacon", "card_hex_break_lamp": return "res://assets/nodes/ART_NODE_LightBud_Healthy.png"
		"card_garden_resurrection", "card_phantom_bloom": return "res://assets/core/ART_CORE_MotherFlower_Healthy.png"
		_: return "res://assets/ui/UI_ICON_Sunburst.png"

static func art(card_id: String, height := 76) -> TextureRect:
	var view := TextureRect.new()
	view.texture = load(art_path(card_id)) as Texture2D
	view.custom_minimum_size.y = height
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if "illustrations_v3" in art_path(card_id) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view
