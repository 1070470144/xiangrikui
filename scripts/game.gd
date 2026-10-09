extends Node2D

signal return_to_menu_requested
signal mother_choices_available(choice_ids: Array[String])
signal run_settled(result: Dictionary)

enum Phase { DAY, NIGHT, VICTORY, FAILURE, RETREATED }
enum Selection { NONE = -1, THORN = 0, PRISM = 1, LIGHT_SPROUT = 2, LANTERN = 3, FROST = 4, HONEYDEW = 5, STORM = 6, GALE = 7, SUNWELL = 8, EMBER = 9, SLUMBER = 10, SPEAR = 11, BURST = 12, STONE = 13, CLEANSE = 14, DRUM = 15 }

const BattlefieldScript = preload("res://scripts/battlefield.gd")
const MotherFlowerScript = preload("res://scripts/mother_flower.gd")
const LightNodeScript = preload("res://scripts/light_node.gd")
const PlantScript = preload("res://scripts/plant.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const EnemySpatialIndex = preload("res://scripts/enemy_spatial_index.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const HudScript = preload("res://scripts/hud.gd")
const EffectScript = preload("res://scripts/effects.gd")
const NightFogScript = preload("res://scripts/night_fog.gd")
const DaylightGlowScript = preload("res://scripts/daylight_glow.gd")
const WorldLightingScript = preload("res://scripts/world_lighting.gd")
const WorldCameraScript = preload("res://scripts/world_camera.gd")
const Balance = preload("res://scripts/balance.gd")
const WaveDirector = preload("res://scripts/wave_director.gd")
const Progression = preload("res://scripts/progression.gd")
const MotherEvolution = preload("res://scripts/mother_evolution.gd")
const CombatDeck = preload("res://scripts/combat_deck.gd")
const CardEffectResolver = preload("res://scripts/card_effect_resolver.gd")
const ContentData = preload("res://scripts/content_data.gd")
const HealthBarScript = preload("res://scripts/world_health_bar.gd")
const TerrainEventControllerScript = preload("res://scripts/terrain_event_controller.gd")
const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")
const MonsterSpawnFXScript = preload("res://scripts/monster_spawn_fx.gd")
const DragWorldPreviewScript = preload("res://scripts/battle_drag_preview.gd")
const ArtLibrary = preload("res://scripts/art_library.gd")
const PlantRoster = preload("res://scripts/plant_roster.gd")
const AcidRainFXScript = preload("res://scripts/acid_rain_fx.gd")
const ThunderstormFXScript = preload("res://scripts/thunderstorm_fx.gd")

var phase: Phase = Phase.DAY
var wave_index := 0
var starting_night := 1
var light_energy := Balance.STARTING_ENERGY
var seeds := Balance.STARTING_SEEDS
var day_time_left := Balance.FIRST_DAY_DURATION
var selected_plant := Selection.NONE
var aiming_sunburst := false
var spawn_queue: Array[Dictionary] = []
var active_enemies: Array[Node] = []
var enemy_index := EnemySpatialIndex.new()
var spawn_cursor := 0
var _queue_batches: Dictionary = {}
var _queue_source_size := -1
var _card_ui_state: Array = []
var performance_samples: Array[Dictionary] = []
var _performance_cursor := 0
var _spawn_usec := 0
var _spawned_this_frame := 0
var _ui_usec := 0
@export var spawn_budget_per_frame := 8
var _hud_refresh_clock := 0.0
var _radar_refresh_clock := 0.0
var _network_refresh_clock := 0.0
var _cached_radar_nodes: Array = []
var _cached_network_lines: Array[Dictionary] = []
var spawn_clock := 0.0
var run_seed := -1
var _run_seed_override := -1
var wave_director := WaveDirector.new()
var _kill_energy_buffer := 0.0
var _energy_regen_buffer := 0.0
var battlefield: Node2D
var mother_flower: Node2D
var light_nodes: Array[Node] = []
const MOTHER_PLANT_CAPACITY := 8
var mother_plant_load := 0
var plants: Array[Node] = []
var hud: CanvasLayer
var night_fog: Node2D
var daylight_glow: Node2D
var world_lighting: Node
var world_camera: Camera2D
var threat_levels := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
var weather := "clear"
var terrain_shift := 0
var boss_active := false
var boss_feedback: Node2D
var environmental_tick := 0.0
var thunderstorm_terrain_tick := 0.0
var weather_seal_time := 0.0
var progression := Progression.new()
var mother_evolution := MotherEvolution.new()
var combat_deck := CombatDeck.new()
var card_effect_resolver := CardEffectResolver.new()
var day_choice_index := 1
var mother_choice_pending := true
var mother_attack_count := 0
var mother_last_target_id := 0
var mother_same_target_hits := 0
var mother_pulse_count := 0
var selected_combat_card := ""
var _seen_enemy_alerts: Dictionary = {}
var _sun_boss_spawned := false
static var PLANT_DEPLOY_IDS := PlantRoster.deploy_map()
var carried_plant_ids: Array[String] = ["deploy_thorn", "deploy_prism", "deploy_lantern", "deploy_frost", "deploy_honeydew"]
var planting_timings: Array[Dictionary] = []
var _combat_card_drag_active := false
var _drag_card_id := ""
var _drag_start_phase := -1
var drag_world_preview: Node2D
var _drag_release_frame := -100
var _drag_camera_process := true
var _drag_camera_input := true
var _transplant_source: Node = null
var terrain_events: Node
var acid_rain_fx: Node2D
var thunderstorm_fx: Node2D

var waves: Array = Balance.WAVES.duplicate(true)
var forecast_queue: Array[Dictionary] = []
var forecast_night := -1
var spawn_forecast: Control

func _prepare_spawn_forecast() -> void:
	forecast_night = wave_index + 1
	forecast_queue.clear()
	if forecast_night <= waves.size():
		wave_director.prepare(battlefield.terrain_map if battlefield != null else null, BattlefieldSpec.CENTER)
		forecast_queue = wave_director.build(forecast_night, run_seed + forecast_night * 104729)
		for entry in forecast_queue:
			if not Vector2(entry.spawn_position).is_finite():
				forecast_queue.clear()
				forecast_night = -1
				push_error("Cannot prepare reachable spawn forecast")
				break
	if is_instance_valid(spawn_forecast):
		spawn_forecast.update_queue(forecast_queue)
		spawn_forecast.visible = phase == Phase.DAY

func _ready() -> void:
	y_sort_enabled = true
	_build_world()
	reset_model()

func get_target_wave_count() -> int:
	return 7

func set_run_seed(value: int) -> void:
	_run_seed_override = value
	run_seed = value

func set_starting_night(value: int) -> void:
	starting_night = clampi(value, 1, 7)

func get_night_rule(night: int) -> Dictionary:
	var rules := {
		1: {"name": "初临之夜", "weather": "clear", "boss": "", "resupply": false},
		2: {"name": "八方来袭", "weather": "clear", "boss": "", "resupply": false},
		3: {"name": "酸雨之夜", "weather": "acid_rain", "boss": "", "resupply": false},
		4: {"name": "雷雨之夜", "weather": "thunderstorm", "boss": "", "resupply": false},
		5: {"name": "根冠巨像与浓雾", "weather": "fog", "boss": "root_colossus", "resupply": false},
		6: {"name": "喘息与补给", "weather": "resupply", "boss": "", "resupply": true},
		7: {"name": "太阳吞噬者", "weather": "eclipse", "boss": "sun_devourer", "resupply": false},
	}
	return rules.get(night, rules[7])

func should_show_night_fog(night: int) -> bool:
	return str(get_night_rule(night).get("weather", "clear")) == "fog"

func is_weather_active() -> bool:
	return phase == Phase.NIGHT and weather_seal_time <= 0.0 and weather != "clear"

func get_weather_enemy_attack_multiplier() -> float:
	return 1.10 if is_weather_active() and weather in ["acid_rain", "thunderstorm"] else 1.0

func get_weather_enemy_speed_multiplier() -> float:
	return 1.10 if is_weather_active() and weather == "thunderstorm" else 1.0

func get_weather_heal_multiplier() -> float:
	return 0.85 if is_weather_active() and weather == "thunderstorm" else 1.0

func get_weather_plant_interval_multiplier() -> float:
	return 1.15 if is_weather_active() and weather == "fog" else 1.0

func _stop_weather_fx() -> void:
	if is_instance_valid(acid_rain_fx): acid_rain_fx.set_active(false)
	if is_instance_valid(thunderstorm_fx): thunderstorm_fx.reset()
	if is_instance_valid(night_fog): night_fog.set_active(false)

func get_light_sprout_cost(at_night: bool) -> int:
	return Balance.NIGHT_LIGHT_SPROUT_COST if at_night else Balance.DAY_LIGHT_SPROUT_COST

func get_plant_seed_cost(kind: int) -> int:
	return int(ContentData.get_flower(PlantRoster.flower_for_selection(kind)).get("seed_cost", 2))

func reset_model() -> void:
	_stop_weather_fx()
	if _run_seed_override < 0:
		var run_rng := RandomNumberGenerator.new()
		run_rng.randomize()
		run_seed = run_rng.randi()
	else:
		run_seed = _run_seed_override
	_kill_energy_buffer = 0.0
	carried_plant_ids.assign(PlantRoster.DEFAULT_IDS)
	planting_timings.clear()
	var resource_loader := get_node_or_null("/root/PlantResources") if is_inside_tree() else null
	if resource_loader != null: resource_loader.request_loadout(carried_plant_ids)
	phase = Phase.DAY
	wave_index = starting_night - 1
	if resource_loader != null: resource_loader.request_night(starting_night)
	light_energy = int(progression.get_meta_value("starting_energy"))
	seeds = Balance.STARTING_SEEDS
	day_time_left = Balance.FIRST_DAY_DURATION
	selected_plant = Selection.NONE
	aiming_sunburst = false
	spawn_queue.clear()
	active_enemies.clear()
	if hud != null: hud.update_enemy_radar(PackedVector2Array(), PackedVector2Array())
	enemy_index.clear(); spawn_cursor = 0; _queue_batches.clear(); _card_ui_state.clear()
	performance_samples.clear()
	_performance_cursor = 0
	_hud_refresh_clock = 0.0; _radar_refresh_clock = 0.0; _network_refresh_clock = 0.0
	spawn_clock = 0.0
	_seen_enemy_alerts.clear()
	_sun_boss_spawned = false
	_energy_regen_buffer = 0.0
	weather = "clear"
	terrain_shift = 0
	boss_active = false
	environmental_tick = 0.0
	thunderstorm_terrain_tick = 0.0
	weather_seal_time = 0.0
	progression.start_run(Balance.STARTING_SEEDS)
	mother_evolution.reset()
	day_choice_index = 1
	mother_choice_pending = true
	mother_attack_count = 0; mother_last_target_id = 0; mother_same_target_hits = 0; mother_pulse_count = 0
	var run_deck: Array[String] = progression.selected_deck.duplicate() if progression.validate_deck(progression.selected_deck) else _default_deck()
	combat_deck.start_run(run_deck, 1)
	if is_inside_tree() and battlefield != null:
		if is_instance_valid(terrain_events): terrain_events.stop_and_restore()
		_clear_dynamic_actors()
		battlefield.reset_slots()
		mother_flower.max_health = get_starting_mother_health()
		mother_flower.reset_state()
		hud.hide_result()
		hud.show_message("按 3 种植光脉芽，再在供光范围内自由种植防御植物")
		night_fog.set_active(false)
		night_fog.clear_reveal_sources()
		daylight_glow.set_active(true)
		if is_instance_valid(thunderstorm_fx): thunderstorm_fx.reset()
		world_lighting.set_phase(true, 0.0)
		world_camera.focus_world(BattlefieldScript.CENTER)
	if is_inside_tree():
		mother_choices_available.emit(get_mother_choices())
		_refresh_card_ui()
	_prepare_spawn_forecast()

func get_carried_plant_ids() -> Array[String]: return carried_plant_ids.duplicate()

func set_carried_plant_ids(ids: Array) -> bool:
	if phase != Phase.DAY or ids.is_empty() or ids.size() > PlantRoster.MAX_SLOTS or _combat_card_drag_active: return false
	var accepted: Array[String] = []
	for id in ids:
		if not id is String or not PLANT_DEPLOY_IDS.has(id) or accepted.has(id): return false
		accepted.append(id)
	carried_plant_ids = accepted
	var loader := get_node_or_null("/root/PlantResources") if is_inside_tree() else null
	if loader != null: loader.request_loadout(carried_plant_ids)
	_clear_phase_selection()
	_refresh_card_ui()
	return true

func can_deploy_plant(kind: int) -> bool:
	if phase != Phase.DAY: return false
	for id in carried_plant_ids:
		if int(PLANT_DEPLOY_IDS.get(id, Selection.NONE)) == kind: return true
	return false

func _plant_loadout_open() -> bool:
	return is_instance_valid(hud) and hud.is_plant_loadout_open()

func _open_plant_loadout() -> void:
	if phase != Phase.DAY or _combat_card_drag_active: return
	_clear_phase_selection()
	hud.show_plant_loadout(get_carried_plant_ids())

func _confirm_plant_loadout(ids: Array[String]) -> void:
	if set_carried_plant_ids(ids):
		hud.hide_plant_loadout()
		hud.show_message("今日携带植物已更新；场上植物保留")

func _clear_phase_selection() -> void:
	selected_combat_card = ""; selected_plant = Selection.NONE; aiming_sunburst = false
	_transplant_source = null
	if _combat_card_drag_active: _finish_combat_card_drag()
	if is_instance_valid(battlefield): battlefield.clear_placement_preview()

func _default_deck() -> Array[String]:
	var deck: Array[String] = []
	for id in ["card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud"]:
		deck.append(id); deck.append(id)
	return deck

func get_mother_choices() -> Array[String]: return mother_evolution.get_choices()

func choose_mother_card(card_id: String) -> bool:
	if not mother_choice_pending:
		return false
	if mother_evolution.path_id.is_empty():
		var accepted: bool = mother_evolution.choose_path(card_id)
		if accepted and is_instance_valid(mother_flower): mother_flower.choose_path(card_id)
		if accepted:
			mother_choice_pending = false
			if is_instance_valid(hud): hud.hide_mother_choices()
		return accepted
	var upgraded: bool = mother_evolution.choose_upgrade(card_id)
	if upgraded and is_instance_valid(mother_flower): mother_flower.choose_evolution(card_id)
	if upgraded:
		mother_choice_pending = false
		if is_instance_valid(hud): hud.hide_mother_choices()
	return upgraded

func begin_day() -> void:
	if is_instance_valid(boss_feedback): boss_feedback.clear_all()
	var resources := get_node_or_null("/root/PlantResources") if is_inside_tree() else null
	if resources != null: resources.request_night(wave_index + 1)
	_stop_weather_fx()
	phase = Phase.DAY
	if is_instance_valid(world_lighting): world_lighting.set_phase(true)
	if is_instance_valid(daylight_glow): daylight_glow.set_active(true)
	if is_instance_valid(night_fog): night_fog.set_active(false)
	if is_instance_valid(thunderstorm_fx): thunderstorm_fx.reset()
	_clear_phase_selection()
	if is_instance_valid(terrain_events): terrain_events.stop_and_restore()
	_prepare_spawn_forecast()
	if is_instance_valid(mother_flower): mother_flower.on_day_started()
	day_choice_index += 1
	mother_choice_pending = not get_mother_choices().is_empty()
	if mother_choice_pending:
		mother_choices_available.emit(get_mother_choices())
		if is_instance_valid(hud): hud.show_mother_choices(get_mother_choices())

func get_combat_hand() -> Array[String]: return combat_deck.get_hand()
func mulligan_combat_card(_card_id: String) -> bool: return false
func play_combat_card(card_id: String, target: Variant) -> Dictionary:
	if phase != Phase.NIGHT: return {"ok":false,"reason":"night_only"}
	return card_effect_resolver.resolve(self, card_id, target)
func can_retreat() -> bool: return phase == Phase.DAY

func get_hud_battle_state() -> Dictionary:
	var phase_name := "day" if phase == Phase.DAY else "night"
	if phase == Phase.VICTORY:
		phase_name = "day"
	var remaining := get_remaining_spawn_count() + _get_active_enemy_count()
	var batch_total := 0
	var batch_current := 0
	batch_total = _queue_batches.size()
	if get_remaining_spawn_count() > 0: batch_current = int(spawn_queue[spawn_cursor].get("batch", 0))
	var boss_direction := -1
	if boss_active:
		for index in range(threat_levels.size()):
			if threat_levels[index] > 0.0:
				boss_direction = index
				break
	return {
		"phase": phase_name,
		"health": mother_flower.health if is_instance_valid(mother_flower) else Balance.MOTHER_MAX_HEALTH,
		"max_health": get_starting_mother_health(),
		"energy": light_energy,
		"seeds": seeds,
		"night": wave_index,
		"night_total": get_target_wave_count(),
		"time_left": day_time_left,
		"remaining_enemies": remaining,
		"batch_current": batch_current,
		"batch_total": batch_total,
		"sunburst_cost": int(get_sunburst_profile()["cost"]),
		"light_sprout_cost": get_light_sprout_cost(phase == Phase.NIGHT),
		"boss_active": boss_active,
		"boss_direction": boss_direction,
	}

func import_profile(profile: Dictionary) -> void:
	progression.import_profile(profile)
	var deck := progression.selected_deck
	if progression.validate_deck(deck): combat_deck.start_run(deck, 1)

func export_profile() -> Dictionary:
	return progression.export_profile()

func get_starting_mother_health() -> float: return float(progression.get_meta_value("max_health"))
func get_day_energy_regen() -> float: return float(progression.get_meta_value("day_regen"))
func get_base_sunburst_damage() -> float: return float(progression.get_meta_value("sunburst_damage"))

func get_sunburst_profile() -> Dictionary:
	return {"cost":mother_evolution.get_sunburst_cost(Balance.SUNBURST_COST), "damage":mother_evolution.get_sunburst_damage(get_base_sunburst_damage()), "radius":mother_evolution.get_sunburst_radius(Balance.SUNBURST_RADIUS), "kill_energy":int(mother_evolution.get_effect_value("sunburst_kill_energy", 0)), "refund_cap":int(mother_evolution.get_effect_value("sunburst_refund_cap", 0)), "afterglow_duration":float(mother_evolution.get_effect_value("sunburst_afterglow_duration", 0.0)), "afterglow_dps":float(mother_evolution.get_effect_value("sunburst_afterglow_dps", 0.0)), "echo_delay":float(mother_evolution.get_effect_value("sunburst_echo_delay", 0.0)), "echo_damage_ratio":float(mother_evolution.get_effect_value("sunburst_echo_damage_ratio", 0.0)), "echo_radius_ratio":float(mother_evolution.get_effect_value("sunburst_echo_radius_ratio", 0.0))}

func retreat_run() -> Dictionary:
	if not can_retreat(): return {"ok":false, "meta_seeds_gained":0}
	_stop_weather_fx()
	var amount := progression.settle_retreat(); phase = Phase.RETREATED; clear_temporary_battle_content()
	if is_instance_valid(thunderstorm_fx): thunderstorm_fx.reset()
	run_settled.emit({"ok":true,"result":"retreat","meta_seeds_gained":amount})
	return {"ok":true,"meta_seeds_gained":amount}

func settle_failure() -> Dictionary:
	_stop_weather_fx()
	if is_instance_valid(world_lighting): world_lighting.set_phase(false)
	if is_instance_valid(daylight_glow): daylight_glow.set_active(false)
	if is_instance_valid(thunderstorm_fx): thunderstorm_fx.reset()
	var amount := progression.settle_failure(); clear_temporary_battle_content(); run_settled.emit({"ok":true,"result":"failure","meta_seeds_gained":amount}); return {"ok":true,"meta_seeds_gained":amount}

func settle_victory() -> Dictionary:
	_stop_weather_fx()
	if is_instance_valid(world_lighting): world_lighting.set_phase(true)
	if is_instance_valid(daylight_glow): daylight_glow.set_active(true)
	if is_instance_valid(night_fog): night_fog.set_active(false)
	if is_instance_valid(thunderstorm_fx): thunderstorm_fx.reset()
	var amount := progression.settle_victory(); clear_temporary_battle_content(); run_settled.emit({"ok":true,"result":"victory","meta_seeds_gained":amount}); return {"ok":true,"meta_seeds_gained":amount}

func clear_temporary_battle_content() -> void:
	if is_instance_valid(boss_feedback): boss_feedback.clear_all()
	var objects: Array[Node] = []
	if is_inside_tree():
		for object in get_tree().get_nodes_in_group("temporary_battle_objects"): objects.append(object)
	else:
		for child in get_children():
			if "object_id" in child: objects.append(child)
	for object in objects:
		if not is_instance_valid(object): continue
		if object.is_inside_tree(): object.queue_free()
		else: object.free()
	var retained: Array[Node] = []
	for plant in plants:
		if not is_instance_valid(plant): continue
		if plant.temporary_lifetime > 0.0:
			if plant.is_inside_tree(): plant.queue_free()
			else: plant.free()
		else: retained.append(plant)
	plants = retained

func clear_end_of_night_content() -> void:
	var objects: Array[Node] = []
	if is_inside_tree():
		for object in get_tree().get_nodes_in_group("temporary_battle_objects"): objects.append(object)
	else:
		for child in get_children():
			if "object_id" in child: objects.append(child)
	for object in objects:
		if is_instance_valid(object) and object.object_id == "card_sun_mine": object.queue_free() if object.is_inside_tree() else object.free()

func spend_energy(cost: int) -> bool:
	if cost < 0 or light_energy < cost: return false
	light_energy -= cost
	return true

func spend_run_seeds(cost: int) -> bool:
	if not progression.spend_run_seeds(cost): return false
	seeds = progression.run_seeds
	return true

func regenerate_energy(seconds: float) -> void:
	if seconds <= 0.0: return
	_energy_regen_buffer += seconds * get_day_energy_regen()
	var whole := int(floor(_energy_regen_buffer))
	if whole > 0:
		light_energy = mini(Balance.MAX_ENERGY, light_energy + whole)
		_energy_regen_buffer -= whole

func begin_night() -> void:
	if phase != Phase.DAY or wave_index >= waves.size(): return
	if _plant_loadout_open(): return
	if mother_choice_pending:
		if is_instance_valid(hud): hud.show_message("请先从中央三张卡牌中选择今日的母花强化")
		return
	if forecast_night != wave_index + 1: _prepare_spawn_forecast()
	if forecast_night < 0: return
	if is_instance_valid(spawn_forecast): spawn_forecast.visible = false
	phase = Phase.NIGHT
	_clear_phase_selection()
	combat_deck.begin_next_night()
	wave_index += 1
	var night_rule := get_night_rule(wave_index)
	weather = str(night_rule["weather"])
	environmental_tick = 0.0
	thunderstorm_terrain_tick = 0.0
	if weather == "fog" and is_instance_valid(night_fog): night_fog.reset_spread()
	boss_active = str(night_rule["boss"]) != ""
	if night_rule.get("resupply", false):
		clear_temporary_battle_content()
		light_energy = mini(Balance.MAX_ENERGY, light_energy + Balance.RESUPPLY_ENERGY)
		progression.gain_run_seeds(Balance.RESUPPLY_SEEDS)
		seeds = progression.run_seeds
		if is_instance_valid(mother_flower): mother_flower.heal(Balance.RESUPPLY_HEAL)
		day_time_left = Balance.RESUPPLY_DURATION
		begin_day()
		if is_instance_valid(hud): hud.show_message("第六夜补给：光能、种子已补充，并从牌库补抽最多2张战术卡；重构防线后再入夜")
		return
	if is_instance_valid(mother_flower): mother_flower.on_night_started()
	spawn_clock = 0.0
	spawn_queue.clear()
	spawn_queue = forecast_queue.duplicate(true)
	spawn_cursor = 0
	_kill_energy_buffer = 0.0
	_update_threats_from_queue()
	selected_plant = Selection.NONE
	aiming_sunburst = false
	if hud != null: hud.show_message("第 %d 夜 · %s" % [wave_index, night_rule["name"]])
	if night_fog != null: night_fog.set_active(should_show_night_fog(wave_index))
	if daylight_glow != null: daylight_glow.set_active(false)
	if is_instance_valid(world_lighting): world_lighting.set_phase(false)
	if is_instance_valid(terrain_events): terrain_events.start_weather(weather)

func _build_world() -> void:
	battlefield = BattlefieldScript.new()
	add_child(battlefield)
	spawn_forecast = preload("res://scripts/spawn_forecast.gd").new()
	spawn_forecast.name = "SpawnForecast"
	drag_world_preview = DragWorldPreviewScript.new()
	drag_world_preview.name = "DragWorldPreview"
	add_child(drag_world_preview)
	terrain_events = TerrainEventControllerScript.new()
	add_child(terrain_events)
	terrain_events.configure(battlefield.terrain_map, 20260928)
	terrain_events.patch_warning_started.connect(_on_terrain_patch_warning)
	terrain_events.patch_applied.connect(_on_terrain_patch_applied)
	acid_rain_fx = AcidRainFXScript.new()
	acid_rain_fx.name = "AcidRainFX"
	acid_rain_fx.z_index = 16
	add_child(acid_rain_fx)
	thunderstorm_fx = ThunderstormFXScript.new()
	thunderstorm_fx.name = "ThunderstormFX"
	thunderstorm_fx.z_index = 15
	add_child(thunderstorm_fx)
	mother_flower = MotherFlowerScript.new()
	mother_flower.position = BattlefieldScript.CENTER
	mother_flower.destroyed.connect(_on_mother_destroyed)
	mother_flower.attack_requested.connect(_on_mother_attack_requested)
	mother_flower.pulse_requested.connect(_on_mother_pulse_requested)
	mother_flower.root_whip_requested.connect(_on_mother_root_whip_requested)
	mother_flower.secondary_damage_requested.connect(_on_mother_secondary_damage_requested)
	mother_flower.reflected_damage_requested.connect(_on_mother_reflected_damage_requested)
	mother_flower.pulse_echo_requested.connect(_on_mother_pulse_echo_requested)
	add_child(mother_flower)
	_attach_health_bar(mother_flower, Color("e6b85c"))
	night_fog = NightFogScript.new(); add_child(night_fog)
	daylight_glow = DaylightGlowScript.new(); add_child(daylight_glow)
	world_lighting = WorldLightingScript.new()
	world_lighting.name = "WorldLighting"
	world_lighting.configure(self)
	add_child(world_lighting)
	world_camera = WorldCameraScript.new(); add_child(world_camera)
	hud = HudScript.new(); add_child(hud)
	spawn_forecast.hud = hud
	hud.add_child(spawn_forecast)
	hud.thorn_requested.connect(func(): _select_plant(Selection.THORN))
	hud.prism_requested.connect(func(): _select_plant(Selection.PRISM))
	hud.light_sprout_requested.connect(func(): _select_plant(Selection.LIGHT_SPROUT))
	hud.sunburst_requested.connect(_select_sunburst)
	hud.wave_requested.connect(begin_night)
	hud.mother_card_requested.connect(func(card_id: String):
		if choose_mother_card(card_id): hud.show_message("母花强化已生效，现在可以进入夜晚")
	)
	hud.plant_loadout_requested.connect(_open_plant_loadout)
	hud.deployment_card_requested.connect(func(id: String):
		if PLANT_DEPLOY_IDS.has(id): _select_plant(int(PLANT_DEPLOY_IDS[id]))
	)
	hud.plant_loadout_confirmed.connect(_confirm_plant_loadout)
	hud.plant_loadout_cancelled.connect(func(): hud.hide_plant_loadout())
	hud.combat_card_requested.connect(_select_combat_card)
	hud.combat_card_drag_started.connect(_start_combat_card_drag)
	hud.combat_card_dropped.connect(_drop_combat_card)
	hud.combat_card_drag_finished.connect(_finish_combat_card_drag)
	hud.mulligan_requested.connect(func(card_id: String):
		if mulligan_combat_card(card_id):
			hud.show_message("已完成本局唯一一次起手换牌")
			_refresh_card_ui()
	)
	hud.restart_requested.connect(reset_model)
	hud.radar_focus_requested.connect(func(point: Vector2): world_camera.focus_world(point))
	var menu_button := Button.new()
	menu_button.text = "返回主界面"; menu_button.anchor_left = 1.0; menu_button.anchor_right = 1.0; menu_button.anchor_top = 0.0; menu_button.anchor_bottom = 0.0; menu_button.offset_left = -154; menu_button.offset_top = 80; menu_button.offset_right = -18; menu_button.offset_bottom = 90; menu_button.add_theme_font_size_override("font_size", 11)
	menu_button.pressed.connect(func(): return_to_menu_requested.emit())
	hud.add_child(menu_button)

func _process(delta: float) -> void:
	if is_instance_valid(spawn_forecast): spawn_forecast.visible = phase == Phase.DAY
	_hud_refresh_clock += delta
	_radar_refresh_clock += delta
	_network_refresh_clock += delta
	var weather_active := phase == Phase.NIGHT and weather_seal_time <= 0.0
	if is_instance_valid(acid_rain_fx):
		acid_rain_fx.set_active(weather_active and weather in ["acid_rain", "thunderstorm"])
	if is_instance_valid(thunderstorm_fx):
		thunderstorm_fx.set_active(weather == "thunderstorm" and phase == Phase.NIGHT and weather_seal_time <= 0.0)
	if is_instance_valid(night_fog):
		night_fog.set_active(weather_active and weather == "fog")
	for plant in plants:
		if is_instance_valid(plant): plant.combat_active = phase == Phase.NIGHT
	if phase == Phase.DAY and not _plant_loadout_open():
		day_time_left -= delta; regenerate_energy(delta)
		if day_time_left <= 0.0: begin_night()
	elif phase == Phase.NIGHT:
		spawn_clock += delta; _process_spawns()
		_process_weather(delta)
		if get_remaining_spawn_count() == 0 and _get_active_enemy_count() == 0: _finish_wave()
	_update_pointer_preview()
	if _network_refresh_clock >= 0.2:
		_network_refresh_clock = 0.0
		_refresh_network_visuals()
	_update_readability_feedback()
	if hud != null and _hud_refresh_clock >= 0.1:
		var ui_started := Time.get_ticks_usec()
		_hud_refresh_clock = 0.0
		var hud_state := get_hud_battle_state()
		hud.update_battle_state(hud_state)
		if _radar_refresh_clock >= 0.2:
			_radar_refresh_clock = 0.0
			_cached_radar_nodes = _radar_nodes()
			_cached_network_lines = _network_lines()
			hud.update_radar(_cached_radar_nodes, _cached_network_lines, threat_levels)
			_refresh_enemy_radar()
		_refresh_card_ui()
		_ui_usec = Time.get_ticks_usec() - ui_started
	var sample := {"frame_usec": int(delta * 1000000.0), "alive": _get_active_enemy_count(), "spawned": _spawned_this_frame, "spawn_usec": _spawn_usec, "query_usec": enemy_index.query_usec, "query_candidates": enemy_index.query_candidates, "ui_usec": _ui_usec, "shadow_usec": battlefield.terrain_map.contact_shadows.update_usec if is_instance_valid(battlefield) else 0}
	if performance_samples.size() < 3600: performance_samples.append(sample)
	else:
		performance_samples[_performance_cursor] = sample
		_performance_cursor = (_performance_cursor + 1) % 3600
	enemy_index.query_usec = 0; enemy_index.query_candidates = 0
	_spawned_this_frame = 0; _spawn_usec = 0; _ui_usec = 0

func get_performance_samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offset in performance_samples.size(): result.append(performance_samples[(_performance_cursor + offset) % performance_samples.size()])
	return result

func get_latest_performance_sample() -> Dictionary:
	if performance_samples.is_empty(): return {}
	var index := performance_samples.size() - 1 if performance_samples.size() < 3600 else (_performance_cursor + 3599) % 3600
	return performance_samples[index].duplicate()

func _refresh_card_ui() -> void:
	if not is_instance_valid(hud): return
	if mother_choice_pending: hud.show_mother_choices(get_mother_choices())
	var phase_name := "day" if phase == Phase.DAY else "night"
	var state: Array = [get_carried_plant_ids().duplicate(), get_combat_hand().duplicate(true), phase_name, light_energy, selected_combat_card]
	if state == _card_ui_state: return
	_card_ui_state = state
	var started := Time.get_ticks_usec()
	hud.set_plant_loadout(get_carried_plant_ids())
	hud.show_combat_hand(get_combat_hand(), phase_name, light_energy, false, selected_combat_card)
	_ui_usec += Time.get_ticks_usec() - started

func _update_readability_feedback() -> void:
	if not is_instance_valid(mother_flower):
		return
	var nearby := 0
	if is_inside_tree():
		for enemy in query_enemies_in_radius(mother_flower.global_position, 260.0):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(mother_flower.global_position) <= 260.0:
				nearby += 1
	mother_flower.set_nearby_enemy_count(nearby)

func _select_combat_card(card_id: String) -> void:
	if phase != Phase.NIGHT or _plant_loadout_open() or not combat_deck.hand.has(card_id): return
	var card := ContentData.get_card(card_id)
	if card.is_empty(): return
	if str(card.get("target_type", "")) == "global":
		var result := play_combat_card(card_id, Vector2.ZERO)
		hud.show_message("%s已发动" % card["name"] if result.get("ok", false) else "当前无法使用这张卡")
		_refresh_card_ui()
		return
	selected_combat_card = card_id
	selected_plant = Selection.NONE
	aiming_sunburst = false
	hud.show_message("已选择%s，请点击战场上的有效目标" % card["name"])

func _start_combat_card_drag(_card_id: String) -> void:
	if _plant_loadout_open(): return
	if _card_id.begins_with("deploy_"):
		if phase != Phase.DAY: return
		if PLANT_DEPLOY_IDS.has(_card_id) and not carried_plant_ids.has(_card_id): return
	elif phase != Phase.NIGHT or not combat_deck.hand.has(_card_id): return
	_combat_card_drag_active = true
	_drag_card_id = _card_id
	_drag_start_phase = phase
	selected_combat_card = ""; selected_plant = Selection.NONE; aiming_sunburst = false
	if is_instance_valid(world_camera):
		_drag_camera_process = world_camera.is_processing()
		_drag_camera_input = world_camera.is_processing_unhandled_input()
		world_camera.set_process(false)
		world_camera.set_process_unhandled_input(false)
		world_camera.dragging = false

func _finish_combat_card_drag() -> void:
	_combat_card_drag_active = false
	_drag_card_id = ""
	if is_instance_valid(drag_world_preview): drag_world_preview.clear()
	_drag_release_frame = Engine.get_process_frames()
	if is_instance_valid(world_camera):
		world_camera.set_process(_drag_camera_process)
		world_camera.set_process_unhandled_input(_drag_camera_input)
		world_camera.dragging = false; world_camera.just_dragged = false

func _drop_combat_card(id: String, viewport_point: Vector2) -> void:
	_drag_release_frame = Engine.get_process_frames()
	if not _combat_card_drag_active or phase != _drag_start_phase or phase not in [Phase.DAY,Phase.NIGHT] or mother_choice_pending or _plant_loadout_open():
		return
	if hud.is_point_over_battle_ui(viewport_point): return
	var point := get_viewport().get_canvas_transform().affine_inverse() * viewport_point
	if id.begins_with("deploy_"):
		if phase != Phase.DAY: return
		match id:
			"deploy_light": _place_light_node(point)
			"deploy_thorn": _place_plant_at(point,Selection.THORN)
			"deploy_prism": _place_plant_at(point,Selection.PRISM)
			"deploy_lantern": _place_plant_at(point,Selection.LANTERN)
			"deploy_frost": _place_plant_at(point,Selection.FROST)
			"deploy_honeydew": _place_plant_at(point,Selection.HONEYDEW)
			"deploy_storm", "deploy_gale", "deploy_sunwell", "deploy_ember", "deploy_slumber", "deploy_spear", "deploy_burst", "deploy_stone", "deploy_cleanse", "deploy_drum": _place_plant_at(point, int(PLANT_DEPLOY_IDS[id]))
			"deploy_repair":
				for node in light_nodes:
					if is_instance_valid(node) and node.global_position.distance_to(point) < BattlefieldSpec.scale_distance(55.0) and node.health < node.max_health:
						if phase == Phase.DAY and spend_energy(Balance.REPAIR_COST): node.repair(Balance.REPAIR_AMOUNT); _rebuild_network()
						break
		_refresh_card_ui()
		return
	_use_combat_card_at(id,point)

func _use_combat_card_at(id: String, point: Vector2) -> void:
	if phase != Phase.NIGHT or _plant_loadout_open(): return
	if not combat_deck.get_hand().has(id): return
	var target: Variant = _combat_card_target(id,point)
	if id == "card_transplant_shovel":
		if not is_instance_valid(_transplant_source):
			if target is Node and target.is_in_group("plants"):
				_transplant_source = target; selected_combat_card = id
				hud.show_message("已选择移植植物，请点击供光范围内的空地；右键取消")
			return
		target = {"plant":_transplant_source,"position":point}
	var result := play_combat_card(id,target)
	if result.get("ok",false):
		selected_combat_card = ""; _transplant_source = null
		hud.show_message("卡牌已生效")
	else:
		hud.show_message("目标无效、阶段不符或光能不足；卡牌已返回手中")
	_refresh_card_ui()

func _occupied_positions(excluded: Node = null) -> Array:
	var positions: Array = []
	for node in light_nodes:
		if node != excluded and is_instance_valid(node): positions.append(node.global_position)
	for plant in plants:
		if plant != excluded and is_instance_valid(plant): positions.append(plant.global_position)
	for object in _temporary_supply_nodes(): positions.append(object.global_position)
	return positions

func _temporary_supply_nodes() -> Array[Node]:
	var result: Array[Node] = []
	var candidates: Array[Node] = []
	if is_inside_tree():
		for object in get_tree().get_nodes_in_group("temporary_battle_objects"): candidates.append(object)
	else:
		for child in get_children(): candidates.append(child)
	for object in candidates:
		if is_instance_valid(object) and "supply_radius" in object and float(object.supply_radius) > 0.0 and "capacity" in object:
			result.append(object)
	return result

func _parent_can_supply_plant(parent: Node) -> bool:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion() or parent.health <= 0.0: return false
	if parent == mother_flower:
		return mother_plant_load < MOTHER_PLANT_CAPACITY
	return is_instance_valid(parent) and parent.is_connected_to_light and parent.load < parent.capacity

func find_best_parent(point: Vector2, _load_cost: int, allow_temporary: bool = true) -> Node:
	var best: Node = null
	var best_distance := INF
	var mother_distance := point.distance_to(mother_flower.global_position if mother_flower != null else BattlefieldScript.CENTER)
	if mother_distance <= Balance.MOTHER_SUPPLY_RADIUS and _parent_can_supply_plant(mother_flower):
		best = mother_flower; best_distance = mother_distance
	for node in light_nodes:
		if not is_instance_valid(node) or not node.is_connected_to_light or not _parent_can_supply_plant(node): continue
		var distance := point.distance_to(node.global_position)
		if distance <= node.supply_radius and distance < best_distance:
			best = node; best_distance = distance
	if allow_temporary:
		for object in _temporary_supply_nodes():
			if not _parent_can_supply_plant(object): continue
			var distance := point.distance_to(object.global_position)
			if distance <= object.supply_radius and distance < best_distance:
				best = object; best_distance = distance
	return best

func can_place_light_node(point: Vector2) -> bool:
	return battlefield.is_position_clear(point, BattlefieldSpec.scale_distance(25.0), _occupied_positions()) and find_best_parent_excluding(point, 0, null, false) != null

func can_place_plant(point: Vector2, kind: int) -> bool:
	return battlefield.is_position_clear(point, BattlefieldSpec.scale_distance(24.0), _occupied_positions()) and find_best_parent(point, get_plant_seed_cost(kind)) != null

func _select_plant(kind: int) -> void:
	if _plant_loadout_open(): return
	if phase != Phase.DAY:
		hud.show_message("植物部署仅限白天"); return
	if kind != Selection.LIGHT_SPROUT and not can_deploy_plant(kind):
		if is_instance_valid(hud): hud.show_message("请在白天携带该植物后再部署")
		return
	selected_plant = kind; aiming_sunburst = false
	hud.show_message("点击土地自由种植，红色预览表示位置无效")

func _handle_click(point: Vector2) -> void:
	if _plant_loadout_open(): return
	if world_camera != null and world_camera.consume_click_was_dragged(): return
	if not selected_combat_card.is_empty():
		_use_combat_card_at(selected_combat_card,point)
		return
	if aiming_sunburst: _cast_sunburst(point); return
	for node in light_nodes:
		if phase == Phase.DAY and point.distance_to(node.global_position) <= 30.0 and node.health < node.max_health:
			if spend_energy(Balance.REPAIR_COST): node.repair(Balance.REPAIR_AMOUNT); _rebuild_network()
			else: hud.show_message("修复需要 %d 光能" % Balance.REPAIR_COST)
			return
	if selected_plant == Selection.LIGHT_SPROUT: _place_light_node(point)
	elif PlantRoster.kind_for_selection(selected_plant) >= 0 and phase == Phase.DAY: _place_plant_at(point, selected_plant)

func _combat_card_target(card_id: String, point: Vector2) -> Variant:
	var target_type := str(ContentData.get_card(card_id).get("target_type", "ground"))
	if target_type in ["ground", "global"]: return point
	var candidates: Array = []
	if target_type == "enemy": candidates = query_enemies_in_radius(point, 55.0)
	elif target_type == "plant": candidates = plants.duplicate()
	elif target_type == "node": candidates = light_nodes.duplicate()
	elif target_type == "plant_or_node": candidates = plants + light_nodes
	var nearest: Node = null
	var nearest_distance := 55.0
	for candidate in candidates:
		if not is_instance_valid(candidate): continue
		var distance := point.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _place_light_node(point: Vector2) -> void:
	if phase != Phase.DAY or _plant_loadout_open(): return
	var cost := get_light_sprout_cost(phase == Phase.NIGHT)
	if not can_place_light_node(point): hud.show_message("光脉芽必须种在现有光源延伸范围内"); return
	if not spend_energy(cost): hud.show_message("光能不足，需要 %d" % cost); return
	var node := LightNodeScript.new()
	node.node_index = light_nodes.size(); node.network_id = node.node_index + 1; node.position = point
	add_child(node); light_nodes.append(node)
	_attach_health_bar(node, Color("d66b72"))
	node.set_parent_source(find_best_parent_excluding(point, 0, null, false))
	node.destroyed.connect(_rebuild_network)
	_rebuild_network()
	hud.show_message("光脉芽已接入网络")

func _place_plant_at(point: Vector2, kind: int) -> void:
	if not can_deploy_plant(kind) or _plant_loadout_open(): return
	var cost := get_plant_seed_cost(kind)
	if not can_place_plant(point, kind): hud.show_message("植物必须种在有效供光范围内"); return
	if not spend_run_seeds(cost): hud.show_message("种子不足，需要 %d" % cost); return
	var placement_started := Time.get_ticks_usec()
	var plant := PlantScript.new()
	var plant_kind: int = PlantRoster.kind_for_selection(kind)
	plant.position = point; plant.configure(plant_kind, 0); plant.projectile_requested.connect(_on_projectile_requested); plant.status_projectile_requested.connect(_on_status_projectile_requested)
	plant.energy_generated.connect(func(amount: int):
		if phase == Phase.NIGHT and is_instance_valid(plant) and plant.health > 0.0 and plant.has_combat_power(): light_energy = mini(Balance.MAX_ENERGY, light_energy + maxi(0, amount))
	)
	add_child(plant); plants.append(plant)
	_attach_health_bar(plant, Color("72c77d"))
	plant.set_power_source(find_best_parent(point, cost))
	var node_finished := Time.get_ticks_usec()
	_rebuild_network()
	planting_timings.append({"kind": kind, "resource_usec": plant.resource_lookup_usec, "node_usec": node_finished - placement_started, "network_usec": Time.get_ticks_usec() - node_finished, "total_usec": Time.get_ticks_usec() - placement_started, "animation_ready": PlantScript.Animations.get_cached_frames(plant.get_flower_id()) != null})
	if planting_timings.size() > 128: planting_timings.pop_front()
	hud.show_message("植物已扎根")

func _rebuild_network() -> void:
	var supplies: Array[Node] = []
	var old_parents: Dictionary = {}
	for source in light_nodes + _temporary_supply_nodes():
		if not is_instance_valid(source) or old_parents.has(source): continue
		old_parents[source] = source.parent_source
		source.set_load(0)
		source.set_parent_source(null)
		if source.health > 0.0 and not source.is_queued_for_deletion(): supplies.append(source)
	mother_plant_load = 0
	# Validate old edges outward from the mother before considering any new edge.
	var pending := supplies.duplicate()
	var progress := true
	while progress:
		progress = false
		for source in pending.duplicate():
			var parent: Node = old_parents.get(source)
			if _supply_parent_valid(parent, source.global_position, supplies):
				source.set_parent_source(parent)
				pending.erase(source)
				progress = true
	# Reconnect broken roots; then retain downstream old edges where possible.
	while not pending.is_empty():
		var connected := false
		for source in pending:
			var parent: Node = old_parents.get(source)
			if not _supply_parent_valid(parent, source.global_position, supplies):
				parent = find_best_parent_excluding(source.global_position, 0, source)
			if parent != null:
				source.set_parent_source(parent)
				pending.erase(source)
				connected = true
				break
		if not connected: break
	var unconnected: Array[Node] = []
	for plant in plants:
		if not is_instance_valid(plant): continue
		if plant.health <= 0.0 or plant.is_queued_for_deletion():
			plant.set_power_source(null)
			continue
		var lantern_support := false
		for lantern in plants:
			if lantern != plant and is_instance_valid(lantern) and lantern.kind == PlantScript.Kind.LANTERN and lantern.health > 0.0 and lantern.global_position.distance_to(plant.global_position) <= lantern.attack_range:
				lantern_support = true; break
		plant.set_lantern_supported(lantern_support)
		var parent: Node = plant.power_source
		if _supply_parent_valid(parent, plant.global_position, supplies) and _parent_can_supply_plant(parent):
			_count_plant_connection(parent)
		else:
			plant.set_power_source(null)
			unconnected.append(plant)
	for plant in unconnected:
		var parent := find_best_parent(plant.global_position, 1)
		plant.set_power_source(parent)
		if parent != null: _count_plant_connection(parent)

func _supply_parent_valid(parent: Node, point: Vector2, supplies: Array[Node]) -> bool:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion() or parent.health <= 0.0: return false
	if parent == mother_flower: return point.distance_to(parent.global_position) <= Balance.MOTHER_SUPPLY_RADIUS
	return parent in supplies and parent.is_connected_to_light and point.distance_to(parent.global_position) <= parent.supply_radius

func _count_plant_connection(parent: Node) -> void:
	if parent == mother_flower: mother_plant_load += 1
	else: parent.set_load(parent.load + 1)

func find_best_parent_excluding(point: Vector2, _load_cost: int, excluded: Node, allow_temporary: bool = true) -> Node:
	if is_instance_valid(mother_flower) and mother_flower.health > 0.0 and point.distance_to(mother_flower.global_position) <= Balance.MOTHER_SUPPLY_RADIUS: return mother_flower
	var best: Node = null
	var best_distance := INF
	for node in light_nodes:
		if node == excluded or not is_instance_valid(node) or node.health <= 0.0 or node.is_queued_for_deletion() or not node.is_connected_to_light: continue
		var distance := point.distance_to(node.global_position)
		if distance <= node.supply_radius and distance < best_distance: best = node; best_distance = distance
	if allow_temporary:
		for object in _temporary_supply_nodes():
			if object == excluded or object.health <= 0.0 or object.is_queued_for_deletion() or not object.is_connected_to_light: continue
			var distance := point.distance_to(object.global_position)
			if distance <= object.supply_radius and distance < best_distance: best = object; best_distance = distance
	return best

func _network_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for node in light_nodes:
		if is_instance_valid(node) and is_instance_valid(node.parent_source):
			lines.append({"from": node.parent_source.global_position, "to": node.global_position, "connected": node.is_connected_to_light, "overloaded": node.load >= node.capacity})
	for plant in plants:
		if is_instance_valid(plant) and plant.health > 0.0 and not plant.is_queued_for_deletion() and is_instance_valid(plant.power_source): lines.append({"from": plant.power_source.global_position, "to": plant.global_position, "connected": plant.has_combat_power()})
	for object in _temporary_supply_nodes():
		lines.append({"from":object.parent_source.global_position if is_instance_valid(object.parent_source) else BattlefieldScript.CENTER, "to": object.global_position, "connected": object.is_connected_to_light, "overloaded": object.load >= object.capacity})
	return lines

func _refresh_enemy_radar() -> void:
	var positions := PackedVector2Array()
	var bosses := PackedVector2Array()
	for enemy in enemy_index.hostiles():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health <= 0.0:
			continue
		positions.append(enemy.global_position)
		if str(ContentData.get_enemy(enemy.enemy_id).get("rank", "")) == "boss":
			bosses.append(enemy.global_position)
	if hud != null: hud.update_enemy_radar(positions, bosses)

func _radar_nodes() -> Array:
	var result: Array = []
	for node in light_nodes:
		if is_instance_valid(node): result.append({"position": node.global_position, "connected": node.is_connected_to_light})
	return result

func _refresh_network_visuals() -> void: battlefield.set_network_lines(_network_lines())

func _process_spawns() -> void:
	var started := Time.get_ticks_usec()
	if _queue_source_size != spawn_queue.size(): _update_threats_from_queue()
	var spawned := 0
	while spawned < spawn_budget_per_frame and spawn_cursor < spawn_queue.size() and float(spawn_queue[spawn_cursor]["time"]) <= spawn_clock:
		var entry: Dictionary = spawn_queue[spawn_cursor]
		spawn_cursor += 1
		var batch := int(entry.get("batch", 0))
		_queue_batches[batch] = int(_queue_batches.get(batch, 1)) - 1
		if int(_queue_batches[batch]) <= 0: _queue_batches.erase(batch)
		var direction := int(entry["direction"])
		threat_levels[direction] = maxf(0.0, threat_levels[direction] - 0.14)
		_spawn_enemy(int(entry["kind"]), direction, entry)
		spawned += 1
	_spawned_this_frame = spawned
	_spawn_usec += Time.get_ticks_usec() - started
	if spawn_cursor == spawn_queue.size():
		spawn_queue.clear(); spawn_cursor = 0; _queue_source_size = 0

func get_remaining_spawn_count() -> int:
	return maxi(0, spawn_queue.size() - spawn_cursor)

func _get_active_enemy_count() -> int:
	return enemy_index.count()

func _get_active_enemies() -> Array[Node]:
	return enemy_index.hostiles()

func get_active_enemies() -> Array[Node]:
	return _get_active_enemies().duplicate()

func query_enemies_in_radius(center: Vector2, radius: float) -> Array[Node]:
	return enemy_index.query_radius(center, radius)

func query_enemies_in_rect(rect: Rect2) -> Array[Node]:
	return enemy_index.query_rect(rect)

func nearest_hostile_enemy(center: Vector2, excluded: Node = null) -> Node2D:
	return enemy_index.nearest(center, excluded)

func sync_enemy(enemy: Node2D) -> void:
	enemy_index.sync(enemy)

func unregister_enemy(enemy: Node) -> void:
	enemy_index.unregister(enemy)
	active_enemies.erase(enemy)

func _register_enemy(enemy: Node2D) -> void:
	active_enemies.append(enemy)
	enemy_index.register(enemy)
	enemy.tree_exiting.connect(unregister_enemy.bind(enemy), CONNECT_ONE_SHOT)

func _spawn_enemy(kind: int, direction: int, entry: Dictionary = {}) -> Node:
	if kind == EnemyScript.Kind.SUN_DEVOURER and _sun_boss_spawned: return null
	# Legacy callers may still supply a compass sector; it no longer selects a fixed entrance.
	var spawn_point: Vector2
	if entry.has("spawn_position"):
		spawn_point = entry.spawn_position
	else:
		wave_director.prepare(battlefield.terrain_map, BattlefieldSpec.CENTER)
		spawn_point = wave_director.sample(float(direction - 2) * PI / 4.0, [])
	if not spawn_point.is_finite(): return null
	if kind == EnemyScript.Kind.SUN_DEVOURER: _sun_boss_spawned = true
	var enemy: Node2D = EnemyScript.new()
	enemy.configure(kind, spawn_point)
	enemy.max_health *= float(entry.get("health_multiplier", 1.0))
	enemy.health = enemy.max_health
	enemy.attack_damage *= float(entry.get("damage_multiplier", 1.0))
	enemy.light_reward = float(entry.get("reward", enemy.light_reward))
	add_child(enemy)
	_attach_health_bar(enemy, Color("d95d68"))
	enemy.set_targets(mother_flower, light_nodes); enemy.set_terrain_map(battlefield.terrain_map); enemy.died.connect(_on_enemy_died); enemy.begin_spawn()
	_register_enemy(enemy)
	enemy.split_requested.connect(_on_enemy_split_requested)
	if enemy.rank == "boss":
		if not is_instance_valid(boss_feedback):
			boss_feedback = preload("res://scripts/boss_battle_feedback.gd").new()
			add_child(boss_feedback)
			boss_feedback.configure(self)
		boss_feedback.register(enemy)
		enemy.boss_laser_requested.connect(_on_boss_laser_requested.bind(enemy))
		enemy.area_damage_requested.connect(_on_boss_area_damage_requested.bind(enemy))
	else:
		enemy.area_damage_requested.connect(_on_enemy_area_damage_requested)
	enemy.dark_sun_requested.connect(_on_enemy_dark_sun_requested)
	if MonsterSpawnFXScript.can_spawn():
		var spawn_fx := MonsterSpawnFXScript.new(); add_child(spawn_fx); spawn_fx.configure(spawn_point)
	if hud != null and not _seen_enemy_alerts.has(enemy.enemy_id):
		_seen_enemy_alerts[enemy.enemy_id] = true
		hud.show_spawn_alert(str(ContentData.get_enemy(enemy.enemy_id).get("name", enemy.enemy_id)))
	return enemy

func _on_enemy_split_requested(at_position: Vector2, count: int) -> void:
	for index in range(maxi(0, count)):
		var remnant: Node2D = EnemyScript.new()
		remnant.configure(EnemyScript.Kind.SPLIT_SHADE, at_position + Vector2(-12.0 if index % 2 == 0 else 12.0, 6.0 * index))
		remnant.enemy_id = "split_remnant"
		remnant.max_health = 24.0; remnant.health = 24.0; remnant.move_speed = 75.0
		remnant.attack_damage = 7.0; remnant.attack_interval = 0.8; remnant.light_reward = 0
		add_child(remnant)
		_attach_health_bar(remnant, Color("d95d68"))
		remnant.set_targets(mother_flower, light_nodes)
		if is_instance_valid(battlefield): remnant.set_terrain_map(battlefield.terrain_map)
		remnant.died.connect(_on_enemy_died)
		_register_enemy(remnant)

func _on_enemy_area_damage_requested(center: Vector2, radius: float, damage: float) -> void:
	damage *= get_weather_enemy_attack_multiplier()
	for plant in plants:
		if is_instance_valid(plant) and plant.global_position.distance_to(center) <= radius:
			plant.take_damage(damage)
	for node in light_nodes:
		if is_instance_valid(node) and node.global_position.distance_to(center) <= radius:
			node.take_damage(damage)

func _on_boss_area_damage_requested(center: Vector2, radius: float, damage: float, owner: Node) -> void:
	if phase != Phase.NIGHT or not is_instance_valid(owner) or owner.health <= 0.0: return
	_on_enemy_area_damage_requested(center, radius, damage)
	if is_instance_valid(mother_flower) and mother_flower.health > 0.0 and mother_flower.global_position.distance_to(center) <= radius:
		mother_flower.take_enemy_damage(damage * get_weather_enemy_attack_multiplier(), "boss", false, owner)

func _on_boss_laser_requested(origin: Vector2, start_angle: float, end_angle: float, reach: float, width: float, owner: Node) -> void:
	if phase != Phase.NIGHT or not is_instance_valid(owner) or owner.health <= 0.0: return
	for plant in plants:
		if not is_instance_valid(plant) or plant == mother_flower or plant.health <= 0.0: continue
		var offset: Vector2 = plant.global_position - origin
		var distance := offset.length()
		if distance > reach + width * 0.5: continue
		var angle := start_angle + wrapf(offset.angle() - start_angle, -PI, PI)
		var inside := angle >= start_angle and angle <= end_angle and distance <= reach
		var start_point := origin + Vector2.from_angle(start_angle) * reach
		var end_point := origin + Vector2.from_angle(end_angle) * reach
		if inside or offset.length() <= width * 0.5 or plant.global_position.distance_to(Geometry2D.get_closest_point_to_segment(plant.global_position, origin, start_point)) <= width * 0.5 or plant.global_position.distance_to(Geometry2D.get_closest_point_to_segment(plant.global_position, origin, end_point)) <= width * 0.5:
			plant.kill_by_boss_laser()

func _on_enemy_dark_sun_requested(stored_light_loss: float) -> void:
	for plant in plants:
		if not is_instance_valid(plant): continue
		if plant.power_state in [PlantScript.PowerState.STORED, PlantScript.PowerState.LOW_LIGHT]:
			plant.advance_power_state(stored_light_loss)

func _on_mother_attack_requested(origin: Vector2, target: Node, damage: float) -> void:
	if not is_instance_valid(target) or target.health <= 0.0: return
	mother_attack_count += 1
	var snapshot: Dictionary = mother_flower.evolution.export_state()
	snapshot["explosion"] = mother_flower.evolution.has_upgrade("mother_corona_04") and mother_attack_count % int(mother_flower.evolution.get_effect_value("attack_explosion_every", 6)) == 0
	var secondary := _nearest_enemy_excluding(origin, mother_flower.evolution.get_mother_attack_range(), target)
	_launch_mother_arrow(origin, target, damage, snapshot, true)
	var evolution: RefCounted = mother_flower.evolution
	if evolution.has_upgrade("mother_sunseed_04") and mother_attack_count % int(evolution.get_effect_value("attack_extra_every", 4)) == 0:
		if secondary != null: _launch_mother_arrow(origin, secondary, damage, snapshot, false)
		else: _launch_mother_arrow(origin, target, damage * float(evolution.get_effect_value("attack_extra_same_ratio", 0.5)), snapshot, false)

func _launch_mother_arrow(origin: Vector2, target: Node, damage: float, snapshot: Dictionary, primary: bool) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.health <= 0.0: return
	var projectile := ProjectileScript.new()
	projectile.is_mother_arrow = true
	projectile.hit_callback = _on_mother_arrow_hit.bind(snapshot, primary)
	add_child(projectile)
	projectile.global_position = origin
	projectile.launch(target, damage)

func _on_mother_arrow_hit(target: Node, origin: Vector2, damage: float, snapshot: Dictionary, primary: bool) -> void:
	if not is_instance_valid(target) or target.health <= 0.0: return
	var evolution := preload("res://scripts/mother_evolution.gd").new()
	evolution.path_id = str(snapshot.get("path_id", "sun_arrow"))
	evolution.selected_upgrades.assign(snapshot.get("selected_upgrades", []))
	var hit_position: Vector2 = target.global_position
	var secondary := _nearest_enemy_excluding(hit_position, evolution.get_mother_attack_range(), target) if primary else null
	if not snapshot.is_empty():
		if target.get_instance_id() == mother_last_target_id: mother_same_target_hits += 1
		else: mother_last_target_id = target.get_instance_id(); mother_same_target_hits = 1
	var hit_damage := damage
	if evolution.has_upgrade("mother_corona_03"):
		hit_damage += minf(float(evolution.get_effect_value("attack_chain_cap", 10.0)), float(mother_same_target_hits - 1) * float(evolution.get_effect_value("attack_chain_add", 2.0)))
	if evolution.has_upgrade("mother_sunseed_06") and target.get_rank() in ["elite", "boss"]:
		hit_damage *= float(evolution.get_effect_value("attack_strong_multiplier", 1.25))
	target.take_mother_damage(hit_damage, origin)
	if evolution.has_upgrade("mother_corona_01"):
		target.apply_burn(float(evolution.get_effect_value("attack_burn_dps", 3.0)), float(evolution.get_effect_value("attack_burn_duration", 3.0)))
	if evolution.has_upgrade("mother_corona_02"):
		_damage_enemies_in_radius(target.global_position, float(evolution.get_effect_value("attack_splash_radius", 45.0)), float(evolution.get_effect_value("attack_splash_damage", 7.0)), target)
	if primary and snapshot.get("explosion", false):
		_damage_enemies_in_radius(target.global_position, float(evolution.get_effect_value("attack_explosion_radius", 70.0)), float(evolution.get_effect_value("attack_explosion_damage", 28.0)))
	if evolution.has_upgrade("mother_sunseed_05") and secondary != null:
		_launch_mother_arrow(hit_position, secondary, damage * float(evolution.get_effect_value("attack_pierce_ratio", 0.65)), {}, false)

func _on_mother_pulse_requested(center: Vector2, radius: float, damage: float, energy: int) -> void:
	mother_pulse_count += 1
	var evolution: RefCounted = mother_flower.evolution
	if evolution.has_upgrade("mother_morningstar_06") and mother_pulse_count % int(evolution.get_effect_value("pulse_super_every", 4)) == 0:
		damage *= float(evolution.get_effect_value("pulse_super_multiplier", 2.5)); radius += float(evolution.get_effect_value("pulse_super_radius_add", 50.0))
	var strong_energy := 0
	for enemy in query_enemies_in_radius(center, radius):
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(center) > radius: continue
		var hit_damage := damage
		if evolution.has_upgrade("mother_morningstar_03") and enemy.health <= enemy.max_health * float(evolution.get_effect_value("pulse_low_health_threshold", 0.30)):
			hit_damage *= float(evolution.get_effect_value("pulse_low_health_multiplier", 1.5))
		enemy.take_mother_damage(hit_damage)
		if evolution.has_upgrade("mother_charge_04") and enemy.get_rank() in ["elite", "boss"]: strong_energy = mini(int(evolution.get_effect_value("pulse_strong_energy_cap", 4)), strong_energy + int(evolution.get_effect_value("pulse_strong_energy", 2)))
		if evolution.has_upgrade("mother_quelling_01") and enemy.get_rank() == "normal": enemy.apply_slow("mother_pulse", float(evolution.get_effect_value("pulse_slow_ratio", 0.15)), float(evolution.get_effect_value("pulse_slow_duration", 2.0)))
		if evolution.has_upgrade("mother_quelling_02"): enemy.remove_positive_buffs()
		if evolution.has_upgrade("mother_quelling_03") and enemy.get_rank() == "normal": enemy.push_from(center, float(evolution.get_effect_value("pulse_push_normal", 30.0)))
		if evolution.has_upgrade("mother_quelling_04"): enemy.apply_attack_slow("mother_pulse", float(evolution.get_effect_value("pulse_attack_slow", 0.20)), float(evolution.get_effect_value("pulse_attack_slow_duration", 3.0)))
		if evolution.has_upgrade("mother_quelling_05"): enemy.interrupt_ability()
		if enemy.health > 0.0:
			if enemy.get_rank() == "normal": enemy.apply_stun(float(evolution.get_effect_value("pulse_stun_normal", 0.5)))
			elif enemy.get_rank() == "elite": enemy.apply_stun(float(evolution.get_effect_value("pulse_stun_elite", 0.2)))
		if evolution.has_upgrade("mother_morningstar_05"): enemy.apply_mother_mark(float(evolution.get_effect_value("pulse_mother_mark_multiplier", 1.15)), float(evolution.get_effect_value("pulse_mother_mark_duration", 3.0)))
	energy += strong_energy
	if evolution.has_upgrade("mother_charge_05") and mother_pulse_count % 3 == 0: energy += int(evolution.get_effect_value("pulse_third_energy", 6))
	var overflow := maxi(0, light_energy + energy - Balance.MAX_ENERGY)
	light_energy = mini(Balance.MAX_ENERGY, light_energy + energy)
	if overflow > 0 and evolution.has_upgrade("mother_charge_06"):
		var shield_gain := minf(float(evolution.get_effect_value("pulse_overflow_shield_each_cap", 10.0)), overflow * float(evolution.get_effect_value("pulse_overflow_shield_ratio", 0.5)))
		mother_flower.shield = minf(float(evolution.get_effect_value("pulse_overflow_shield_cap", 40.0)), mother_flower.shield + shield_gain)

func _on_mother_root_whip_requested(center: Vector2, radius: float, damage: float) -> void:
	var count := 0
	for enemy in query_enemies_in_radius(center, radius):
		if is_instance_valid(enemy) and enemy.global_position.distance_to(center) <= radius:
			enemy.take_mother_damage(damage); count += 1
			if mother_flower.evolution.has_upgrade("mother_counterroot_04"):
				if enemy.get_rank() == "normal": enemy.apply_stun(float(mother_flower.evolution.get_effect_value("root_normal_root", 0.7)))
				elif enemy.get_rank() == "elite": enemy.apply_slow("mother_root", float(mother_flower.evolution.get_effect_value("root_elite_slow", 0.30)), float(mother_flower.evolution.get_effect_value("root_elite_slow_duration", 1.5)))
			if count >= int(mother_flower.evolution.get_effect_value("root_whip_targets", 1)): break

func _on_mother_secondary_damage_requested(center: Vector2, radius: float, damage: float) -> void:
	_damage_enemies_in_radius(center, radius, damage)
	if mother_flower.evolution.has_upgrade("mother_corona_05") and is_equal_approx(damage, float(mother_flower.evolution.get_effect_value("solar_wind_damage", 20.0))):
		for enemy in query_enemies_in_radius(center, radius):
			if is_instance_valid(enemy) and enemy.global_position.distance_to(center) <= radius: enemy.apply_slow("solar_wind", float(mother_flower.evolution.get_effect_value("solar_wind_slow", 0.20)), float(mother_flower.evolution.get_effect_value("solar_wind_slow_duration", 2.0)))

func _on_mother_reflected_damage_requested(attacker: Node, damage: float) -> void:
	if is_instance_valid(attacker): attacker.take_area_damage(damage)

func _on_mother_pulse_echo_requested(center: Vector2, radius: float, damage: float, delay: float) -> void:
	_spawn_mother_damage_zone("mother_pulse_echo", center, radius, delay, damage, delay, delay)

func _nearest_enemy_excluding(center: Vector2, radius: float, excluded: Node) -> Node:
	var result: Node = null; var best := radius
	for enemy in query_enemies_in_radius(center, radius):
		if enemy == excluded or not is_instance_valid(enemy): continue
		var distance := center.distance_to(enemy.global_position)
		if distance <= best: best = distance; result = enemy
	return result

func _damage_enemies_in_radius(center: Vector2, radius: float, damage: float, excluded: Node = null) -> int:
	var count := 0
	var multiplier := float(mother_flower.evolution.get_effect_value("secondary_damage_multiplier", 1.0))
	for enemy in query_enemies_in_radius(center, radius):
		if enemy == excluded or not is_instance_valid(enemy) or enemy.global_position.distance_to(center) > radius: continue
		enemy.take_mother_damage(damage * multiplier); count += 1
	return count

func _on_status_projectile_requested(_origin: Vector2, target: Node, damage: float, status: Dictionary) -> void:
	if not is_instance_valid(target): return
	if target.has_method("take_directional_damage"): target.take_directional_damage(damage, _origin)
	else: target.take_damage(damage)
	if status.get("type", "") == "slow": target.apply_slow(str(status.get("source", "plant")), float(status.get("ratio", 0.0)), float(status.get("duration", 0.0)))

func _update_threats_from_queue() -> void:
	threat_levels = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
	_queue_batches.clear()
	_queue_source_size = spawn_queue.size()
	for index in range(spawn_cursor, spawn_queue.size()):
		var entry: Dictionary = spawn_queue[index]
		threat_levels[int(entry["direction"])] += 0.14
		var batch := int(entry.get("batch", 0))
		_queue_batches[batch] = int(_queue_batches.get(batch, 0)) + 1

func _on_enemy_died(reward: float, at_position: Vector2) -> void:
	_kill_energy_buffer += reward
	var earned := floori(_kill_energy_buffer + 0.000001)
	_kill_energy_buffer = maxf(0.0, _kill_energy_buffer - earned)
	light_energy = mini(Balance.MAX_ENERGY, light_energy + earned)
	if is_instance_valid(mother_flower): mother_flower.on_nearby_enemy_killed(mother_flower.global_position.distance_to(at_position))
	if is_inside_tree():
		var fx := EffectScript.new(); add_child(fx); fx.configure(at_position, 36.0)

func _finish_wave() -> void:
	clear_end_of_night_content()
	if is_instance_valid(terrain_events): terrain_events.stop_and_restore()
	threat_levels = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
	if wave_index >= waves.size():
		phase = Phase.VICTORY
		if is_instance_valid(mother_flower): mother_flower.on_day_started()
		settle_victory(); night_fog.set_active(false); daylight_glow.set_active(true); hud.show_result(true); hud.show_message("最后的太阳碎片撑到了黎明")
	else:
		begin_day(); night_fog.set_active(false); daylight_glow.set_active(true); day_time_left = Balance.DAY_DURATION
		progression.gain_run_seeds(Balance.NIGHT_SEED_REWARD)
		seeds = progression.run_seeds
		if wave_index == 4: light_energy = mini(Balance.MAX_ENERGY, light_energy + Balance.NIGHT_FOUR_ENERGY_REWARD)
		hud.show_message("白昼回归：重构光网并向外围扩张")

func _process_weather(delta: float) -> void:
	if phase != Phase.NIGHT: return
	if is_instance_valid(terrain_events): terrain_events.advance(delta)
	weather_seal_time = maxf(0.0, weather_seal_time - delta)
	if weather_seal_time > 0.0: return
	environmental_tick += delta
	if weather == "thunderstorm": thunderstorm_terrain_tick += delta
	if weather in ["acid_rain", "thunderstorm"] and environmental_tick >= 1.0:
		environmental_tick = 0.0
		mother_flower.take_damage(1.0)
		for plant in plants:
			if is_instance_valid(plant): plant.take_environment_damage(0.5)
	if weather == "thunderstorm" and thunderstorm_terrain_tick >= 4.0:
		thunderstorm_terrain_tick = 0.0
		terrain_shift = (terrain_shift + 1) % 4
		battlefield.set_terrain_shift(terrain_shift)

func _on_terrain_patch_warning(_cells: Array[Vector2i], duration: float) -> void:
	if is_instance_valid(hud): hud.show_message("暴雨正在侵蚀土地：沼泽将在 %.0f 秒后形成" % duration)

func _on_terrain_patch_applied(cells: Array[Vector2i]) -> void:
	if not is_instance_valid(battlefield): return
	var removed_plants: Array[Node] = []
	for plant in plants:
		if is_instance_valid(plant) and battlefield.terrain_map.world_to_cell(plant.global_position) in cells:
			removed_plants.append(plant)
	for plant in removed_plants:
		plants.erase(plant)
		plant.queue_free() if plant.is_inside_tree() else plant.free()
	var removed_nodes: Array[Node] = []
	for light_node in light_nodes:
		if is_instance_valid(light_node) and battlefield.terrain_map.world_to_cell(light_node.global_position) in cells:
			removed_nodes.append(light_node)
	for light_node in removed_nodes:
		light_nodes.erase(light_node)
		light_node.queue_free() if light_node.is_inside_tree() else light_node.free()
	for object in _temporary_supply_nodes():
		if battlefield.terrain_map.world_to_cell(object.global_position) in cells:
			object.queue_free() if object.is_inside_tree() else object.free()
	_rebuild_network()
	if is_instance_valid(hud): hud.show_message("土地已化为沼泽，区域内防御设施被吞没")

func _on_mother_destroyed() -> void:
	if phase == Phase.VICTORY: return
	phase = Phase.FAILURE; settle_failure(); hud.show_result(false); hud.show_message("母花已熄灭，按 R 再次守护")

func _select_sunburst() -> void:
	if phase != Phase.NIGHT: hud.show_message("太阳爆闪只能在黑夜使用"); return
	if light_energy < Balance.SUNBURST_COST: hud.show_message("光能不足，需要 %d" % Balance.SUNBURST_COST); return
	aiming_sunburst = true; selected_plant = Selection.NONE; hud.show_message("点击战场释放太阳爆闪；右键取消")

func _unhandled_input(event: InputEvent) -> void:
	if _plant_loadout_open(): return
	if _combat_card_drag_active or Engine.get_process_frames() <= _drag_release_frame + 1: return
	if event.is_action_pressed("debug_add_resources"):
		light_energy += 100
		seeds += 100
		progression.run_seeds += 100
		if is_instance_valid(hud): hud.show_message("资源已增加：种子 +100，光能 +100")
	elif event.is_action_pressed("select_thorn"): _select_plant(Selection.THORN)
	elif event.is_action_pressed("select_prism"): _select_plant(Selection.PRISM)
	elif event.is_action_pressed("select_light_sprout"): _select_plant(Selection.LIGHT_SPROUT)
	elif event.is_action_pressed("sunburst"): _select_sunburst()
	elif event.is_action_pressed("start_wave"): begin_night()
	elif event.is_action_pressed("restart") and phase in [Phase.VICTORY, Phase.FAILURE]: reset_model()
	elif event.is_action_pressed("cancel_action"): _cancel_selection()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: _cancel_selection()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		call_deferred("_handle_click", get_viewport().get_canvas_transform().affine_inverse() * event.position)

func _on_projectile_requested(origin: Vector2, target: Node, damage: float) -> void:
	if not is_instance_valid(target): return
	var projectile := ProjectileScript.new(); projectile.global_position = origin; add_child(projectile); projectile.launch(target, damage)

func _cast_sunburst(point: Vector2) -> void:
	var profile := get_sunburst_profile(); var cost := int(profile["cost"])
	if not spend_energy(cost): aiming_sunburst = false; return
	var damage := float(profile["damage"]); var radius := float(profile["radius"]); var kills := 0
	for enemy in query_enemies_in_radius(point, radius):
		if is_instance_valid(enemy) and point.distance_to(enemy.global_position) <= radius:
			var alive_before: bool = enemy.health > 0.0; enemy.take_area_damage(damage)
			if alive_before and enemy.health <= 0.0: kills += 1
	light_energy = mini(Balance.MAX_ENERGY, light_energy + mini(int(profile["refund_cap"]), kills * int(profile["kill_energy"])))
	if float(profile["afterglow_duration"]) > 0.0: _spawn_mother_damage_zone("mother_sunburst_afterglow", point, radius, float(profile["afterglow_duration"]), float(profile["afterglow_dps"]), 1.0, 0.0)
	if float(profile["echo_delay"]) > 0.0: _spawn_mother_damage_zone("mother_sunburst_echo", point, radius * float(profile["echo_radius_ratio"]), float(profile["echo_delay"]), damage * float(profile["echo_damage_ratio"]), float(profile["echo_delay"]), float(profile["echo_delay"]))
	var fx := EffectScript.new(); add_child(fx); fx.configure(point, radius)
	aiming_sunburst = false; battlefield.set_aim_preview(point, false); hud.show_message("太阳爆闪驱散了黑暗")

func _spawn_mother_damage_zone(id: String, point: Vector2, radius: float, duration: float, damage: float, interval: float, delay: float) -> void:
	var zone := preload("res://scripts/temporary_battle_object.gd").new(); add_child(zone)
	zone.configure(id, point, {"radius":radius,"duration":duration,"periodic_damage":damage,"hits":maxi(1, int(ceil(duration / maxf(interval, duration)))),"tick_interval":interval,"start_delay":delay})

func _cancel_selection() -> void:
	_transplant_source = null
	selected_plant = Selection.NONE; aiming_sunburst = false; selected_combat_card = ""; battlefield.clear_placement_preview(); battlefield.set_aim_preview(Vector2.ZERO, false); hud.show_message("已取消选择")

func _attach_health_bar(target: Node, color: Color) -> void:
	if not is_instance_valid(target) or target.get_node_or_null("WorldHealthBar") != null: return
	var bar := HealthBarScript.new()
	bar.name = "WorldHealthBar"
	if target == mother_flower: bar.offset = Vector2(-27, -118)
	target.add_child(bar)
	bar.setup(target, color)

func _update_pointer_preview() -> void:
	if battlefield == null: return
	if _combat_card_drag_active:
		battlefield.clear_placement_preview()
		battlefield.set_aim_preview(Vector2.ZERO, false)
		_update_drag_world_preview()
		return
	if is_instance_valid(drag_world_preview): drag_world_preview.clear()
	var point := get_global_mouse_position()
	battlefield.set_aim_preview(point, aiming_sunburst)
	if selected_plant == Selection.LIGHT_SPROUT:
		var parent := find_best_parent_excluding(point, 0, null, false)
		battlefield.set_placement_preview(point, BattlefieldSpec.scale_distance(25.0), can_place_light_node(point), BattlefieldSpec.scale_distance(190.0), parent.global_position if parent != null else Vector2.ZERO, parent != null)
	elif PlantRoster.kind_for_selection(selected_plant) >= 0 and phase == Phase.DAY:
		var cost := get_plant_seed_cost(selected_plant); var parent := find_best_parent(point, cost)
		battlefield.set_placement_preview(point, BattlefieldSpec.scale_distance(24.0), can_place_plant(point, selected_plant), 0.0, parent.global_position if parent != null else Vector2.ZERO, parent != null)
	else: battlefield.clear_placement_preview()

func _update_drag_world_preview() -> void:
	if not is_instance_valid(drag_world_preview): return
	if phase != _drag_start_phase or phase not in [Phase.DAY, Phase.NIGHT] or mother_choice_pending or _plant_loadout_open() or (is_instance_valid(hud) and hud._card_drag_cancelled):
		drag_world_preview.clear()
		return
	var viewport_point := get_viewport().get_mouse_position()
	if is_instance_valid(hud) and hud.is_point_over_battle_ui(viewport_point):
		drag_world_preview.clear()
		return
	var point := get_viewport().get_canvas_transform().affine_inverse() * viewport_point
	var id := _drag_card_id
	var texture: Texture2D = null
	var radius := 0.0
	var caption := ""
	var valid := false
	var parent: Node = null
	var sprite_scale := 0.58
	var sprite_offset := -18.0
	if id.begins_with("deploy_"):
		match id:
			"deploy_light":
				caption = "种植光脉芽"; texture = ArtLibrary.load_texture(ArtLibrary.NODE_HEALTHY)
				sprite_scale = 0.72; sprite_offset = -8.0; radius = Balance.LIGHT_NODE_SUPPLY_RADIUS
				parent = find_best_parent_excluding(point, 0, null, false)
				valid = phase == Phase.DAY and can_place_light_node(point) and light_energy >= get_light_sprout_cost(false)
			"deploy_thorn", "deploy_prism", "deploy_lantern", "deploy_frost", "deploy_honeydew", "deploy_storm", "deploy_gale", "deploy_sunwell", "deploy_ember", "deploy_slumber", "deploy_spear", "deploy_burst", "deploy_stone", "deploy_cleanse", "deploy_drum":
				var kind: int = PLANT_DEPLOY_IDS[id]
				caption = "种植" + str(ContentData.get_flower(PlantRoster.flower_for_selection(kind)).get("name", "植物"))
				texture = ArtLibrary.load_texture(PlantRoster.texture_path(PlantRoster.kind_for_selection(kind)))
				parent = find_best_parent(point, get_plant_seed_cost(kind))
				valid = can_deploy_plant(kind) and can_place_plant(point, kind) and progression.run_seeds >= get_plant_seed_cost(kind)
			"deploy_repair":
				caption = "修复光脉芽"
				for node in light_nodes:
					if is_instance_valid(node) and node.global_position.distance_to(point) < BattlefieldSpec.scale_distance(55.0) and node.health < node.max_health:
						point = node.global_position; valid = phase == Phase.DAY and light_energy >= Balance.REPAIR_COST; break
		drag_world_preview.show_target(point, valid, radius, caption, texture, sprite_scale, sprite_offset, parent)
		return
	var target: Variant = _combat_card_target(id, point)
	var preview: Dictionary = card_effect_resolver.get_target_preview(self, id, target)
	if preview.is_empty(): drag_world_preview.clear(); return
	if target != null: point = preview["point"]
	if id == "card_temporary_sprout":
		texture = ArtLibrary.load_texture(ArtLibrary.NODE_HEALTHY); sprite_scale = 0.72; sprite_offset = -8.0
		parent = find_best_parent_excluding(point, 0, null, false)
	elif id == "card_phantom_bloom" and target is Node and "art_sprite" in target and is_instance_valid(target.art_sprite):
		texture = target.art_sprite.texture
	drag_world_preview.show_target(point, bool(preview["valid"]), float(preview["radius"]), str(preview["name"]), texture, sprite_scale, sprite_offset, parent, bool(preview["global"]), preload("res://scripts/temporary_battle_object.gd").MINE_TRIGGER_RADIUS if id == "card_sun_mine" else 0.0, preview.get("rect_size", Vector2.ZERO))

func _clear_dynamic_actors() -> void:
	if is_instance_valid(boss_feedback): boss_feedback.clear_all()
	for enemy in get_tree().get_nodes_in_group("enemies"): enemy.queue_free()
	for enemy in get_tree().get_nodes_in_group("friendly_enemies"): enemy.queue_free()
	active_enemies.clear()
	enemy_index.clear()
	for plant in plants: if is_instance_valid(plant): plant.queue_free()
	for node in light_nodes: if is_instance_valid(node): node.queue_free()
	plants.clear(); light_nodes.clear()
	mother_plant_load = 0
