# Frostfox video generation status

The selected model is available in GET /v1/task-capabilities: minimax_h3_image_audio_to_video, one image, one required audio file, 6 seconds supported, 16:9, 768p, audio cannot be disabled, no reference_mode options.

POST /v1/tasks was attempted using the documented multipart protocol and an Idempotency-Key. No task ID was returned. Cloudflare returned HTTP 403 / 1010, browser_signature_banned, retryable=false, owner_action_required=true.

The site owner must remove the browser-signature restriction for the authorised API client before submission can resume. Do not work around it by changing signatures or clients. Ray ID: a441e3590e0584cf. Response timestamp: 2026-10-02T07:10:34Z.

No video has been generated or integrated. Existing Godot resources are unchanged. Both character inputs and prompts are prepared. run_frostfox_video_tasks.py reads credentials exclusively from FROSTFOX_API_KEY. On resumed requests, unchanged request parameters reuse the saved idempotency key. Modified requests use a new key.

After successful generation: use sprite-gen video-frames for canonical chroma removal, video-loop for full-cycle selection and motion QA, then integrate verified frames with native source timings.
