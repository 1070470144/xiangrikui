extends RefCounted

const BACKGROUND_WORLD_2880 := "res://assets/backgrounds/ART_BG_GreenhouseWorld_2880.png"
const BACKGROUND_FOREGROUND := "res://assets/backgrounds/ART_FG_GreenhouseMist.png"
const MAIN_MENU_BACKGROUND := "res://assets/backgrounds/ART_BG_MainMenu_Greenhouse.png"

const MOTHER_HEALTHY := "res://assets/core/generated/mother_realism_v1/healthy.png"
const MOTHER_DAMAGED := "res://assets/core/generated/mother_realism_v1/damaged.png"
const MOTHER_CRITICAL := "res://assets/core/generated/mother_realism_v1/critical.png"

const THORN_POWERED := "res://assets/plants/ART_PLANT_ThornFlower_Powered.png"
const THORN_UNPOWERED := "res://assets/plants/ART_PLANT_ThornFlower_Unpowered.png"
const PRISM_POWERED := "res://assets/plants/ART_PLANT_PrismFlower_Powered.png"
const PRISM_UNPOWERED := "res://assets/plants/ART_PLANT_PrismFlower_Unpowered.png"

const SHADOW_MOVE := "res://assets/enemies/ART_ENEMY_ShadowBeast_Move.png"
const SHADOW_ATTACK := "res://assets/enemies/ART_ENEMY_ShadowBeast_Attack.png"
const BUG_MOVE := "res://assets/enemies/ART_ENEMY_ErosionBug_Move.png"
const BUG_ATTACK := "res://assets/enemies/ART_ENEMY_ErosionBug_Attack.png"

const NODE_HEALTHY := "res://assets/nodes/ART_NODE_LightBud_Healthy.png"
const NODE_DAMAGED := "res://assets/nodes/ART_NODE_LightBud_Damaged.png"
const NODE_BROKEN := "res://assets/nodes/ART_NODE_LightBud_Broken.png"

const PROJECTILE := "res://assets/effects/ART_VFX_PrismProjectile.png"
const SUNBURST := "res://assets/effects/ART_VFX_Sunburst_Ring.png"
const DISSOLVE := "res://assets/effects/ART_VFX_ShadowDissolve.png"

const UI_PANEL_TOP := "res://assets/ui/UI_PANEL_TopBar.png"
const UI_PANEL_ACTION := "res://assets/ui/UI_PANEL_ActionBar.png"
const UI_PANEL_RESULT := "res://assets/ui/UI_PANEL_Result.png"
const UI_BUTTON_NORMAL := "res://assets/ui/UI_BUTTON_Normal.png"
const UI_BUTTON_HOVER := "res://assets/ui/UI_BUTTON_Hover.png"
const UI_BUTTON_PRESSED := "res://assets/ui/UI_BUTTON_Pressed.png"
const UI_BUTTON_DISABLED := "res://assets/ui/UI_BUTTON_Disabled.png"
const UI_ICON_THORN := "res://assets/ui/UI_ICON_ThornFlower.png"
const UI_ICON_PRISM := "res://assets/ui/UI_ICON_PrismFlower.png"
const UI_ICON_SUNBURST := "res://assets/ui/UI_ICON_Sunburst.png"
const UI_ICON_REPAIR := "res://assets/ui/UI_ICON_Repair.png"
const UI_BAR_HEALTH := "res://assets/ui/UI_BAR_Health.png"
const UI_BAR_ENERGY := "res://assets/ui/UI_BAR_Energy.png"

const UI_GEN_PANEL_TOP := "res://assets/ui/generated/UI_Panel_Top.png"
const UI_GEN_PANEL_ACTION := "res://assets/ui/generated/UI_Panel_Action.png"
const UI_GEN_BUTTON_NORMAL := "res://assets/ui/generated/UI_Button_Normal.png"
const UI_GEN_BUTTON_HOVER := "res://assets/ui/generated/UI_Button_Hover.png"
const UI_GEN_BUTTON_PRESSED := "res://assets/ui/generated/UI_Button_Pressed.png"
const UI_GEN_BUTTON_DISABLED := "res://assets/ui/generated/UI_Button_Disabled.png"
const UI_GEN_CARD := "res://assets/ui/generated/UI_Card.png"
const UI_SCROLL_PANEL := "res://assets/ui/generated/mm_scroll_panel.png"
const UI_SCROLL_CHAPTER_RULE := "res://assets/ui/generated/mm_scroll_chapter_rule.png"
const UI_SCROLL_GARDENER_SEAL := "res://assets/ui/generated/mm_gardener_seal.png"
const UI_SCROLL_PRIMARY := "res://assets/ui/generated/mm_scroll_primary_{state}.png"
const UI_SCROLL_SECONDARY := "res://assets/ui/generated/mm_scroll_secondary_{state}.png"
const UI_GEN_BAR_HEALTH := "res://assets/ui/generated/UI_Bar_Health.png"
const UI_GEN_BAR_ENERGY := "res://assets/ui/generated/UI_Bar_Energy.png"

static var _texture_cache: Dictionary = {}

static func get_cached_texture(path: String) -> Texture2D:
	return _texture_cache.get(path)

static func load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path): return _texture_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture != null: _texture_cache[path] = texture
	return texture
