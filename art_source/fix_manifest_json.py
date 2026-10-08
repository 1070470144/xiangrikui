import json
from pathlib import Path

for path in (Path(__file__).resolve().parents[1] / "assets/enemies/animations").glob("*/manifest.json"):
    text = path.read_text(encoding="utf-8")
    while text.endswith("\\n"):
        text = text[:-2]
    while text.count("}") > text.count("{"):
        text = text[:-1]
    data = json.loads(text)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
