# Sunflower Defense Formal Art Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Godot prototype's geometric actor, environment, effect, and UI presentation with a coherent production-oriented hand-painted asset set while preserving all gameplay behavior.

**Architecture:** Generate and post-process raster assets into a stable `assets/` contract, then add texture-aware rendering to the existing gameplay nodes. Every actor keeps its procedural drawing as a fallback, while formal textures, state switching, and lightweight runtime animation become the primary presentation path.

**Tech Stack:** Godot 4.7.2, GDScript 2.0, PNG with alpha, AI image generation, Pillow-based image inspection/post-processing, Godot headless tests and movie-frame capture.

---

## File Structure

- `assets/backgrounds/` — full-screen base garden and transparent foreground mist.
- `assets/core/` — mother flower health-state textures.
- `assets/plants/` — thorn and prism powered/unpowered textures.
- `assets/enemies/` — shadow beast and erosion bug movement/attack textures.
- `assets/nodes/` — healthy, damaged, and broken light-bud textures.
- `assets/effects/` — projectile, sunburst ring, and shadow dissolve textures.
- `assets/ui/` — scalable panels, button states, progress bars, and action icons.
- `art_source/` — retained raw generation outputs and contact sheets, excluded from Godot imports.
- `scripts/art_library.gd` — centralized texture paths and safe loading helpers.
- `tests/test_art_assets.gd` — file, dimensions, alpha, and loadability contract.
- Existing gameplay scripts — add Sprite2D-backed presentation and keep behavior APIs unchanged.

### Task 1: Create the Asset Contract and Failing Validation

**Files:**
- Create: `tests/test_art_assets.gd`
- Modify: `tests/test_runner.gd`
- Create: `scripts/art_library.gd`
- Create: `art_source/.gdignore`

- [ ] **Step 1: Write the failing asset validation suite**

The suite defines every required final path and asserts that `ResourceLoader.exists(path)` is true, the resource is a `Texture2D`, dimensions match the asset specification, and actor/effect textures report alpha support through their imported image data.

```gdscript
const REQUIRED := {
    "res://assets/backgrounds/ART_BG_GreenhouseGarden_Base.png": Vector2i(1152, 648),
    "res://assets/core/ART_CORE_MotherFlower_Healthy.png": Vector2i(256, 256),
    "res://assets/plants/ART_PLANT_ThornFlower_Powered.png": Vector2i(160, 160),
    "res://assets/enemies/ART_ENEMY_ShadowBeast_Move.png": Vector2i(192, 160),
    "res://assets/nodes/ART_NODE_LightBud_Healthy.png": Vector2i(96, 96),
    "res://assets/effects/ART_VFX_Sunburst_Ring.png": Vector2i(512, 512),
}
```

- [ ] **Step 2: Run the suite and verify RED**

Run the Godot headless test runner. Expected: failures list missing `res://assets/...` resources.

- [ ] **Step 3: Implement the art library contract**

Create constants for every formal texture and a helper:

```gdscript
static func load_texture(path: String) -> Texture2D:
    if not ResourceLoader.exists(path):
        return null
    return load(path) as Texture2D
```

- [ ] **Step 4: Exclude raw generation files**

Create `art_source/.gdignore`; only processed final assets are imported by Godot.

### Task 2: Produce Environment and Mother-Flower Benchmark Assets

**Files:**
- Create: `art_source/background_raw.png`
- Create: `art_source/mother_flower_raw.png`
- Create: `assets/backgrounds/ART_BG_GreenhouseGarden_Base.png`
- Create: `assets/backgrounds/ART_FG_GreenhouseMist.png`
- Create: `assets/core/ART_CORE_MotherFlower_Healthy.png`
- Create: `assets/core/ART_CORE_MotherFlower_Damaged.png`
- Create: `assets/core/ART_CORE_MotherFlower_Critical.png`

- [ ] **Step 1: Generate the environment key art**

Use the approved art direction prompt: 3/4 top-down ruined greenhouse, elliptical garden bed, cold navy and muted violet surroundings, dark brown-purple soil, broken iron ribs and glass, painterly storybook brushwork, playable center kept low-detail, no units, no UI, no text, 16:9.

- [ ] **Step 2: Generate the mother-flower state sheet**

Generate three aligned views of the same botanical design: multi-layer sunflower petals, thick root collar, warm golden-white core, subtle painterly shadow, healthy/damaged/critical states, transparent or removable background, no text.

- [ ] **Step 3: Post-process exact outputs**

Crop and resize the background to 1152×648. Extract the foreground mist as a transparent edge layer. Remove backgrounds from the flower states, normalize them to 256×256, align their ground anchor, clean alpha fringes, and preserve consistent scale.

- [ ] **Step 4: Create a contact sheet and review at runtime scale**

Create `art_source/environment_core_contact.png` containing the 1152×648 background plus the three flowers rendered at their in-game size. Reject outputs where the center is too busy, the flower is not the brightest focal point, or state silhouettes drift.

### Task 3: Produce Plants, Enemies, and Light Nodes

**Files:**
- Create all specified PNGs under `assets/plants/`, `assets/enemies/`, and `assets/nodes/`.
- Create raw sheets and a review contact sheet under `art_source/`.

- [ ] **Step 1: Generate one coherent actor sheet**

