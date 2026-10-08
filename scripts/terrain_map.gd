extends Node2D

const BattlefieldSpec = preload("res://scripts/battlefield_spec.gd")
const GroundTileSet = preload("res://assets/tilesets/BattlefieldTileSet.tres")
const MacroDetailTileSet = preload("res://assets/tilesets/BattlefieldMacroDetailTileSet.tres")
const AcidOverlayTileSet = preload("res://assets/tilesets/BattlefieldAcidOverlayTileSet.tres")
const ContinuousGroundShader = preload("res://assets/tilesets/continuous_ground.gdshader")
const ContinuousGroundTexture = preload("res://assets/tilesets/battlefield_continuous_ground.png")

signal preview_changed(cells: Array[Vector2i], terrain: String, seconds_left: float)
signal terrain_changed(cells: Array[Vector2i], terrain: String)

const GRID_SIZE := BattlefieldSpec.GRID_SIZE
const CELL_SIZE := BattlefieldSpec.CELL_SIZE
const WORLD_RECT := BattlefieldSpec.WORLD_RECT
const SWAMP_MOVEMENT_MULTIPLIER := 0.55

var initial_cells: Dictionary = {}
var current_cells: Dictionary = {}
var preview_cells: Array[Vector2i] = []
var preview_terrain := ""
var preview_seconds_left := 0.0
var ground_tile_map: TileMapLayer
var macro_detail_tile_map: TileMapLayer
var overlay_tile_map: TileMapLayer
var acid_overlay_tile_map: TileMapLayer
var acid_preview_tile_map: TileMapLayer
var _effect_clock := 0.0
var _redraw_elapsed := 0.0
var contact_shadows: Node2D

func _init() -> void:
	contact_shadows = preload("res://scripts/ground_contact_shadows.gd").new()
	contact_shadows.name = "GroundContactShadows"
	contact_shadows.z_index = 5
	add_child(contact_shadows)
	ground_tile_map = TileMapLayer.new()
	ground_tile_map.name = "GroundTileMap"
	ground_tile_map.tile_set = GroundTileSet
	ground_tile_map.scale = Vector2.ONE * (BattlefieldSpec.CELL_SIZE / 160.0)
	ground_tile_map.z_index = 0
	var surface_material := ShaderMaterial.new()
	surface_material.shader = ContinuousGroundShader
	surface_material.set_shader_parameter("surface_texture", ContinuousGroundTexture)
	surface_material.set_shader_parameter("world_size", WORLD_RECT.size)
	ground_tile_map.material = surface_material
	add_child(ground_tile_map)
	macro_detail_tile_map = TileMapLayer.new()
	macro_detail_tile_map.name = "GroundMacroDetailTileMap"
	macro_detail_tile_map.tile_set = MacroDetailTileSet
	macro_detail_tile_map.scale = ground_tile_map.scale
	macro_detail_tile_map.z_index = 1
	add_child(macro_detail_tile_map)
	overlay_tile_map = TileMapLayer.new()
	overlay_tile_map.name = "TerrainOverlayTileMap"
	overlay_tile_map.tile_set = GroundTileSet
	overlay_tile_map.scale = ground_tile_map.scale
	overlay_tile_map.z_index = 2
	add_child(overlay_tile_map)
	acid_overlay_tile_map = TileMapLayer.new()
	acid_overlay_tile_map.name = "AcidOverlayTileMap"
	acid_overlay_tile_map.tile_set = AcidOverlayTileSet
	acid_overlay_tile_map.scale = ground_tile_map.scale
	acid_overlay_tile_map.z_index = 3
	acid_overlay_tile_map.modulate = Color(1.0, 1.0, 1.0, 0.70)
	add_child(acid_overlay_tile_map)
	acid_preview_tile_map = TileMapLayer.new()
	acid_preview_tile_map.name = "AcidPreviewTileMap"
	acid_preview_tile_map.tile_set = AcidOverlayTileSet
	acid_preview_tile_map.scale = ground_tile_map.scale
	acid_preview_tile_map.z_index = 4
	acid_preview_tile_map.modulate = Color(1.0, 1.0, 1.0, 0.35)
	add_child(acid_preview_tile_map)
	_build_initial_layout()
	_build_ground_visuals()
	_build_macro_detail_visuals()

func _ready() -> void:
	# Keep the modular terrain above any legacy background node that may still
	# exist in an older scene instance. Actor/effect nodes are added at higher
	# z values by the battle scene, so this does not cover gameplay objects.
	z_index = -10
	ground_tile_map.material.set_shader_parameter("world_origin", global_position)
	set_process(true)
	queue_redraw()

func update_lighting_shadows(actors: Array[Node], state: Dictionary) -> void:
	contact_shadows.update_bodies(actors, state)

func _process(delta: float) -> void:
	var has_swamp := acid_overlay_tile_map.get_used_rect().size != Vector2i.ZERO
	if preview_cells.is_empty() and not has_swamp:
		return
	_effect_clock = fposmod(_effect_clock + delta, 1.0)
	_redraw_elapsed += delta
	if _redraw_elapsed >= 1.0 / 30.0:
		_redraw_elapsed = fmod(_redraw_elapsed, 1.0 / 30.0)
		queue_redraw()

func _build_initial_layout() -> void:
	initial_cells.clear()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			initial_cells[cell] = "soil"
	current_cells = initial_cells.duplicate(true)

func _build_ground_visuals() -> void:
	if ground_tile_map == null: return
	ground_tile_map.clear()
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			# The shader samples the same world surface across all logical cells.
			ground_tile_map.set_cell(Vector2i(x, y), 0, Vector2i.ZERO, 0)

