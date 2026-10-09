extends SceneTree

class Victim extends Node2D:
	var health := 1000.0
	var friendly := false
	func take_area_damage(amount: float) -> void: health -= amount

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var victims: Array = []
	for point in [Vector2.ZERO, Vector2(160, 50), Vector2(161, 0), Vector2(0, 51)]:
		var enemy := Victim.new()
		host.add_child(enemy)
		enemy.position = point
		enemy.add_to_group("enemies")
		victims.append(enemy)
	var friend := Victim.new()
	host.add_child(friend)
	friend.friendly = true
	friend.add_to_group("enemies")
	var zone = load("res://scripts/temporary_battle_object.gd").new()
	host.add_child(zone)
	zone.configure("card_sun_pierce", Vector2.ZERO, {"duration":4.0,"rect_width":320.0,"rect_height":100.0,"periodic_damage":12.0})
	zone.advance_rect_damage(0.49)
	assert(victims[0].health == 1000.0)
	zone.advance_rect_damage(0.01)
	assert(victims[0].health == 988.0)
	zone.advance_rect_damage(3.5)
	assert(victims[0].health == 904.0 and victims[1].health == 904.0)
	assert(victims[2].health == 1000.0 and victims[3].health == 1000.0 and friend.health == 1000.0)
	assert(zone.is_queued_for_deletion())
	for suite in ["res://tests/test_combat_deck.gd", "res://tests/test_card_effects.gd"]:
		var failures: Array = load(suite).new().run()
		for failure in failures: push_error(failure)
		assert(failures.is_empty())
	host.queue_free()
	print("SUN_PIERCE_RECT_PASS")
	quit()
