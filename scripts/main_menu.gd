extends Control

signal start_requested(level: int)

const ArtLibrary = preload("res://scripts/art_library.gd")
const ArtManifest = preload("res://scripts/art_manifest.gd")
const ContentData = preload("res://scripts/content_data.gd")
const DeckBuilderScene = preload("res://scenes/deck_builder.tscn")
const BackgroundMotionScript = preload("res://scripts/main_menu_background_motion.gd")

const PLANTS := [
	{
		"name": "荆棘花",
		"subtitle": "近距离范围防卫",
		"description": "扎根于光脉旁，持续用尖刺攻击附近的多个敌人。光脉断裂后会停止攻击。",
		"texture": ArtLibrary.THORN_POWERED,
	},
	{
		"name": "棱镜花",
		"subtitle": "远距离单体输出",
		"description": "聚集太阳能量，向远处的敌人发射高伤害光弹。适合保护薄弱分支。",
		"texture": ArtLibrary.PRISM_POWERED,
	},
]

const MONSTERS := [
	{
		"id": "shadow_beast",
		"name": "影兽",
		"subtitle": "突袭型敌人",
		"description": "从温室边缘逼近，优先冲向中央的太阳母花。移动迅速，必须尽早拦截。",
		"texture": ArtLibrary.SHADOW_MOVE,
	},
	{
		"id": "erosion_bug",
		"name": "蚀芽虫",
		"subtitle": "破坏型敌人",
		"description": "会主动啃噬四周的光脉节点。节点失效后，对应区域的植物将失去能量。",
		"texture": ArtLibrary.BUG_MOVE,
	},
	{"id":"husk_ram", "name":"枯壳撞兽", "subtitle":"冲锋型敌人", "description":"厚重的枯壳保护身体，接近目标时发起冲锋，造成强力撞击。", "texture":"res://assets/enemies/animations/husk_ram/walk-frame-0.png"},
	{"id":"spore_moth", "name":"腐孢蛾", "subtitle":"飞行腐蚀型敌人", "description":"在空中振翅逼近，从远处释放腐孢，让植物持续受到腐蚀伤害。", "texture":"res://assets/enemies/animations/spore_moth/walk-frame-0.png"},
	{"id":"shell_scarab", "name":"黑甲育虫", "subtitle":"装甲型敌人", "description":"坚硬的甲壳减少正面伤害，需要从侧翼攻击或使用范围伤害。", "texture":"res://assets/enemies/animations/shell_scarab/walk-frame-0.png"},
]

const SETTINGS_ENTRIES := ["主音量", "全屏显示", "减少动态效果"]
const HOME_ACTION_LABELS := ["继续守夜", "卡组配置", "七夜记录", "温室图鉴", "设置"]
const HOME_TAGLINE := "太阳已经熄灭，而守夜仍将继续。"
const NIGHT_RECORDS := [
	{"number": 1, "name": "初临"},
	{"number": 2, "name": "八方来袭"},
	{"number": 3, "name": "酸雨"},
	{"number": 4, "name": "雷雨"},
	{"number": 5, "name": "根冠巨像"},
	{"number": 6, "name": "喘息"},
	{"number": 7, "name": "太阳吞噬者"},
]
const PROFILE_PATH := "user://local_profile.cfg"
const ACCOUNTS_PATH := "user://local_accounts.cfg"
const ART_MANIFEST_PATH := "res://art_source/manifests/main_menu.json"

var local_profile := {
	"account_type": "本地账号",
	"player_name": "温室守护者",
	"level_progress": 0,
	"highest_wave": 0,
	"play_time_minutes": 0,
	"meta_seeds": 0,
	"unlocked_cards": ContentData.STARTER_CARD_IDS.duplicate(),
	"mother_meta_levels": {"max_health":0, "starting_energy":0, "day_regen":0, "sunburst_damage":0},
	"selected_deck": [],
}
var local_accounts: Array[Dictionary] = []
var page_stack: Control
var start_pending := false
var selected_starting_night := 1
var motion_enabled := true
var background_motion: Control

func _init() -> void:
	_load_local_profile()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_local_profile()
	_build_background()
	_show_home()

func get_plant_entries() -> Array:
	var roster = preload("res://scripts/plant_roster.gd")
	var entries: Array = []
	for i in range(roster.FLOWER_IDS.size()):
		var flower := ContentData.get_flower(roster.FLOWER_IDS[i])
		entries.append({"id":flower.id, "name":flower.name, "subtitle":"光脉植物 · 种子 %d" % flower.seed_cost, "description":roster.DESCRIPTIONS[i], "texture":roster.texture_path(i)})
	return entries

