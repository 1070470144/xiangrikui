extends SceneTree

const Library = preload("res://scripts/plant_animation_library.gd")
const Plant = preload("res://scripts/plant.gd")
const Helper = preload("res://tests/plant_resource_test_helper.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var species := "thorn_flower"
	assert(Library.get_cached_frames(species) == null)
	Library.request_species(species)
	Library.request_species(species)
	assert(Library._jobs.size() == 1, "Requests must be deduplicated")
	var plant := Plant.new()
	root.add_child(plant)
	plant.set_process(false)
	assert(plant.art_sprite.visible and not plant.animation_sprite.visible)
	plant.health = 31.0
	plant._cooldown = 0.7
	plant.set_powered(false)
	var removed := Plant.new()
	root.add_child(removed)
	removed.queue_free()
	var dead := Plant.new()
	root.add_child(dead)
	dead.take_damage(100000.0)
	await Helper.wait_for_species(self, species)
	assert(plant.animation_sprite.visible)
	assert(plant.health == 31.0 and plant._cooldown == 0.7)
	assert(plant.power_state == Plant.PowerState.STORED)
	assert(not dead.visible, "Resource completion must not resurrect dead plants")
	assert(dead.revive())
	assert(dead.animation_sprite.animation == "revive")
	var cached := Library.get_cached_frames(species)
	var second := Plant.new()
	root.add_child(second)
	assert(second.animation_sprite.sprite_frames == cached)
	Library.request_species("missing_test_species")
	assert(Library._failed.has("missing_test_species"))
	Library.request_species("missing_test_species")
	assert(not Library._jobs.has("missing_test_species"))
	plant.free()
	dead.free()
	second.free()
	print("PLANT_ASYNC_RESOURCES_PASS")
	quit()
