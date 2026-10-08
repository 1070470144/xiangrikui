# MM Feature Art Manifest Design

## Goal

Change `mm-tools` from a screenshot-first asset decomposition workflow into a feature-first art pipeline. Every implemented UI feature must include a versioned JSON manifest that describes its visual assets, feeds generation jobs to `sprite-gen`, and binds completed assets into Godot at runtime.

The playable feature and its provisional UI remain the source of truth for behavior and layout. An AI concept image may guide style, but it is not required for discovering which assets the feature needs.

## Workflow

1. Implement the feature completely with functional controls and a readable provisional UI.
2. Add one manifest for that feature under `art_source/manifests/<feature>.json`.
3. Record every meaningful visual element, including generated images and program-rendered text.
4. Validate the manifest against its schema and the target Godot scene.
5. Show the generation plan to the user and obtain confirmation.
6. Generate only enabled, missing assets through `sprite-gen gen --provider mm-api --model gpt-image-2`.
7. Verify file names, dimensions, transparency, checksums, and target bindings.
8. Load the same manifest in Godot and apply available assets. Missing or invalid assets retain the provisional UI fallback.
9. Capture the running feature and compare it with the intended art direction before accepting the result.

The manifest is created while implementing the feature, not reconstructed later from screenshots.

## Directory Layout

```text
art_source/
  manifests/
    battle_hud.json
    main_menu.json
  schemas/
    mm_art_manifest.schema.json
  generated/mm_tools/
    battle_hud/
    main_menu/
aiskill/mm-tools/
  SKILL.md
  mm_manifest.py
scripts/
  art_manifest.gd
tests/
  test_art_manifest.gd
  test_mm_manifest.py
```

## Manifest Contract

Each feature owns one JSON document. `schema_version` enables future migrations, while `feature` provides the stable namespace used by generated output and reports.

```json
{
  "$schema": "../schemas/mm_art_manifest.schema.json",
  "schema_version": 1,
  "feature": "battle_hud",
  "scene": "res://scenes/main.tscn",
  "root_node": "Game/HUD",
  "style": {
    "reference_images": [],
    "prompt_prefix": "末日温室厚涂绘本风，清晰游戏 UI，统一材质与光照"
  },
  "assets": [
    {
      "id": "hud_background",
      "kind": "background",
      "role": "战斗 HUD 整体背景",
      "generation": {
        "enabled": true,
        "provider": "mm-api",
        "model": "gpt-image-2",
        "prompt": "横向战斗状态栏背景，不含文字，不含图标",
        "transparent": false
      },
      "output": {
        "path": "res://art_source/generated/mm_tools/battle_hud/hud_background.png",
        "size": [1920, 220],
        "mode": "full_image"
      },
      "bindings": [
        {
          "node": "Background",
          "property": "texture"
        }
      ]
    },
    {
      "id": "end_turn_button",
      "kind": "button",
      "role": "结束白昼按钮",
      "states": ["normal", "hover", "pressed", "disabled"],
      "generation": {
        "enabled": true,
        "provider": "mm-api",
        "model": "gpt-image-2",
        "prompt": "藤蔓与旧黄铜构成的横向按钮框，不含文字",
        "transparent": true
      },
      "output": {
        "path_pattern": "res://art_source/generated/mm_tools/battle_hud/end_turn_{state}.png",
        "size": [240, 72],
        "mode": "nine_patch",
        "patch_margin": [24, 24, 24, 24]
      },
      "bindings": [
        {
          "node": "EndTurnButton",
          "property_map": {
            "normal": "theme_override_styles/normal",
            "hover": "theme_override_styles/hover",
            "pressed": "theme_override_styles/pressed",
            "disabled": "theme_override_styles/disabled"
          }
        }
      ]
    },
    {
      "id": "end_turn_label",
      "kind": "text",
      "role": "结束白昼按钮文案",
      "generation": {
        "enabled": false
      },
      "runtime": {
        "text": "结束白昼",
        "font_size": 22,
        "color": "#FFF0B0"
      },
      "bindings": [
        {
          "node": "EndTurnButton",
          "property": "text"
        }
      ]
    }
  ]
}
```

### Required Top-Level Fields

- `$schema`: relative path to the checked-in JSON Schema.
- `schema_version`: integer, initially `1`.
- `feature`: unique lowercase `snake_case` identifier.
- `scene`: Godot scene containing the binding root.
- `root_node`: stable node path within the instantiated scene.
- `style`: shared references and prompt prefix for visual consistency.
- `assets`: ordered list of visual requirements.

### Asset Fields

