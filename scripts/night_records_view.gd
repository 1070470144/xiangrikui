extends Control

const Visual = preload("res://scripts/deck_builder_style.gd")
const ART := "res://assets/ui/generated/night_records/"
const NOTES := [
	["平静夜色", "初次守夜，建立温室的第一道防线。", "先连接光脉，再让近战与远程植物覆盖入口。"],
	["多向进攻", "敌人从多个方向逼近，考验防线的覆盖。", "留意外围节点，避免所有输出集中在同一条路径。"],
	["酸雨天气", "腐蚀性降雨威胁植物与光脉，恢复能力变得关键。", "准备甘露与修复类卡牌，及时照顾受损的供光节点。"],
	["雷雨天气", "雷雨笼罩温室，天气干扰与敌人的进攻同时到来。", "分散防线，保留应急供光和恢复资源。"],
	["首领 · 浓雾", "根冠巨像在浓雾中现身，首领抗性考验持续输出。", "保持稳定供光；用减速与根墙争取输出时间。"],
	["补给之夜", "经历重压后迎来喘息与补给，为最后的守夜做准备。", "补齐关键植物、修复节点，保留应对首领的卡牌。"],
	["终夜 · 日蚀", "太阳吞噬者降临，温室迎来七夜旅程的最后考验。", "保护母花与光脉，集中输出并随时准备恢复防线。"],
]
var progress := 0
var entries: Array = []
var selected := 1
var chapters: Array[Button] = []
var hero: TextureRect
var heading: Label
var status: Label
var subtitle: Label
var description: Label
var advice: Label

func setup(records: Array, profile: Dictionary, back: Callable) -> void:
	entries = records
	progress = clampi(int(profile.get("level_progress", 0)), 0, 7)
	selected = mini(progress + 1, 7)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Visual.theme()
	var background := _art("background", Vector2.ZERO, Vector2(1152, 648)); add_child(background)
	var shade := ColorRect.new(); shade.color = Color(0.015, 0.03, 0.03, 0.28); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(shade)
	var return_button := Button.new(); return_button.text = "返回"; return_button.position = Vector2(38, 25); return_button.size = Vector2(96, 42); return_button.pressed.connect(back); add_child(return_button)
	var title := _label("七夜记录", 30, Visual.GOLD); title.position = Vector2(155, 24); add_child(title)
	var summary := _label("%s  ·  已守住 %d / 7 夜  ·  %d 分钟" % [str(profile.get("player_name", "温室守护者")), progress, int(profile.get("play_time_minutes", 0))], 14, Visual.PAPER); summary.position = Vector2(630, 38); summary.size.x = 484; summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; add_child(summary)
	var panel := _art("journal_panel", Vector2(28, 86), Vector2(1096, 530)); add_child(panel)
	var row := HBoxContainer.new(); row.name = "NightChapters"; row.position = Vector2(54, 108); row.size = Vector2(1044, 188); row.add_theme_constant_override("separation", 10); add_child(row)
	for entry in entries:
		var number := int(entry.number)
		var button := Button.new(); button.name = "Night%d" % number; button.custom_minimum_size = Vector2(140, 184); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.clip_contents = true; button.tooltip_text = "查看第 %d 夜档案" % number
		button.pressed.connect(select_night.bind(number)); row.add_child(button); chapters.append(button)
		var image := _art("night_%d" % number, Vector2(5, 5), Vector2(130, 101)); image.name = "ChapterArt"; button.add_child(image)
		var number_label := _label("第 %d 夜" % number, 12, Visual.MUTED); number_label.position = Vector2(8, 111); number_label.size.x = 124; number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; button.add_child(number_label)
		var name_label := _label(str(entry.name), 17, Visual.PAPER); name_label.position = Vector2(6, 129); name_label.size.x = 128; name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; button.add_child(name_label)
		var state := _label("已守住" if number <= progress else ("下一夜" if number == progress + 1 else "未完成"), 11, Visual.GOLD if number <= progress + 1 else Visual.MUTED); state.position = Vector2(8, 157); state.size.x = 124; state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; button.add_child(state)
	hero = _art("night_%d" % selected, Vector2(54, 322), Vector2(390, 258)); hero.name = "NightHero"; add_child(hero)
	heading = _label("", 28, Visual.GOLD); heading.name = "NightHeading"; heading.position = Vector2(478, 326); add_child(heading)
	status = _label("", 13, Visual.MUTED); status.position = Vector2(932, 340); status.size.x = 154; status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; add_child(status)
	subtitle = _label("", 14, Visual.GOLD); subtitle.position = Vector2(479, 374); add_child(subtitle)
	description = _label("", 19, Visual.PAPER); description.position = Vector2(479, 405); description.size = Vector2(599, 66); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(description)
	var advice_title := _label("守夜建议", 13, Visual.GOLD); advice_title.position = Vector2(479, 487); add_child(advice_title)
	advice = _label("", 16, Visual.MUTED); advice.position = Vector2(479, 513); advice.size = Vector2(599, 56); advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(advice)
	select_night(selected)

func select_night(number: int) -> void:
	selected = clampi(number, 1, 7)
	hero.texture = load(ART + "night_%d.png" % selected)
	heading.text = "第 %d 夜 · %s" % [selected, entries[selected - 1].name]
	status.text = "已守住" if selected <= progress else ("下一次守夜" if selected == progress + 1 else "尚未完成")
	subtitle.text = NOTES[selected - 1][0]
	description.text = NOTES[selected - 1][1]
	advice.text = NOTES[selected - 1][2]
	for index in chapters.size():
		var button := chapters[index]
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := Visual.panel(Color("132422"), Visual.GOLD if index + 1 == selected else Color("52615b"), 4)
			if state == "hover": style.border_color = Visual.GOLD; style.bg_color = Color("263b30")
			button.add_theme_stylebox_override(state, style)
		button.get_node("ChapterArt").modulate = Color.WHITE if index + 1 <= progress + 1 or index + 1 == selected else Color(0.58, 0.66, 0.65)

func _label(value: String, font_size: int, tint: Color) -> Label:
	var node := Label.new(); node.text = value; node.add_theme_font_size_override("font_size", font_size); node.modulate = tint; node.mouse_filter = Control.MOUSE_FILTER_IGNORE; return node

func _art(asset: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var image := TextureRect.new(); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.texture = load(ART + asset + ".png"); image.position = pos; image.size = dimensions; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.clip_contents = true; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; return image
