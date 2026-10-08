# Battle UI V5: color and vertical hand contract

## Stage 1: problem and visual direction

The actual V4 Godot screenshots have coherent botanical materials, but the
olive-grey glass dominates the header and cards. Compact cards show illustrations
and costs without effect descriptions. V5 replaces the battle UI palette with
midnight blue-grey, muted warm paper and aged copper. The greenhouse world art
stays unchanged and the mother flower remains the warm, brightest focal point.

The project art guide section 8 specifies old gardening records and luminous
instruments, blue-grey surfaces, worn paper edges and thin gold lines. Collectible
card games inform only the vertical illustration/name/effect hierarchy, overlapping
hand and drag interaction. Do not reproduce another game's logo, artwork,
distinctive frame, lettering, character design or branded cost symbol.

Project evidence uses seven existing runtime assets: V3 primary frame and bezel,
mother-flower portrait, light-bud/root specimen, thorn flower, prism flower and
repair icon. Actual V4 screenshots establish material/obstruction baseline;
actual V5 provisional 1280×720 capture confirms the navy/ivory direction before
generation (`tmp/battle-ui-v5-layout/1280x720-hud-night-runtime.png`). The latter
shows that the new V5 navy siblings are bound to both primary-button and radar
rim, while all three headers use the native navy fallback pending the new master.

Two mature external examples were fetched for layout-only research:
[Hearthstone](https://playhearthstone.com/en-us/) official page, archived as
`tmp/battle-ui-v5-research/Hearthstone.html`; and
[Slay the Spire](https://store.steampowered.com/app/646570/Slay_the_Spire/) commercial
page, archived as `tmp/battle-ui-v5-research/Slay_the_Spire.html`. Hearthstone
informs cost/illustration/title/effect hierarchy and an overlapping hand; Slay
the Spire informs concise combat-effect text and readable cost cues. These pages
are not authority for the project palette, botanical art, frame design or branding.

## Stage 2: implementation and generation boundary

Two paid master images are planned: a quiet navy-glass header and a vertical
botanical card frame. No generation runs until the root agent obtains the user's
confirmation of the complete plan. Runtime uses existing plant illustrations and
draws all text, gem, costs and selection outlines natively. No generated tray: the
hand floats over the battlefield with no continuous background rectangle.

Reuse V3 primary-button states and instrument ring through deterministic
green-to-navy recoloring into new V5 sibling assets; preserve warm bronze, brush
lightness and exact alpha geometry. Keep every original V3/V4 asset.

Palette: surface #172331, raised #263449, muted paper #cfc1a3, paper ink #282c33,
aged brass #b98b55, primary text #f2e6cf, selection #e3b66b, warning #8e3d4a,
disabled #65717e, native cost gem #355b82. Avoid pale green, neon blue, white
glare, candy saturation and shiny chrome. Paper should read as a small record
label; it must not become the dominant luminous surface of the screen.

Cards display at 142×218 logical pixels. A 33px cost gem occupies the top-left;
illustration x12 y28 w118 h68; title y98–121; paper begins y121 at height85;
description x12 y126 through y199. These slots stay empty in the generated master.
Generate no gem, cost, icon, plant, word, pseudo-text or divider through text.
Native description ink is dark on paper; title is warm pale on dark navy.

Five cards occupy approximately 748 logical pixels. A card hover rises 36 pixels
and scales 1.06; the hand rests 18 pixels from the bottom. Native drag previews
and the transparent world drop surface supply interaction; generated textures
never change gameplay targeting or intercept input. Hover/selected outline and
disabled appearance share the same source silhouette. Battle code owns the hand
layout, tooltips and descriptions, including safe truncation or expansion for long
effects. Generation code owns verified PNGs and reports.

Review actual Godot day/night at 1152×648, 1280×720 and 1920×1080: header text
must stay inside quiet glass; card titles and descriptions must not cross metal
rails; energy costs/phase restrictions must remain distinguishable; the floating
hand and hover preview must not persistently obscure the central mother flower;
the instrument rim must not cover threat marks. Inspect the original raw image
before trim/derivation, preserve corner aspect ratios and determine patch margins
from the runtime texture, never from oversized source pixels.

## Stage 1/2 Verification (2026-09-30)

Official Hearthstone and Slay the Spire pages were used only for layout research;
HTTP 200 HTML evidence is in `tmp/battle-ui-v5-research/`. Adopted ideas are the
vertical portrait/effect hierarchy, corner cost, hover inspection and stable-hand
drag. Project art remains original. Day has native Deployment/Tactics tabs so
deployment and day-only tactical cards share one location.

All four day tools support native drag with existing supply, clearance and resource
validation. Night cards use the existing resolver. Transplant is two-stage: first
drop selects the source, a valid destination moves it and consumes once; invalid
targets, insufficient energy, phase changes, Escape, right-click and modal
interruption preserve resources. Camera movement is locked during drag, and world
release coordinates come from the mouse event before deferred handling.

All 24 effect captions fit the 114x73 region at 12px. Actual overload and golden
domain effects are written explicitly. Verified commands:
`tests/test_card_drag_integration.gd` -> `CARD DRAG INTEGRATION PASSED (0 failures)`;
`tests/test_battle_card_copy.gd` -> `BATTLE CARD COPY CHECK: 0 failures`.
The known Windows certificate-store warning is non-fatal. Legacy seven-failure
`test_battle_hud.gd` and obsolete V3 short-card assertions remain outside V5 scope.

Runtime evidence in `tmp/battle-ui-v5-layout/`: day/night at 1152x648, 1280x720,
1920x1080, plus `1280x720-hud-day-tactics-runtime.png`,
`1280x720-hud-hover-runtime.png`, `1280x720-hud-drag-runtime.png`, and the
mother-choice capture. Native navy button states and tactical bezel are bound;
the two paid master images remain pending user confirmation.
