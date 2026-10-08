extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const Plant = preload("res://scripts/plant.gd")
const Feedback = preload("res://scripts/boss_battle_feedback.gd")
const Cards = preload("res://scripts/card_effect_resolver.gd")
var failures: Array[String] = []
var checks := 0

class Mother extends Node2D:
	var health := 1000.0

class Host extends Node2D:
	enum Phase { DAY, NIGHT }
	var phase := Phase.NIGHT
	var plants: Array[Node] = []
	var sprouts: Array[Node] = []
	func _temporary_supply_nodes() -> Array[Node]: return sprouts

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func boss() -> Node:
	var result: Node = Enemy.new()
	result.configure_by_id("root_crown_colossus", Vector2.ZERO)
	return result

func run() -> void:
	test_light()
	test_slam_interrupt()
	test_thresholds()
	test_zones()
	test_animation_compatibility()
	for path in ["res://tests/test_expanded_units.gd", "res://tests/test_card_effects.gd", "res://tests/test_fog_reveal.gd"]:
		var suite: RefCounted = load(path).new()
		failures.append_array(suite.run())
	if failures.is_empty(): print("ROOT BOSS PASSED: ", checks, " checks + units/cards/fog regression")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func test_light() -> void:
	var host := Host.new()
	root.add_child(host)
	var enemy: Node = boss()
	host.add_child(enemy)
	enemy.set_process(false)
	var mother := Mother.new()
	host.add_child(mother)
	mother.position = Vector2(1000, 0)
	enemy.mother_flower = mother
	var light: Node = preload("res://scripts/light_node.gd").new()
	host.add_child(light)
	light.set_process(false)
	enemy.light_nodes.append(light)
	check(enemy.is_in_boss_light(), "connected node covers boss")
	enemy.advance_root_light(2.0, enemy.is_in_boss_light())
	light.is_connected_to_light = false
	enemy.advance_root_light(0.1, enemy.is_in_boss_light())
	check(enemy.boss_light_progress == 0.0, "disconnect resets consecutive coverage")
	light.is_connected_to_light = true
	var second: Node = preload("res://scripts/light_node.gd").new()
	host.add_child(second)
	second.set_process(false)
	enemy.light_nodes.append(second)
	enemy.advance_root_light(2.0, enemy.is_in_boss_light())
	check(enemy.core_exposed_time == 0.0 and enemy.boss_light_progress == 2.0, "overlapping sources do not accelerate")
	enemy.advance_root_light(1.0, true)
	check(enemy.core_exposed_time == 3.0, "three seconds opens three second core window")
	check(is_equal_approx(enemy.calculate_incoming_damage(100, true, false), 135), "exposed damage multiplier")
	enemy.advance_root_light(3.0, true)
	check(enemy.boss_light_cooldown == 8.0, "cooldown begins when exposure ends")
	enemy.advance_root_light(7.0, true)
	check(enemy.boss_light_progress == 0.0 and enemy.core_exposed_time == 0.0, "cooldown prevents accumulation")
	enemy.advance_root_light(4.0, true)
	check(enemy.core_exposed_time == 3.0, "long frame consumes cooldown before accumulation")
	light.is_connected_to_light = false
	second.is_connected_to_light = false
	var sprout: Node = preload("res://scripts/temporary_battle_object.gd").new()
	host.add_child(sprout)
	sprout.configure("card_temporary_sprout", Vector2.ZERO, {"health":80, "supply_radius":170})
	sprout.set_parent_source(mother)
	host.sprouts.append(sprout)
	check(enemy.is_in_boss_light(), "connected temporary sprout covers boss")
	sprout.set_parent_source(null)
	check(not enemy.is_in_boss_light(), "disconnected sprout does not cover")
	mother.position = Vector2.ZERO
	check(enemy.is_in_boss_light(), "living mother covers boss")
	mother.health = 0
	check(not enemy.is_in_boss_light(), "dead mother does not cover")
	host.free()

func test_slam_interrupt() -> void:
	var enemy: Node = boss()
	var counts := {"hits":0, "zones":0, "warnings":0}
	enemy.area_damage_requested.connect(func(center: Vector2, radius: float, damage: float) -> void:
		counts.hits += 1
		check(center == Vector2(80, 90) and radius == 112 and damage == 22, "locked impact and damage contract"))
	enemy.boss_warning_requested.connect(func(_skill: String, _center: Vector2, radius: float, duration: float) -> void:
		counts.warnings += 1
		check(radius == 112 and duration == 1.2, "warning matches impact radius and cast time"))
	enemy.boss_zone_requested.connect(func(_kind: String, _center: Vector2, radius: float, duration: float) -> void:
		counts.zones += 1
		check(radius == 125 and duration == 3.5, "root zone contract"))
	enemy.start_boss_skill("slam", Vector2(80, 90), 1.2)
	enemy.advance_boss(1.0)
	check(counts.hits == 0, "no damage before landing")
	enemy.advance_boss(1.0)
	enemy.advance_boss(2.0)
	check(counts.hits == 1 and counts.zones == 1, "low FPS exactly one impact and zone")
	enemy.start_boss_skill("slam", Vector2(80, 90), 1.2)
	check(enemy.interrupt_ability(), "cast can be interrupted")
	enemy.advance_boss(10.0)
	check(counts.hits == 1 and counts.zones == 1, "interrupt cancels pending hit and zone")
	enemy.core_exposed_time = 1.5
	check(not enemy.interrupt_ability() and enemy.core_exposed_time == 1.5, "repeated interrupt does not refresh window")
	enemy.free()
	var host := Host.new()
	root.add_child(host)
	enemy = boss()
	host.add_child(enemy)
	enemy.set_process(false)
	enemy.start_boss_skill("slam", Vector2.ZERO, 1.2)
	var resolver := Cards.new()
	resolver._apply_enemy_stasis(host, 4.0)
	check(enemy.ability_windup == 0 and enemy.stun_time == 0.6 and enemy.core_exposed_time == 2, "time stasis shares interrupt entry and preserves boss control")
	var mother := Mother.new()
	host.add_child(mother)
	mother.position = Vector2(310, 50)
	enemy.mother_flower = mother
	enemy.core_exposed_time = 0
	enemy.special_cooldown = 0
	enemy.advance_boss(0.01)
	check(enemy.boss_cast_position == mother.position and enemy.ability_windup == 1.2, "no plants locks mother position")
	enemy.interrupt_ability()
	enemy.core_exposed_time = 0
	var plant: Node = Plant.new()
	plant.configure(Plant.Kind.THORN, 0)
	host.add_child(plant)
	plant.set_process(false)
	plant.position = Vector2(80, 0)
	enemy.special_cooldown = 0
	enemy.advance_boss(0.01)
	plant.position = Vector2(180, 0)
	check(enemy.boss_cast_position == Vector2(80, 0), "nearest living plant selected and no tracking after lock")
	host.free()

