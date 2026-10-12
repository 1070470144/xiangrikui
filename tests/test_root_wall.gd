extends SceneTree
func _initialize() -> void:
	var wall = load("res://scripts/temporary_battle_object.gd").new()
	wall.configure("card_root_wall", Vector2.ZERO, {})
	var stopped: Vector2 = wall.clip_movement(Vector2(0,-100), Vector2(0,100))
	assert(stopped.y < -25)
	assert(wall.clip_movement(Vector2(300,-100), Vector2(300,100)) == Vector2(300,100))
	wall.remaining_time = 0
	assert(wall.clip_movement(Vector2(0,-100), Vector2(0,100)) == Vector2(0,100))
	wall.free()
	print("ROOT_WALL_PASS")
	quit()
