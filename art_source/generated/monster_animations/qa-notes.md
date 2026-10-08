# Motion QA

- Shadow beast walk: rejected initial repeated crouch; regenerated distinct extended, planted and lifted paws. Eight-frame, 12 fps gait with alternating paw contacts and smaller adjacent pose changes; accepted for current game scale.
- Shadow beast attack: eight-frame, 12 fps anticipation, coil, jaw opening, bite, recoil and recovery; identity stable.
- Erosion bug walk: eight-frame, 12 fps alternating forelegs and hind legs, stable carapace and smoother creeping loop.
- Erosion bug attack: eight-frame, 12 fps mandible extension/opening, bite and recovery.
- All frames are nonempty and fully contained. Canonical extraction and inspection passed without warnings. No local pose drawing or timing repair was used.
- Locomotion remains stylized rather than physically measured. References are original project creature stills plus the generated layout guides; no extra motion references.

