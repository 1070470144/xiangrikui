extends Node

const MainMenuScript = preload("res://scripts/main_menu.gd")
const GameScript = preload("res://scripts/game.gd")
const ProfileStore = preload("res://scripts/profile_store.gd")

var current_screen: Node
var active_profile: Dictionary = {}

func _ready() -> void:
	show_menu()

func show_menu() -> void:
	var menu := MainMenuScript.new()
	if not active_profile.is_empty(): menu.apply_progression_profile(active_profile)
	_replace_screen(menu)
	active_profile = current_screen.get_local_profile()
	current_screen.start_requested.connect(start_game)

func start_game(level: int = 1) -> void:
	active_profile = current_screen.get_local_profile()
	var game := GameScript.new()
	game.import_profile(active_profile)
	game.set_starting_night(level)
	var loader := get_node_or_null("/root/PlantResources")
	if loader != null:
		loader.request_loadout(game.get_carried_plant_ids())
		loader.request_night(level)
	game.return_to_menu_requested.connect(show_menu)
	game.run_settled.connect(_on_run_settled)
	_replace_screen(game)

func _on_run_settled(_result: Dictionary) -> void:
	if current_screen == null or not current_screen.has_method("export_profile"): return
	var progression_profile: Dictionary = current_screen.export_profile()
	for key in progression_profile.keys(): active_profile[key] = progression_profile[key]
	var store := ProfileStore.new(); store.save_profile(active_profile); store.save_account_progress(active_profile)

func _replace_screen(next_screen: Node) -> void:
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = next_screen
	add_child(current_screen)
