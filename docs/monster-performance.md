# Monster crowd performance

Enemy count, ring radii, damage, rewards and native animation FPS remain unchanged.
Nearby combat queries use a 256-unit spatial grid with precise distance/rectangle
filtering and stable spawn order. Movement, knockback, conversion, death and tree
exit update membership immediately. Hostile-list snapshots rebuild only after
membership changes, so deaths during multi-target attacks cannot mutate iteration.

Spawn queues use a cursor and incremental direction/batch counts, at most eight
entries per frame. Consumed entries remain until the queue drains, then it clears.
Use `get_remaining_spawn_count()` instead of raw queue size during generation.
`get_active_enemies()` returns a compatibility copy; internal queries use snapshots.

Monster animations use lossless paged atlases and the persistent resource service.
White-day entry requests the upcoming night's species. Plants and monsters share
the 16-frame / approximately 2 ms assembly budget. Texture pages render before
publication using the actor lighting shader. Unavailable animation uses cached
static art or procedural fallback; readiness does not reset combat/action timers.
Monster attack effects are procedural and need no external texture loading.

Two shared shadow textures replace 28 circle draws per actor. The projection shader
reconstructs opacity for the current lighting strength; position, rotation, stretch
and contact-shadow shape retain the previous settings. Only shadows within the
viewport plus a 160-unit margin are submitted. All monster animations remain full rate.

Rebuild and read-only verification:

```text
python scripts/build_monster_animation_atlases.py
python tests/test_monster_atlas_assets.py
python tests/test_plant_atlas_assets.py
```

After Godot imports the pages, run correctness tests:

```text
godot --headless --path . --script tests/test_enemy_performance.gd
godot --headless --path . --script tests/test_monster_animations.gd
godot --headless --path . --script tests/test_wave_director.gd
godot --headless --path . --script tests/test_plant_async_resources.gd
godot --headless --path . --script tests/test_runner.gd
```

Rendered performance measurement (headless rendering is rejected):

```text
godot --path . --script tests/monster_pressure_capture.gd
```

The harness uses night seven, seed 777, five fixed plants, fixed camera, and elevated
fixture health for defenders and enemies to prevent early failure and keep the full
crowd alive for the stable interval. This only affects the benchmark, not normal
gameplay. It runs a cold night and a second night sharing process caches, each for
the configured night duration plus 60 seconds. CSVs and shadow screenshots are
written to `output/performance`. Compare the same harness, resolution, renderer,
hardware and VSync settings on the previous and optimized revisions. The screenshot
frame is excluded from timing. Stable P95 target is <=16.7 ms; record actual peak
enemy count and actual P95 even when the target is missed. Per-phase CPU timings do
not measure GPU execution; inspect Godot's rendering profiler when CPU totals do
not explain wall-frame time.

Sampling runs after rendered frames and uses the latest ring-buffer entry even
after wrapping. Night resource requests also prewarm the shared sunburst texture;
death effects read caches and fall back to their existing procedural drawing.

`Game.get_performance_samples()` exposes the last 3,600 chronological samples:
frame interval, alive hostiles, spawned entries, spawn/query/UI/shadow CPU times and
spatial-query candidates. Samples use a ring buffer, avoiding array shifting.

Current validation: offline atlas checks are available; Godot is not installed in
this environment. Engine compilation, gameplay regression, shadow screenshot
comparison and measured frame-rate acceptance remain pending. No 60 FPS claim is
made without a rendered run on the target machine.
