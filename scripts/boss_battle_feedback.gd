extends Node2D

# Ownership stays here so disconnect/death/reset restore every plant immediately.
var game: Node
var warnings: Dictionary = {}
var zones: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var bosses: Array[Node] = []
var guards: Dictionary = {}
var panel: PanelContainer
var health_bar: ProgressBar
var status: Label
var title: Label
const VideoEffect = preload("res://scripts/root_boss_video_effect.gd")
var video_effects: Array[Node] = []
var enraged_owners: Dictionary = {}

func _video(kind: String, point: Vector2, radius: float, duration: float, owner: Node, follow: Node2D = null) -> void:
	if not is_instance_valid(owner) or not ("enemy_id" in owner) or owner.enemy_id != "root_crown_colossus": return
	if not FileAccess.file_exists("res://assets/effects/root_boss/atlas_manifest.json"): return
	if DisplayServer.get_name() == "headless": return
	var effect := VideoEffect.new()
	add_child(effect)
	if effect.configure(kind, point, radius, duration, owner.get_instance_id(), follow): video_effects.append(effect)
	else: effect.queue_free()

func _core_video(duration: float, owner: Node) -> void:
	_video("exposed_fx", owner.global_position + Vector2(0, -105), 65, duration, owner, owner)

func configure(value: Node) -> void:
	game = value
	z_index = 30 # Above the night fog, below the screen HUD.
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-210, 98)
	panel.size = Vector2(420, 82)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.055, 0.045, 0.94)
	style.border_color = Color("b38b50")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	holder.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(400, 12)
	health_bar.show_percentage = false
	var health_bg := StyleBoxFlat.new()
	health_bg.bg_color = Color("2c211c")
	health_bar.add_theme_stylebox_override("background", health_bg)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("a64732")
	health_bar.add_theme_stylebox_override("fill", health_fill)
	box.add_child(health_bar)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	box.add_child(status)
	panel.hide()

func register(boss: Node) -> void:
	bosses.append(boss)
	boss.boss_warning_requested.connect(_warning.bind(boss))
	boss.boss_zone_requested.connect(_zone.bind(boss))
	boss.boss_special_finished.connect(_finished.bind(boss))
	boss.boss_summon_requested.connect(_summon.bind(boss))
	boss.boss_cleanup_requested.connect(clear_owner.bind(boss))
	boss.boss_core_exposed.connect(_core_video.bind(boss))
	boss.tree_exiting.connect(clear_owner.bind(boss), CONNECT_ONE_SHOT)

func _warning(kind: String, center: Vector2, radius: float, duration: float, owner: Node) -> void:
	warnings[owner.get_instance_id()] = {"kind":kind, "center":center, "radius":radius, "time":duration, "duration":duration}
	queue_redraw()

func _zone(kind: String, center: Vector2, radius: float, duration: float, owner: Node) -> void:
	zones.append({"kind":kind, "center":center, "radius":radius, "time":duration, "owner":owner.get_instance_id()})
	_video("root_lock", center, radius, duration, owner)
	update_roots()

func _finished(kind: String, owner: Node) -> void:
	var id := owner.get_instance_id()
	if kind == "slam" and warnings.has(id):
		var warning: Dictionary = warnings[id]
		impacts.append({"center":warning.center, "radius":warning.radius, "time":0.5, "owner":id})
		_video("impact", warning.center, warning.radius, 0.5, owner)
	warnings.erase(id)
	if kind == "interrupted":
		for effect in video_effects:
			if is_instance_valid(effect) and effect.effect_owner == id: effect.queue_free()
	queue_redraw()

func _summon(_kind: String, center: Vector2, count: int, owner: Node) -> void:
	if not is_instance_valid(owner) or owner.health <= 0.0 or game.phase != game.Phase.NIGHT: return
	_video("summon_fx", center, 100, 1.0, owner)
	for i in range(count):
		var guard: Node = game._spawn_enemy(game.EnemyScript.Kind.HUSK_RAM, 0, {"spawn_position":center + Vector2(-60 if i % 2 == 0 else 60, 25)})
		if guard != null:
			var id := owner.get_instance_id()
			if not guards.has(id): guards[id] = []
			guards[id].append(guard)

func _clear_guards(id: int) -> void:
	for guard in guards.get(id, []):
		if not is_instance_valid(guard): continue
		if game.has_method("unregister_enemy"): game.unregister_enemy(guard)
		guard.queue_free()
	guards.erase(id)

func clear_owner(owner: Node) -> void:
	var id := owner.get_instance_id()
	enraged_owners.erase(id)
	for effect in video_effects:
		if is_instance_valid(effect) and effect.effect_owner == id: effect.queue_free()
	_clear_guards(id)
	warnings.erase(id)
	zones = zones.filter(func(zone: Dictionary) -> bool: return int(zone.owner) != id)
	impacts = impacts.filter(func(impact: Dictionary) -> bool: return int(impact.owner) != id)
	bosses.erase(owner)
	update_roots()
	queue_redraw()

