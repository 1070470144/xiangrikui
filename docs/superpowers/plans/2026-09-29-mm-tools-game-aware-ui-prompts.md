# mm-tools Game-Aware UI Prompts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mm-tools` build auditable `sprite-gen` prompts for UI image assets from project style evidence, runtime UI semantics, engineering constraints, and explicit exclusions.

**Architecture:** Keep each feature Manifest as the single source of truth. Extend its `style` block with project evidence and reusable visual constraints, extend generated UI assets with a compact `ui_spec`, and compose the final prompt deterministically in `mm_manifest.py` before passing it to `sprite-gen gen`. Existing manifests with no enabled generation remain compatible; manifests that request new image generation must satisfy the stronger contract.

**Tech Stack:** Python 3.11, `unittest`, JSON Schema draft 2020-12, `sprite-gen gen`, Godot 4 resource manifests.

---

## File map

- Modify `art_source/schemas/mm_art_manifest.schema.json`: describe structured style evidence, `sprite_gen_contract`, comfort constraints, exclusions, and per-asset `ui_spec`.
- Modify `aiskill/mm-tools/mm_manifest.py`: validate the new contract and compose stable UI prompts.
- Modify `tests/test_mm_manifest.py`: specify validation, prompt composition, compatibility, and generation-command behavior before implementation.
- Modify `aiskill/mm-tools/SKILL.md`: document style sampling, `sprite-gen` prompt extraction, UI resource semantics, and visual-comfort gates.
- Modify `art_source/manifests/main_menu.json`: migrate enabled UI generation entries to the new contract.
- Modify `art_source/manifests/deck_builder.json`: migrate enabled UI generation entries to the new contract.
- Modify `art_source/manifests/battle_hud.json`: migrate enabled UI generation entries to the new contract without changing unrelated HUD behavior.

### Task 1: Specify the project-style and UI prompt contract

**Files:**
- Modify: `tests/test_mm_manifest.py`

- [ ] **Step 1: Extend the minimal fixture with a complete style profile and UI specification**

Replace the fixture's `style` object with:

```python
"style": {
    "reference_images": ["res://tmp/main-menu-review/menu00000000.png"],
    "prompt_prefix": "末日温室绘本风游戏 UI",
    "evidence": [
        {
            "source": "res://Design/Sunflower-Defense-Art-Style-Guide.md",
            "kind": "art_guide",
            "reason": "项目批准的色彩、材质与 UI 语言",
        }
    ],
    "sprite_gen_contract": "sprite-gen/docs/gen.md",
    "visual_anchor": "深墨绿旧纸，氧化黄铜细边，克制暖金高光，可见手绘笔触",
    "comfort_constraints": ["中央保持低细节", "高亮只服务主操作", "避免持续高饱和发光"],
    "avoid": ["现代科技 HUD", "霓虹赛博风", "玻璃拟态", "伪文字", "水印"],
},
```

Add this block to the generated button:

```python
"ui_spec": {
    "purpose": "主操作按钮边框",
    "display_size": [160, 48],
    "content_safe_area": [24, 10, 24, 10],
    "layout": "低矮横向按钮，边缘装饰，中央文字区域留空",
    "state_contract": "所有状态保持相同轮廓和装饰位置，只改变亮度、高光和按压深度",
    "negative": ["文字", "字母", "数字", "图标", "投影底板", "厚重外发光"],
},
```

- [ ] **Step 2: Add failing validation tests**

Add tests that remove one required field at a time and assert a targeted error:

