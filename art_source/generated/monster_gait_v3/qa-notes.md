# Gait revision 3

Original eight-frame walks were rejected by the user for unnatural legs. New source: original project creature still + prepared eight-slot guide. Per-species phase constraints live in sprite-request.json, not hand-painted poses.

Shadow beast: four-legged gait, front/rear paw alternation; visible frame differences, stable identity. Stylized small-runtime candidate, not measured foot-contact/stride certification.

Erosion bug: first candidate failed anatomy because of elongated talons and shell-height changes; retained as walk-rejected-extra-claws.png. Retry uses short tapered legs, fixed shell and alternating insect support groups. Contact-sheet review found better shell stability and no added hand-like claws. Small leg sweep remains stylized; no claim of physically precise locomotion.

Both rows: eight frames at 12 fps, extraction and automated inspect succeed. Attack source reused from prior run. No locally drawn in-betweens or timing concealment. Previous full runs retained in monster_animations.

Runtime correction: walk phase integrates speed each update rather than recomputing from elapsed time multiplied by current speed, removing phase jumps under slow/buff changes. Attack duration now uses frame count/fps and reaches the final recovery pose. Tests cover speed-change continuity, slowed phase increments, final attack frame, facing and stun.

Additional runtime polish: the first render step after movement stops keeps the last grounded walk pose before returning to neutral, preventing a visible leg snap at target contact.