- `id`: unique lowercase `snake_case` identifier within the feature.
- `kind`: one of `background`, `portrait`, `illustration`, `panel`, `button`, `icon`, `bar`, `decoration`, or `text`.
- `role`: human-readable purpose in the feature.
- `generation.enabled`: whether `sprite-gen` should create image files.
- `output`: required for generated assets; contains a fixed path or state-based path pattern, exact size, and usage mode.
- `bindings`: one or more relative node paths and target properties.
- `states`: required when an asset has multiple visual states.
- `runtime`: program-rendered properties for non-generated elements such as text.

## Decomposition Rules

The feature's interaction and reuse boundaries determine assets:

- A complete character portrait or decorative illustration is one `full_image` asset unless animation, equipment swaps, or independent interaction requires layers.
- Buttons do not contain baked text. Their visual states may be generated separately or derived from an approved base image.
- Text is always rendered by Godot so localization, accessibility, and dynamic content remain functional.
- Icons are separate when reused, recolored, independently animated, or changed by state.
- Panels and backgrounds are separate only when they have different scaling, visibility, or reuse behavior.
- Stretchable UI declares `nine_patch` and explicit margins.
- A concept image can populate `style.reference_images`, but cannot override the feature-defined asset list.

## Generation Tool

`aiskill/mm-tools/mm_manifest.py` provides four commands:

```text
python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
python aiskill/mm-tools/mm_manifest.py plan art_source/manifests/battle_hud.json
python aiskill/mm-tools/mm_manifest.py generate art_source/manifests/battle_hud.json
python aiskill/mm-tools/mm_manifest.py verify art_source/manifests/battle_hud.json
```

`validate` checks the JSON Schema, unique IDs, safe project-relative paths, state placeholders, supported binding forms, and required fields. It also inspects the referenced Godot scene when possible and reports missing node paths.

`plan` expands state variants and prints the exact generation jobs without writing files or calling an API. This output is the user approval surface.

`generate` refuses to run without explicit confirmation, invokes `sprite-gen` with the fixed `mm-api` provider and `gpt-image-2` model, and never silently overwrites an existing image. It combines `style.prompt_prefix` with each asset prompt and expands `{state}` jobs.

`verify` checks output presence, PNG format, dimensions, alpha requirements, and report metadata. It emits a non-secret status report adjacent to the manifest or generated feature directory. API keys and authorization headers are never serialized.

## Godot Runtime Binding

`scripts/art_manifest.gd` owns parsing, validation needed at runtime, and binding. Feature code supplies the manifest path and the instantiated root node. The loader resolves each binding relative to `root_node`, loads image resources through `ResourceLoader`, and applies supported properties.

Version 1 supports:

- Direct texture properties such as `texture`.
- Button state style properties represented by `StyleBoxTexture` for `nine_patch` outputs.
- Program-rendered text plus font size and color overrides.

Unsupported kinds or properties produce a clear warning and leave the provisional UI unchanged. A malformed manifest, missing node, missing texture, or incompatible property must not prevent the feature from running. Runtime code never calls `sprite-gen` and never writes generated files.

Bindings are intentionally explicit rather than inferred from node names. Renaming a UI node therefore causes validation to fail before asset generation or release.

## Feature Development Rule

A UI feature is complete only when all of the following exist:

1. Functional implementation with usable provisional visuals.
2. A checked-in manifest covering every meaningful visual element.
3. Stable node names referenced by the manifest.
4. Automated manifest validation.
5. Fallback behavior when final art is absent.

The manifest may legitimately contain only non-generated entries when a feature uses purely programmatic visuals.

## Failure Handling

- Invalid schema or unsafe paths: stop before planning or generation.
- Duplicate asset IDs or expanded output paths: stop and list conflicts.
- Existing output file: skip and report unless the user explicitly selects a future overwrite mode.
- Generation failure: retain successful independent outputs, mark the failed job, and return a failing exit code.
- Missing runtime asset: warn once and keep the provisional UI.
- Missing node or incompatible property: warn with feature, asset ID, node, and property; continue other bindings.
- Unsupported schema version: reject during tooling validation and ignore safely at runtime.

## Testing

Python tests cover schema validation, job expansion, disabled text assets, state path expansion, path traversal rejection, duplicate outputs, and overwrite refusal. Generation subprocess calls are replaced with a controlled test double; tests assert constructed arguments without using the network.

Godot tests cover JSON parsing, direct texture binding, button state binding, text binding, missing-file fallback, missing-node isolation, and unsupported-version handling. A small test scene and tiny fixture PNGs keep tests deterministic.

The existing headless test suite remains the regression gate. An example manifest for one existing feature proves the complete contract before other features are migrated.

## Initial Scope

Version 1 introduces the schema, CLI, Godot loader, tests, updated `mm-tools` instructions, and one representative existing feature manifest. It does not automatically infer assets from screenshots, train models, create animations, generate fonts, or migrate every existing screen.
