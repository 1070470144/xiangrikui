# Battle UI V5 generation, stage 3 partial result

The user approved two master-image calls on 2026-09-30: navy status frame and vertical botanical card. Installed sprite-gen 2.11.0 used explicit openai provider, gpt-image-2, and the approved gateway. Credentials stayed in process environment.

The initial sandbox invocation could not establish TCP (PermissionError errno 13). A read-only GET under approved escalated access returned HTTP 200. The two real requests then ran with approved network access. No paid retry or extra call was made.

- Header: successful sprite-gen native alpha report. Requested 1536x512; gateway returned 2048x768. Raw preserved unchanged. Alpha-transparent percentage 48.61, no stale transparent RGB pixels in verified output. Manifest master normalized to 768x256. Runtime derivative uses the immutable raw alpha bounds [16,165,2032,577], uniformly scaled corners and stretched quiet centers, padded to 304x88. Runtime derivative check passed.
- Card: server returned RGB with drawn checkerboard. sprite-gen native-alpha gate rejected it. No success report or verified master exists. Rejected candidate preserved as `art_source/generated/mm_tools/battle_ui_v5/vertical_botanical_card.rejected_rgb.png`. The non-uniform simulated transparency cannot be accepted as native alpha or repaired through canonical single-color chroma removal.

`mm_manifest.py verify art_source/manifests/battle_ui_v5.json` reports only the missing vertical_botanical_card. `process_battle_ui_v5.py --available-only --check` passes for the available header and preserved navy palette derivatives. The four card states remain native fallback. The complete two-resource stage 3 gate has not passed and stage 4 cannot be declared complete. One additional card request requires a new explicit paid-batch confirmation; no additional request has been made.

## Proposed next paid batch (not executed)

One call only: vertical_botanical_card, openai provider through the same approved gateway, gpt-image-2, 3:4 source ratio, native PNG alpha. Header remains the already verified existing output and must not be regenerated. Revised prompt explicitly requires exterior alpha=0 instead of painted checkerboard and paper upper boundary at exactly 121/218 (55.5%) of the card silhouette, matching native title/description slots. Runtime derivation additionally measures the actual paper transition and fits the two quiet regions to the declared slots without stretching corners. The original executed prompt and usage are retained in the successful header report; original rejected card is retained as evidence. The revised manifest is validated, but this next call still requires user confirmation.
