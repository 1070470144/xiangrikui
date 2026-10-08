extends SceneTree

class Target extends Node2D:
	var health := 100.0
	var friendly_time := 0.0
	func take_damage(amount: float) -> void:
		health -= amount

class Thorn extends "res://scripts/plant.gd":
	var targets: Array = []
	func _nearby_enemies(_center: Vector2, _radius: float) -> Array:
		return targets

func _initialize() -> void:
	var thorn := Thorn.new()
	thorn.configure(thorn.Kind.THORN, 0)
	assert(thorn.attack_damage == 20.0)
	for i in range(12):
		thorn.targets.append(Target.new())
	thorn._attack_thorn()
	for i in range(12):
		assert(thorn.targets[i].health == (80.0 if i < 10 else 100.0), "hit exactly ten targets for twenty damage")
	for target in thorn.targets:
		target.free()
	thorn.free()
	print("THORN DAMAGE TEST PASSED")
	quit()
