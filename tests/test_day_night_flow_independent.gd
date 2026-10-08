extends SceneTree

# Independent runtime contract. Loadout interactions route real mouse events
# through the live Godot viewport; no UI signals are emitted by this test.
const Deck = preload("res://scripts/combat_deck.gd")
const Content = preload("res://scripts/content_data.gd")
const Plants = preload("res://scripts/plant.gd")
var failures: Array[String] = []
var viewport: SubViewport
var game: Node
var mouse := Vector2.ZERO
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func frames() -> void:
	await process_frame
	await process_frame

func click(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(), "Real click control visible: " + str(control.name if control != null else "missing"))
	if control == null: return
	var point := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point; move.global_position = point; move.relative = point - mouse; mouse = point
	viewport.push_input(move, true); await frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		viewport.push_input(event, true); await frames()

func control(named: String) -> Control: return game.hud._root.find_child(named, true, false) as Control

func click_point(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point; move.global_position = point; move.relative = point-mouse; mouse=point
	viewport.push_input(move,true); await frames()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		viewport.push_input(event,true); await frames()

func deck_ids() -> Array[String]:
	return ["card_sun_pierce","card_sun_pierce","card_root_snare","card_root_snare","card_emergency_dew","card_emergency_dew","card_root_wall","card_root_wall","card_sun_mine","card_sun_mine","card_focus_mark","card_focus_mark"]

func sorted(ids: Array[String]) -> Array[String]:
	var result := ids.duplicate(); result.sort(); return result

func settle_mother() -> void:
	if game.mother_choice_pending:
		var choices: Array[String] = game.get_mother_choices()
		check(not choices.is_empty() and game.choose_mother_card(choices[0]), "Choose actual daily mother upgrade")
	game.hud.hide_mother_choices()
	await frames()

func refresh() -> void:
	game.hud.update_battle_state(game.get_hud_battle_state()); game._refresh_card_ui(); await frames()

func deck_contract() -> void:
	var deck := Deck.new(); var ids := deck_ids()
	check(deck.start_run(ids, 31), "Accept outside twelve-card deck")
	check(deck.hand.is_empty() and deck.draw_pile.size() == 12, "No tactics drawn in initial daytime")
	deck.begin_next_night()
	check(deck.hand.size() == 4 and deck.draw_pile.size() == 8, "First night draws exactly four")
	var held := deck.get_hand(); var played := held[0]
	check(deck.consume(played), "Valid held card consumed")
	check(deck.hand.size() == 3 and deck.draw_pile.size() == 8, "Playing does not draw replacements")
	check(not deck.consume("unknown") and deck.hand.size() == 3, "Unknown consumption cannot draw")
	for night in range(2, 8):
		var before := deck.get_hand(); var remaining := deck.draw_pile.size()
		deck.begin_next_night()
		check(deck.hand.size() == before.size() + mini(2, remaining), "Fixed two-card allotment night %d" % night)
		check(deck.hand.slice(0, before.size()) == before, "Unplayed hand retained night %d" % night)
		check(sorted(deck.hand + deck.draw_pile + deck.consumed) == sorted(ids), "Card conservation night %d" % night)
	check(deck.hand.size() == 11 and deck.draw_pile.is_empty() and deck.consumed.size() == 1, "Pile exhaustion never reshuffles played cards")
	for id in deck.get_hand(): check(deck.consume(id), "Exhaustion consumption")
	deck.begin_next_night()
	check(deck.hand.is_empty() and deck.consumed.size() == 12, "Fully spent deck remains empty")
	check(not Deck.validate_card_play("card_transplant_shovel", "day",100,{"type":"plant"}), "Transplant is not a day-only dead card")
	check(Deck.validate_card_play("card_transplant_shovel", "night",100,{"type":"plant"}), "Transplant remains playable at night")

func runtime_contract() -> void:
	viewport = SubViewport.new(); viewport.size = Vector2i(1280,720); viewport.handle_input_locally = true; root.add_child(viewport)
	var game_script := load("res://scripts/game.gd") as Script
	check(game_script != null and game_script.can_instantiate(), "Live game script compiles")
	if game_script == null or not game_script.can_instantiate(): return
	game = game_script.new()
	var ids := deck_ids(); game.import_profile({"selected_deck":ids,"unlocked_cards":Content.STARTER_CARD_IDS.duplicate()})
	viewport.add_child(game); await frames()
	game.set_process(false); game.mother_flower.set_process(false)
	await settle_mother(); await refresh()
	check(sorted(game.combat_deck.draw_pile) == sorted(ids), "Actual imported outside deck survives _ready/reset")
	check(game.get_combat_hand().is_empty(), "Actual battle starts with empty tactical hand")
	check(game.hud.day_action_panel.visible and not game.hud.combat_hand_panel.visible, "Day exposes only deployment")
	check(game.hud.hand_tabs == null or not game.hud.hand_tabs.visible, "No daytime tactical tab")
	var original: Array[String] = game.get_carried_plant_ids()
	await click(control("PlantLoadoutButton")); check(game.hud.is_plant_loadout_open(), "Daily loadout opens by real click")
	await click(control("LoadoutCard_deploy_prism")); await click(control("CancelLoadout"))
	check(not game.hud.is_plant_loadout_open() and game.get_carried_plant_ids() == original, "Cancel preserves committed loadout")
	await click(control("PlantLoadoutButton"))
	for id in ["deploy_prism","deploy_lantern","deploy_frost","deploy_honeydew"]: await click(control("LoadoutCard_"+id))
	await click(control("ConfirmLoadout"))
	check(game.get_carried_plant_ids() == ["deploy_thorn"], "Confirm real mouse commits current plant cards")
	check(not game.hud.is_plant_loadout_open(), "Confirm closes modal")
	check(game.can_deploy_plant(game.Selection.THORN) and not game.can_deploy_plant(game.Selection.PRISM), "Only committed plants deployable")
	check(not game.set_carried_plant_ids([]) and not game.set_carried_plant_ids(["deploy_thorn","deploy_thorn"]) and not game.set_carried_plant_ids(["card_sun_mine"]), "Empty duplicate and tactical loadout rejected")
	await click(control("PlantLoadoutButton")); await click(control("LoadoutCard_deploy_thorn"))
	check((control("ConfirmLoadout") as Button).disabled, "Cannot confirm empty plant loadout")
	game.begin_night(); check(game.phase == game.Phase.DAY, "Open loadout prevents phase transition")
	await click(control("CancelLoadout")); game.begin_night(); await refresh()
	check(game.phase == game.Phase.NIGHT and game.get_combat_hand().size() == 4, "Actual first night draws four")
	check(not game.hud.day_action_panel.visible and game.hud.combat_hand_panel.visible, "Night exposes only tactical cards")
	check(not control("PlantLoadoutButton").visible and not game.set_carried_plant_ids(["deploy_prism"]), "Night cannot alter plant loadout")
	var held: Array[String] = game.get_combat_hand(); game.begin_night()
	check(game.get_combat_hand() == held, "Repeated begin_night cannot draw extra cards")
	for night in range(2,6):
		game.begin_day(); await settle_mother(); await refresh()
		check(game.get_carried_plant_ids() == ["deploy_thorn"], "Plant carry persists to day %d" % night)
		await click(control("PlantLoadoutButton")); check(game.hud.is_plant_loadout_open(), "Every day permits loadout %d" % night)
		await click(control("CancelLoadout"))
		var before: Array[String] = game.get_combat_hand(); game.begin_night(); await refresh()
		check(game.get_combat_hand().size() == before.size()+2, "Actual night %d draws two despite retained hand" % night)
	check(game.get_combat_hand().size() == 12 and game.combat_deck.draw_pile.is_empty(), "Actual five nights exhaust twelve-card draw pile")
	game.begin_day(); await settle_mother(); game.begin_night(); await refresh()
	check(game.phase == game.Phase.DAY and game.wave_index == 6, "Sixth night resupply returns to deployment daytime")
	check(game.combat_deck.nights_drawn == 6, "Sixth night resupply uses its one numbered night allotment")
	await settle_mother(); game.begin_night(); await refresh()
	check(game.get_combat_hand().size() == 12 and game.combat_deck.draw_pile.is_empty(), "Final night cannot reshuffle exhausted pile")
	check(game.combat_deck.nights_drawn == 7, "Seventh night allotment occurs once after resupply")
	game.begin_day(); await settle_mother(); await refresh()
	game.combat_deck.hand.assign(["card_sun_mine"])
	var energy: int = game.light_energy
	var result: Dictionary = game.play_combat_card("card_sun_mine",Vector2(1600,1400))
	check(not result.get("ok",false) and game.light_energy == energy and game.get_combat_hand() == ["card_sun_mine"], "Any-phase tactical metadata cannot bypass day gameplay guard")
	check(game.export_profile().selected_deck == ids, "Battle flow never rewrites outside selected tactical deck")
	check(game.set_carried_plant_ids(["deploy_lantern","deploy_frost","deploy_honeydew"]), "Extended flowers can be carried")
	game.progression.run_seeds = 12; game.seeds = 12
	for pair in [[game.Selection.LANTERN,Plants.Kind.LANTERN],[game.Selection.FROST,Plants.Kind.FROST],[game.Selection.HONEYDEW,Plants.Kind.HONEYDEW]]:
		var point := Vector2.INF
		for i in range(24):
			var candidate := Vector2(1440,1440)+Vector2.from_angle(TAU*i/24.0)*150.0
			if game.can_place_plant(candidate,pair[0]): point = candidate; break
		check(point != Vector2.INF, "Extended plant fixture has valid supplied site")
		if point == Vector2.INF: continue
		var count: int = game.plants.size(); game._place_plant_at(point,pair[0])
		check(game.plants.size() == count+1 and game.plants[-1].kind == pair[1], "Deployment creates matching extended flower kind %d" % pair[0])
	var planted: Array = game.plants.duplicate()
	for plant in planted: plant.set_process(false)
	check(game.set_carried_plant_ids(["deploy_thorn"]) and game.plants == planted, "Changing carry preserves already planted flowers")
	var node_point := Vector2.INF
	for i in range(24):
		var candidate := Vector2(1440,1440)+Vector2.from_angle(TAU*i/24.0)*200.0
		if game.can_place_light_node(candidate): node_point=candidate; break
	check(node_point != Vector2.INF,"Night repair fixture has valid node site")
	game.light_energy=100; game._place_light_node(node_point)
	check(game.light_nodes.size()==1,"Daytime node fixture planted")
	if game.light_nodes.size()==1:
		var node: Node=game.light_nodes[0]; node.set_process(false); node.health=50.0
		game.phase=game.Phase.NIGHT; game.selected_plant=game.Selection.NONE; await refresh()
		var before_energy: int=game.light_energy; var before_seeds: int=game.seeds
		for action_name in ["select_thorn","select_prism","select_light_sprout"]:
			var action := InputEventAction.new(); action.action=action_name; action.pressed=true
			viewport.push_input(action,true); await frames()
			check(game.selected_plant==game.Selection.NONE,"Night shortcut cannot arm deployment: "+action_name)
		game._place_light_node(Vector2(1540,1440)); game._place_plant_at(Vector2(1540,1440),game.Selection.THORN)
		check(game.light_nodes.size()==1 and game.plants==planted and game.light_energy==before_energy and game.seeds==before_seeds,"Night direct deployment preserves actors and resources")
		await click_point(viewport.canvas_transform*node.global_position)
		check(node.health==50.0 and game.light_energy==before_energy,"Night actual mouse click cannot repair node or spend energy")
	viewport.queue_free(); await frames()

func run() -> void:
	deck_contract(); await runtime_contract()
	for failure in failures: push_error(failure)
	print("DAY_NIGHT_INDEPENDENT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
