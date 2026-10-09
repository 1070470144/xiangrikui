extends RefCounted

const Resolver = preload("res://scripts/card_effect_resolver.gd")
const CombatDeck = preload("res://scripts/combat_deck.gd")
const ContentData = preload("res://scripts/content_data.gd")
const Plant = preload("res://scripts/plant.gd")
var failures: Array[String] = []

class FakeEnemy extends Node2D:
	var health := 100.0
	var rank := "normal"
	var friendly := false
	var card_damage_multiplier := 1.0
	func take_damage(amount: float) -> void: health -= amount
	func apply_slow(_source: String, _ratio: float, _duration: float) -> void: pass
	func convert_to_friendly(_duration: float) -> bool: friendly = true; return true

class FakeGame extends Node:
	var battlefield := FakeField.new()
	var phase := 1
	var light_energy := 100
	var combat_deck := CombatDeck.new()
	var weather_seal_time := 0.0
	func spend_energy(cost: int) -> bool:
		if light_energy < cost: return false
		light_energy -= cost; return true

class FakeField extends RefCounted:
	func is_inside_plantable_area(_point: Vector2) -> bool: return true

class HealingNode extends Node2D:
	var health := 20.0
	func heal(amount: float) -> bool:
		health += amount
		return true

func expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> Array[String]:
	test_every_card_has_a_runtime_handler()
	test_damage_card_consumes_once()
	test_ranked_card_durations()
	test_resurrection_uses_reverse_death_order()
	test_zone_rank_rules()
	test_phantom_position_is_legal()
	test_same_named_zones_refresh_instead_of_stack()
	test_ground_target_validation_precedes_payment()
	test_emergency_dew_heals_plants_only_in_radius()
	return failures

func test_every_card_has_a_runtime_handler() -> void:
	var resolver := Resolver.new()
	var supported: Array[String] = resolver.get_supported_card_ids()
	expect(supported.size() == 24, "resolver must explicitly support all twenty-four cards")
	for card in ContentData.COMBAT_CARDS:
		expect(supported.has(str(card["id"])), "resolver missing handler for %s" % card["id"])

func test_damage_card_consumes_once() -> void:
	var game := FakeGame.new(); game.combat_deck.start_run(["card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce","card_sun_pierce"], 7)
	game.combat_deck.begin_next_night()
	var enemy := FakeEnemy.new(); enemy.add_to_group("enemies")
	var resolver := Resolver.new(); var result := resolver.resolve(game, "card_sun_pierce", Vector2.ZERO)
	expect(result.get("ok", false), "damage card must resolve")
	expect(enemy.health == 100.0 and game.light_energy == 96 and result.get("created", []).size() == 1, "sun pierce creates a delayed zone and spends four energy")
	expect(game.combat_deck.remaining_count() == 11, "successful play must permanently consume card")
	enemy.free(); game.free()

func test_ranked_card_durations() -> void:
	var resolver := Resolver.new()
	expect(resolver.get_stasis_duration("normal") == 4.0, "time stasis must stop normal enemies for four seconds")
	expect(resolver.get_stasis_duration("elite") == 2.0, "time stasis must stop elites for two seconds")
	expect(resolver.get_stasis_duration("boss") == 0.6, "time stasis must stop bosses for 0.6 seconds")
	expect(resolver.get_root_prison_duration("normal") == 3.0 and resolver.get_root_prison_duration("elite") == 1.2, "root prison must use rank-specific roots")
	expect(resolver.get_redemption_duration("normal") == 20.0 and resolver.get_redemption_duration("elite") == 12.0, "shadow redemption must last less on elites")

func test_resurrection_uses_reverse_death_order() -> void:
	var game_script := ResourceLoader.load("res://scripts/game.gd") as Script
	var game: Node = game_script.new(); var dead: Array[Node] = []
	for i in range(5):
		var plant: Node = Plant.new(); plant.configure(Plant.Kind.THORN, 0); plant.health = 0.0; plant.death_order = i + 1; plant.global_position = Vector2(i * 100, 0); game.plants.append(plant); dead.append(plant)
	var blocker: Node = Plant.new(); blocker.configure(Plant.Kind.THORN, 0); blocker.global_position = dead[4].global_position; game.plants.append(blocker)
	var resolver := Resolver.new(); var revived: int = resolver._resurrect_plants(game)
	expect(revived == 3, "garden resurrection must revive at most three valid plants")
	expect(dead[4].health == 0.0, "resurrection must skip a death position occupied by a living plant")
	expect(dead[3].health > 0.0 and dead[2].health > 0.0 and dead[1].health > 0.0 and dead[0].health == 0.0, "resurrection must continue in reverse death order after skips")
	for plant in dead: plant.free()
	blocker.free(); game.free()

func test_zone_rank_rules() -> void:
	var object_script := ResourceLoader.load("res://scripts/temporary_battle_object.gd") as Script
	var prison: Node = object_script.new(); prison.configure("card_root_prison", Vector2.ZERO, {"radius":90.0,"duration":3.0})
	expect(prison.get_ranked_control("normal") == {"stun":3.0}, "root prison must root normal enemies for three seconds")
	expect(prison.get_ranked_control("elite") == {"stun":1.2}, "root prison must root elites for 1.2 seconds")
	expect(prison.get_ranked_control("boss") == {"slow":0.12,"duration":3.0}, "root prison must only slow bosses")
	var snare: Node = object_script.new(); snare.configure("card_root_snare", Vector2.ZERO, {"duration":6.0})
	expect(snare.get_slow_for_rank("boss") == 0.10 and snare.get_slow_for_rank("elite") == 0.30, "root snare must use documented boss resistance")
	prison.free(); snare.free()

