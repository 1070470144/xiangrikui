extends SceneTree

const Plant = preload("res://scripts/plant.gd")
const Roster = preload("res://scripts/plant_roster.gd")
const Library = preload("res://scripts/plant_animation_library.gd")
var checks := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var ready_only := OS.get_cmdline_user_args().has("--ready-only")
	for kind in range(15):
		await preload("res://tests/plant_resource_test_helper.gd").wait_for_species(self, Roster.FLOWER_IDS[kind])
		var frames := Library.get_frames(Roster.FLOWER_IDS[kind])
		if ready_only and (frames == null or not frames.has_animation("attack")): continue
		assert(frames != null, "Missing video animation " + Roster.FLOWER_IDS[kind])
		assert(frames.get_frame_count("idle") > 8 and frames.get_frame_count("attack") > 8)
		assert(frames.get_animation_loop("idle") and not frames.get_animation_loop("attack"))
		assert(frames.get_frame_count("attack") == 64 and frames.has_animation("revive"))
		var plant := Plant.new(); plant.kind = kind; root.add_child(plant); plant.set_process(false)
		assert(plant.animation_sprite.visible and not plant.art_sprite.visible)
		assert(plant.animation_sprite.animation == "idle")
		plant._animate_art(true)
		assert(plant.animation_sprite.animation == "attack")
		await create_timer(1.15).timeout
		assert(plant.animation_sprite.animation == "idle", "Attack should return to idle")
		plant.power_state = Plant.PowerState.DORMANT; plant._update_animation_power()
		var paused_frame: int = plant.animation_sprite.frame
		await create_timer(0.12).timeout
		assert(plant.animation_sprite.frame == paused_frame)
		plant.set_powered(true); assert(plant.animation_sprite.speed_scale == 1.0)
		plant.configure((kind+1)%15,0)
		var next_frames := Library.get_frames(plant.get_flower_id())
		if next_frames != null:
			assert(plant.animation_sprite.sprite_frames == next_frames)
		else:
			assert(plant.art_sprite.visible and not plant.animation_sprite.visible)
		plant.free(); checks += 1
	print("PLANT_VIDEO_ANIMATION species=",checks," failures=0")
	quit(0)
