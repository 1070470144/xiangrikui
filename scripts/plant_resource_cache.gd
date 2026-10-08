extends Node

signal species_ready(species: String)
signal enemy_ready(enemy_id: String)

const Animations = preload("res://scripts/plant_animation_library.gd")
const AttackFX = preload("res://scripts/plant_attack_fx.gd")
const MonsterAnimations = preload("res://scripts/monster_animation_library.gd")
const Balance = preload("res://scripts/balance.gd")
const ArtLibrary = preload("res://scripts/art_library.gd")
const EnemyKinds := ["shadow_beast", "erosion_bug", "root_crown_colossus", "sun_devourer", "husk_ram", "spore_moth", "lantern_eater", "rot_caller", "split_shade", "shell_scarab"]
const Roster = preload("res://scripts/plant_roster.gd")
const ActorShader = preload("res://assets/tilesets/world_actor_lighting.gdshader")
var textures: Dictionary = {}
var _pending: Dictionary = {}
var _failed: Dictionary = {}
var _warm_queue: Array[Dictionary] = []
var _warming: Dictionary = {}
var _warm_frame := 0
var _viewport: SubViewport
var _sprite: Sprite2D
var _actor_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(32, 32)
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(16, 16)
	_viewport.add_child(_sprite)
	_actor_material = ShaderMaterial.new()
	_actor_material.shader = ActorShader

func request_texture(path: String) -> void:
	if textures.has(path) or _pending.has(path) or _failed.has(path): return
	# Warmup requests also count as pending until rendered.
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path, "Texture2D") != OK:
		_failed[path] = true
		return
	_pending[path] = false

func get_texture(path: String) -> Texture2D:
	return textures.get(path)

func texture_failed(path: String) -> bool:
	return _failed.has(path)

func request_loadout(ids: Array) -> void:
	for id in ids:
		var kind := Roster.DEPLOY_IDS.find(str(id))
		if kind < 0: continue
		request_texture(Roster.texture_path(kind))
		Animations.request_species(Roster.FLOWER_IDS[kind])
	AttackFX.request_style("frost")
	AttackFX.request_style("pollen")

func request_night(night: int) -> void:
	if night < 1 or night > Balance.NIGHT_CONFIGS.size(): return
	var wave: Dictionary = Balance.NIGHT_CONFIGS[night - 1]
	for index in wave.counts:
		if int(wave.counts[index]) > 0: MonsterAnimations.request_species(EnemyKinds[int(index)])
	# Nonanimated enemies use these shared static attack/movement sprites.
	for path in [ArtLibrary.SHADOW_MOVE, ArtLibrary.SHADOW_ATTACK, ArtLibrary.BUG_MOVE, ArtLibrary.BUG_ATTACK, ArtLibrary.SUNBURST]: request_texture(path)

func request_enemy(enemy_id: String) -> void:
	MonsterAnimations.request_species(enemy_id)

func _process(_delta: float) -> void:
	for path in _pending.keys():
		if bool(_pending[path]): continue
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var texture := ResourceLoader.load_threaded_get(path) as Texture2D
			_pending[path] = true
			if texture == null: _failed[path] = true; _pending.erase(path)
			else: _warm_queue.append({"path": path, "texture": texture})
			break
		elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			_pending.erase(path)
			_failed[path] = true
	if not _warming.is_empty() and Engine.get_process_frames() >= _warm_frame + 2:
		textures[_warming.path] = _warming.texture
		_pending.erase(_warming.path)
		_warming = {}
		_sprite.texture = null
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _warming.is_empty() and not _warm_queue.is_empty():
		_warming = _warm_queue.pop_front()
		_sprite.texture = _warming.texture
		_sprite.material = _actor_material if str(_warming.path).begins_with("res://assets/plants/") or str(_warming.path).begins_with("res://assets/enemies/") else null
		_sprite.scale = Vector2.ONE * (30.0 / maxf(_sprite.texture.get_width(), _sprite.texture.get_height()))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_warm_frame = Engine.get_process_frames()
	var deadline := Time.get_ticks_usec() + 2000
	var assembled := Animations.advance_loading(self)
	MonsterAnimations.advance_loading(self, 16 - assembled, deadline)
	AttackFX.advance_loading(self)
