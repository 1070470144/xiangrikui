extends Node2D

## Video-derived botanical effects. Combat remains owned by the plant.
const ASSET_ROOT := "res://assets/effects/plants/"
static var _assets: Dictionary = {}
static var _pending_assets: Dictionary = {}
static var _failed_styles: Dictionary = {}

var _sprite: Sprite2D
var _elapsed := 0.0
var _duration := 0.72
var _frame_count := 0

func _ready() -> void:
	z_as_relative = false
	z_index = 17
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	hide()
	set_process(false)

static func _load_asset(style: String) -> Dictionary:
	return _assets.get(style, {})

static func request_style(style: String) -> void:
	if style == "vine" or _assets.has(style) or _pending_assets.has(style) or _failed_styles.has(style): return
	var tree := Engine.get_main_loop() as SceneTree
	var loader := tree.root.get_node_or_null("PlantResources") if tree != null else null
	if loader == null: return
	var meta_path := ASSET_ROOT + style + ".strip.json"
	var runtime_path := ASSET_ROOT + style + ".runtime.json"
	var texture_path := ASSET_ROOT + style + ".atlas.png"
	if not FileAccess.file_exists(meta_path) or not FileAccess.file_exists(runtime_path): _failed_styles[style] = true; return
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	var runtime: Variant = JSON.parse_string(FileAccess.get_file_as_string(runtime_path))
	if not meta is Dictionary or not runtime is Dictionary: _failed_styles[style] = true; return
	loader.request_texture(texture_path)
	var asset := {"path": texture_path, "frames": int(meta.frames), "height": float(meta.h),
		"columns": int(runtime.columns), "rows": int(runtime.rows),
		"anchor": Vector2(float(runtime.anchor[0]), float(runtime.anchor[1])),
		"reach": Vector2(float(runtime.reach_vector[0]), float(runtime.reach_vector[1])),
		"duration": float(runtime.duration)}
	_pending_assets[style] = asset

static func advance_loading(loader: Node) -> void:
	for style in _pending_assets.keys():
		var asset: Dictionary = _pending_assets[style]
		if loader.texture_failed(asset.path):
			_failed_styles[style] = true
			_pending_assets.erase(style)
			continue
		var texture: Texture2D = loader.get_texture(asset.path)
		if texture == null: continue
		asset.texture = texture
		_assets[style] = asset
		_pending_assets.erase(style)

func trigger(target: Vector2, effect_style: String = "vine") -> void:
	if effect_style == "vine": return
	var asset := _load_asset(effect_style)
	if asset.is_empty() or _sprite == null: return
	_elapsed = 0.0
	_duration = asset.duration
	_frame_count = asset.frames
	_sprite.frame = 0
	_sprite.texture = asset.texture
	_sprite.hframes = asset.columns
	_sprite.vframes = asset.rows
	_sprite.position = -asset.anchor
	rotation = 0.0
	position = Vector2(0, -20)
	position += target
	scale = Vector2.ONE * (86.0 / float(asset.height))
	show()
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		hide()
		set_process(false)
		return
	_sprite.frame = mini(_frame_count - 1, int(_elapsed / _duration * _frame_count))
