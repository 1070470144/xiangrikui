"""Submit exactly one Seedance lightning request and record its lifecycle.

The API key is intentionally read only from ARK_API_KEY. This script never
retries a submitted task; rerunning it polls the existing task instead.
"""
from __future__ import annotations

import json, os, sys, time
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent / "generated" / "weather" / "thunderstorm_realism_v1"
TASK = ROOT / "task.json"
PROMPT = ("Fixed orthographic top-down game weather plate on a pure magenta background. "
          "Distant layered storm clouds with one brief forked lightning flash, realistic "
          "cinematic rain-night lighting, restrained blue-white illumination. No characters, "
          "text, UI, camera movement, white screen, geometric halo or smoke. Keep cloud mass "
          "subtle and return to the same pose for a clean short loop.")

def call(payload: dict) -> dict:
    key = os.environ.get("ARK_API_KEY")
    if not key:
        raise RuntimeError("ARK_API_KEY is not set")
    req = Request("https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks",
                  data=json.dumps(payload).encode("utf-8"), method="POST",
                  headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    with urlopen(req, timeout=60) as response:
        return json.load(response)

def main() -> int:
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "prompt.txt").write_text(PROMPT, encoding="utf-8")
    if TASK.exists():
        print("Existing task.json found; no second paid request will be submitted.")
        return 0
    record = {"submitted": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
              "model": "doubao-seedance-2-0-mini-260615", "duration": 4,
              "ratio": "1:1", "generate_audio": False, "watermark": False,
              "prompt": PROMPT, "status": "submitting"}
    TASK.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        result = call({"model": record["model"], "content": [{"type": "text", "text": PROMPT}],
                       "generate_audio": False, "ratio": "1:1", "duration": 4, "watermark": False})
        record.update({"status": "submitted", "response": result})
        TASK.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except Exception as exc:
        record.update({"status": "failed", "error": str(exc)})
        TASK.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
        print(str(exc), file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
