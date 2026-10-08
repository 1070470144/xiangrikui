# Modular ruins terrain

## Continuous ground update (2026-10-04)

The current normal battlefield samples one static 4096x4096 surface in world coordinates through `assets/tilesets/continuous_ground.gdshader`. TileMap quadrants therefore share the same image rather than independently repeating a small soil tile. The 72x72 logical ground TileMap, planting checks, movement multipliers and weather overlays remain independent of this visual surface.

Composition follows the broad open ground and concentrated environmental dressing visible in the live DYSMANTLE Steam gallery: https://store.steampowered.com/app/846770/DYSMANTLE/ . No reference artwork was copied or uploaded. A connected weathered concrete apron and old route cross the map; vegetation grows along two broad perimeter banks. The mother flower stands in a quiet soil clearing. The old randomly scattered macro islands and procedural short cracks, stone circles and grass strokes are removed from normal rendering.

Rebuild the current surface with `scripts/build_continuous_ground.py`, using a Python environment with Pillow and NumPy. Source artwork and the layout preview live in `output/imagegen/tilesets/`; runtime texture is `assets/tilesets/battlefield_continuous_ground.png`. Its import enables mipmaps for distant camera views. The surface is baked offline and the runtime shader samples one texture per fragment; there is no per-frame texture generation. GPU memory for the uncompressed 4096 square plus mipmaps is approximately 85 MiB; frame rate has not been benchmarked.

The quiet soil source was generated through sprite-gen's explicit OpenAI API provider, model `gpt-image-2`, high quality, on the user-selected `https://newapi.oairegbox.cc/v1` gateway. Credentials were supplied only to the child process environment, never saved. The final prompt and generation report are `continuous-soil-prompt.txt` and `continuous-soil-source.report.json`. The prompt requests a flat overhead expanse of low-contrast compacted soil, very few tiny pebbles, no rubble, vegetation, objects or grid. Existing original concrete and overgrowth textures supply the larger surrounding regions. No video generation is needed for static ground.

Validation: modular terrain and acid rain FX suites pass. Actual Godot near, overview and acid-state captures are `battlefield-tilemap-{near,overview,acid}.png` in the same output folder. Editor import emits existing missing .NET SDK / temporary WAV warnings; runtime captures and the GDScript suites complete successfully.

The sections below describe the earlier tile-based revisions, retained as provenance for the reusable source materials and acid atlases.

Normal ground uses battlefield_ground_ruins_spritegen.png plus battlefield_macro_ruins_spritegen.png. Both are packed from output/imagegen/tilesets/ruins-ground-source.png, generated with sprite-gen, gpt-image-2, through the explicitly requested gateway. No credential is stored in this project.

The imported art_source/generated/modular_terrain_overlay.png is reused for wet previews and acid corrosion. Its painted rectangles have gutters and opaque ground interiors; it is not a seamless base tile. The builder crops the measured bounds and derives joined corrosion variants with exposed-edge masks. The original sheet is preserved. Decorative and splash rows remain available but are not added to the normal battlefield: the splash row has chroma contamination, and the doorway art has a different perspective.

Rebuild: run scripts/build_ruins_terrain_atlas.py with the sprite-gen virtual environment. scripts/build_battlefield_tileset.py delegates to the same builder to avoid restoring the previous soil sources.

The 72x72 grid, 40 world-unit cells, actor layers and collision rules are preserved. Weather restoration clears active and preview overlays. Dynamic draws are culled to the camera viewport and refreshed at up to 30 Hz; no frame-rate benchmark was performed.

Style direction: abandoned survival environments such as Project Zomboid and Dysmantle. Live retrieval of the Steam reference page failed in this session, so no reference screenshots were downloaded or copied.

Validation: test_modular_terrain_runner.gd and test_acid_rain_fx.gd pass. Full test_runner.gd fails on HUD contracts, viewport layouts, camera zoom and missing world_threat_feedback in test_game_flow.gd; no terrain assertions failed. Captures are in output/imagegen/tilesets/battlefield-tilemap-{near,overview,acid}.png.

## Rich material update

Reviewed the live DYSMANTLE Steam storefront gameplay gallery: https://store.steampowered.com/app/846770/DYSMANTLE/ . Adopted its separation of calm terrain, localized rubble and vegetation as the composition reference, keeping this game's overhead projection. Generated three original material textures through sprite-gen and the user-selected gpt-image-2 gateway: ruins-concrete-source.png, ruins-overgrowth-source.png, ruins-rust-source.png. No reference art was copied or uploaded.

The macro atlas now contains twelve 640px patches at 7680x640. Irregular alpha boundaries, flipped orientations, seeded random selection and noise-based material regions break up repetition. Five ground variants have different interiors and shared boundaries. These remain static TileMap cells below acid overlays; the 72x72 terrain logic and actor layers are unchanged.

Revalidated modular terrain and acid FX suites; both pass. Captured normal near view, overview and acid state after integration. This update adds no animated sprites or per-frame material placement; frame rate has not been benchmarked.