func _build_macro_detail_visuals() -> void:
	if macro_detail_tile_map == null: return
	macro_detail_tile_map.clear()
	# Regional concrete and vegetation are baked into the continuous surface.
	# Retain the optional detail layer for future authored landmarks, without
	# scattering independently feathered islands over the connected materials.

func sync_visual_cell(cell: Vector2i, terrain: String) -> void:
	if not is_valid_cell(cell): return
	if terrain == "swamp":
		overlay_tile_map.set_cell(cell, 0, Vector2i((cell.x + cell.y) % 3, 1), 0)
	else:
		overlay_tile_map.erase_cell(cell)
		acid_overlay_tile_map.erase_cell(cell)
	_sync_acid_neighborhood(cell)

func _sync_acid_neighborhood(cell: Vector2i) -> void:
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var affected: Array[Vector2i] = [cell]
	for direction in directions: affected.append(cell + direction)
	for target in affected:
		if str(current_cells.get(target, "soil")) != "swamp": continue
		var mask := 0
		for index in range(4):
			if str(current_cells.get(target + directions[index], "soil")) != "swamp":
				mask |= 1 << index
		var variant := posmod(target.x * 3 + target.y, 4)
		acid_overlay_tile_map.set_cell(target, 1, Vector2i(variant * 4 + mask % 4, 4 + mask / 4))

func sync_visual_patch(cells: Array[Vector2i], terrain: String) -> void:
	for cell in cells: sync_visual_cell(cell, terrain)

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(world_position.x / CELL_SIZE), 0, GRID_SIZE.x - 1), clampi(floori(world_position.y / CELL_SIZE), 0, GRID_SIZE.y - 1))

func cell_to_world_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y

func get_terrain_at(world_position: Vector2) -> String:
	if not WORLD_RECT.has_point(world_position): return "void"
	return str(current_cells.get(world_to_cell(world_position), "soil"))

func is_plantable_at(world_position: Vector2) -> bool:
	return get_terrain_at(world_position) == "soil"

func get_movement_multiplier(world_position: Vector2) -> float:
	return SWAMP_MOVEMENT_MULTIPLIER if get_terrain_at(world_position) == "swamp" else 1.0

func preview_terrain_patch(cells: Array[Vector2i], terrain: String, duration: float) -> void:
	acid_preview_tile_map.clear()
	preview_cells = cells.duplicate()
	if terrain == "swamp":
		for cell in preview_cells:
			if is_valid_cell(cell):
				acid_preview_tile_map.set_cell(cell, 0, Vector2i(posmod(cell.x + cell.y, 4), 0))
	preview_terrain = terrain
	preview_seconds_left = maxf(0.0, duration)
	preview_changed.emit(preview_cells, preview_terrain, preview_seconds_left)
	queue_redraw()

func update_preview(seconds_left: float) -> void:
	preview_seconds_left = maxf(0.0, seconds_left)
	preview_changed.emit(preview_cells, preview_terrain, preview_seconds_left)
	queue_redraw()

func clear_preview() -> void:
	acid_preview_tile_map.clear()
	preview_cells.clear()
	preview_terrain = ""
	preview_seconds_left = 0.0
	queue_redraw()

func apply_terrain_patch(cells: Array[Vector2i], terrain: String) -> void:
	var changed: Array[Vector2i] = []
	for cell in cells:
		if not is_valid_cell(cell): continue
		current_cells[cell] = terrain
		changed.append(cell)
		sync_visual_cell(cell, terrain)
	clear_preview()
	terrain_changed.emit(changed, terrain)
	queue_redraw()

func restore_temporary_terrain() -> void:
	current_cells = initial_cells.duplicate(true)
	overlay_tile_map.clear()
	acid_overlay_tile_map.clear()
	clear_preview()
	terrain_changed.emit([], "restored")
	queue_redraw()

func get_cells_with_terrain(types: Array[String]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in current_cells:
		if str(current_cells[key]) in types: result.append(Vector2i(key))
	return result

func _draw() -> void:
	var visible_rect: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	for key in acid_overlay_tile_map.get_used_cells():
		var cell := Vector2i(key)
		var terrain := str(current_cells[key])
		var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
		if not visible_rect.intersects(rect.grow(50.0)): continue
		if terrain == "swamp":
			var pulse := 0.18 + sin(_effect_clock * TAU + float(cell.x * 13 + cell.y * 7)) * 0.04
			draw_rect(rect.grow(-3.0), Color(0.38, 0.48, 0.18, 0.34), true)
			draw_circle(rect.get_center() + Vector2(-18, 9), 17.0, Color(0.54, 0.72, 0.24, 0.24 + pulse))
			draw_circle(rect.get_center() + Vector2(22, -16), 11.0, Color(0.75, 0.82, 0.28, 0.25 + pulse))
			draw_arc(rect.get_center(), 43.0, 0.2, 2.7, 18, Color(0.72, 0.84, 0.32, 0.52), 2.0)
			# Small acid bubbles and runoff marks make the affected cells readable
			# without adding a full-screen animated overlay.
			draw_circle(rect.get_center() + Vector2(-28, -24), 3.0 + pulse * 4.0, Color(0.82, 0.92, 0.38, 0.65))
			draw_line(rect.get_center() + Vector2(30, -28), rect.get_center() + Vector2(24, 10), Color(0.68, 0.82, 0.28, 0.55), 2.0)
	if not preview_cells.is_empty():
		var pulse := 0.38 + sin(Time.get_ticks_msec() * 0.012) * 0.16
		for cell in preview_cells:
			var rect := Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE).grow(-3.0)
			if not visible_rect.intersects(rect): continue
			draw_rect(rect, Color(0.86, 0.44, 0.18, pulse), true)
			draw_rect(rect, Color("f59e45"), false, 4.0)
