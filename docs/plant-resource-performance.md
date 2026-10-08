# Plant resource loading

`PlantResources` persists across game screens. It requests only carried or
actually instantiated species. Plant animation frame reads and attack effect
triggers are cache-only; unavailable visuals never block gameplay.

Build lossless animation pages (maximum 2048 pixels per dimension):

    python scripts/build_plant_animation_atlases.py

The builder checks all source frame pixels against the packed and saved pages.
Source images remain available for editing; runtime animation loading uses only
`atlas_manifest.json` and atlas pages. Rebuild after changing source animations.

Texture requests are deduplicated and loaded with Godot's threaded loader.
Completed pages render one at a time for two process frames in a 32-pixel
SubViewport before publication, using the battlefield actor shader for plants
and the default sprite material for effects. Animation assembly is shared across species,
limited to 16 frames and approximately 2 ms per process frame. The cache retains
resources for the process lifetime. Missing resources are remembered as failed.

On cold creation plants use cached static art, or procedural fallback while
static art loads. A readiness signal attaches animation only to a living plant;
revival explicitly checks for newly available animation. Combat state is not
reconfigured on readiness. Effects not yet loaded are skipped.

Offline validation (no Godot required):

    python tests/test_plant_atlas_assets.py

Runtime validation (after Godot has imported the generated PNG pages):

    godot --headless --path . --script tests/test_plant_async_resources.gd
    godot --headless --path . --script tests/test_plant_video_animation.gd
    godot --headless --path . --script tests/test_plant_death_animation.gd
    godot --headless --path . --script tests/test_plant_attack_video_fx.gd

Use a rendered game run for GPU warmup and frame-time acceptance; headless tests
cannot prove absence of GPU upload stalls. `Game.planting_timings` retains the
last 128 placement samples (resource lookup, node, network and total microseconds,
readiness).
Cold-session target: placement P95 <= 5 ms and no resource-induced frame above
50 ms. These targets require measurement on the target machine.
