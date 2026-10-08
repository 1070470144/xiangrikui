extends SceneTree

class Target extends Node2D:
	var health := 100.0
	var friendly := false
	var burn := 0.0
	func take_damage(amount: float) -> void: health -= amount
	func take_mother_damage(amount: float, _origin: Vector2) -> void: health -= amount
	func apply_burn(amount: float, _duration: float) -> void: burn = amount
	func get_rank() -> String: return "normal"

class Host extends Node2D:
	var mother_flower: Node
	var targets: Array = []
	func query_enemies_in_radius(_point: Vector2, _radius: float) -> Array: return targets

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var mother := preload("res://scripts/mother_flower.gd").new()
	host.add_child(mother)
	host.mother_flower = mother
	mother.set_process(false)
	mother.combat_night = true
	var target := Target.new()
	host.add_child(target)
	target.position = Vector2(200, 0)
	var arrow := preload("res://scripts/projectile.gd").new()
	arrow.is_mother_arrow = true
	arrow.hit_callback = func(victim, _origin, damage): victim.health -= damage
	host.add_child(arrow)
	arrow.set_process(false)
	arrow.launch(target, 18.0)
	arrow.set_process(false)
	assert(target.health == 100.0)
	arrow._process(0.2)
	assert(target.health == 100.0)
	target.position = Vector2(220, 30)
	arrow._process(0.5)
	assert(target.health == 82.0)
	arrow._process(0.1)
	assert(target.health == 82.0)
	var cancelled := preload("res://scripts/projectile.gd").new()
	cancelled.is_mother_arrow = true
	host.add_child(cancelled)
	cancelled.launch(target, 18.0)
	cancelled.set_process(false)
	target.health = 0.0
	cancelled._process(0.5)
	assert(cancelled.is_queued_for_deletion())
	var game = preload("res://scripts/game.gd").new()
	var model = preload("res://scripts/mother_flower.gd").new()
	game.add_child(model)
	game.mother_flower = model
	model.reset_state()
	model.evolution.choose_path("sun_arrow")
	assert(is_equal_approx(model.evolution.get_mother_attack_range(), 280.0), "sun arrow initial range is 280")
	model.evolution.selected_upgrades.assign(["mother_sunseed_02"])
	assert(is_equal_approx(model.evolution.get_mother_attack_range(), 315.0), "sun arrow range upgrade adds 35")
	model.evolution.selected_upgrades.clear()
	model.evolution.selected_upgrades.assign(["mother_corona_01", "mother_corona_03"])
	var victim := Target.new()
	game.add_child(victim)
	game._on_mother_attack_requested(Vector2.ZERO, victim, 18.0)
	assert(victim.health == 100.0 and victim.burn == 0.0)
	var shot = game.get_child(game.get_child_count()-1)
	shot.hit_callback.call(victim, Vector2.ZERO, 18.0)
	assert(victim.health == 82.0 and victim.burn == 3.0)
	model.evolution.selected_upgrades.clear()
	shot.hit_callback.call(victim, Vector2.ZERO, 18.0)
	assert(victim.health == 62.0) # captured chain upgrade, independent of current upgrades
	var second := Target.new()
	game.add_child(second)
	second.position = Vector2(150, 0)
	victim.position = Vector2(100, 0)
	game.enemy_index.register(victim)
	game.enemy_index.register(second)
	model.evolution.selected_upgrades.assign(["mother_sunseed_04", "mother_sunseed_05"])
	game.mother_attack_count = 3
	var before := game.get_child_count()
	game._on_mother_attack_requested(Vector2.ZERO, victim, 18.0)
	assert(game.get_child_count() == before + 2, "fourth successful shot creates an independent extra arrow")
	var primary = game.get_child(before)
	primary.hit_callback.call(victim, Vector2.ZERO, 18.0)
	assert(second.health == 100.0, "pierce must wait for its own arrival")
	var pierce = game.get_child(game.get_child_count()-1)
	var before_pierce := game.get_child_count()
	pierce.hit_callback.call(second, victim.position, 18.0*0.65)
	assert(is_equal_approx(second.health, 88.3))
	assert(game.get_child_count() == before_pierce, "pierce does not recursively create arrows")
	game.free()
	target.health = 100.0
	host.targets = [target]
	mother.choose_path("sun_arrow")
	mother.combat_night = true
	mother.attack_cooldown = 10.0
	var emitted := [0]
	mother.attack_requested.connect(func(_origin, _target, _damage): emitted[0] += 1)
	mother._mother_attack()
	mother._process(0.1)
	assert(emitted[0] == 0)
	mother._process(0.06)
	assert(emitted[0] == 1)
	mother._mother_attack()
	target.health = 0.0
	mother._process(0.2)
	assert(emitted[0] == 1)
	target.health = 100.0
	mother._mother_attack()
	mother.on_day_started()
	mother._process(0.2)
	assert(emitted[0] == 1)
	print("SUN ARROW TESTS PASSED")
	host.queue_free()
	await process_frame
	quit()
