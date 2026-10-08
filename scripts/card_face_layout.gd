extends RefCounted

# Measured safe rectangles in the 700 × 860 generated card textures.
# Both the collection and the detail view use these same artwork coordinates.
const REGIONS := {
	"common": {"title": Rect2(120, 31, 510, 49), "art": Rect2(58, 100, 582, 319), "cost": Rect2(22, 26, 76, 59)},
	"rare": {"title": Rect2(145, 28, 460, 43), "art": Rect2(79, 98, 542, 335), "cost": Rect2(27, 28, 75, 59)},
	"legendary": {"title": Rect2(130, 79, 440, 43), "art": Rect2(59, 146, 582, 281), "cost": Rect2(25, 36, 68, 51)},
}

static func place(node: Control, rarity: String, region: String) -> void:
	var bounds: Rect2 = REGIONS.get(rarity, REGIONS.common)[region]
	node.anchor_left = bounds.position.x / 700.0
	node.anchor_top = bounds.position.y / 860.0
	node.anchor_right = bounds.end.x / 700.0
	node.anchor_bottom = bounds.end.y / 860.0
	node.offset_left = 0; node.offset_top = 0
	node.offset_right = 0; node.offset_bottom = 0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH
	node.clip_contents = true
