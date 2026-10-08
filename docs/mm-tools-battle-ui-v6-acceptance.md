# Battle UI compact view and bottom fan

Stage 1: the user requested more battlefield visibility, a smaller HUD and a
bottom fan hand that rises for inspection. Existing project deck faces, navy
readouts and prior runtime evidence remain the visual authority. The change is
native layout and interaction; it requires no generated image or paid call.

Stage 2: readouts and the right action/instrument use 0.82 scale anchored to
their screen edge. The card face stays full size for legible rules. The resting
hand starts 170 pixels above the bottom and extends 48 pixels beyond it, with
145px spacing, 0.105 radians rotation per slot and 10px arc per slot. Hover lifts
the inspected card 95px and straightens it. Native drag returns the dim source
to its resting fan before creating a preview so it cannot obstruct the world.
Plant drag has an empty native ghost; tactical cards use a small offset preview
to leave the world placement/range indicator visible. Game owns those world
indicators and target validation.

Camera default zoom changes from 2.05 to 1.35; the minimum is 0.8. Default view
width/height increases by 1.52 times, showing approximately 2.31 times the world
area. Existing camera bounds and user zoom controls remain active.

Stage 3: existing verified deck faces and readout assets remain bound through
the same manifest; native layout changes are recorded in its
`native_layout_update`. Manifest validate passes. No new bitmap was generated.

Stage 4: actual Game captures at 1152x648, 1280x720 and 1920x1080 are in
`tmp/battle-ui-v6-layout/`. Each size includes actual default camera day/night,
the previous 2.05 camera comparison and hover triggered by real viewport mouse
input. The pointer stays at its original position for five frames; the card
remains raised and fully readable. The rest fan sits at the bottom and leaves
the mother flower visible. Header and right controls are smaller, while all
card effect text retains 12px size. Focused real drag, caption fit and viewport
checks all pass with zero failures after the final source-rest correction.

Independent lower-edge mouse motion found an inspection hitbox issue and a
live-refresh reset. Both were corrected: hover retains the union of the original
fan footprint and raised face; hand refresh updates the resting transform while
preserving the raised state. The independent five-card 1152x648 test exercises
upper/lower hover points, repeated tiny pointer motion and live hand refresh and
passes. Real native drag and viewport checks pass after this correction too.

Stable previews: `output/imagegen/previews/battle-ui-v6-day.png`,
`battle-ui-v6-night.png`, `battle-ui-v6-hover.png`. World drag indicator screenshots
and their independent actual-event tests are produced by the game-preview
implementation owner and should accompany this layout record for final delivery.
