extends SceneTree

# Real viewport event routing: no card signals or gameplay callbacks are invoked.
var failures: Array[String] = []
var viewport: SubViewport
var game: Node2D
var mouse := Vector2.ZERO

class TargetEnemy extends Node2D:
	var health := 100.0
	func take_damage(amount: float) -> void: health -= amount
	func get_rank() -> String: return "normal"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func frame() -> void:
	await process_frame
	await process_frame

func motion(point: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - mouse
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	mouse = point
	viewport.push_input(event, true)
	await frame()

func button(pressed: bool, index: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = mouse
	event.global_position = mouse
	event.button_index = index
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and index == MOUSE_BUTTON_LEFT else 0
	viewport.push_input(event, true)
	await frame()

func fixture(ids: Array[String], phase: int = 1, energy: int = 100) -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()
		await frame()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.handle_input_locally = true
	root.add_child(viewport)
	game = load("res://scripts/game.gd").new()
	viewport.add_child(game)
	await frame()
	game.set_process(false)
	game.mother_flower.set_process(false)
	game.phase = phase
	game.mother_choice_pending = false
	game.hud.hide_mother_choices()
	game.light_energy = energy
	game.combat_deck.hand = ids.duplicate()
	game.combat_deck.draw_pile.assign(["card_root_snare", "card_emergency_dew", "card_sun_mine"])
	game.combat_deck.consumed.clear()
	game.world_camera.position_smoothing_enabled = false
	game.world_camera.zoom = Vector2.ONE * 1.7
	game.world_camera.position = Vector2(1440, 1440)
	game.world_camera.force_update_scroll()
	game.hud.update_battle_state(game.get_hud_battle_state())
	game._refresh_card_ui()
	await frame()

func card(index: int = 0) -> Control:
	return game.hud.combat_hand_row.get_child(index) as Control

func screen(world: Vector2) -> Vector2:
	return viewport.canvas_transform * world

func start(index: int = 0) -> void:
	await start_control(card(index))

func start_control(source: Control) -> void:
	await motion(source.get_global_rect().get_center())
	await button(true)
	check(not game.hud.is_card_drag_active(), "Press must not start drag before threshold")
	await motion(mouse + Vector2(1, -1), true)
	check(not game.hud.is_card_drag_active(), "Subthreshold pointer motion must not start drag")
	await motion(mouse + Vector2(0, -40), true)
	check(game.hud.is_card_drag_active(), "Threshold motion must start a native card drag")
	check(viewport.gui_is_dragging(), "Drag must use Godot GUI drag preview")

func drop(point: Vector2) -> void:
	await motion(point, true)
	await button(false)
	check(not game.hud.is_card_drag_active(), "Release must finish drag state")
	check(not viewport.gui_is_dragging(), "Release must remove native preview")

func untouched(energy: int, hand: Array[String], label: String) -> void:
	check(game.light_energy == energy, label + ": no energy spent")
	check(game.get_combat_hand() == hand, label + ": hand unchanged")
	check(game.combat_deck.consumed.is_empty(), label + ": no card consumed")

func day_cases() -> void:
	var point := Vector2(1540, 1320)
	await fixture(["card_transplant_shovel"], 0)
	await start_control(game.hud.light_sprout_button)
	await drop(screen(point))
	check(game.light_nodes.size() == 1 and game.light_energy == 85, "Day deployment drag creates real light node and spends fifteen energy once")
	if game.light_nodes.size() == 1:
		check(game.light_nodes[0].global_position.distance_to(point) < 0.1, "Day deployment drop uses correct world position")
	check(game.selected_plant == -1, "Deployment drag must not leave a second placement armed")

	await fixture(["card_transplant_shovel"], 0)
	await start_control(game.hud.light_sprout_button)
	await drop(screen(Vector2(1700, 1300)))
	check(game.light_nodes.is_empty() and game.light_energy == 100, "Day deployment outside supply spends nothing and creates no node")
	await start_control(game.hud.light_sprout_button)
	game.light_energy = 0
	await drop(screen(point))
	check(game.light_nodes.is_empty() and game.light_energy == 0, "Day deployment rechecks energy on release")

	await fixture(["card_transplant_shovel"], 0)
	await start_control(game.hud.thorn_button)
	game.progression.run_seeds = 0
	game.seeds = 0
	await drop(screen(point))
	check(game.plants.is_empty() and game.seeds == 0, "Day plant drag rechecks seed budget on release")

	await fixture(["card_transplant_shovel"], 0)
	await start_control(game.hud.light_sprout_button)
	await button(true, MOUSE_BUTTON_RIGHT)
	await button(false, MOUSE_BUTTON_RIGHT)
	await drop(screen(point))
	check(game.light_nodes.is_empty() and game.light_energy == 100, "Right click cancels day deployment drag")

	await fixture(["card_transplant_shovel"], 0)
	var tactics := game.hud.find_child("TacticsTab", true, false) as Button
	check(tactics != null and tactics.is_visible_in_tree(), "Day tactics tab must be reachable")
	if tactics == null: return
	await motion(tactics.get_global_rect().get_center())
	await button(true)
	await button(false)
	check(game.hud.combat_hand_panel.is_visible_in_tree() and card().is_visible_in_tree(), "Actual tab click must reveal day tactical hand")
	var plant := load("res://scripts/plant.gd").new() as Node2D
	plant.position = point
	plant.configure(0, 0)
	plant.add_to_group("plants")
	game.add_child(plant)
	plant.set_process(false)
	game.plants.append(plant)
	game._rebuild_network()
	await start()
	await drop(screen(point))
	untouched(100, ["card_transplant_shovel"], "Transplant source selection")
	check(game.selected_combat_card == "card_transplant_shovel", "Transplant must retain selected card for destination step")
	await motion(screen(Vector2(1440, 1440)))
	await button(true)
	await button(false)
	untouched(100, ["card_transplant_shovel"], "Invalid transplant destination")
	check(plant.global_position.distance_to(point) < 0.1, "Invalid transplant destination leaves source unmoved")
	var destination := Vector2(1330, 1360)
	await motion(screen(destination))
	check(not game.hud.is_point_over_battle_ui(screen(destination)), "Valid transplant destination must be outside HUD")
	await button(true)
	await button(false)
	check(plant.global_position.distance_to(destination) < 0.1, "Second actual mouse target moves transplant source")
	check(game.light_energy == 97 and game.combat_deck.consumed == ["card_transplant_shovel"], "Transplant consumes exactly once after valid destination")
	check(game.selected_combat_card.is_empty(), "Successful transplant clears pending selection")

func run() -> void:
	await fixture(["card_root_wall", "card_root_wall"])
	var source := card(0)
	var camera_before: Vector2 = game.world_camera.position
	var world := Vector2(1540, 1320)
	check(game.battlefield.is_inside_plantable_area(world), "Fixture ground must be legal")
	await start()
	check(game.light_energy == 100 and game.combat_deck.consumed.is_empty(), "Drag start must not apply or consume")
	game.light_energy = 90
	game._refresh_card_ui()
	await frame()
	check(is_instance_valid(source) and card(0) == source, "Energy refresh must preserve held card instance")
	await motion(Vector2(2, 250), true)
	await create_timer(0.12).timeout
	check(game.world_camera.position.is_equal_approx(camera_before), "Edge scrolling and mouse panning must stop during drag")
	await drop(screen(world))
	check(game.light_energy == 83, "Valid ground drop spends cost exactly once")
	check(game.combat_deck.consumed == ["card_root_wall"], "Duplicate card drag consumes one copy")
	check(game.get_combat_hand().count("card_root_wall") == 1 and game.get_combat_hand().size() == 4, "Successful drop replenishes hand and preserves duplicate")
	var zones := get_nodes_in_group("temporary_battle_objects")
	check(zones.size() == 1, "Ground drop creates one actual battle effect")
	if zones.size() == 1:
		check(zones[0].global_position.distance_to(world) < 0.1, "Drop position must invert camera canvas transform at nondefault zoom")
	check(game.selected_combat_card.is_empty(), "Drop must not arm a second click cast")
	check(game.world_camera.is_processing() and game.world_camera.is_processing_unhandled_input(), "Drag must restore camera input and processing")

	await fixture(["card_sun_pierce"])
	var enemy := TargetEnemy.new()
	enemy.position = Vector2(1540, 1320)
	game.add_child(enemy)
	enemy.add_to_group("enemies")
	await start()
	await drop(screen(enemy.global_position))
	check(enemy.health == 58.0 and game.light_energy == 96, "Targeted drop must deal actual 42 damage and cost four")
	check(game.combat_deck.consumed.size() == 1, "Targeted drop consumes once")

	await fixture(["card_sun_pierce"])
	await start()
	await drop(screen(world))
	untouched(100, ["card_sun_pierce"], "Missing target")

	await fixture(["card_root_wall"])
	await start()
	await drop(game.hud.primary_action_button.get_global_rect().get_center())
	untouched(100, ["card_root_wall"], "Drop over action UI")
	await start()
	await drop(card().get_global_rect().get_center())
	untouched(100, ["card_root_wall"], "Drop back into hand")

	await fixture(["card_root_wall"])
	await start()
	game.light_energy = 0
	game._refresh_card_ui()
	await drop(screen(world))
	untouched(0, ["card_root_wall"], "Energy changed while held")

	await fixture(["card_root_wall"])
	await start()
	game.phase = 0
	game._refresh_card_ui()
	await drop(screen(world))
	untouched(100, ["card_root_wall"], "Phase changed while held")

	await fixture(["card_root_wall"])
	await start()
	game.phase = 3
	game._refresh_card_ui()
	await drop(screen(world))
	untouched(100, ["card_root_wall"], "Battle ended while held")

	await fixture(["card_root_wall"])
	await start()
	game.mother_choice_pending = true
	game.hud.show_mother_choices(game.get_mother_choices())
	await drop(screen(world))
	untouched(100, ["card_root_wall"], "Modal mother choice appeared while held")

	await fixture(["card_root_wall"])
	await start()
	await drop(screen(Vector2(1440, 1440)))
	untouched(100, ["card_root_wall"], "Invalid ground in mother core")

	await fixture(["card_root_wall"], 1, 0)
	await motion(card().get_global_rect().get_center())
	await button(true)
	await motion(mouse + Vector2(0, -40), true)
	check(not game.hud.is_card_drag_active() and not viewport.gui_is_dragging(), "Unaffordable card must not start native drag")
	await button(false)
	untouched(0, ["card_root_wall"], "Unaffordable card")

	await fixture(["card_weather_seal"])
	await start()
	check(game.weather_seal_time == 0.0 and game.light_energy == 100, "Global card must not fire on drag start")
	await drop(screen(world))
	check(game.weather_seal_time == 12.0 and game.light_energy == 86, "Global card applies only at valid drop")
	check(game.combat_deck.consumed == ["card_weather_seal"], "Global drop consumes once")

	await fixture(["card_root_wall"])
	await start()
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	viewport.push_input(cancel, true)
	await frame()
	await drop(screen(world))
	untouched(100, ["card_root_wall"], "Escape cancels held card")

	await day_cases()

	for issue in failures: push_error(issue)
	print("CARD DRAG INTEGRATION ", "PASSED" if failures.is_empty() else "FAILED", " (", failures.size(), " failures)")
	viewport.queue_free()
	await frame()
	quit(0 if failures.is_empty() else 1)
