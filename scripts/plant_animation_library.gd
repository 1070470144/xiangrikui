extends RefCounted

const ROOT := "res://assets/plants/animations/"
static var _cache: Dictionary = {}
static var _offsets: Dictionary = {}
static var _display_scales: Dictionary = {}
static var _jobs: Dictionary = {}
static var _failed: Dictionary = {}

static func service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("PlantResources") if tree != null else null

static func get_offset(species: String, state: String) -> Vector2:
	return _offsets.get(species, {}).get(state, Vector2.ZERO)

static func get_display_scale(species: String, state: String) -> float:
	return float(_display_scales.get(species, {}).get(state, 1.0))

static func get_frames(species: String) -> SpriteFrames:
	return get_cached_frames(species)

static func get_cached_frames(species: String) -> SpriteFrames:
	return _cache.get(species)

static func request_species(species: String) -> void:
	if _cache.has(species) or _jobs.has(species) or _failed.has(species): return
	var loader := service()
	if loader == null: return
	var path := ROOT + species + "/atlas_manifest.json"
	if not FileAccess.file_exists(path): _failed[species] = true; return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or not manifest.get("states", {}).has("idle"):
		_failed[species] = true
		return
	var frames := SpriteFrames.new(); frames.remove_animation("default")
	var offsets: Dictionary = {}
	var display_scales: Dictionary = {}
	var records: Array = []
	for state in ["idle", "attack", "death", "revive"]:
		if not manifest.get("states",{}).has(state): continue
		var spec: Dictionary = manifest.states[state]
		display_scales[state] = float(spec.get("display_scale", 1.0))
		var draw_offset: Array = spec.get("draw_offset", [0, 0])
		offsets[state] = Vector2(float(draw_offset[0]), float(draw_offset[1]))
		frames.add_animation(state)
		frames.set_animation_speed(state,float(spec.fps))
		frames.set_animation_loop(state,bool(spec.loop))
		for record in spec.regions:
			var texture_path := ROOT + species + "/" + str(record.page)
			loader.request_texture(texture_path)
			records.append({"state": state, "path": texture_path, "region": record.region})
	_jobs[species] = {"frames": frames, "records": records, "cursor": 0, "offsets": offsets, "scales": display_scales}

static func advance_loading(loader: Node) -> int:
	var started := Time.get_ticks_usec()
	var count := 0
	for species in _jobs.keys():
		var job: Dictionary = _jobs[species]
		while int(job.cursor) < job.records.size():
			if count >= 16 or Time.get_ticks_usec() - started >= 2000: return count
			var record: Dictionary = job.records[int(job.cursor)]
			if loader.texture_failed(record.path):
				_failed[species] = true
				_jobs.erase(species)
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
		if _jobs.has(species) and int(job.cursor) == job.records.size():
			_cache[species] = job.frames
			_offsets[species] = job.offsets
			_display_scales[species] = job.scales
			_jobs.erase(species)
			loader.species_ready.emit(species)
	return count
