extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const AttackFX = preload("res://scripts/monster_attack_fx.gd")
const Animations = preload("res://scripts/monster_animation_library.gd")
var failures: Array[String] = []

class AttackTarget extends Node2D:
	var hits := 0
	func take_enemy_damage(_amount: float, _rank: String, _melee: bool, _attacker: Node = null) -> void:
		hits += 1

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	for id in ["shadow_beast", "erosion_bug", "husk_ram", "spore_moth", "shell_scarab"]:
		Animations.request_species(id)
		var deadline := Time.get_ticks_msec() + 30000
		while Animations.get_frames(id) == null and Time.get_ticks_msec() < deadline: await process_frame
		assert(Animations.get_frames(id) != null, "Monster resource preparation timed out")
		var enemy := Enemy.new()
		root.add_child(enemy)
		enemy.set_process(false)
		enemy.configure_by_id(id, Vector2.ZERO)
		expect(enemy.animation_frames != null, id + " must load generated frames")
		if enemy.animation_frames == null:
			enemy.queue_free()
			continue
		var walk_count := enemy.animation_frames.get_frame_count("walk")
		var walk_fps := enemy.animation_frames.get_animation_speed("walk")
		var attack_count := enemy.animation_frames.get_frame_count("attack")
		expect(walk_count > 1, id + " must load a complete walk cycle")
		expect(is_equal_approx(walk_fps, 24.0), id + " preserves native video FPS")
		expect(attack_count > 8, id + " loads a full video attack")
		for state in ["walk", "attack"]:
			var layout: Dictionary = enemy.animation_frames.get_meta(state + "_layout")
			var source_fps := enemy.animation_frames.get_animation_speed(state)
			expect(layout["frames"] == enemy.animation_frames.get_frame_count(state), id + " frame count follows manifest")
			expect(is_equal_approx(float(layout["durations_ms"][0]), 1000.0 / source_fps), id + " native frame duration is preserved")
		if id == "shadow_beast":
			expect(walk_count == 15 and is_equal_approx(walk_fps, 24.0), "video walk uses all 15 native frames at 24 FPS")
			expect(enemy.animation_frames.get_frame_texture("walk", 0).get_size() == Vector2(252, 192), "video game padding preserves the full character")
		expect(not enemy.animation_frames.get_animation_loop("attack"), "attack is a one-shot")
		var target := AttackTarget.new()
		root.add_child(target)
		target.position = Vector2(200, 0)
		enemy.target = target
		enemy._process(0.13)
		var first := enemy.art_sprite.texture
		enemy._process(0.13)
		expect(enemy.art_sprite.texture != first, id + " walk must advance")
		enemy.charge_time = 0.0
		var phase := enemy._walk_phase
		enemy.apply_slow("test", 0.5, 1.0)
		enemy._animate_art(0.0)
		expect(is_equal_approx(enemy._walk_phase, phase), "speed changes must not jump gait phase")
		enemy._animate_art(0.05)
		var expected_phase := fmod(phase + 0.05 * walk_fps * 0.5, float(walk_count))
		expect(is_equal_approx(enemy._walk_phase, expected_phase), "slow changes phase increment only")
		enemy._moving = false
		enemy._animate_art(0.0)
		expect(enemy.art_sprite.texture == enemy.animation_frames.get_frame_texture("walk", int(enemy._walk_phase)), "first stopped render preserves current gait frame")
		enemy._animate_art(0.0)
		if id != "spore_moth":
			expect(enemy.art_sprite.texture == enemy.animation_frames.get_frame_texture("walk", 0), "second stopped render returns to neutral frame")
		enemy.slow_ratio = 0.0
		target.position = enemy.position + Vector2(-10, 0)
		enemy._attack_pose = 0.4
		enemy._animation_clock = 0.0
		enemy._moving = false
		enemy._animate_art(0.1)
		var attack_index := mini(attack_count - 1, int(0.1 / enemy._art_attack_duration() * attack_count))
		expect(enemy.art_sprite.texture == enemy.animation_frames.get_frame_texture("attack", attack_index), id + " attack advances at the game attack cadence")
		var attack_layout: Dictionary = enemy.animation_frames.get_meta("attack_layout")
		var runtime: Dictionary = enemy.animation_frames.get_meta("runtime")
		var rendered_ground := enemy.art_sprite.position.y + (float(attack_layout["ground_y"]) - enemy.art_sprite.texture.get_height() * 0.5) * enemy._art_scale()
		expect(is_equal_approx(rendered_ground, float(runtime["ground_offset"])), id + " attack remains anchored at the correct floor/hover height")
		expect(enemy.art_sprite.flip_h, "faces left toward target")
		enemy._animation_clock = enemy._art_attack_duration() - 0.00001
		enemy._update_art_texture()
		expect(enemy.art_sprite.texture == enemy.animation_frames.get_frame_texture("attack", attack_count - 1), id + " attack recovery frame is reached before pose ends")
		enemy.apply_stun(1.0)
		var clock := enemy._animation_clock
		var held_pose := enemy._attack_pose
		var held_texture := enemy.art_sprite.texture
		enemy._process(0.05)
		expect(enemy._animation_clock == clock, "stun freezes playback")
		expect(enemy._attack_pose == held_pose and enemy.art_sprite.texture == held_texture, id + " stun preserves attack pose and remaining playback duration")
		enemy._attack_pose = 0.0
		enemy._moving = false
		enemy._was_moving = false
		enemy._animate_art(0.2)
		if id == "spore_moth":
			expect(enemy.art_sprite.texture == enemy.animation_frames.get_frame_texture("walk", int(enemy._walk_phase)), "stationary moth keeps hovering with wing motion")
		else:
			expect(enemy.art_sprite.texture == enemy.animation_frames.get_frame_texture("walk", 0), "idle holds neutral frame")
		target.position = enemy.position + Vector2(20, 0)
		enemy.stun_time = 0.0
		enemy._attack_cooldown = 0.0
		var fx_before := root.get_children().filter(func(child: Node) -> bool: return child.get_script() == AttackFX).size()
		enemy._process(0.01)
		var fx_after := root.get_children().filter(func(child: Node) -> bool: return child.get_script() == AttackFX).size()
		expect((target as AttackTarget).hits == 1, id + " attack still deals exactly one hit")
		expect(fx_after == fx_before + 1, id + " attack spawns one visual effect")
		for child in root.get_children():
			if child.get_script() == AttackFX:
				child._process(1.0)
		await process_frame
		expect(root.get_children().filter(func(child: Node) -> bool: return child.get_script() == AttackFX).is_empty(), id + " attack effect cleans itself up")
		target.queue_free()
		enemy.queue_free()
	await process_frame
	if failures.is_empty():
		print("MONSTER ANIMATIONS PASSED")
		quit(0)
	else:
		for message in failures: push_error(message)
		quit(1)
