extends SceneTree

const Plant = preload("res://scripts/plant.gd")
const Library = preload("res://scripts/plant_animation_library.gd")
const Roster = preload("res://scripts/plant_roster.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind in range(15):
		await preload("res://tests/plant_resource_test_helper.gd").wait_for_species(self, Roster.FLOWER_IDS[kind])
		var plant := Plant.new()
		plant.kind = kind
		root.add_child(plant)
		plant.set_process(false)
		assert(plant.attack_fx != null)
		var frames := Library.get_frames(Roster.FLOWER_IDS[kind])
		assert(frames != null and frames.has_animation("idle") and frames.has_animation("attack"))
		plant._animate_art(true)
		var expected := plant.art_sprite.scale * Library.get_display_scale(Roster.FLOWER_IDS[kind], "attack")
		assert(plant.animation_sprite.scale.is_equal_approx(expected), "Attack scale must match idle body size")
		plant.attack_fx.trigger(Vector2(20, 0), "vine")
		assert(not plant.attack_fx.visible, "Legacy external vine effect must be removed")
		plant.free()
	print("PLANT_ATTACK_VIDEO_FX_PASS external_fx_removed=1 scale_checked=15")
	quit()