func clear_all() -> void:
	for effect in video_effects:
		if is_instance_valid(effect): effect.queue_free()
	video_effects.clear()
	enraged_owners.clear()
	for id in guards.keys(): _clear_guards(id)
	warnings.clear()
	zones.clear()
	impacts.clear()
	update_roots()
	if panel != null: panel.hide()
	queue_redraw()

func update_roots() -> void:
	if not is_instance_valid(game): return
	for plant in game.plants:
		if not is_instance_valid(plant): continue
		var rooted := false
		for zone in zones:
			if plant.health > 0.0 and plant.global_position.distance_to(zone.center) <= float(zone.radius): rooted = true; break
		plant.boss_root_interval_multiplier = 1.2 if rooted else 1.0

func advance_zones(delta: float) -> void:
	for zone in zones: zone.time = maxf(0.0, float(zone.time) - delta)
	zones = zones.filter(func(zone: Dictionary) -> bool: return float(zone.time) > 0.0)
	update_roots()

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	if game.phase != game.Phase.NIGHT:
		clear_all()
		return
	advance_zones(delta)
	for warning in warnings.values(): warning.time = maxf(0.0, float(warning.time) - delta)
	for impact in impacts: impact.time -= delta
	impacts = impacts.filter(func(impact: Dictionary) -> bool: return float(impact.time) > 0.0)
	bosses = bosses.filter(func(boss: Node) -> bool: return is_instance_valid(boss) and boss.health > 0.0)
	for index in range(video_effects.size() - 1, -1, -1):
		if not is_instance_valid(video_effects[index]) or video_effects[index].is_queued_for_deletion(): video_effects.remove_at(index)
	for owner in bosses:
		if owner.boss_enraged and not enraged_owners.has(owner.get_instance_id()):
			enraged_owners[owner.get_instance_id()] = true
			_video("enraged_fx", owner.global_position + Vector2(0, -100), 115, 1.5, owner, owner)
	panel.visible = not bosses.is_empty()
	if panel.visible:
		var boss: Node = bosses[0]
		title.text = ("根冠巨像" if boss.enemy_id == "root_crown_colossus" else "太阳吞噬者") + (" · 狂暴" if boss.boss_enraged else "")
		health_bar.max_value = boss.max_health
		health_bar.value = boss.health
		if boss.core_exposed_time > 0.0:
			status.text = "核心暴露 %.1f 秒 · 承伤 +35%%" % boss.core_exposed_time
			status.modulate = Color("ffe1a0")
		elif boss.ability_windup > 0.0:
			status.text = ("砸地蓄力" if boss.boss_skill == "slam" else "技能蓄力") + " %.1f 秒 · 可打断" % boss.ability_windup
			status.modulate = Color("ff9c80")
		elif boss.enemy_id == "root_crown_colossus":
			status.text = "灯光压制 %.1f / 3 秒" % boss.boss_light_progress if boss.boss_light_cooldown <= 0.0 else "核心冷却 %.1f 秒" % boss.boss_light_cooldown
			status.modulate = Color("d6ceba")
		else: status.text = "连接光节点 · 防备吞噬"
	queue_redraw()

func _draw() -> void:
	for zone in zones:
		var point: Vector2 = to_local(zone.center)
		draw_circle(point, float(zone.radius), Color(0.34, 0.2, 0.1, 0.16))
		draw_arc(point, float(zone.radius), 0, TAU, 64, Color(0.68, 0.48, 0.24, 0.6), 2)
		for i in range(9):
			var ray := Vector2.from_angle(i * TAU / 9)
			draw_line(point + ray * 20, point + ray * float(zone.radius), Color(0.4, 0.3, 0.15, 0.65), 3)
	for warning in warnings.values():
		var point: Vector2 = to_local(warning.center)
		var radius := float(warning.radius)
		draw_circle(point, radius, Color(0.8, 0.12, 0.04, 0.18))
		draw_arc(point, radius, 0, TAU, 80, Color("ffbb73"), 3)
		draw_arc(point, radius - 7, -PI / 2, -PI / 2 + TAU * (1.0 - float(warning.time) / float(warning.duration)), 80, Color("ff573a"), 5)
		draw_line(point - Vector2(12, 0), point + Vector2(12, 0), Color("ffe0a0"), 2)
		draw_line(point - Vector2(0, 12), point + Vector2(0, 12), Color("ffe0a0"), 2)
	for impact in impacts:
		var t := 1.0 - float(impact.time) / 0.5
		draw_arc(to_local(impact.center), float(impact.radius) * (0.4 + 0.6 * t), 0, TAU, 80, Color(1, 0.72, 0.4, 1 - t), 8 * (1 - t) + 1)