```python
def test_generated_ui_requires_project_style_evidence(self):
    module = load_module()
    manifest = minimal_manifest()
    manifest["style"]["evidence"] = []
    errors = module.validate_manifest(manifest, ROOT)
    self.assertTrue(any("style.evidence" in error for error in errors))

def test_generated_ui_rejects_external_only_style_evidence(self):
    module = load_module()
    manifest = minimal_manifest()
    manifest["style"]["evidence"] = [{
        "source": "https://example.com/game-ui.png",
        "kind": "external_reference",
        "reason": "layout reference",
    }]
    errors = module.validate_manifest(manifest, ROOT)
    self.assertTrue(any("project evidence" in error for error in errors))

def test_generated_ui_requires_sprite_gen_contract(self):
    module = load_module()
    manifest = minimal_manifest()
    del manifest["style"]["sprite_gen_contract"]
    errors = module.validate_manifest(manifest, ROOT)
    self.assertTrue(any("sprite_gen_contract" in error for error in errors))

def test_generated_ui_requires_engineering_semantics(self):
    module = load_module()
    manifest = minimal_manifest()
    del manifest["assets"][0]["ui_spec"]["content_safe_area"]
    errors = module.validate_manifest(manifest, ROOT)
    self.assertTrue(any("content_safe_area" in error for error in errors))
```

- [ ] **Step 3: Add a failing prompt-composition test**

```python
def test_ui_prompt_contains_game_style_engineering_and_negative_constraints(self):
    module = load_module()
    job = module.build_jobs(minimal_manifest(), ROOT)[0]
    prompt = job["prompt"]
    for expected in (
        "末日温室绘本风游戏 UI",
        "氧化黄铜细边",
        "主操作按钮边框",
        "160x48",
        "中央文字区域留空",
        "所有状态保持相同轮廓",
        "不得生成：文字、字母、数字、图标、投影底板、厚重外发光",
        "真实透明 PNG",
    ):
        self.assertIn(expected, prompt)
```

- [ ] **Step 4: Run the focused tests and verify RED**

Run:

```powershell
python -m unittest tests.test_mm_manifest.ManifestPlanningTests -v
```

Expected: the new tests fail because structured style fields and `ui_spec` are not validated or composed.

- [ ] **Step 5: Commit the tests**

```powershell
git add tests/test_mm_manifest.py
git commit -m "test: specify game-aware UI prompt contract"
```

### Task 2: Extend the JSON schema without breaking non-generating manifests

**Files:**
- Modify: `art_source/schemas/mm_art_manifest.schema.json`

- [ ] **Step 1: Add reusable schema definitions**

Add `$defs.styleEvidence` and `$defs.uiSpec`:

```json
"styleEvidence": {
  "type": "object",
  "additionalProperties": false,
  "required": ["source", "kind", "reason"],
  "properties": {
    "source": {"type": "string", "minLength": 1},
    "kind": {"enum": ["art_guide", "design_system", "runtime_screenshot", "runtime_asset", "accepted_manifest", "external_reference"]},
    "reason": {"type": "string", "minLength": 1}
  }
},
"uiSpec": {
  "type": "object",
  "additionalProperties": false,
  "required": ["purpose", "display_size", "content_safe_area", "layout", "negative"],
  "properties": {
    "purpose": {"type": "string", "minLength": 1},
    "display_size": {"type": "array", "prefixItems": [{"type": "integer", "minimum": 1}, {"type": "integer", "minimum": 1}], "minItems": 2, "maxItems": 2},
    "content_safe_area": {"type": "array", "items": {"type": "integer", "minimum": 0}, "minItems": 4, "maxItems": 4},
    "layout": {"type": "string", "minLength": 1},
    "state_contract": {"type": "string", "minLength": 1},
    "negative": {"type": "array", "items": {"type": "string", "minLength": 1}, "minItems": 1, "uniqueItems": true}
  }
}
```

- [ ] **Step 2: Extend `style` and `asset` properties**

Add optional schema properties while keeping the existing required pair for compatibility:

```json
"evidence": {"type": "array", "items": {"$ref": "#/$defs/styleEvidence"}},
"sprite_gen_contract": {"type": "string", "minLength": 1},
"visual_anchor": {"type": "string", "minLength": 1},
"comfort_constraints": {"type": "array", "items": {"type": "string", "minLength": 1}, "uniqueItems": true},
"avoid": {"type": "array", "items": {"type": "string", "minLength": 1}, "uniqueItems": true}
```

