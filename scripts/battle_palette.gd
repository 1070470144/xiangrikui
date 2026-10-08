extends RefCounted
## V5 battle-only colors. Keep world art and original textures unchanged.

const SURFACE := Color("172331")
const SURFACE_RAISED := Color("263449")
const SURFACE_EDGE := Color("35445a")
const PAPER := Color("cfc1a3")
const PAPER_SHADE := Color("aa9a7d")
const PAPER_TEXT := Color("282c33")
const BRASS := Color("b98b55")
const BRASS_SHADE := Color("785e44")
const TEXT := Color("f2e6cf")
const SECONDARY_TEXT := Color("c1c8d0")
const SELECTED := Color("e3b66b")
const WARNING := Color("8e3d4a")
const DISABLED := Color("65717e")
const COST_GEM := Color("355b82")
const COST_TEXT := Color("fff0d2")

static func surface_style(selected := false, disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE if disabled else SURFACE_RAISED
	style.border_color = DISABLED if disabled else (SELECTED if selected else BRASS_SHADE)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 8; style.content_margin_bottom = 8
	return style

static func caption_style(disabled := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_SHADE if disabled else PAPER
	style.set_corner_radius_all(4)
	return style

static func map_green_to_navy(pixel: Color) -> Color:
	# Preserve native alpha, warm brass and amber light; map only cool/green
	# painted glass. Lightness follows the source so brushwork remains visible.
	if pixel.a == 0.0:
		return Color(0, 0, 0, 0)
	if pixel.r > pixel.g * 1.07 and pixel.g > pixel.b * 1.08:
		return pixel
	if pixel.g < pixel.r * 0.90 or pixel.g < pixel.b * 1.02:
		return pixel
	var lightness := 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
	var amount := clampf(lightness, 0.0, 1.0)
	var mapped := Color("101a29").lerp(Color("65778e"), amount)
	mapped.a = pixel.a
	return mapped

static func navy_copy(source: Image) -> Image:
	var output := source.duplicate() as Image
	output.convert(Image.FORMAT_RGBA8)
	for y in output.get_height():
		for x in output.get_width():
			output.set_pixel(x, y, map_green_to_navy(output.get_pixel(x, y)))
	return output
