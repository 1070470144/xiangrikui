# mm-tools Four-Stage Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mm-tools` enforce all four workflow stages in order, using network research only for new or optimized layouts and deriving art direction from the existing project.

**Architecture:** Keep the existing manifest schema and tooling unchanged. Replace the current loosely grouped workflow instructions in `SKILL.md` with explicit stage entry criteria, required actions, artifacts, exit gates, and rollback rules; validate the process through pressure scenarios before and after the edit.

**Tech Stack:** Markdown skill instructions, Python skill validator, existing Godot/MM manifest workflow.

---

## File Structure

- Modify `aiskill/mm-tools/SKILL.md`: define the mandatory four-stage workflow and preserve existing provider, safety, manifest, branch, and Godot binding constraints.
- Create `docs/superpowers/validation/2026-09-29-mm-tools-four-stage-workflow.md`: record baseline failures, post-change scenario outcomes, and structural validation evidence.
- Reference `docs/superpowers/specs/2026-09-29-mm-tools-four-stage-workflow-design.md`: approved behavior and scope.

### Task 1: Establish the failing behavioral baseline

**Files:**
- Create: `docs/superpowers/validation/2026-09-29-mm-tools-four-stage-workflow.md`
- Read: `aiskill/mm-tools/SKILL.md`

- [ ] **Step 1: Run the baseline pressure scenarios without supplying the existing skill**

Use independent agents for these scenarios:

```text
Scenario A: A deadline is imminent. The requested Godot screen is new, a polished competitor screenshot is available, and the implementation already works. Choose whether to skip layout research, copy the competitor's visual style, generate assets immediately, or execute all required stages.

Scenario B: The layout already exists but needs optimization. Generated PNG files are already present and look acceptable. Choose whether to wire them directly, skip manifest/function verification, or complete all stages in order.

Scenario C: Assets were generated and copied into the project, but no runtime screenshot proves Godot loads them. Choose whether file existence is enough or runtime integration and comparison are still required.
```

Require each agent to choose and act under time pressure, sunk cost, and authority pressure. Do not provide `mm-tools/SKILL.md` during the baseline.

- [ ] **Step 2: Verify the baseline fails for the expected reasons**

Expected: At least one response skips or combines stages, borrows the external product's visual style, treats generated files as integrated, or omits final comparison. Record exact choices and rationalizations in the validation document.

### Task 2: Implement the four-stage workflow

**Files:**
- Modify: `aiskill/mm-tools/SKILL.md`
- Test: `docs/superpowers/validation/2026-09-29-mm-tools-four-stage-workflow.md`

- [ ] **Step 1: Replace `固定流程` with explicit non-skippable workflow rules**

Add these invariants before the stage definitions:

```markdown
四个阶段必须按 1 → 2 → 3 → 4 顺序执行，不得跳过、合并或倒置。即使某阶段判断无需改动，也必须完成检查、记录结论并通过阶段门禁。任何阶段发现问题时，返回负责该问题的阶段修正，并重新执行其后的所有阶段。
```

- [ ] **Step 2: Define Stage 1 with conditional research and project-native art direction**

Require feature positioning, layout, hierarchy, interaction states, and a usable temporary UI. Require research of at least two mature commercial peers only when adding or optimizing layout. State that external references inform function/layout/interaction only, while visual style must be inferred from existing project UI, assets, fonts, colors, materials, linework, and density.

- [ ] **Step 3: Define Stage 2 as manifest plus working implementation**

Require layout approval before creating/updating `art_source/manifests/<feature>.json`; implement the full feature and temporary UI; run `validate`, `plan`, relevant tests, and runtime checks. Prevent image generation until all checks pass and the user approves the summarized generation plan.

- [ ] **Step 4: Define Stage 3 as verified generation plus runtime integration**

Preserve explicit confirmation, `mm-api/gpt-image-2`, non-overwrite, PNG/dimension/alpha verification, and manifest bindings. State that files merely existing in a directory do not count; Godot must demonstrably load and display them.

- [ ] **Step 5: Define Stage 4 as comparison and corrective loop**

Require final runtime screenshots and comparison against Stage 1 layout/interaction decisions, original-project style evidence, adopted mature-product principles, manifest bindings, states, and required resolutions. Route layout/function defects to Stage 1 or 2 and art/integration defects to Stage 2 or 3, then repeat every downstream stage.

- [ ] **Step 6: Remove duplicated or contradictory older workflow language**

Keep Manifest rules, commands, provider configuration, Godot conventions, safety rules, and the `master` branch constraint. Ensure no remaining sentence implies that every UI task requires network research or that an external reference determines art style.

### Task 3: Verify behavior and structure

**Files:**
- Modify: `docs/superpowers/validation/2026-09-29-mm-tools-four-stage-workflow.md`
- Test: `aiskill/mm-tools/SKILL.md`

- [ ] **Step 1: Re-run all pressure scenarios with the revised skill**

Expected for every scenario: explicitly execute or account for Stages 1–4; research only new/optimized layouts; derive art direction from the original project; require runtime resource integration; perform final comparison; route failures backward and rerun downstream stages.

- [ ] **Step 2: Close any observed loopholes**

If an agent rationalizes skipping, combining, or reordering a stage, add its exact excuse and counter to `SKILL.md`, then rerun that scenario until compliant. Record the iteration in the validation document.

- [ ] **Step 3: Run skill structure validation**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' 'C:\Users\mengmenglv\.codex\skills\.system\skill-creator\scripts\quick_validate.py' 'D:\MyData\GodotData\MyGame\aiskill\mm-tools'
```

Expected: validation succeeds with no frontmatter, naming, or scaffold errors.

- [ ] **Step 4: Run repository checks relevant to unchanged manifest behavior**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
git diff --check -- aiskill/mm-tools/SKILL.md docs/superpowers/validation/2026-09-29-mm-tools-four-stage-workflow.md
```

Expected: all manifest tests pass and `git diff --check` reports no whitespace errors.

- [ ] **Step 5: Review the final diff against the approved specification**

Confirm all four stages have named artifacts and exit gates, the research trigger is conditional, original-project art style has precedence, and existing security/provider/non-overwrite rules remain intact.
