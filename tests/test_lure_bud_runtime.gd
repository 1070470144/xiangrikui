extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var enemy = load("res://scripts/enemy.gd").new()
	host.add_child(enemy)
	enemy.health = 100.0
	enemy.rank = "boss"
	enemy.global_position = Vector2(2000, 2000)
	var bud = load("res://scripts/temporary_battle_object.gd").new()
	host.add_child(bud)
	bud.configure("card_lure_bud", Vector2.ZERO, {"taunt":true,"health":75.0,"duration":12.0})
	assert(enemy.target == bud)
	assert(enemy._nearest_taunt_object() == bud)
	bud.take_damage(10000.0)
	assert(bud.health == 75.0)
	assert(bud.remaining_time == 12.0)
	bud.remaining_time = 0.0
	assert(enemy._nearest_taunt_object() == null)
	host.free()
	print("LURE_BUD_PASS")
	quit()
