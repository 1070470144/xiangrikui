"""Create one resumable Seedance acid-rain clip; never submit a second task."""
from __future__ import annotations
import base64, json, os, time, urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art_source/generated/weather/acid_rain_realism_v2"
API = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"
MODEL = "doubao-seedance-2-0-mini-260615"

def request(method: str, url: str, payload: dict | None = None) -> dict:
    key = os.environ.get("ARK_API_KEY")
    if not key: raise RuntimeError("ARK_API_KEY is required")
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as response: return json.load(response)

def reference() -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "reference-magenta.png"
    if path.exists(): return path
    image = Image.new("RGB", (768, 768), (255, 0, 255))
    draw = ImageDraw.Draw(image)
    # Neutral guide marks only help the model preserve a fixed impact plane;
    # they are outside the requested subject and are never used at runtime.
    draw.line((160, 575, 608, 575), fill=(255, 0, 255), width=1)
    image.save(path)
    return path

def main() -> None:
    folder = OUT
    ref = reference()
    task_file, marker, clip = folder / "task.json", folder / "submitted", folder / "acid_rain.mp4"
    if clip.exists(): print("clip already downloaded"); return
    if task_file.exists(): task_id = json.loads(task_file.read_text(encoding="utf-8"))["id"]
    else:
        if marker.exists(): raise RuntimeError("submission already attempted; resume task.json only")
        prompt = ("Fixed locked orthographic top-down camera for a premium dark fantasy garden-defense game VFX sprite. "
                  "Solid uniform pure magenta #FF00FF background on every frame, no scenery, no text, no watermark. "
                  "Create a clearly visible four-second seamless acid rain weather loop: many fine diagonal rain streaks at layered depths, "
                  "natural variation in speed and brightness, with restrained sickly yellow-green translucency. "
                  "Across the lower half, several small localized droplets strike an invisible wet ground plane and create realistic shallow acid crowns, "
                  "tiny outward splashes and brief wet reflective patches that fade naturally. The wet reflections are localized and transparent, never a full-screen glow. "
                  "Keep the rain readable at battlefield scale without obscuring units or the HUD. Start and end with matching density, impact timing and empty-space layout. "
                  "No camera motion, zoom, cuts, scene change, characters, large smoke clouds, neon aura, circular UI rings, geometric symbols, lightning or explosions. No audio.")
        (folder / "prompt.txt").write_text(prompt, encoding="utf-8")
        marker.write_text("One authorized video submission. Never delete this marker to retry.\n", encoding="utf-8")
        encoded = "data:image/png;base64," + base64.b64encode(ref.read_bytes()).decode()
        result = request("POST", API, {"model": MODEL, "content": [
            {"type":"text", "text":prompt},
            {"type":"image_url", "image_url":{"url":encoded}, "role":"first_frame"},
            {"type":"image_url", "image_url":{"url":encoded}, "role":"last_frame"}],
            "duration":4, "ratio":"1:1", "generate_audio":False, "watermark":False})
        task_id = result["id"]
        task_file.write_text(json.dumps({"id":task_id,"model":MODEL,"duration":4,"ratio":"1:1"}, indent=2), encoding="utf-8")
        print("submitted one authorized acid-rain task", flush=True)
    for _ in range(180):
        result = request("GET", API + "/" + task_id)
        status = result.get("status")
        (folder / "status.json").write_text(json.dumps({"id":task_id,"status":status,"error":result.get("error")}, indent=2), encoding="utf-8")
        if status == "succeeded":
            last_error = None
            for _attempt in range(3):
                try:
                    with urllib.request.urlopen(result["content"]["video_url"], timeout=120) as response: data = response.read()
                    break
                except Exception as error: last_error = error; time.sleep(3)
            else: raise RuntimeError("download failed: " + str(last_error))
            if b"ftyp" not in data[:32]: raise RuntimeError("response is not MP4")
            clip.write_bytes(data); print("downloaded acid-rain.mp4", flush=True); return
        if status in {"failed", "expired", "cancelled"}: raise RuntimeError("Seedance task " + str(status))
        time.sleep(10)
    raise RuntimeError("task still pending; rerun to resume without POST")

if __name__ == "__main__": main()
