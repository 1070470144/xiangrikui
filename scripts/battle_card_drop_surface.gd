extends Control

signal card_dropped(card_id: String, viewport_position: Vector2)

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "battle_combat_card" and data.get("card_id") is String and not str(data.get("card_id")).is_empty()

func _drop_data(at: Vector2, data: Variant) -> void:
	card_dropped.emit(str(data["card_id"]), get_global_transform_with_canvas() * at)
