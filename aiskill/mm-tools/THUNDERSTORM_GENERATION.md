# Thunderstorm asset runbook

The generation path is intentionally explicit and single submission. Set the
credentials only in the current process; do not put either key in a file or
command argument.

```powershell
$env:OPENAI_API_KEY = '<newapi-key>'
$env:ARK_API_KEY = '<volcengine-key>'
$skill = 'C:\Users\刘冉\.codex\skills\sprite-gen'
$run = 'D:\mm\data\xiangrikui\art_source\generated\weather\thunderstorm_realism_v1'
$py = "$skill\.venv\Scripts\python.exe"

& $py xiangrikui/aiskill/mm-tools/generate_thunderstorm_reference.py `
  --sprite-gen-root $skill `
  --out "$run\battle-reference.png" `
  --report "$run\battle-reference.report.json"

& $py xiangrikui/aiskill/mm-tools/seedance_weather_video.py submit `
  --run-dir $run --reference "$run\battle-reference.png"
# Poll until status is succeeded, then download once:
& $py xiangrikui/aiskill/mm-tools/seedance_weather_video.py poll --run-dir $run
& $py xiangrikui/aiskill/mm-tools/seedance_weather_video.py download --run-dir $run

& $py xiangrikui/aiskill/mm-tools/build_thunderstorm_asset.py `
  --clip "$run\thunderstorm.mp4" --run-dir $run `
  --project-root D:\mm\data\xiangrikui --sprite-gen-root $skill
```

The final publish step refuses incomplete extraction, non-RGBA frames, empty
alpha, or a failed SpriteGen loop report. The Godot runtime continues using its
procedural lightning path whenever `lightning.json` is absent or `qa_passed` is
false.