Add `"ui_spec": {"$ref": "#/$defs/uiSpec"}` to the asset properties. Conditional requirements remain in Python because they depend on `generation.enabled` and `kind`.

- [ ] **Step 3: Validate the schema syntax**

Run:

```powershell
python -m json.tool art_source/schemas/mm_art_manifest.schema.json > $null
```

Expected: exit code 0.

- [ ] **Step 4: Commit the schema**

```powershell
git add art_source/schemas/mm_art_manifest.schema.json
git commit -m "feat: describe UI prompt semantics in art manifest schema"
```

### Task 3: Implement validation and deterministic UI prompt composition

**Files:**
- Modify: `aiskill/mm-tools/mm_manifest.py`
- Test: `tests/test_mm_manifest.py`

- [ ] **Step 1: Add generated-image and UI-kind helpers**

Add near the constants:

```python
UI_KINDS = {"panel", "button", "icon", "bar", "decoration"}
PROJECT_EVIDENCE_KINDS = {
    "art_guide", "design_system", "runtime_screenshot", "runtime_asset", "accepted_manifest"
}


def _generated_assets(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        asset for asset in manifest.get("assets", [])
        if isinstance(asset, dict)
        and isinstance(asset.get("generation"), dict)
        and asset["generation"].get("enabled") is True
    ]
```

- [ ] **Step 2: Validate style evidence only when generation is enabled**

Inside `validate_manifest`, before the asset loop, inspect `style` when `_generated_assets(manifest)` is non-empty. Require non-empty `evidence`, `sprite_gen_contract`, `visual_anchor`, `comfort_constraints`, and `avoid`. Require at least one evidence item whose `kind` is in `PROJECT_EVIDENCE_KINDS`; an `external_reference` alone must fail with `style.evidence requires at least one project evidence source`.

- [ ] **Step 3: Validate UI engineering semantics**

For each enabled asset whose kind is in `UI_KINDS`, require `ui_spec` and its `purpose`, `display_size`, `content_safe_area`, `layout`, and non-empty `negative`. When an asset has more than one state, also require `state_contract`. Validate that each four-value safe-area inset is non-negative and does not consume the full display width or height.

- [ ] **Step 4: Add a focused prompt composer**

Add:

```python
def compose_prompt(manifest: dict[str, Any], asset: dict[str, Any], state: str | None) -> str:
    style = manifest["style"]
    generation = asset["generation"]
    ui = asset.get("ui_spec")
    lines = [
        f"为 Godot 游戏生成一个可直接使用的{asset['kind']}图片资源。",
        f"项目风格：{style['prompt_prefix']}。",
        f"视觉锚点：{style['visual_anchor']}。",
        f"资源功能：{asset['role']}。",
        generation["prompt"].strip().rstrip("。") + "。",
    ]
    if ui:
        width, height = ui["display_size"]
        left, top, right, bottom = ui["content_safe_area"]
        lines.extend([
            f"游戏内实际显示尺寸：{width}x{height} 像素。",
            f"用途：{ui['purpose']}。",
            f"布局：{ui['layout']}。",
            f"内容安全区：左 {left}px、上 {top}px、右 {right}px、下 {bottom}px。",
        ])
        if ui.get("state_contract"):
            lines.append(f"状态一致性：{ui['state_contract']}。")
    if state is not None:
        lines.append(f"当前输出状态：{state}。")
    lines.append("舒适度约束：" + "；".join(style["comfort_constraints"]) + "。")
    forbidden = [*style["avoid"], *(ui.get("negative", []) if ui else [])]
    lines.append("不得生成：" + "、".join(dict.fromkeys(forbidden)) + "。")
    lines.append("禁止任何可读或伪造的文字、字母、数字、签名和水印；文字由 Godot 字体系统绘制。")
    if generation["transparent"]:
        lines.append("输出为真实透明 PNG；禁止棋盘格、白底、纯色背景和背景底板。")
    return "\n".join(lines)
```

- [ ] **Step 5: Use the composer and expose prompt provenance in jobs**

