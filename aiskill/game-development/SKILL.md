---
name: game-development
description: Use when building or extending a playable gameplay prototype inside an existing Godot project, especially when the request asks for comparable-game research, core-loop validation, level or spatial structure, placeholder visuals, or no production UI.
---

# Godot Gameplay Prototyping

Build the smallest playable Godot prototype that answers the user's gameplay question. Research informs the structure; a runnable scene and observed tests are the deliverable.

## Scope Contract

- Work in the existing Godot project and preserve its engine version, architecture, input conventions, and unrelated changes.
- Treat the requested feature as the boundary. Do not expand a prototype into a complete game or unrelated refactor.
- “No UI” means no production menus, HUD, inventory, settings, onboarding, or visual polish. A simple debug overlay is allowed only when it materially helps validation; keep it visually plain, default-off, and toggleable.
- Use primitives, solid colors, labels attached to world objects, particles, and other placeholders. Do not start an art-production workflow unless separately requested.

## Workflow

1. **Establish the baseline.** Inspect project files, project settings, main scene, input map, existing gameplay code, tests, design documents, and working-tree changes. Run the current project or headless checks before editing and record pre-existing failures.
2. **Define the playable question.** Express the feature as a short loop: player action → simulation response → feedback → success/failure or repeat. State the prototype entry scene, controls, end condition, restart path, and what evidence would answer the question.
3. **Research 3–5 genuine comparables.** Choose games similar in the requested mechanic, camera, spatial structure, or session loop—not merely genre labels. Use current, attributable sources and distinguish direct evidence from inference. For each game capture:
   - play-space and camera structure;
   - player start, traversal, encounter, spawn, objective, and failure layout;
   - pacing or state progression;
   - the transferable design principle;
   - what will deliberately not be copied.
4. **Synthesize before coding.** Produce a compact comparison and select one prototype structure. Explain which observations influenced the layout and which project constraints changed them. Borrow abstract principles only; never copy code, maps, art, characters, text, distinctive content, or exact tuning.
5. **Implement the vertical slice.** Prefer focused scenes/resources/scripts with explicit responsibilities. Build only the entities and systems required for one complete loop. Keep tunable gameplay values exported or data-driven where that matches the project.
6. **Make behavior readable without production UI.** Use world-space shape, color, motion, audio, hit flashes, spawn telegraphs, and state changes. The optional debug overlay may expose values such as phase, health, entity count, and test state, but must not become the primary gameplay feedback.
7. **Verify proportionally.** Add automated tests for deterministic rules before their implementation when the project supports tests. Run relevant tests, launch the actual prototype, play through success/failure/restart, check the debugger for errors, and confirm the comparison research visibly affected the result.

## Required Deliverables

- A runnable prototype scene integrated through a clear project entry point.
- A short `3–5 comparables → observed structure → adopted principle → rejected element` record.
- Controls, success/failure conditions, restart instructions, and important tuning locations.
- Exact verification commands and observed results, including pre-existing failures.
- Known limitations and the next gameplay question worth testing.

## Completion Gate

Do not call the work complete if it is only a design document, static scene, scripted demonstration, or unrun test suite. Completion requires a human-controllable core loop, meaningful simulation response, readable feedback, a reachable failure or completion state, a working replay/restart path, and evidence from both automated checks and an actual Godot run.

## Common Failure Modes

- Picking famous genre examples without studying spatial or systemic similarity.
- Listing references after implementation without showing how they changed the prototype.
- Building formal UI to compensate for unclear world feedback.
- Hard-coding a cinematic demo instead of implementing interactive rules.
- Adding progression, content, polish, or architecture that the playable question does not require.
- Claiming success from source inspection alone.
