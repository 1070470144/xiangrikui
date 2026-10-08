extends RefCounted

var failures: Array[String] = []

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	expect(ResourceLoader.exists("res://assets/tilesets/battlefield_ground_ruins_spritegen.png"), "battlefield ruins ground tileset texture must exist")
	expect(ResourceLoader.exists("res://assets/tilesets/BattlefieldTileSet.tres"), "battlefield TileSet resource must exist")
	expect(ResourceLoader.exists("res://assets/tilesets/battlefield_macro_ruins_spritegen.png"), "macro ruins detail texture must exist")
	expect(ResourceLoader.exists("res://assets/tilesets/BattlefieldMacroDetailTileSet.tres"), "macro detail TileSet resource must exist")
	var ground_image := load("res://assets/tilesets/battlefield_ground_ruins_spritegen.png") as Texture2D
	var macro_image := load("res://assets/tilesets/battlefield_macro_ruins_spritegen.png") as Texture2D
	expect(ground_image != null and ground_image.get_size() == Vector2(1280, 320), "ruins ground atlas must preserve 160 pixel tile layout")
	expect(macro_image != null and macro_image.get_size() == Vector2(7680, 640), "ruins macro atlas must contain twelve 640 pixel material patches")
	expect(ResourceLoader.exists("res://assets/tilesets/battlefield_acid_overlay_tileset.png"), "acid overlay atlas texture must exist")
	expect(ResourceLoader.exists("res://assets/tilesets/BattlefieldAcidOverlayTileSet.tres"), "acid overlay TileSet resource must exist")
	var acid_image := load("res://assets/tilesets/battlefield_acid_overlay_tileset.png") as Texture2D
	expect(acid_image != null and acid_image.get_size() == Vector2(640, 640), "acid atlas must contain four rows of 160 pixel cells")
	var terrain_script := ResourceLoader.load("res://scripts/terrain_map.gd", "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if terrain_script == null or not terrain_script.can_instantiate(): return ["terrain map script must compile"]
	var terrain: Node = terrain_script.new()
	expect(terrain.has_method("sync_visual_cell"), "terrain map must expose visual cell synchronization")
	expect(terrain.has_method("sync_visual_patch"), "terrain map must expose visual patch synchronization")
	if not terrain.has_method("sync_visual_cell") or not terrain.has_method("sync_visual_patch"):
		terrain.free()
		return failures
	expect(terrain.ground_tile_map != null, "terrain map must own a ground TileMapLayer")
	expect(terrain.macro_detail_tile_map != null, "terrain map must own a macro detail TileMapLayer")
	expect(terrain.overlay_tile_map != null, "terrain map must own a terrain overlay TileMapLayer")
	expect(terrain.acid_overlay_tile_map != null, "terrain map must own an acid overlay TileMapLayer")
	expect(terrain.ground_tile_map.tile_set.tile_size == Vector2i(160, 160), "TileSet must use full 160 pixel tile regions")
	expect(terrain.ground_tile_map.scale == Vector2(0.25, 0.25), "tile layer must display 160 pixel tiles at 40 world units")
	expect(terrain.overlay_tile_map.scale == Vector2(0.25, 0.25), "overlay tile layer must align with ground cells")
	expect(terrain.ground_tile_map.get_used_cells().size() == 72 * 72, "ground TileMapLayer must cover the full 72 by 72 grid")
	expect(terrain.macro_detail_tile_map.tile_set.tile_size == Vector2i(640, 640), "macro details must span four logical cells per tile")
	expect(terrain.macro_detail_tile_map.get_used_cells().is_empty(), "normal terrain must not scatter isolated material islands")
	var surface_material := terrain.ground_tile_map.material as ShaderMaterial
	expect(surface_material != null, "ground cells must share a continuous surface material")
	if surface_material != null:
		var surface := surface_material.get_shader_parameter("surface_texture") as Texture2D
		expect(surface != null and surface.get_size() == Vector2(4096, 4096), "continuous ground must cover the complete world at high resolution")
		expect(surface_material.get_shader_parameter("world_size") == Vector2(2880, 2880), "surface coordinates must span the logical battlefield")
	var cell := Vector2i(8, 9)
	var cells: Array[Vector2i] = [cell]
	terrain.preview_terrain_patch(cells, "swamp", 3.0)
	expect(terrain.acid_preview_tile_map.get_cell_atlas_coords(cell).y == 0, "warning must use wet ground row")
	expect(terrain.get_terrain_at(terrain.cell_to_world_center(cell)) == "soil", "warning must preserve soil behavior")
	terrain.apply_terrain_patch(cells, "swamp")
	expect(terrain.acid_preview_tile_map.get_used_cells().is_empty(), "applying acid must clear warning tiles")
	expect(terrain.get_terrain_at(terrain.cell_to_world_center(cell)) == "swamp", "swamp patch must update logical terrain")
	expect(terrain.overlay_tile_map.get_cell_source_id(cell) >= 0, "swamp patch must update overlay TileMapLayer")
	expect(terrain.overlay_tile_map.get_cell_atlas_coords(cell).y == 1, "swamp patch must use the corrosive overlay row")
	expect(terrain.acid_overlay_tile_map.get_cell_source_id(cell) >= 0, "swamp patch must update acid overlay TileMapLayer")
	expect(terrain.acid_overlay_tile_map.get_cell_atlas_coords(cell).y >= 4, "active acid must use joined corrosion rows")
	expect(terrain.acid_overlay_tile_map.get_cell_source_id(cell + Vector2i.RIGHT) == -1, "acid must not affect neighboring soil")
	var adjacent: Array[Vector2i] = [cell + Vector2i.RIGHT]
	terrain.apply_terrain_patch(adjacent, "swamp")
	var joined_coords: Vector2i = terrain.acid_overlay_tile_map.get_cell_atlas_coords(cell)
	var edge_mask := (joined_coords.y - 4) * 4 + joined_coords.x % 4
	expect((edge_mask & 2) == 0, "adjacent acid cells must not fade their shared edge")
	terrain.restore_temporary_terrain()
	expect(terrain.overlay_tile_map.get_cell_source_id(cell) == -1, "terrain restore must clear swamp overlay")
	expect(terrain.acid_overlay_tile_map.get_cell_source_id(cell) == -1, "terrain restore must clear acid overlay")
	expect(terrain.acid_preview_tile_map.get_used_cells().is_empty(), "terrain restore must clear warning tiles")
	expect(terrain.acid_overlay_tile_map.get_used_cells().is_empty(), "restore must clear all joined corrosion tiles")
	terrain.free()
	return failures
