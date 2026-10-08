# Battle UI V5 acceptance: final deck-face reuse

## Final scope correction (2026-10-01)

The user requested battle cards use the existing project deck-builder style.
The rejected new card generation was therefore superseded by direct reuse of
`deck_builder/faces_v5/card_face_{common,rare,legendary}_v5.png` and existing
`deck_builder/illustrations_v3/{card_id}.png`. No extra paid request was made.
The rejection record and original prompts are retained as generation history;
the manifest now disables card generation and records the reuse contract.

Cards are 177x218, preserving the deck face's 700:860 aspect. The shared
`card_face_layout.gd` places title, cost and illustration in the actual measured
texture slots, with rarity-specific geometry. Deck faces also appear on the
drag preview and hover states. The original native paper and gem backgrounds
are empty so the reused painted material remains visible. Deployment tools use
the common face and their actual existing icons; tactical cards use deck art.
Native effects occupy x23,y117,w131,h74 at 12px, inside all three paper borders.
Target captions occupy the bottom rail with contrast chosen for the material;
the legendary target has a small quiet paper badge to avoid its center clasp.

The initial day hand width was increased to 711 so four cards are fully visible
and do not overlap the primary action even before the first resource refresh.
All three sizes were recaptured after the final correction: 1152x648, 1280x720,
1920x1080, day/night, day tactics, hover, actual drag and all three rarities.
Final review images are `output/imagegen/previews/battle-ui-v5-final-1280x720-`
`day.png`, `night.png`, and `rarities.png`. Evidence files remain in
`tmp/battle-ui-v5-layout/` and the current deck screenshot is
`tmp/battle-ui-v5-research/deck-current.png`.

Manifest validate and verify pass. Actual drag, 24-card caption fit and V5
viewport/binding tests pass with zero failures. Independent review checked
rarity text placement and corrected narrow paper margins and target bounds.
This final reuse scope completes stages 3 and 4: the accepted navy header and
reused project card faces are present in actual Godot runtime, with no pending
generated asset required. The earlier partial assessment below is preserved
as history and is superseded by this final acceptance.

## Stages 1 and 2: complete

See `mm-tools-battle-ui-v5-stage12.md` for project visual evidence, layout-only
commercial references, native implementation and the user-confirmed two-master
plan. V4 baseline: `output/imagegen/previews/battle-hud-v4-1280x720-hud-night-runtime.png`.
V5 preserves the original plants and botanical copper language, moves instruments
to navy, and makes effect/cost/target information visible in vertical cards.
Deployment and day tactics share one tabbed location. Native drag uses real
targeting and resource validation; transplant is reachable and consumes once.

## Stage 3: partial

`navy_status_frame` passed native-alpha generation and individual verify. Its
runtime texture is `assets/ui/generated/battle_ui_v5/navy_status_frame.png`.
The original image was visually checked: quiet navy center, restrained copper
corner leaves, no writing or portrait. Processor trim and runtime nine-patch
preserve corner shapes. HUD reads the same manifest to bind all three headers.
Actual Godot OpenGL screenshots show the generated header with native text;
corners do not cross the health/phase/resource readouts.

The second paid call for `vertical_botanical_card` produced RGB with a baked
checkerboard. It failed the sprite-gen native-alpha contract. The rejected image
is not bound, and cards keep functional native navy frames and paper captions.
No additional paid call was made by this implementation agent.

Navy button states and tactical bezel are deterministic new siblings of existing
project art. Original V3/V4 assets remain intact. Cards automatically use the
same manifest component binding only when verified runtime textures are ready;
native paper is hidden then so it cannot obscure the generated paper.

## Stage 4: partial runtime review

Actual captures cover 1152x648, 1280x720 and 1920x1080 day/night, day-tactics,
hover, drag and mother choices in `tmp/battle-ui-v5-layout/`. Stable review copies:
`output/imagegen/previews/battle-ui-v5-partial-1280x720-day.png` and
`output/imagegen/previews/battle-ui-v5-partial-1280x720-night.png`.

Compared with V4, the navy header stays subordinate to the warm mother flower;
there is no added glow or saturation, no bright tray, and sparse copper corners
retain the existing materials. All text fits and the floating hand stays above
the bottom edge without overlapping the right action or persistent mother area.
Hover and the actual native mouse drag preview preserve source identity.

After header import, all focused suites passed with zero failures:
`test_card_drag_integration.gd`, `test_battle_card_copy.gd`, and
`test_battle_ui_v5.gd`. This covers actual day/night mouse chains, cancel/modal
conditions, camera locking, resource preservation, all 24 effect captions, three
viewport sizes and generated-header binding. The known certificate warning is
non-fatal. Editor import also reports missing .NET SDK, while GDScript runtime
captures and tests succeed. Legacy missing-overlay assertions are not claimed
to pass by these focused checks.

Full four-stage completion remains open because the generated card master has
not passed its transparency contract. Header integration and gameplay are
reviewable; complete card generation and subsequent runtime review require
resolution of that rejected asset.
