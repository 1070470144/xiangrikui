extends Control

const Visual = preload("res://scripts/deck_builder_style.gd")
const Content = preload("res://scripts/content_data.gd")
const PlantAnimations = preload("res://scripts/plant_animation_library.gd")
const MonsterAnimations = preload("res://scripts/monster_animation_library.gd")
const ART := "res://assets/ui/generated/greenhouse_codex/"
const IDS := [["thorn_flower", "prism_flower"], ["shadow_beast", "erosion_bug"]]
static var _preview_bounds: Dictionary = {}
var groups: Array = []
var category := 0
var selected := 0
var list: VBoxContainer
var hero: TextureRect
var hero_animation: AnimatedSprite2D
var animation_choice: OptionButton
var _preview_id := ""
var _preview_scale := 1.0
var title: Label
var subtitle: Label
var description: Label
var stats: Label
var tip: Label
var count: Label
var tabs: Array[Button] = []

func setup(plants: Array, monsters: Array, back: Callable) -> void:
	groups = [plants, monsters]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Visual.theme()
	add_child(_image("background", Vector2.ZERO, Vector2(1152, 648)))
	var shade := ColorRect.new(); shade.color = Color(0.02, 0.035, 0.03, 0.24); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(shade)
	var return_button := Button.new(); return_button.text = "返回"; return_button.position = Vector2(38, 25); return_button.size = Vector2(96, 42); return_button.pressed.connect(back); add_child(return_button)
	add_child(_label("温室图鉴", 30, Visual.GOLD, Vector2(155, 24)))
	add_child(_label("植物档案与暗影观察记录", 14, Visual.MUTED, Vector2(829, 40)))
	add_child(_image("specimen_board", Vector2(28, 87), Vector2(1096, 531)))
	for index in 2:
		var button := Button.new(); button.name = "PlantTab" if index == 0 else "MonsterTab"; button.text = "植物" if index == 0 else "怪物"; button.position = Vector2(51 + index * 115, 110); button.size = Vector2(106, 38); button.pressed.connect(select_category.bind(index)); add_child(button); tabs.append(button)
	count = _label("", 12, Visual.MUTED, Vector2(54, 167)); add_child(count)
	var scroll := ScrollContainer.new(); scroll.name = "EntryScroll"; scroll.position = Vector2(52,198); scroll.size = Vector2(224,377); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	list = VBoxContainer.new(); list.name = "EntryList"; list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 12); scroll.add_child(list)
	hero = _image("thorn_flower", Vector2(301, 111), Vector2(451, 369)); hero.name = "SpecimenArt"; add_child(hero)
	hero_animation = AnimatedSprite2D.new()
	hero_animation.name = "SpecimenAnimation"
	hero_animation.centered = true
	hero_animation.visible = false
	hero_animation.position = hero.position + hero.size * 0.5
	hero_animation.animation_finished.connect(func():
		if hero_animation.visible: hero_animation.play()
	)
	add_child(hero_animation)
	animation_choice = OptionButton.new()
	animation_choice.name = "AnimationChoice"
	animation_choice.position = Vector2(312, 486)
	animation_choice.size = Vector2(160, 32)
	animation_choice.item_selected.connect(_select_animation)
	add_child(animation_choice)
	var original := TextureRect.new(); original.name = "InGameAppearance"; original.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; original.position = Vector2(307, 523); original.size = Vector2(68, 68); original.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; original.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(original)
	tip = _label("", 14, Visual.PAPER, Vector2(390, 531)); tip.size = Vector2(356, 59); tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(tip)
	title = _label("", 30, Visual.GOLD, Vector2(786, 119)); title.name = "EntryTitle"; add_child(title)
	subtitle = _label("", 15, Visual.MUTED, Vector2(786, 164)); add_child(subtitle)
	add_child(_label("观察笔记", 13, Visual.GOLD, Vector2(786, 215)))
	description = _label("", 17, Visual.PAPER, Vector2(786, 245)); description.name = "EntryDescription"; description.size = Vector2(301, 117); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(description)
	add_child(_label("基础资料", 13, Visual.GOLD, Vector2(786, 382)))
	stats = _label("", 16, Visual.PAPER, Vector2(786, 415)); stats.name = "EntryStats"; stats.size = Vector2(299, 170); stats.add_theme_constant_override("line_spacing", 10); add_child(stats)
	select_category(0)

func select_category(value: int) -> void:
	category = clampi(value, 0, 1)
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	count.text = "%s档案 · %d 个条目" % ["植物" if category == 0 else "怪物", groups[category].size()]
	for index in groups[category].size():
		var entry: Dictionary = groups[category][index]
		var button := Button.new(); button.name = "Entry%d" % index; button.custom_minimum_size = Vector2(224, 104); button.pressed.connect(select_entry.bind(index)); list.add_child(button)
		var id := str(entry.get("id", IDS[category][mini(index, IDS[category].size()-1)]))
		var art := _image(id, Vector2(7, 7), Vector2(66, 88)); button.add_child(art)
		var name_label := _label(str(entry.name), 19, Visual.PAPER, Vector2(84, 25)); button.add_child(name_label)
		var number_label := _label("档案 %02d" % (index + 1), 12, Visual.MUTED, Vector2(84, 57)); button.add_child(number_label)
	for index in 2:
		for state in ["normal", "hover", "pressed"]: tabs[index].add_theme_stylebox_override(state, Visual.button_plate(state, index == category))
	select_entry(0)