Replace the comma-joined prompt construction in `build_jobs` with `compose_prompt`. Add these job fields:

```python
"sprite_gen_contract": manifest["style"].get("sprite_gen_contract"),
"style_evidence": manifest["style"].get("evidence", []),
"ui_spec": asset.get("ui_spec"),
```

Keep the generated command's explicit `--provider mm-api`, `--model gpt-image-2`, and native-alpha behavior unchanged.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run:

```powershell
python -m unittest tests.test_mm_manifest -v
```

Expected: all Manifest tests pass.

- [ ] **Step 7: Commit implementation**

```powershell
git add aiskill/mm-tools/mm_manifest.py tests/test_mm_manifest.py
git commit -m "feat: compose game-aware UI generation prompts"
```

### Task 4: Migrate the checked-in UI manifests

**Files:**
- Modify: `art_source/manifests/main_menu.json`
- Modify: `art_source/manifests/deck_builder.json`
- Modify: `art_source/manifests/battle_hud.json`
- Test: `tests/test_mm_manifest.py`

- [ ] **Step 1: Add a migration regression test**

```python
def test_checked_in_generating_manifests_use_game_aware_ui_contract(self):
    module = load_module()
    for name in ("main_menu.json", "deck_builder.json", "battle_hud.json"):
        manifest = module.load_manifest(ROOT / "art_source" / "manifests" / name)
        self.assertEqual([], module.validate_manifest(manifest, ROOT), name)
        if any(asset["generation"]["enabled"] for asset in manifest["assets"]):
            self.assertTrue(manifest["style"]["evidence"], name)
            self.assertEqual("sprite-gen/docs/gen.md", manifest["style"]["sprite_gen_contract"])
            for asset in manifest["assets"]:
                if asset["generation"]["enabled"] and asset["kind"] in module.UI_KINDS:
                    self.assertIn("ui_spec", asset, f"{name}:{asset['id']}")
```

- [ ] **Step 2: Run the migration test and verify RED**

Run:

```powershell
python -m unittest tests.test_mm_manifest.ManifestPlanningTests.test_checked_in_generating_manifests_use_game_aware_ui_contract -v
```

Expected: FAIL naming the first manifest without the new fields.

- [ ] **Step 3: Add shared project style data to each manifest**

Use project-local evidence such as `res://Design/Sunflower-Defense-Art-Style-Guide.md`, the relevant Godot runtime screenshot, and accepted feature records. Use this shared anchor:

```text
末日温室绘本风；深蓝黑和墨绿色低饱和底色，旧纸与暗色玻璃材质，纤细氧化黄铜边框，克制的暖金生命光，可见手绘笔触，装饰集中在边缘
```

Use comfort constraints that preserve clean centers, limit simultaneous highlights, and keep small-size UI readable. Use exclusions for modern technology HUD, neon cyberpunk, excessive glassmorphism, candy saturation, generated text, signatures, and watermarks.

- [ ] **Step 4: Add `ui_spec` to every enabled UI image asset**

Derive `display_size` from the target Control's runtime size, not the provider canvas. Derive `content_safe_area` from existing patch margins and text/icon placement. For state groups, require fixed geometry and describe only the allowed lighting or depression change. Do not add `ui_spec` to text assets or disabled generation entries.

- [ ] **Step 5: Validate and inspect every expanded plan**

Run:

```powershell
python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/main_menu.json
python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/deck_builder.json
python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json
python aiskill/mm-tools/mm_manifest.py plan art_source/manifests/main_menu.json
python aiskill/mm-tools/mm_manifest.py plan art_source/manifests/deck_builder.json
python aiskill/mm-tools/mm_manifest.py plan art_source/manifests/battle_hud.json
```

Expected: every validation exits 0; every plan includes project evidence, `sprite_gen_contract`, runtime semantics, exclusions, and the composed prompt. No command performs paid generation.

- [ ] **Step 6: Commit migrated manifests**

