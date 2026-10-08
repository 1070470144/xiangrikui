extends RefCounted

const Library = preload("res://scripts/plant_animation_library.gd")

static func wait_for_species(tree: SceneTree, species: String) -> void:
	Library.request_species(species)
	var deadline := Time.get_ticks_msec() + 30000
	while Library.get_cached_frames(species) == null:
		assert(not Library._failed.has(species), "Animation load failed: " + species)
		assert(Time.get_ticks_msec() < deadline, "Animation load timed out: " + species)
		await tree.process_frame
