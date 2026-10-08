extends SceneTree

const Plant = preload("res://scripts/plant.gd")
const Library = preload("res://scripts/plant_animation_library.gd")
const Roster = preload("res://scripts/plant_roster.gd")
var deaths := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind in range(15):
		await preload("res://tests/plant_resource_test_helper.gd").wait_for_species(self, Roster.FLOWER_IDS[kind])
		var frames := Library.get_frames(Roster.FLOWER_IDS[kind])
		assert(frames != null and frames.has_animation("attack"))
		assert(frames.has_animation("death"), "Missing death: " + Roster.FLOWER_IDS[kind])
		assert(frames.has_animation("revive"), "Missing revive: " + Roster.FLOWER_IDS[kind])
		assert(not frames.get_animation_loop("revive") and frames.get_frame_count("revive") >= 24)
		assert(not frames.get_animation_loop("death") and frames.get_frame_count("death") >= 24)
		var plant := Plant.new()
		plant.kind = kind
		root.add_child(plant)
		plant.set_process(false)
		plant.destroyed.connect(func(_plant: Node): deaths += 1)
		plant.power_state = Plant.PowerState.DORMANT
		plant.take_damage(100000.0)
		assert(plant.dying and plant.visible and not plant.can_attack())
		assert(plant.animation_sprite.animation == "death" and plant.animation_sprite.speed_scale > 0.0)
		plant._animate_art(true)
		assert(plant.animation_sprite.animation == "death")
		await create_timer(1.3).timeout
		assert(not plant.visible and deaths == kind + 1)
		plant.take_damage(100000.0)
		assert(deaths == kind + 1)
		assert(plant.revive())
		plant.set_process(false)
		assert(plant.visible and not plant.dying and plant.reviving)
		assert(plant.animation_sprite.animation == "revive" and not plant.can_attack())
		plant._animate_art(true)
		assert(plant.animation_sprite.animation == "revive")
		await create_timer(1.35).timeout
		assert(not plant.reviving and plant.animation_sprite.animation == "idle")
		plant.take_damage(100000.0)
		assert(plant.revive())
		plant.set_process(false)
		await create_timer(1.3).timeout
		assert(plant.visible and deaths == kind + 1, "Revival must cancel pending death")
		plant.take_damage(100000.0)
		assert(plant.revive())
		plant.take_damage(100000.0)
		assert(plant.dying and not plant.reviving and plant.animation_sprite.animation == "death")
		assert(plant.revive())
		plant.set_process(false)
		plant.free()
	print("PLANT_DEATH_ANIMATION_PASS species=15 deaths=", deaths)
	quit()