Use a single prompt and visual reference strategy to produce thorn flower, prism flower, shadow beast, erosion bug, and light bud on one neutral/chroma background. Require 3/4 top-down perspective, consistent light from upper left, strong silhouettes, limited internal detail, and no overlap.

- [ ] **Step 2: Extract individual assets**

Segment each cell, remove the background, resize to its exact canvas, and align the ground anchor. Powered/unpowered or move/attack variants must share canvas and anchor coordinates.

- [ ] **Step 3: Validate silhouettes at runtime scale**

Create a contact sheet with each unit rendered over the final garden at expected in-game scale. Ensure the two plants and two enemies remain distinguishable without labels.

- [ ] **Step 4: Correct palette and alpha**

Limit warm yellow to player life-light, shift enemy highlights to cold cyan, remove white/black fringes, and keep transparent corners fully alpha zero.

### Task 4: Produce Effects and UI Skin

**Files:**
- Create final PNGs under `assets/effects/` and `assets/ui/`.

- [ ] **Step 1: Generate the effect sheet**

Create a gold-white prism projectile, radial sunburst ring, and blue-violet shadow dissolve with transparent backgrounds and generous padding.

- [ ] **Step 2: Generate the UI material sheet**

Create dark botanical notebook panels, worn gold line borders, button states, progress-bar materials, and four action icons. UI assets contain no embedded text.

- [ ] **Step 3: Slice and normalize**

Export panels and buttons with nine-patch-safe corners; export icons at 128×128; ensure state textures share identical dimensions.

- [ ] **Step 4: Inspect alpha and edge safety**

Render each asset over black, white, and the final background to detect halos or illegible dark edges.

### Task 5: Integrate Background and Actor Sprites

**Files:**
- Modify: `scripts/battlefield.gd`
- Modify: `scripts/mother_flower.gd`
- Modify: `scripts/light_node.gd`
- Modify: `scripts/plant.gd`
- Modify: `scripts/enemy.gd`
- Modify: `scripts/projectile.gd`

- [ ] **Step 1: Add presentation contract tests**

Extend integration tests to assert that each runtime actor creates a `Sprite2D`, loads a non-null texture, and switches texture when health, power, kind, or connection state changes.

- [ ] **Step 2: Verify tests fail before integration**

Run unit and integration tests. Expected: missing sprite nodes or null texture assertions.

- [ ] **Step 3: Add background layers**

`battlefield.gd` creates a base Sprite2D at z-index -20 and a foreground Sprite2D at z-index 20. Keep only dynamic veins, sockets, previews, warnings, and targeting graphics in `_draw()`.

- [ ] **Step 4: Add actor sprites with fallback**

Each actor creates a centered Sprite2D, scales to the current gameplay footprint, updates textures on state changes, and skips the geometric body portion of `_draw()` when the texture is available. Shadows, range hints, hit flash, and dynamic glow remain procedural.

- [ ] **Step 5: Add lightweight animation**

Apply breathing, sway, compression, attack lunge, and hit flash through Sprite2D scale, rotation, position, and modulate. Do not change gameplay coordinates or collision logic.

- [ ] **Step 6: Run all tests**

Expected: art contract, unit, and integration suites pass; no missing-resource output.

### Task 6: Integrate Effects and UI

**Files:**
- Modify: `scripts/effects.gd`
- Modify: `scripts/hud.gd`
- Modify: `scripts/game.gd` only if effect-kind selection requires an explicit parameter.

- [ ] **Step 1: Add effect and HUD contract tests**

Assert projectile and sunburst nodes use formal textures; HUD buttons use texture-backed normal, hover, pressed, and disabled styles; action icons load and appear.

- [ ] **Step 2: Verify tests fail before integration**

Run tests and confirm missing texture-backed presentation.

- [ ] **Step 3: Integrate formal effects**

Use effect textures as primary visuals while preserving runtime scale, rotation, fade, and radius animation.

- [ ] **Step 4: Apply the UI skin**

Create `StyleBoxTexture` resources at runtime from the processed panel/button textures. Apply consistent margins, progress-bar backgrounds/fills, and action icons without changing labels or input signals.

- [ ] **Step 5: Run all tests**

Expected: all presentation and gameplay tests pass.

### Task 7: Visual Regression and Final Verification

**Files:**
- Create: `preview_formal/` captured frames.
- Create: `art_source/before_after.png`.
- Modify: `README.md` with asset structure and art replacement notes.

- [ ] **Step 1: Import all resources in Godot**

Run Godot headless editor import and inspect output for missing resources, parser errors, or failed texture imports.

- [ ] **Step 2: Run gameplay verification**

Run the unit suite, integration smoke suite, and a 900-frame main-scene check. All commands must exit zero with no script errors.

- [ ] **Step 3: Capture the formal-art build**

Use Godot movie-frame capture at 1152×648. Capture day setup, a night combat frame, broken light branch, sunburst, failure, and victory states.

- [ ] **Step 4: Compare against the prototype**

Create a side-by-side before/after image. Confirm the final version replaces geometric bodies, improves environmental depth, maintains gameplay readability, and keeps the mother flower as the brightest focal point.

- [ ] **Step 5: Update documentation**

Document the asset folders, exact Godot launch command, generation-source location, fallback behavior, and how to replace individual assets later.

- [ ] **Step 6: Audit every requirement**

Check every asset listed in the formal-art spec, every runtime state, all test outputs, all import logs, and the final screenshots. Missing or indirect evidence remains unfinished.

