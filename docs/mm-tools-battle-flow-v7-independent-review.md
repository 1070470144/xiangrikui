# Battle flow V7 independent runtime review

Date: 2026-10-02. Branch: master. No paid generation, commit or push.

The independent test is `tests/test_day_night_flow_independent.gd`. It loads the actual game into a 1280×720 Godot SubViewport. Loadout opening, plant toggles, confirmation, cancellation and damaged-node clicking use `SubViewport.push_input` mouse events; keyboard deployment guards use actual InputEventAction routing. The test does not emit UI signals. Day/night lifecycle and direct-call security checks invoke the model APIs separately.

Command: Godot 4.7.2 console, `--headless --path . --script tests/test_day_night_flow_independent.gd`.

Final output: `DAY_NIGHT_INDEPENDENT checks=117 failures=0`, exit code 0. Windows root-certificate-store warning is environmental; no GDScript parse or runtime errors occurred.

Verified:

- Initial day draws no tactical cards; imported outside selected deck survives `_ready` and reset.
- First numbered night draws four cards; following numbered nights add two without replacing retained cards. Consuming a card does not draw a replacement. Card conservation, draw-pile exhaustion, no reshuffle and no mulligan are enforced.
- Sixth numbered night grants its allotment once before entering its existing resupply daytime. Seventh night grants one subsequent allotment. Empty piles remain empty.
- Day displays only deployment and carried-plant adjustment. Night displays only tactical cards and cannot change carried plants.
- Real pointer confirmation applies the draft, cancellation preserves the committed selection, and empty confirmation is disabled. Every later day offers the adjustment entry. Duplicate, empty and tactical IDs are rejected as plant loadouts.
- Loadout changes preserve already planted flowers. Lantern, frost and honeydew deployments create their matching Plant.Kind rather than the shifted Selection enum value.
- Any-phase tactical metadata cannot bypass the daytime gameplay guard. Transplant is usable at night and no longer a stranded day-only tactical card.
- Night thorn, prism and light-sprout keyboard actions cannot arm deployment. Direct night plant/light-node deployment leaves actors, seeds and light energy unchanged. Actual night pointer clicking on a damaged node neither repairs it nor spends light energy.

Review found and implementations corrected: modal cards moving away from pointer clicks due to fan hover behavior; extended flower Selection/Plant.Kind mismatch; nonexistent artwork constants; and night damaged-node click repair bypass. The repair assertion isolates pointer effects by disabling autonomous honeydew healing in the fixture, avoiding a false failure from its legitimate eight-point heal.

This review covers function and actual input routing. Final visual review and three-resolution Godot captures are recorded separately in `docs/mm-tools-battle-flow-v7-ui.md`.

## Accumulated twelve-card access follow-up

The required maximum retained hand introduces tighter overlap than the earlier five-card fan. A focused independent test, `tests/test_twelve_card_access_independent.gd`, runs the live game at 1152×648 and routes real mouse motion, press and release events through Godot. All twelve exact Control instances, including duplicate IDs, expose a reachable pointer area, retain stable raised hover through jitter and hand refresh, start native drag on the same instance, and return to the hand without resource spending or consumption. Other copies never enter drag state, and the source identity remains stable.

Command: `--headless --path . --script tests/test_twelve_card_access_independent.gd`. Final output: `TWELVE_CARD_ACCESS_INDEPENDENT instances=12 failures=0`, exit code 0. No unresolved input-access differences remain.
