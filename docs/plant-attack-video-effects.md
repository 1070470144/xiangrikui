# Plant attack video effects

The isolated vine, pollen and frost effects replace the procedural drawing in
`scripts/plant_attack_fx.gd`. Whole-plant attack animations remain separate.
Damage, cooldowns, healing and status projectiles are owned by `plant.gd`.

Generation uses the previously configured compatible GPT image endpoint for
transparent reference stills, then Ark Seedance for four-second first/last-frame
videos. SpriteGen `video-frames` performs extraction, chroma removal and edge
checks. SpriteGen `video-loop --state attack --cycle pinned --anchor none`
assembles the entire return-to-start action. The runtime plays it once in
0.64-0.72 seconds, using every published strip frame and elapsed-time playback.

Runtime assets: `assets/effects/plants/*.atlas.png`, `*.strip.json` and
`*.runtime.json`. Shared textures are cached across plants. Vine placement follows
the target direction and distance; pollen and frost play at the target.
Effects have absolute z-index 17 so they remain visible above weather overlays.

Source stills, prompts, MP4s, saved task IDs and SpriteGen reports are under
`art_source/generated/plant_attack_fx_video_v2/`. The earlier text-only trial is
preserved in `plant_attack_fx_video/`; it was rejected because the video model
painted a shaded pink floor that could not be keyed. It is never loaded by the game.

To resume generation, set `ARK_API_KEY`, `OPENAI_API_KEY` and
`OPENAI_BASE_URL` in the process environment and run
`art_source/plant_effect_video_ark.py` with SpriteGen's venv Python.
No credentials are stored in source. Existing clips and saved tasks are reused;
an unresolved creation intent stops resubmission for manual inspection.

Verification: Godot `tests/test_plant_attack_video_fx.gd` checks all three effects,
frame advancement, layering, completion, restart, reverse direction and support
placement. Run with `--capture` using a rendering-enabled Godot process to save
`tmp/plant-video-attack-preview.png`.

Canonical strip cells are repacked into an eight-column texture for Godot so a
long horizontal strip cannot exceed GPU texture-width limits. No source-video
frames are manually extracted. Effects allow subject edge contact: the vine's
three impact frames emit small fragments beyond the canvas while the complete
whip and curled tip remain visible. Radial bursts emit particles out of the
canvas. SpriteGen still rejects residual-only key contact.
