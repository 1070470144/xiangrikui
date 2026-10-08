extends PanelContainer

var quality := "common"
var frame: Texture2D

func setup(rarity: String, back := false) -> void:
	quality = rarity
	var path := "res://assets/ui/generated/deck_builder/faces_v5/card_face_%s_v5.png" % ("back" if back else rarity)
	if ResourceLoader.exists(path): frame = load(path) as Texture2D
	queue_redraw()

func _draw() -> void:
	if frame != null: draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