func get_monster_entries() -> Array:
	return MONSTERS

func get_local_profile() -> Dictionary:
	return local_profile.duplicate(true)

func decode_profile_field(key: String, value: Variant) -> Variant:
	if key in ["unlocked_cards", "mother_meta_levels", "selected_deck"] and value is String:
		var parsed: Variant = JSON.parse_string(value)
		return parsed if parsed != null else value
	return value

func apply_progression_profile(profile: Dictionary) -> void:
	for key in ["meta_seeds", "unlocked_cards", "mother_meta_levels", "selected_deck"]:
		if profile.has(key): local_profile[key] = profile[key].duplicate(true) if profile[key] is Array or profile[key] is Dictionary else profile[key]
	_save_local_profile()

func get_deck_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for id in local_profile.get("unlocked_cards", ContentData.STARTER_CARD_IDS):
		var card := ContentData.get_card(str(id))
		if not card.is_empty(): options.append(card.duplicate(true))
	return options

func set_selected_deck(deck: Array[String]) -> bool:
	if deck.size() != ContentData.DECK_SIZE: return false
	var unlocked: Array = local_profile.get("unlocked_cards", ContentData.STARTER_CARD_IDS)
	var counts := {}
	var rare_count := 0
	var legendary_count := 0
	for id in deck:
		if not unlocked.has(id): return false
		var card := ContentData.get_card(id)
		if card.is_empty(): return false
		counts[id] = int(counts.get(id, 0)) + 1
		if int(counts[id]) > int(card.get("copies_allowed", 1)): return false
		if str(card.get("rarity", "")) == "rare": rare_count += 1
		elif str(card.get("rarity", "")) == "legendary": legendary_count += 1
	if rare_count > 4 or legendary_count > 1: return false
	local_profile["selected_deck"] = deck.duplicate()
	_save_local_profile()
	return true

func get_settings_entries() -> Array:
	return SETTINGS_ENTRIES

func get_home_action_labels() -> Array:
	return HOME_ACTION_LABELS.duplicate()

func get_home_tagline() -> String:
	return HOME_TAGLINE

func get_night_records() -> Array:
	return NIGHT_RECORDS.duplicate(true)

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	if is_instance_valid(background_motion): background_motion.set_motion_enabled(enabled)

func get_local_accounts() -> Array:
	if local_accounts.is_empty():
		_load_local_profile()
	return local_accounts.duplicate(true)

func create_local_account(account_name: String) -> bool:
	var clean_name := account_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 16:
		return false
	for account in local_accounts:
		if str(account.get("player_name", "")) == clean_name:
			return false
	local_accounts.append(_new_account(clean_name))
	_save_accounts()
	return true

func switch_local_account(account_name: String) -> bool:
	for account in local_accounts:
		if str(account.get("player_name", "")) == account_name:
			local_profile["player_name"] = account_name
			local_profile["level_progress"] = account.get("level_progress", 0)
			local_profile["highest_wave"] = account.get("highest_wave", 0)
			local_profile["play_time_minutes"] = account.get("play_time_minutes", 0)
			for key in ["meta_seeds", "unlocked_cards", "mother_meta_levels", "selected_deck"]:
				local_profile[key] = account.get(key, local_profile[key])
			_save_local_profile()
			return true
	return false

func delete_local_account(account_name: String) -> bool:
	if local_accounts.size() <= 1:
		return false
	var account_index := -1
	for index in local_accounts.size():
		if str(local_accounts[index].get("player_name", "")) == account_name:
			account_index = index
			break
	if account_index < 0:
		return false
	var deleting_current := str(local_profile.get("player_name", "")) == account_name
	local_accounts.remove_at(account_index)
	if deleting_current:
		var fallback_index := mini(account_index, local_accounts.size() - 1)
		return switch_local_account(str(local_accounts[fallback_index].get("player_name", "")))
	_save_accounts()
	return true

func _build_background() -> void:
	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.color = Color("111827")
	add_child(fallback)
	var bg := TextureRect.new()
	bg.name = "MainMenuBackground"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = ArtLibrary.load_texture(ArtLibrary.MAIN_MENU_BACKGROUND)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	background_motion = BackgroundMotionScript.new()
	background_motion.name = "MainMenuBackgroundMotion"
	background_motion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_motion.motion_enabled = motion_enabled
	add_child(background_motion)
	var atmosphere := ColorRect.new()
	atmosphere.name = "AtmosphereShade"
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.color = Color(0.02, 0.035, 0.055, 0.18)
	add_child(atmosphere)
	page_stack = Control.new()
	page_stack.name = "PageStack"
	page_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_stack)

