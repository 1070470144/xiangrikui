extends RefCounted

const REQUIRED := {
	"res://assets/backgrounds/ART_FG_GreenhouseMist.png": Vector2i(1152, 648),
	"res://assets/core/ART_CORE_MotherFlower_Healthy.png": Vector2i(256, 256),
	"res://assets/core/ART_CORE_MotherFlower_Damaged.png": Vector2i(256, 256),
	"res://assets/core/ART_CORE_MotherFlower_Critical.png": Vector2i(256, 256),
	"res://assets/plants/ART_PLANT_ThornFlower_Powered.png": Vector2i(160, 160),
	"res://assets/plants/ART_PLANT_ThornFlower_Unpowered.png": Vector2i(160, 160),
	"res://assets/plants/ART_PLANT_PrismFlower_Powered.png": Vector2i(160, 160),
	"res://assets/plants/ART_PLANT_PrismFlower_Unpowered.png": Vector2i(160, 160),
	"res://assets/enemies/ART_ENEMY_ShadowBeast_Move.png": Vector2i(192, 160),
	"res://assets/enemies/ART_ENEMY_ShadowBeast_Attack.png": Vector2i(192, 160),
	"res://assets/enemies/ART_ENEMY_ErosionBug_Move.png": Vector2i(160, 128),
	"res://assets/enemies/ART_ENEMY_ErosionBug_Attack.png": Vector2i(160, 128),
	"res://assets/nodes/ART_NODE_LightBud_Healthy.png": Vector2i(96, 96),
	"res://assets/nodes/ART_NODE_LightBud_Damaged.png": Vector2i(96, 96),
	"res://assets/nodes/ART_NODE_LightBud_Broken.png": Vector2i(96, 96),
	"res://assets/effects/ART_VFX_PrismProjectile.png": Vector2i(64, 32),
	"res://assets/effects/ART_VFX_Sunburst_Ring.png": Vector2i(512, 512),
	"res://assets/effects/ART_VFX_ShadowDissolve.png": Vector2i(192, 192),
	"res://assets/ui/UI_PANEL_TopBar.png": Vector2i(776, 106),
	"res://assets/ui/UI_PANEL_ActionBar.png": Vector2i(776, 89),
	"res://assets/ui/UI_PANEL_Result.png": Vector2i(512, 256),
	"res://assets/ui/UI_BUTTON_Normal.png": Vector2i(173, 59),
	"res://assets/ui/UI_BUTTON_Hover.png": Vector2i(175, 59),
	"res://assets/ui/UI_BUTTON_Pressed.png": Vector2i(173, 59),
	"res://assets/ui/UI_BUTTON_Disabled.png": Vector2i(174, 59),
	"res://assets/ui/UI_ICON_ThornFlower.png": Vector2i(128, 128),
	"res://assets/ui/UI_ICON_PrismFlower.png": Vector2i(128, 128),
	"res://assets/ui/UI_ICON_Sunburst.png": Vector2i(128, 128),
	"res://assets/ui/UI_ICON_Repair.png": Vector2i(128, 128),
	"res://assets/ui/UI_BAR_Health.png": Vector2i(256, 32),
	"res://assets/ui/UI_BAR_Energy.png": Vector2i(256, 32),
}

const UI_PREVIEW := "res://art_source/ui_crop_preview.png"

var failures: Array[String] = []

func run() -> Array[String]:
	var art_script := load("res://scripts/art_library.gd") as Script
	var constants := art_script.get_script_constant_map() if art_script != null else {}
	if not constants.has("MAIN_MENU_BACKGROUND"):
		failures.append("art library must expose the generated main menu background")
	elif not ResourceLoader.exists(str(constants["MAIN_MENU_BACKGROUND"])):
		failures.append("generated main menu background must exist")
	for path in REQUIRED:
		if not ResourceLoader.exists(path):
			failures.append("formal art missing: %s" % path)
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			failures.append("formal art failed to load: %s" % path)
			continue
		if texture.get_size() != Vector2(REQUIRED[path]):
			failures.append("formal art size mismatch: %s" % path)
	if not FileAccess.file_exists(UI_PREVIEW):
		failures.append("UI crop preview missing: %s" % UI_PREVIEW)
	else:
		var preview := Image.load_from_file(UI_PREVIEW)
		if preview == null or preview.get_size() != Vector2i(1200, 760):
			failures.append("UI crop preview size mismatch: %s" % UI_PREVIEW)
	return failures