func test_thresholds() -> void:
	var enemy: Node = boss()
	var counter := {"summons":0}
	enemy.boss_summon_requested.connect(func(_kind: String, _center: Vector2, count: int) -> void: counter.summons += count)
	enemy.take_damage(enemy.max_health * 0.8)
	check(enemy.boss_pending_summons == 3 and enemy.boss_enraged, "crossing three thresholds enqueues all and enrages")
	enemy._process_boss_thresholds(enemy.max_health, enemy.health)
	check(enemy.boss_pending_summons == 3, "thresholds are deduplicated")
	enemy.expose_core(3)
	enemy.advance_boss(20)
	check(enemy.boss_pending_summons == 3 and enemy.ability_windup == 0, "core exposure pauses queued new skills")
	enemy.core_exposed_time = 0
	for i in range(3):
		enemy.advance_boss(0.01)
		enemy.advance_boss(1.0)
		enemy.advance_boss(0.7)
	check(counter.summons == 6 and enemy.boss_pending_summons == 0, "three serial summons of two guards")
	enemy.special_cooldown = 0
	enemy.advance_boss(0.01)
	check(enemy.special_cooldown == 4.5, "enrage special interval remains 4.5")
	enemy.take_damage(100000)
	check(enemy.ability_windup == 0 and enemy.boss_pending_summons == 0 and enemy.boss_skill == "", "death cancels pending boss work")
	enemy.free()

func test_zones() -> void:
	var host := Host.new()
	root.add_child(host)
	var plant: Node = Plant.new()
	plant.configure(Plant.Kind.THORN, 0)
	host.add_child(plant)
	plant.set_process(false)
	host.plants.append(plant)
	plant.card_interval_multiplier = 0.8
	var fx := Feedback.new()
	host.add_child(fx)
	fx.configure(host)
	fx.set_process(false)
	var enemy: Node = boss()
	host.add_child(enemy)
	enemy.set_process(false)
	fx.register(enemy)
	fx._zone("root_lock", Vector2.ZERO, 125, 3.5, enemy)
	fx._zone("root_lock", Vector2.ZERO, 125, 3.5, enemy)
	check(is_equal_approx(plant.get_effective_interval_multiplier(), 0.96), "zones do not stack or overwrite cards")
	plant.position = Vector2(200, 0)
	fx.update_roots()
	check(plant.boss_root_interval_multiplier == 1, "leaving restores interval")
	plant.position = Vector2.ZERO
	fx.update_roots()
	fx.advance_zones(4)
	check(plant.boss_root_interval_multiplier == 1 and fx.zones.is_empty(), "zone expiry restores interval at low FPS")
	enemy.start_boss_skill("slam", Vector2.ZERO, 1.2)
	check(fx.warnings.size() == 1, "warning signal connected")
	enemy.interrupt_ability()
	check(fx.warnings.is_empty(), "interrupt clears warning")
	fx._zone("root_lock", Vector2.ZERO, 125, 3.5, enemy)
	enemy.take_damage(100000)
	check(fx.zones.is_empty() and plant.boss_root_interval_multiplier == 1, "death clears owned zones immediately")
	fx._zone("root_lock", Vector2.ZERO, 125, 3.5, plant)
	fx.clear_all()
	check(fx.zones.is_empty() and plant.boss_root_interval_multiplier == 1, "reset/end clears all zones")
	host.free()

func test_animation_compatibility() -> void:
	var enemy: Node = boss()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	for state in ["idle", "slam"]:
		frames.add_animation(state)
		frames.set_animation_speed(state, 10)
		for i in range(50 if state == "slam" else 1): frames.add_frame(state, texture)
	frames.set_meta("slam_layout", {"impact_time":2.0})
	enemy.animation_frames = frames
	enemy._cache_animation_metadata()
	enemy._setup_art()
	enemy.start_boss_skill("slam", Vector2.ZERO, 1.2)
	enemy.advance_boss(0.6)
	enemy._update_art_texture()
	check(enemy._last_art_state == "slam" and enemy._last_art_frame == 10, "source windup retimed to logical impact")
	enemy.advance_boss(0.6)
	enemy._update_art_texture()
	check(enemy._last_art_frame == 20, "visual landing equals logical landing frame")
	enemy.interrupt_ability()
	enemy._attack_pose = 0.1
	enemy.boss_recovery = 0
	enemy._update_art_texture()
	check(enemy._last_art_state == "idle", "partial review sample safely falls back to still")
	enemy.free()