func _clear_page() -> void:
	for child in page_stack.get_children():
		page_stack.remove_child(child)
		child.queue_free()

func _show_home() -> void:
	_clear_page()
	start_pending = false
	var root := Control.new()
	root.name = "HomePage"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_stack.add_child(root)

	var title_box := VBoxContainer.new()
	title_box.name = "TitleBlock"
	title_box.position = Vector2(54, 54)
	title_box.size = Vector2(660, 150)
	title_box.add_theme_constant_override("separation", 8)
	root.add_child(title_box)
	var title := _label("最后的向日葵", 52, Color("fff3bd"))
	# Layered outline and shadow give the title a hand-lettered, storybook finish
	# while keeping the default Chinese font readable on the dark greenhouse.
	title.add_theme_color_override("font_outline_color", Color("4a321c"))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.025, 0.05, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 2)
	title_box.add_child(title)
	var tagline := _label(HOME_TAGLINE, 18, Color("d5dccb"))
	title_box.add_child(tagline)

	var account := _account_entry_button()
	account.position = Vector2(846, 28)
	account.size = Vector2(278, 58)
	root.add_child(account)

	var menu_panel := PanelContainer.new()
	menu_panel.name = "MenuJournal"
	menu_panel.set_meta("visual_direction", "greenhouse_gardener_record")
	menu_panel.position = Vector2(778, 84)
	menu_panel.size = Vector2(346, 550)
	menu_panel.add_theme_stylebox_override("panel", _greenhouse_record_style())
	root.add_child(menu_panel)
	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	menu_panel.add_child(margin)
	var actions := VBoxContainer.new()
	actions.name = "ActionList"
	actions.add_theme_constant_override("separation", 6)
	margin.add_child(actions)
	var record_header := HBoxContainer.new()
	record_header.name = "GardenerRecordHeader"
	record_header.add_theme_constant_override("separation", 10)
	actions.add_child(record_header)
	var header_title := _label("园丁记录", 18, Color("c9c5a5"))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_header.add_child(header_title)
	var gardener_badge := Label.new()
	gardener_badge.name = "GardenerBadge"
	gardener_badge.text = "✦"
	gardener_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gardener_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gardener_badge.custom_minimum_size = Vector2(28, 28)
	gardener_badge.add_theme_font_size_override("font_size", 14)
	gardener_badge.add_theme_color_override("font_color", Color("c5ae68"))
	gardener_badge.add_theme_stylebox_override("normal", _compact_style(Color("14221f"), Color("786b49")))
	record_header.add_child(gardener_badge)
	var archive_divider := HSeparator.new()
	archive_divider.name = "ArchiveDivider"
	archive_divider.add_theme_stylebox_override("separator", _greenhouse_divider_style())
	actions.add_child(archive_divider)
	var primary := _home_menu_button("继续守夜", _request_start, true)
	primary.name = "PrimaryStartButton"
	primary.custom_minimum_size = Vector2(290, 56)
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.add_theme_font_size_override("font_size", 25)
	actions.add_child(primary)
	var progress := clampi(int(local_profile.get("level_progress", 0)), 0, 7)
	var progress_text := "尚未开始 · 第一夜等待园丁" if progress == 0 else "第 %d 夜 · %s" % [progress, NIGHT_RECORDS[progress - 1]["name"]]
	var progress_label := _label(progress_text, 13, Color("c4b77f"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(progress_label)
	for entry in [
		["DeckBuilderButton", _home_menu_button("卡组配置", _show_deck_builder)],
		["NightRecordsButton", _home_menu_button("七夜记录", _show_night_records)],
		["CodexButton", _home_menu_button("温室图鉴", _show_codex)],
		["SettingsButton", _home_menu_button("设置", _show_settings)],
	]:
		var secondary: Button = entry[1]
		secondary.name = entry[0]
		secondary.custom_minimum_size = Vector2(290, 44)
		secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		secondary.add_theme_font_size_override("font_size", 19)
		actions.add_child(secondary)
	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(flex)
	var exit_button := Button.new()
	exit_button.text = "退出游戏"
	exit_button.flat = true
	exit_button.custom_minimum_size.y = 30
	exit_button.add_theme_font_size_override("font_size", 15)
	exit_button.add_theme_color_override("font_color", Color("87938a"))
	exit_button.add_theme_color_override("font_hover_color", Color("d8c98f"))
	exit_button.pressed.connect(func(): get_tree().quit())
	actions.add_child(exit_button)

	var version := _label("本地版本 · 数据仅保存在此设备", 12, Color("6f7d78"))
	version.position = Vector2(28, 620)
	root.add_child(version)
	for warning in ArtManifest.apply_file(ART_MANIFEST_PATH, self):
		push_warning(warning)
	if primary.is_inside_tree():
		primary.grab_focus()
	else:
		primary.call_deferred("grab_focus")
	if motion_enabled:
		_animate_home(title_box, menu_panel)

func _request_start() -> void:
	if start_pending:
		return
	start_pending = true
	if not motion_enabled:
		start_requested.emit(selected_starting_night)
		return
	var home := page_stack.get_node_or_null("HomePage") as Control
	var veil := ColorRect.new()
	veil.name = "StartTransitionVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.06, 0.035, 0.02, 0.0)
	page_stack.add_child(veil)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if home != null:
		tween.tween_property(home, "modulate:a", 0.0, 0.42)
	tween.tween_property(veil, "color", Color(0.015, 0.02, 0.025, 1.0), 0.5)
	tween.chain().tween_callback(func(): start_requested.emit(selected_starting_night))

func _show_level_select() -> void:
	var root := _modal_shell("选择关卡", Vector2(760, 430))
	var hint := _label("选择要进入的夜晚", 17, Color("c4d1ba"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	var levels := GridContainer.new()
	levels.columns = 4
	levels.add_theme_constant_override("h_separation", 12)
	levels.add_theme_constant_override("v_separation", 12)
	root.add_child(levels)
	for level in range(1, 8):
		var label := "第 %d 夜\n%s" % [level, NIGHT_RECORDS[level - 1]["name"]]
		if level == selected_starting_night:
			label += "\n· 当前目标"
		var button := _home_menu_button(label, _request_level_start.bind(level))
		button.custom_minimum_size = Vector2(170, 72)
		button.add_theme_font_size_override("font_size", 16)
		levels.add_child(button)
	var note := _label("进入后会从所选夜晚的白昼阶段开始准备。", 14, Color("9eae9c"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)

func _request_level_start(level: int) -> void:
	selected_starting_night = clampi(level, 1, 7)
	_show_level_select()

func _animate_home(title_box: Control, menu_panel: Control) -> void:
	var title_end := title_box.position
	var panel_end := menu_panel.position
	title_box.position.y += 10.0
	menu_panel.position.x += 18.0
	title_box.modulate.a = 0.0
	menu_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_box, "position", title_end, 0.3)
	tween.tween_property(title_box, "modulate:a", 1.0, 0.24)
	tween.tween_property(menu_panel, "position", panel_end, 0.34).set_delay(0.05)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.28).set_delay(0.05)

func _account_entry_button() -> Button:
	var button := Button.new()
	button.name = "AccountEntry"
	button.text = "%s\n本地存档" % str(local_profile.get("player_name", "温室守护者"))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("eee0aa"))
	button.add_theme_stylebox_override("normal", _compact_style(Color("14231ee8"), Color("7f7651")))
	button.add_theme_stylebox_override("hover", _compact_style(Color("21352ce8"), Color("d0ad54")))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.pressed.connect(_show_account_switcher)
	return button

func _profile_panel() -> Control:
	var panel := PanelContainer.new()
	var profile_style := _panel_style(Color("172a23dc"), Color("6f835e"), 1)
	profile_style.content_margin_left = 20
	profile_style.content_margin_right = 20
	profile_style.content_margin_top = 12
	profile_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", profile_style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var section_title := _label("账号资料", 14, Color("91b483"))
	box.add_child(section_title)
	var header := HBoxContainer.new()
	box.add_child(header)
	var avatar := Label.new()
	avatar.text = "✦"
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.custom_minimum_size = Vector2(40, 36)
	avatar.add_theme_font_size_override("font_size", 23)
	avatar.add_theme_color_override("font_color", Color("ffe6a0"))
	avatar.add_theme_stylebox_override("normal", _panel_style(Color("314932"), Color("bca35a"), 1))
	header.add_child(avatar)
	var header_gap := _spacer(0)
	header.add_child(header_gap)
	var player := _label(str(local_profile["player_name"]), 19, Color("f2dfaa"))
	player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(player)
	var type_label := _label(str(local_profile["account_type"]), 14, Color("9fb795"))
	header.add_child(type_label)
	box.add_child(_separator())
	var save_state := _label("离线存档 · 数据保存在本设备", 12, Color("8fa58a"))
	box.add_child(save_state)
	box.add_child(_stat_row("关卡进度", "%d / 7" % int(local_profile["level_progress"])))
	box.add_child(_stat_row("游戏时间", "%d 分钟" % int(local_profile["play_time_minutes"])))
	var switch_button := _menu_button("切换账号", _show_account_switcher)
	switch_button.custom_minimum_size.y = 36
	switch_button.add_theme_font_size_override("font_size", 15)
	box.add_child(switch_button)
	return panel

func _modal_shell(title_text: String, panel_size: Vector2 = Vector2(900, 520)) -> VBoxContainer:
	_clear_page()
	var shade := ColorRect.new()
	shade.name = "ModalShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.035, 0.55)
	page_stack.add_child(shade)
	var root := VBoxContainer.new()
	root.name = title_text + "Page"
	root.position = (Vector2(1152, 648) - panel_size) * 0.5
	root.size = panel_size
	root.add_theme_constant_override("separation", 14)
	page_stack.add_child(root)
	var back := _back_button(_show_home)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(back)
	var heading := _label(title_text, 34, Color("fff0b0"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(heading)
	return root

func _show_night_records() -> void:
	_clear_page()
	var records := Control.new()
	records.name = "七夜记录Page"
	records.set_script(preload("res://scripts/night_records_view.gd"))
	page_stack.add_child(records)
	records.setup(NIGHT_RECORDS, local_profile, _show_home)

func _show_account_switcher() -> void:
	var root := _archive_shell("园丁档案", "本地存档 / GARDENER ARCHIVES")
	var hint := _label("选择一份档案继续守夜 · 进度独立保存在本设备", 15, Color("a9c49e"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _compact_style(Color("17231fdd"), Color("625e43")))
	root.add_child(stats)
	var stat_box := HBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 40)
	stats.add_child(stat_box)
	stat_box.add_child(_label("当前 · " + str(local_profile["player_name"]), 18, Color("f2dfaa")))
	stat_box.add_child(_stat_row("关卡进度", "%d / 7" % int(local_profile["level_progress"])))
	stat_box.add_child(_stat_row("游戏时间", "%d 分钟" % int(local_profile["play_time_minutes"])))
	var scroll := ScrollContainer.new()
	scroll.name = "AccountScroll"
	scroll.custom_minimum_size.y = 190
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "AccountList"
	list.add_theme_constant_override("separation", 9)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var delete_dialog := ConfirmationDialog.new()
	delete_dialog.name = "DeleteAccountDialog"
	delete_dialog.title = "删除本地存档"
	delete_dialog.ok_button_text = "确认删除"
	delete_dialog.cancel_button_text = "取消"
	root.add_child(delete_dialog)
	for account in local_accounts:
		var name := str(account.get("player_name", "未命名"))
		var row := HBoxContainer.new()
		row.name = "AccountRow"
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var selected := name == str(local_profile["player_name"])
		var caption := "%s%s\n第 %d / 7 夜   ·   %d 分钟" % [name, "  · 当前档案" if selected else "", int(account.get("level_progress", 0)), int(account.get("play_time_minutes", 0))]
		var button := _menu_button(caption, func():
			switch_local_account(name)
			_show_home()
		)
		button.custom_minimum_size.y = 70
		button.add_theme_font_size_override("font_size", 17)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if selected:
			button.add_theme_stylebox_override("normal", _greenhouse_button_style(Color("243b2bf0"), Color("baa565"), 2))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		var delete_button := Button.new()
		delete_button.name = "DeleteAccountButton"
		delete_button.text = "删除"
		delete_button.tooltip_text = "至少需要保留一个本地存档" if local_accounts.size() <= 1 else "删除这个本地存档"
		delete_button.disabled = local_accounts.size() <= 1
		delete_button.custom_minimum_size = Vector2(76, 70)
		delete_button.add_theme_font_size_override("font_size", 15)
		delete_button.add_theme_color_override("font_color", Color("e7c5b2"))
		delete_button.add_theme_color_override("font_hover_color", Color("fff0e8"))
		delete_button.add_theme_stylebox_override("normal", _compact_style(Color("382521e8"), Color("8b5d4f")))
		delete_button.add_theme_stylebox_override("hover", _compact_style(Color("59322be8"), Color("d88a72")))
		delete_button.add_theme_stylebox_override("focus", _focus_style())
		delete_button.pressed.connect(func():
			delete_dialog.dialog_text = "确定删除存档“%s”吗？\n删除后无法恢复。" % name
			for connection in delete_dialog.confirmed.get_connections():
				delete_dialog.confirmed.disconnect(connection["callable"])
			delete_dialog.confirmed.connect(func():
				if delete_local_account(name):
					_show_account_switcher()
			, CONNECT_ONE_SHOT)
			delete_dialog.popup_centered(Vector2i(430, 180))
		)
		row.add_child(delete_button)
	var create_box := HBoxContainer.new()
	create_box.name = "AccountCreateArea"
	create_box.add_theme_constant_override("separation", 8)
	root.add_child(create_box)
	var new_name := LineEdit.new()
	new_name.placeholder_text = "为新档案填写园丁名称"
	new_name.custom_minimum_size.y = 40
	new_name.add_theme_font_size_override("font_size", 16)
	new_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_box.add_child(new_name)
	var create_button := _menu_button("＋ 新建档案", func():
		if create_local_account(new_name.text):
			switch_local_account(new_name.text.strip_edges())
			_show_account_switcher()
	)
	create_button.custom_minimum_size = Vector2(170, 40)
	create_button.add_theme_font_size_override("font_size", 16)
	create_box.add_child(create_button)

func _show_settings() -> void:
	var root := _archive_shell("设置", "设备偏好 / GREENHOUSE SETTINGS")
	var volume_row := _settings_row(root, "主音量", "调整游戏的整体声音大小")
	var volume_box := VBoxContainer.new()
	volume_box.custom_minimum_size.x = 280
	volume_row.add_child(volume_box)
	var value_label := _label("", 18, Color("f2dfaa"))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_box.add_child(value_label)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	volume.custom_minimum_size.y = 42
	value_label.text = "%d%%" % roundi(volume.value)
	var track := _compact_style(Color("0a1513"), Color("796d45"))
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	volume.add_theme_stylebox_override("slider", track)
	var fill := _compact_style(Color("64835a"), Color("c1a66a"))
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	volume.add_theme_stylebox_override("grabber_area", fill)
	volume.add_theme_stylebox_override("grabber_area_highlight", fill)
	volume.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
		value_label.text = "%d%%" % roundi(value)
	)
	volume_box.add_child(volume)
	var display_row := _settings_row(root, "全屏显示", "使用整个屏幕呈现温室")
	var fullscreen := CheckButton.new()
	fullscreen.text = "启用"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.add_theme_font_size_override("font_size", 20)
	fullscreen.toggled.connect(_set_fullscreen)
	_style_settings_toggle(fullscreen)
	display_row.add_child(fullscreen)
	var motion_row := _settings_row(root, "减少动态效果", "关闭装饰动态，让界面更平静")
	var reduced_motion := CheckButton.new()
	reduced_motion.text = "启用"
	reduced_motion.button_pressed = not motion_enabled
	reduced_motion.add_theme_font_size_override("font_size", 20)
	reduced_motion.toggled.connect(func(enabled: bool): set_motion_enabled(not enabled))
	_style_settings_toggle(reduced_motion)
	motion_row.add_child(reduced_motion)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(gap)
	var note := _label("设置立即生效，仅作用于当前设备。", 15, Color("91a48d"))
	root.add_child(note)

func _archive_shell(title_text: String, subtitle: String) -> VBoxContainer:
	_clear_page()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.02, 0.72)
	page_stack.add_child(shade)
	var background := TextureRect.new()
	background.position = Vector2(106, 40)
	background.size = Vector2(940, 568)
	background.texture = load("res://assets/ui/generated/archive_settings_panel_v1.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_stack.add_child(background)
	var root := VBoxContainer.new()
	root.name = title_text + "Page"
	root.position = Vector2(166, 82)
	root.size = Vector2(820, 480)
	root.add_theme_constant_override("separation", 14)
	page_stack.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_label(subtitle, 13, Color("a59b72")))
	titles.add_child(_label(title_text, 32, Color("fff0b0")))
	var back := _menu_button("返回温室", _show_home)
	back.custom_minimum_size = Vector2(132, 42)
	back.add_theme_font_size_override("font_size", 16)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	root.add_child(_separator())
	return root

func _settings_row(root: VBoxContainer, title_text: String, description: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 96
	panel.add_theme_stylebox_override("panel", _greenhouse_button_style(Color("10201cdb"), Color("5e593e"), 1))
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	labels.add_theme_constant_override("separation", 8)
	row.add_child(labels)
	labels.add_child(_label(title_text, 21, Color("f2dfaa")))
	labels.add_child(_label(description, 15, Color("a1b39a")))
	return row

func _style_settings_toggle(toggle: CheckButton) -> void:
	toggle.custom_minimum_size = Vector2(144, 48)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.add_theme_font_size_override("font_size", 17)
	toggle.add_theme_color_override("font_color", Color("f2dfaa"))
	toggle.add_theme_color_override("font_hover_color", Color("fff4cd"))
	toggle.add_theme_color_override("font_pressed_color", Color("fff4cd"))
	toggle.add_theme_stylebox_override("normal", _greenhouse_button_style(Color("15251f"), Color("756a48"), 1))
	toggle.add_theme_stylebox_override("hover", _greenhouse_button_style(Color("2b402b"), Color("c8b273"), 1))
	toggle.add_theme_stylebox_override("pressed", _greenhouse_button_style(Color("304b32"), Color("c8b273"), 1))
	toggle.add_theme_stylebox_override("focus", _focus_style())
	toggle.text = "已开启" if toggle.button_pressed else "已关闭"
	toggle.toggled.connect(func(enabled: bool): toggle.text = "已开启" if enabled else "已关闭")

func _show_deck_builder(_reset_draft: bool = true) -> void:
	_clear_page()
	var builder = DeckBuilderScene.instantiate()
	page_stack.add_child(builder)
	builder.setup(get_local_profile())
	builder.back_requested.connect(_show_home)
	builder.save_deck_requested.connect(func(deck: Array[String]): builder.report_deck_save_result(set_selected_deck(deck)))
	builder.profile_patch_requested.connect(func(patch: Dictionary):
		for key in patch: local_profile[key] = patch[key]
		builder.report_profile_patch_result(_save_local_profile() == OK)
	)

func _starter_deck() -> Array[String]:
	var result: Array[String] = []
	for id in ["card_sun_pierce", "card_root_snare", "card_emergency_dew", "card_root_wall", "card_sun_mine", "card_lure_bud"]:
		result.append(id)
		result.append(id)
	return result

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _load_local_profile() -> void:
	local_accounts.clear()
	var accounts_config := ConfigFile.new()
	if accounts_config.load(ACCOUNTS_PATH) == OK:
		var stored: Variant = accounts_config.get_value("accounts", "list", [])
		if stored is Array:
			for account in stored:
				if account is Dictionary:
					local_accounts.append(account)
	if local_accounts.is_empty():
		local_accounts.append(_new_account("温室守护者"))
		_save_accounts()
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return
	for key in local_profile.keys():
		local_profile[key] = decode_profile_field(key, config.get_value("profile", key, local_profile[key]))
	if not switch_local_account(str(local_profile["player_name"])):
		switch_local_account(str(local_accounts[0]["player_name"]))

func _save_local_profile() -> Error:
	var config := ConfigFile.new()
	for key in local_profile.keys():
		config.set_value("profile", key, local_profile[key])
	var result := config.save(PROFILE_PATH)
	for account in local_accounts:
		if str(account.get("player_name", "")) == str(local_profile["player_name"]):
			for key in ["level_progress", "highest_wave", "play_time_minutes", "meta_seeds", "unlocked_cards", "mother_meta_levels", "selected_deck"]:
				account[key] = local_profile[key]
	_save_accounts()
	return result

func _new_account(account_name: String) -> Dictionary:
	return {
		"player_name": account_name,
		"level_progress": 0,
		"highest_wave": 0,
		"play_time_minutes": 0,
		"meta_seeds": 0,
		"unlocked_cards": ContentData.STARTER_CARD_IDS.duplicate(),
		"mother_meta_levels": {"max_health":0, "starting_energy":0, "day_regen":0, "sunburst_damage":0},
		"selected_deck": [],
	}

func _save_accounts() -> void:
	var config := ConfigFile.new()
	config.set_value("accounts", "list", local_accounts)
	config.save(ACCOUNTS_PATH)

func _stat_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	var label := _label(label_text, 14, Color("aebdaa"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_label(value_text, 14, Color("ffe6a0")))
	return row

func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.modulate = Color("718064")
	return separator

func _show_codex() -> void:
	_clear_page()
	var codex := Control.new()
	codex.name = "温室图鉴Page"
	codex.set_script(preload("res://scripts/greenhouse_codex_view.gd"))
	page_stack.add_child(codex)
	codex.setup(get_plant_entries(), get_monster_entries(), _show_home)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_level_select") and page_stack != null:
		var home := page_stack.get_node_or_null("HomePage")
		if home != null:
			_show_level_select()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("cancel_action") and page_stack != null:
		var home := page_stack.get_node_or_null("HomePage")
		if home == null:
			_show_home()
			get_viewport().set_input_as_handled()

func _codex_page(title: String, entries: Array) -> Control:
	var margin := MarginContainer.new()
	margin.name = title
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	for entry in entries:
		row.add_child(_codex_card(entry))
	return margin

func _codex_card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("203329d9"), Color("bca35a"), 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 170)
	portrait.texture = ArtLibrary.load_texture(entry["texture"])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(portrait)
	var name_label := _label(entry["name"], 23, Color("ffe6a0"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var subtitle := _label(entry["subtitle"], 15, Color("a9c49e"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	var description := _label(entry["description"], 14, Color("e1e7da"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 54
	box.add_child(description)
	return panel

func _make_panel(pos: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _panel_style(Color("10241de8"), Color("c7a954"), 3))
	return panel

func _home_menu_button(text_value: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.set_meta("menu_button_variant", "primary" if primary else "secondary")
	button.add_theme_color_override("font_color", Color("f8e7b0"))
	button.add_theme_color_override("font_hover_color", Color("fff6d4"))
	button.add_theme_color_override("font_pressed_color", Color("ead28a"))
	button.add_theme_stylebox_override("focus", _focus_style())
	if primary:
		button.add_theme_stylebox_override("normal", _greenhouse_button_style(Color("101c1dde"), Color("766a46"), 1))
		button.add_theme_stylebox_override("hover", _greenhouse_button_style(Color("172824f0"), Color("d6bd70"), 2))
		button.add_theme_stylebox_override("pressed", _greenhouse_button_style(Color("0b1516f5"), Color("a38a4d"), 1))
		button.add_theme_stylebox_override("disabled", _greenhouse_button_style(Color("111719d0"), Color("4c4b3e"), 1))
	else:
		button.add_theme_stylebox_override("normal", _greenhouse_button_style(Color("101a1bc8"), Color("514c39"), 1))
		button.add_theme_stylebox_override("hover", _greenhouse_button_style(Color("162421e8"), Color("aa9154"), 2))
		button.add_theme_stylebox_override("pressed", _greenhouse_button_style(Color("0b1415ee"), Color("75633f"), 1))
		button.add_theme_stylebox_override("disabled", _greenhouse_button_style(Color("111719b8"), Color("403f38"), 1))
	button.pressed.connect(callback)
	return button

func _home_primary_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _home_secondary_style(fill: Color, border: Color, bottom_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_bottom = bottom_width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _greenhouse_record_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1518ee")
	style.border_color = Color("756846")
	style.border_width_left = 2
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	return style

func _greenhouse_button_style(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _greenhouse_divider_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6f6447")
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style

func _menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 62)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color("f8e7b0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _greenhouse_button_style(Color("101a1bd8"), Color("514c39"), 1))
	button.add_theme_stylebox_override("hover", _greenhouse_button_style(Color("1b2d28ee"), Color("c7a954"), 2))
	button.add_theme_stylebox_override("pressed", _greenhouse_button_style(Color("0a1315f2"), Color("8f7744"), 1))
	button.add_theme_stylebox_override("disabled", _greenhouse_button_style(Color("111719c0"), Color("403f38"), 1))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.pressed.connect(callback)
	return button

func _back_button(callback: Callable) -> Button:
	var button := _menu_button("返回", callback)
	button.custom_minimum_size = Vector2(190, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return button

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer

func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style

func _texture_style(path: String, left: float, top: float, right: float, bottom: float, content_margin := 10.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = ArtLibrary.load_texture(path)
	style.set_texture_margin(SIDE_LEFT, left)
	style.set_texture_margin(SIDE_TOP, top)
	style.set_texture_margin(SIDE_RIGHT, right)
	style.set_texture_margin(SIDE_BOTTOM, bottom)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: style.set_content_margin(side, content_margin)
	return style

func _journal_style() -> StyleBoxFlat:
	var style := _panel_style(Color("0b1315f2"), Color("7e6b3d"), 1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 2
	style.border_width_left = 2
	style.border_width_right = 1
	style.shadow_color = Color(0, 0, 0, 0.62)
	style.shadow_size = 18
	return style

func _seal_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("5b211de8")
	style.border_color = Color("9f5442")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style

func _chapter_rule_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("8e7848")
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style

func _compact_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("fff0b0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.expand_margin_left = 2
	style.expand_margin_right = 2
	style.expand_margin_top = 2
	style.expand_margin_bottom = 2
	return style
