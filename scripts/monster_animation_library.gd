extends RefCounted

const ROOT := "res://assets/enemies/animations/"
const ANIMATED_IDS := ["shadow_beast", "erosion_bug", "husk_ram", "spore_moth", "shell_scarab", "root_crown_colossus", "sun_devourer"]
static var _cache: Dictionary = {}
static var _jobs: Dictionary = {}
static var _failed: Dictionary = {}

static func get_frames(enemy_id: String) -> SpriteFrames:
	return _cache.get(enemy_id)

static func request_species(enemy_id: String) -> void:
	if _cache.has(enemy_id) or _jobs.has(enemy_id) or _failed.has(enemy_id): return
	if enemy_id not in ANIMATED_IDS: _failed[enemy_id] = true; return
	var tree := Engine.get_main_loop() as SceneTree
	var loader := tree.root.get_node_or_null("PlantResources") if tree != null else null
	if loader == null: return
	var path := ROOT + enemy_id + "/atlas_manifest.json"
	if not FileAccess.file_exists(path): _failed[enemy_id] = true; return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary: _failed[enemy_id] = true; return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.set_meta("runtime", manifest.get("runtime", {}))
	var records: Array = []
	var states: Dictionary = manifest.get("states", {})
	var sample := enemy_id == "root_crown_colossus" and bool(manifest.get("review_sample", false))
	for required in (["idle", "slam"] if sample else ["walk", "attack", "spawn", "death"]):
		if not states.has(required): _failed[enemy_id] = true; return
	for state in states:
		if state not in ["idle", "walk", "attack", "spawn", "death", "slam", "summon", "exposed", "enraged"]: continue
		var spec: Dictionary = manifest.states[state]
		if spec.get("regions", []).is_empty() or float(spec.get("fps", 0)) <= 0.0: _failed[enemy_id] = true; return
		frames.set_meta(state + "_layout", spec)
		frames.add_animation(state)
		frames.set_animation_speed(state, float(spec.fps))
		frames.set_animation_loop(state, bool(spec.loop))
		for record in spec.regions:
			var texture_path := ROOT + enemy_id + "/" + str(record.page)
			loader.request_texture(texture_path)
			records.append({"state": state, "path": texture_path, "region": record.region})
	_jobs[enemy_id] = {"frames": frames, "records": records, "cursor": 0}

static func advance_loading(loader: Node, max_frames: int, deadline: int) -> void:
	var count := 0
	for enemy_id in _jobs.keys():
		var job: Dictionary = _jobs[enemy_id]
		while int(job.cursor) < job.records.size():
			if count >= max_frames or Time.get_ticks_usec() >= deadline: return
			var record: Dictionary = job.records[int(job.cursor)]
			if loader.texture_failed(record.path):
				_failed[enemy_id] = true
				_jobs.erase(enemy_id)
				break
			var texture: Texture2D = loader.get_texture(record.path)
			if texture == null: break
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			var rect: Array = record.region
			atlas.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
			atlas.filter_clip = true
			job.frames.add_frame(record.state, atlas)
			job.cursor = int(job.cursor) + 1
			count += 1
		if _jobs.has(enemy_id) and int(job.cursor) == job.records.size():
			_cache[enemy_id] = job.frames
			_jobs.erase(enemy_id)
			loader.enemy_ready.emit(enemy_id)

static func manifest_states(enemy_id: String) -> Array[String]:
	var path := ROOT + enemy_id + "/manifest.json"
	if not FileAccess.file_exists(path): return []
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary: return []
	var result: Array[String] = []
	for key in manifest.get("animation", {}).get("rows", {}): result.append(str(key))
	result.sort()
	return result