func select_entry(index: int) -> void:
	selected = clampi(index, 0, groups[category].size() - 1)
	var entry: Dictionary = groups[category][selected]
	var id := str(entry.get("id", IDS[category][mini(selected, IDS[category].size()-1)]))
	hero.texture = _specimen_texture(id)
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_update_hero_animation(id)
	title.text = str(entry.name); subtitle.text = str(entry.subtitle); description.text = str(entry.description)
	get_node("InGameAppearance").texture = _animation_frame(id) if hero_animation.visible else load(str(entry.texture))
	var definitions: Array = Content.FLOWERS if category == 0 else Content.ENEMIES
	for data in definitions:
		if data.id != id: continue
		if category == 0:
			stats.text = "生命  %d\n种子消耗  %d\n作用范围  %d\n伤害  %d\n间隔  %.2f 秒" % [data.health, data.seed_cost, data.get("range",0), data.get("damage",0), data.get("interval",0)]
		else:
			stats.text = "生命  %d\n移动速度  %d\n攻击伤害  %d\n攻击间隔  %.2f 秒\n首次出现  第 %d 夜" % [data.health, data.speed, data.damage, data.interval, data.first_night]
	tip.text = "加入五个植物槽之一，在白昼种植并保持光脉供能。" if category == 0 else str(entry.description)
	for number in list.get_child_count():
		var button := list.get_child(number) as Button
		for state in ["normal", "hover", "pressed"]:
			var style := Visual.panel(Color(0.06, 0.1, 0.09, 0.5), Visual.GOLD if number == selected or state == "hover" else Color("4d5b4f"), 5)
			button.add_theme_stylebox_override(state, style)

func _image(asset: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var image := TextureRect.new(); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.texture = _specimen_texture(asset); image.position = pos; image.size = dimensions; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if preload("res://scripts/plant_roster.gd").FLOWER_IDS.has(asset) else TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.clip_contents = true; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; return image

func _specimen_texture(id: String) -> Texture2D:
	var roster = preload("res://scripts/plant_roster.gd")
	var index: int = roster.FLOWER_IDS.find(id)
	if index >= 2: return load(roster.texture_path(index))
	var codex_path := ART + id + ".png"
	if ResourceLoader.exists(codex_path): return load(codex_path)
	return _animation_frame(id)

func _animation_frame(id: String) -> Texture2D:
	var frames := _animation_frames(id)
	if frames == null: return null
	var state := "idle" if category == 0 else "walk"
	if not frames.has_animation(state) or frames.get_frame_count(state) == 0: return null
	return frames.get_frame_texture(state, 0)

func _animation_frames(id: String) -> SpriteFrames:
	return PlantAnimations.get_frames(id) if preload("res://scripts/plant_roster.gd").FLOWER_IDS.has(id) else MonsterAnimations.get_frames(id)

func _update_hero_animation(id: String) -> void:
	_preview_id = id
	hero_animation.stop()
	animation_choice.clear()
	var frames := _animation_frames(id)
	if frames == null:
		hero_animation.visible = false
		hero.visible = true
		animation_choice.hide()
		return
	var state := "idle" if category == 0 else "walk"
	if not frames.has_animation(state):
		hero_animation.visible = false
		hero.visible = true
		return
	hero_animation.sprite_frames = frames
	hero_animation.animation = state
	hero_animation.position = hero.position + hero.size * 0.5
	# Fit every action to the same base scale so switching states does not resize the body.
	var bounds := _get_preview_bounds(id, frames)
	_preview_scale = minf(hero.size.x / maxf(bounds.size.x, 1.0), hero.size.y / maxf(bounds.size.y, 1.0)) * 0.88
	hero_animation.position -= bounds.get_center() * _preview_scale
	var states := ["idle", "attack", "death", "revive"] if category == 0 else ["walk", "attack", "spawn", "death"]
	var labels := {"idle":"待机", "walk":"移动", "attack":"攻击", "death":"死亡", "revive":"复活", "spawn":"出场"}
	for action in states:
		if frames.has_animation(action):
			animation_choice.add_item(labels[action])
			animation_choice.set_item_metadata(animation_choice.item_count - 1, action)
	animation_choice.show()
	hero.visible = false
	hero_animation.visible = true
	_select_animation(0)

func _get_preview_bounds(id: String, frames: SpriteFrames) -> Rect2:
	if _preview_bounds.has(id): return _preview_bounds[id]
	var bounds := Rect2()
	var found := false
	for action in frames.get_animation_names():
		var action_scale := PlantAnimations.get_display_scale(id, action) if category == 0 else 1.0
		var action_offset := PlantAnimations.get_offset(id, action) if category == 0 else Vector2.ZERO
		for frame in frames.get_frame_count(action):
			var texture := frames.get_frame_texture(action, frame)
			var used := Rect2(texture.get_image().get_used_rect())
			if not used.has_area(): continue
			used.position = (used.position - texture.get_size() * 0.5 + action_offset) * action_scale
			used.size *= action_scale
			bounds = bounds.merge(used) if found else used
			found = true
	_preview_bounds[id] = bounds
	return bounds

func _select_animation(index: int) -> void:
	var state := str(animation_choice.get_item_metadata(index))
	hero_animation.stop()
	hero_animation.offset = PlantAnimations.get_offset(_preview_id, state) if category == 0 else Vector2.ZERO
	var display_scale := PlantAnimations.get_display_scale(_preview_id, state) if category == 0 else 1.0
	hero_animation.scale = Vector2.ONE * _preview_scale * display_scale
	hero_animation.play(state)

func _label(value: String, font_size: int, tint: Color, pos: Vector2) -> Label:
	var label := Label.new(); label.text = value; label.position = pos; label.add_theme_font_size_override("font_size", font_size); label.modulate = tint; label.mouse_filter = Control.MOUSE_FILTER_IGNORE; return label