```powershell
git add art_source/manifests/main_menu.json art_source/manifests/deck_builder.json art_source/manifests/battle_hud.json tests/test_mm_manifest.py
git commit -m "feat: migrate UI manifests to game-aware prompts"
```

### Task 5: Update the mm-tools skill workflow

**Files:**
- Modify: `aiskill/mm-tools/SKILL.md`

- [ ] **Step 1: Add the style-profile gate to stage 1**

Document that stage 1 samples approved art guides, 1–3 Godot runtime screenshots, and 3–8 relevant runtime assets. Require evidence paths, a concrete visual anchor, comfort constraints, and explicit exclusions. State that external games may inform layout but never provide the target art style.

- [ ] **Step 2: Add the sprite-gen/UI prompt gate to stage 2**

Document these prompt layers in order:

```text
game resource purpose
runtime display size and safe area
project visual anchor
asset-specific composition and state contract
comfort constraints
project exclusions and AI-artifact exclusions
transparent-output instruction when applicable
```

State explicitly that `mm-tools` owns resource need and Godot semantics, while the installed `sprite-gen` image-generation contract owns provider-facing execution. Simple solid fills, gradients, regular strokes, and other Theme-drawable primitives should not become AI image jobs by default.

- [ ] **Step 3: Add group-consistency and comfort checks to stages 3 and 4**

Require matching geometry, light direction, edge handling, visual weight, and detail density across a state group. Require Godot runtime comparison with existing screens and reject excessive glow, saturation, texture, decoration, or persistent visual noise.

- [ ] **Step 4: Review the skill for contradictions**

Run:

```powershell
rg -n "style|prompt|sprite-gen|comfortable|舒适|reference|参考|外部" aiskill/mm-tools/SKILL.md
```

Expected: the four stages consistently identify project-local evidence as the art-style authority and `sprite-gen` as the execution contract; no section tells the model to copy external game art.

- [ ] **Step 5: Commit the skill update**

```powershell
git add aiskill/mm-tools/SKILL.md
git commit -m "docs: require game-aware UI prompts in mm-tools"
```

### Task 6: Final verification

**Files:**
- Verify: `aiskill/mm-tools/mm_manifest.py`
- Verify: `art_source/schemas/mm_art_manifest.schema.json`
- Verify: `art_source/manifests/main_menu.json`
- Verify: `art_source/manifests/deck_builder.json`
- Verify: `art_source/manifests/battle_hud.json`
- Verify: `tests/test_mm_manifest.py`

- [ ] **Step 1: Run the full Python test file**

```powershell
python -m unittest tests.test_mm_manifest -v
```

Expected: all tests pass.

- [ ] **Step 2: Run manifest validation for every checked-in manifest**

```powershell
Get-ChildItem art_source/manifests/*.json | ForEach-Object {
    python aiskill/mm-tools/mm_manifest.py validate $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "manifest validation failed: $($_.Name)" }
}
```

Expected: every manifest prints `valid:` and the command exits 0.

- [ ] **Step 3: Check diffs and secrets**

```powershell
git diff --check
rg -n "Authorization|api_key|SPRITE_GEN_MM_API_KEY" art_source/manifests aiskill/mm-tools tests
```

Expected: `git diff --check` exits 0; no secret value appears. Legitimate configuration-key names may remain in provider code, but manifests and reports contain no credential.

- [ ] **Step 4: Confirm no image generation occurred**

```powershell
git status --short art_source/generated assets/ui/generated
```

Expected: this implementation introduces no newly generated PNG or report files. Paid generation remains behind the existing explicit confirmation gate.

- [ ] **Step 5: Commit any verification-only corrections**

```powershell
git add aiskill/mm-tools/SKILL.md aiskill/mm-tools/mm_manifest.py art_source/schemas/mm_art_manifest.schema.json art_source/manifests/main_menu.json art_source/manifests/deck_builder.json art_source/manifests/battle_hud.json tests/test_mm_manifest.py
git commit -m "chore: verify mm-tools UI prompt pipeline"
```
