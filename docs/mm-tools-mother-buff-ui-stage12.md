# Mother evolution chooser — stages 1 and 2

## Functional boundaries and content

User asked for sprite-gen improvement of the buff selection page and individual mother forms for each option. There are **3 initial paths + 54 upgrades = 57 distinct identities**. This UI work does not collapse choices into tier-only forms. The initial chooser explains attack/survival/pulse direction. Daily chooser names its branch and explicitly shows current rank → chosen next rank, exact numerical benefit, and click feedback. A single real mouse release confirms one choice; existing game validation applies it. Overlay blocks deployment input. Text is native and portrait remains a separate TextureRect so the per-option form implementation can provide its accepted image without baking copy into artwork.

All 54 descriptions in `scripts/mother_upgrade_presentation.gd` were derived from `mother_evolution.gd`, `mother_flower.gd` and `game.gd`, including limits, timing and enemy-rank restrictions. They are not generic ‘strengthen mother’ labels. Fallback state is fully functional while paid art is pending.

## Layout study

Official/commerce sources fetched successfully into `tmp/mother-buff-research/slay.html` and `hades.html`:

- Slay the Spire, https://store.steampowered.com/app/646570/Slay_the_Spire/: adopt parallel independently readable card options, effect before confirmation. Adapt to three botanical permanent choices; do not adopt external artwork or branding.
- Hades, https://www.supergiantgames.com/games/hades/: adopt benefit-first choice hierarchy, persistent boon selection and immediate feedback. Adapt to explicit branch progression and numerical effect. External sources are layout-only and never generation art authority.

## Project evidence and visual anchor

Approved guide: `Design/Sunflower-Defense-Art-Style-Guide.md`. Existing runtime baseline: `output/imagegen/previews/battle-flow-v7-loadout-selection-1280x720.png`. Actual new runtime evidence: `output/imagegen/previews/mother-buff-paths-1280x720.png` and `mother-buff-effects-1280x720.png`. Relevant runtime material samples: `assets/core/ART_CORE_MotherFlower_Healthy.png`, `assets/ui/generated/battle_ui_v5/primary_action_normal.png`, `assets/ui/generated/battle_ui_v5/tactical_bezel.png`.

Anchor: navy rectangular cards with thin aged copper edging, warm ivory effect paper, native dark ink, restrained hand-painted botanical corner relief and warm upper-left light. Three equal-width cards in centered navy modal. Ornament must stay within edge safe area; copy stays in quiet solid paper. No neon, bright glow, dense noise, motion streaks, heavy metallic gloss, copied commercial branding or baked text. Hover uses border and explicit action feedback, never shifts layout.

## Implementation and generation contract

`art_source/manifests/mother_buff_ui.json` is SSoT. One generated shared transparent outer-edge master, source 768×1024, runtime 252×350. The modal, paper, states, text and portrait fallback are native/reused and have generation disabled. Only frame generation is enabled. Model fixed to mm-api/gpt-image-2. Explicit binding uses per-card `FrameArt.texture` via `scripts/art_manifest.gd`. Missing frame leaves fully usable native card. This is **one paid image call**; no calls were executed. Per-option mother images and video atlases are separate animation scope and must appear in the parent's combined confirmation plan.

## Stage gates

`tests/mother_buff_ui_capture.gd` runs target Godot game, saves initial/daily modal screenshots at 1152×648, 1280×720, 1920×1080. It checks all 54 effect descriptions, card bounds, effect-paper geometry, and actual mouse-motion/down/up selection with exactly one distinct upgrade ID. Native fallback has passed all three sizes. System CA root-store warning is a host warning, with no Godot script failure. Frame is pending stage-3 confirmation and generation, so stage 4 and whole feature completion are not claimed.