func test_phantom_position_is_legal() -> void:
	var game_script := ResourceLoader.load("res://scripts/game.gd") as Script
	var battlefield_script := ResourceLoader.load("res://scripts/battlefield.gd") as Script
	var game: Node = game_script.new(); game.battlefield = battlefield_script.new()
	var source: Node = Plant.new(); source.configure(Plant.Kind.THORN, 0); source.global_position = Vector2(700, 950); game.plants.append(source)
	var resolver := Resolver.new(); var point: Vector2 = resolver.find_phantom_position(game, source)
	expect(point != Vector2.INF, "phantom bloom must find a legal neighboring position")
	expect(point.distance_to(source.global_position) >= 48.0 and game.battlefield.is_inside_plantable_area(point), "phantom position must not overlap its source and must stay plantable")
	source.free(); game.battlefield.free(); game.free()

func test_same_named_zones_refresh_instead_of_stack() -> void:
	var game := Node.new(); var resolver := Resolver.new()
	var first: Node = resolver._spawn_zone(game, "card_root_snare", Vector2.ZERO, {"duration":6.0,"radius":70.0}, {"slow_ratio":0.30})
	first.remaining_time = 1.0
	var second: Node = resolver._spawn_zone(game, "card_root_snare", Vector2(10, 0), {"duration":6.0,"radius":70.0}, {"slow_ratio":0.30})
	expect(first == second and game.get_child_count() == 1 and first.remaining_time == 6.0, "same named persistent zones must refresh instead of stacking")
	game.free()

func test_ground_target_validation_precedes_payment() -> void:
	var game_script := ResourceLoader.load("res://scripts/game.gd") as Script
	var battlefield_script := ResourceLoader.load("res://scripts/battlefield.gd") as Script
	var game: Node = game_script.new(); game.battlefield = battlefield_script.new(); game.phase = game.Phase.NIGHT; game.light_energy = 100
	var deck: Array[String] = ["card_root_wall","card_root_wall","card_root_snare","card_root_snare","card_emergency_dew","card_emergency_dew","card_sun_mine","card_sun_mine","card_lure_bud","card_lure_bud","card_emergency_light","card_focus_mark"]
	game.combat_deck.start_run(deck, 1)
	game.combat_deck.hand.clear(); game.combat_deck.hand.append("card_root_wall")
	var before: int = game.light_energy; var result: Dictionary = game.play_combat_card("card_root_wall", Vector2(-100, -100))
	expect(not result.get("ok", false) and game.light_energy == before and game.combat_deck.hand.has("card_root_wall"), "invalid ground targets must not spend energy or consume cards")
	game.battlefield.free(); game.free()

func test_emergency_dew_heals_plants_only_in_radius() -> void:
	var game_script := ResourceLoader.load("res://scripts/game.gd") as Script
	var game: Node = game_script.new()
	var inside: Node = Plant.new(); inside.configure(Plant.Kind.THORN, 0); inside.global_position = Vector2(100, 100); inside.health = 20.0; game.plants.append(inside); game.add_child(inside)
	var outside: Node = Plant.new(); outside.configure(Plant.Kind.THORN, 0); outside.global_position = Vector2(300, 100); outside.health = 20.0; game.plants.append(outside); game.add_child(outside)
	var second: Node = Plant.new(); second.configure(Plant.Kind.THORN, 0); second.global_position = Vector2(240, 100); second.health = second.max_health - 10.0; game.plants.append(second); game.add_child(second)
	var node := HealingNode.new(); node.global_position = Vector2(100, 100); node.add_to_group("light_nodes"); game.add_child(node)
	var resolver := Resolver.new()
	var affected: int = resolver._heal_plants(game, Vector2(100, 100), 140.0, 45.0)
	expect(affected == 2 and inside.health == minf(inside.max_health, 65.0) and second.health == second.max_health, "emergency dew must heal multiple plants including the radius boundary and cap health")
	expect(outside.health == 20.0, "emergency dew must not heal plants outside range")
	expect(node.health == 20.0, "emergency dew must not heal light nodes")
	game.battlefield = load("res://scripts/battlefield.gd").new()
	game.phase = game.Phase.NIGHT; game.light_energy = 100
	game.combat_deck.hand.assign(["card_emergency_dew"])
	var point := Vector2(700, 950)
	inside.global_position = point; inside.health = inside.max_health - 10.0
	var preview: Dictionary = resolver.get_target_preview(game, "card_emergency_dew", point)
	expect(preview.get("valid", false) and preview.get("radius", 0.0) == 140.0, "dew preview must use the ground point and radius 140")
	var result: Dictionary = resolver.resolve(game, "card_emergency_dew", point)
	expect(result.get("ok", false) and game.light_energy == 95 and game.combat_deck.consumed.count("card_emergency_dew") == 1, "successful dew must spend five energy and consume once")
	game.combat_deck.hand.assign(["card_emergency_dew"])
	result = resolver.resolve(game, "card_emergency_dew", point)
	expect(not result.get("ok", false) and game.light_energy == 95 and game.combat_deck.hand.has("card_emergency_dew"), "full-health area must not spend energy or consume dew")
	game.battlefield.free(); inside.free(); second.free(); outside.free(); node.free(); game.free()
