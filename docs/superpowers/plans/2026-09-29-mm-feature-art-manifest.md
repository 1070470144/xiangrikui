# MM Feature Art Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a versioned feature-level JSON art manifest that drives both `sprite-gen` jobs and safe Godot runtime UI binding.

**Architecture:** A JSON Schema defines the shared contract. A Python CLI validates manifests, expands generation jobs, invokes `sprite-gen`, and verifies PNG outputs. A focused GDScript loader reads the same manifest and applies supported textures, button states, and program-rendered text while preserving provisional UI on failure.

**Tech Stack:** Python 3.11 standard library, Pillow, `jsonschema`, Godot 4.7 GDScript, existing headless test runner.

---

### Task 1: Python Manifest Contract and Job Planning

**Files:**
- Create: `tests/test_mm_manifest.py`
- Create: `art_source/schemas/mm_art_manifest.schema.json`
- Create: `aiskill/mm-tools/mm_manifest.py`

- [ ] Write Python tests that load a minimal manifest and assert validation, disabled text omission, state expansion, duplicate-output rejection, and path-traversal rejection.
- [ ] Run `python -m unittest tests.test_mm_manifest -v` and confirm failure because `mm_manifest.py` does not exist.
- [ ] Add the version 1 JSON Schema and implement `load_manifest`, `validate_manifest`, and `build_jobs` with project-relative path enforcement.
- [ ] Re-run the focused Python tests and confirm they pass.

### Task 2: Generation and Verification Commands

**Files:**
- Modify: `tests/test_mm_manifest.py`
- Modify: `aiskill/mm-tools/mm_manifest.py`

- [ ] Add failing tests for fixed provider/model arguments, existing-file refusal, PNG dimensions, and alpha verification.
- [ ] Run the focused tests and confirm the expected failures.
- [ ] Implement `validate`, `plan`, `generate`, and `verify` subcommands. Require `--confirm` for generation, call `sprite-gen gen --provider mm-api --model gpt-image-2`, and never overwrite outputs.
- [ ] Re-run the focused tests and confirm they pass.

### Task 3: Godot Runtime Loader

**Files:**
- Create: `tests/test_art_manifest.gd`
- Modify: `tests/test_runner.gd`
- Create: `scripts/art_manifest.gd`
- Create: `tests/fixtures/art_manifest/runtime.json`
- Create: `tests/fixtures/art_manifest/test_texture.svg`

- [ ] Add a Godot suite asserting manifest parsing, text binding, direct texture binding, missing-node isolation, and unsupported-version rejection.
- [ ] Add the suite to `tests/test_runner.gd`, run the headless test command, and confirm failure because the loader is missing.
- [ ] Implement a stateless `ArtManifest.apply_file(path, scene_root)` API that returns warning strings rather than breaking the feature.
- [ ] Re-run the headless suite and confirm it passes.

### Task 4: Representative Feature Manifest and Rules

**Files:**
- Create: `art_source/manifests/battle_hud.json`
- Modify: `aiskill/mm-tools/SKILL.md`
- Modify: `tests/test_mm_manifest.py`

- [ ] Add a failing test that validates the checked-in `battle_hud.json` and confirms it includes generated UI assets plus non-generated text entries.
- [ ] Run the focused test and confirm failure because the example manifest is missing.
- [ ] Add the Battle HUD manifest using stable feature semantics and current resource paths.
- [ ] Rewrite `mm-tools` workflow so feature implementation creates the manifest before art generation; preserve confirmation, provider, secret-handling, and non-overwrite rules.
- [ ] Re-run Python tests and manifest validation.

### Task 5: Final Verification

**Files:**
- Review all files changed by Tasks 1-4.

- [ ] Run `python -m unittest tests.test_mm_manifest -v`.
- [ ] Run `python aiskill/mm-tools/mm_manifest.py validate art_source/manifests/battle_hud.json`.
- [ ] Run the complete Godot headless test suite from `README.md`.
- [ ] Run `git diff --check` and inspect the scoped diff for secrets, accidental generated output, and unrelated edits.
