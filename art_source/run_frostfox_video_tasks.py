"""Submit Frostfox video.generate tasks and download successful artifacts.

The API key is read only from FROSTFOX_API_KEY. No key is written to disk.
"""
from __future__ import annotations
import json, os, sys, time, uuid, urllib.request, urllib.error, wave
from urllib.parse import urlsplit
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT / "art_source/generated/monster_video_frostfox"
API = "https://market.frostfox.ai/v1"
KEY = os.environ.get("FROSTFOX_API_KEY", "").strip()
if not KEY:
    raise SystemExit("FROSTFOX_API_KEY is required in the process environment")

PROMPTS = {
    "shadow_beast": ("Animate the supplied shadow beast reference into a polished game animation video. "
        "Locked camera, fixed side view facing right, full body centered on a flat pure green background. "
        "Perform two complete natural in-place quadruped walking cycles like a high quality action RPG creature: "
        "clear weight transfer, stable planted front and hind paws, low recovery arcs, rolling shoulders, hip counterbalance, "
        "subtle spine flex and restrained tail counter-motion. Keep exactly four legs with fixed joints and proportions. "
        "No camera motion, no zoom, no extra limbs, no morphing, no foot skating, no hopping, no scenery, no text, no blur."),
    "erosion_bug": ("Animate the supplied erosion bug reference into a polished game animation video. "
        "Locked camera, fixed side view facing right, full body centered on a flat pure green background. "
        "Perform two complete natural in-place insect crawl cycles like a high quality action RPG creature: "
        "fixed rigid shell and head, six short jointed legs with alternating tripod support, three grounded legs throughout, "
        "small smooth planted-foot travel and low recovery arcs. Preserve the exact carapace, mandibles and leg attachment points. "
        "No extra claws, no hands, no talons, no limb morphing, no shell bounce, no hovering, no scenery, no text, no blur."),
}

def silent_wav(path: Path, seconds: int = 6) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
        w.writeframes(b"\0\0" * 16000 * seconds)

def multipart(parts: list[tuple[str, str | None, bytes, str]]) -> tuple[bytes, str]:
    boundary = "----FrostFoxBoundary" + uuid.uuid4().hex
    chunks: list[bytes] = []
    for field, filename, data, mime in parts:
        disposition = f'form-data; name="{field}"'
        if filename is not None:
            disposition += f'; filename="{filename}"'
        chunks.append(f"--{boundary}\r\nContent-Disposition: {disposition}\r\nContent-Type: {mime}\r\n\r\n".encode())
        chunks.append(data); chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode())
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"

def call(method: str, path: str, data: bytes | None = None, content_type: str | None = None, idem: str | None = None):
    headers = {"Authorization": f"Bearer {KEY}", "Accept": "application/json"}
    if content_type: headers["Content-Type"] = content_type
    if idem: headers["Idempotency-Key"] = idem
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            raw = r.read()
            return r.status, json.loads(raw.decode("utf-8")) if raw else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        diagnostic = {"http_status": e.code, "path": path,
                      "ray_id": e.headers.get("cf-ray"), "client": "Python urllib (default signature)"}
        try:
            error = json.loads(body)
            for field in ("title", "detail", "error_code", "error_name", "retryable", "owner_action_required", "ray_id", "timestamp"):
                if field in error: diagnostic[field] = error[field]
        except (ValueError, TypeError):
            diagnostic["response_summary"] = "Non-JSON error response; raw body not logged"
        ROOT.mkdir(parents=True, exist_ok=True)
        (ROOT / "last-http-error.json").write_text(json.dumps(diagnostic, indent=2), encoding="utf-8")
        print(json.dumps(diagnostic), flush=True)
        if e.code == 403:
            raise RuntimeError("Frostfox HTTP 403: access denied. Stop; contact the service owner. No automatic retry.") from e
        raise RuntimeError(f"Frostfox HTTP {e.code} at {path}; no automatic retry") from e

def submit(name: str) -> Path:
    out = ROOT / name; out.mkdir(parents=True, exist_ok=True)
    prompt_file = out / "video-prompt.txt"; prompt_file.write_text(PROMPTS[name], encoding="utf-8")
    still = out / "input-green.png"
    audio = out / "silent-reference.wav"; silent_wav(audio)
    request_obj = {"operation":"video.generate", "model":"minimax_h3_image_audio_to_video",
        "input":{"prompt":PROMPTS[name]},
        "parameters":{"duration_seconds":6,"aspect_ratio":"16:9","resolution":"768p","generate_audio":True}}
    request_json = json.dumps(request_obj, ensure_ascii=False).encode()
    body, ctype = multipart([("request", None, request_json, "application/json"),
                             ("reference", still.name, still.read_bytes(), "image/png"),
                             ("audio", audio.name, audio.read_bytes(), "audio/wav")])
    saved_request = out / "task-request.json"
    previous = json.loads(saved_request.read_text(encoding="utf-8")) if saved_request.exists() else {}
    same_request = {k:v for k,v in previous.items() if k != "idempotency_key"} == request_obj
    idem = previous["idempotency_key"] if same_request else str(uuid.uuid4())
    (out / "task-request.json").write_text(json.dumps({**request_obj, "idempotency_key": idem}, indent=2), encoding="utf-8")
    status, reply = call("POST", "/tasks", body, ctype, idem)
    (out / "task-created.json").write_text(json.dumps(reply, indent=2, ensure_ascii=False), encoding="utf-8")
    task_id = reply.get("task_id") or reply.get("id")
    if not task_id: raise RuntimeError(f"No task id returned for {name}")
    for _ in range(120):
        _, state = call("GET", f"/tasks/{task_id}")
        state_name = str(state.get("status", "")).lower()
        print(name, task_id, state_name, flush=True)
        if state_name == "success":
            (out / "task-success.json").write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
            artifacts = state.get("artifacts") or []
            video = next((a for a in artifacts if str(a.get("media_type", "")).startswith("video/") or str(a.get("type", "")).startswith("video")), None)
            if video is None and artifacts: video = artifacts[0]
            if not video: raise RuntimeError(f"No artifact in successful {name} task")
            url = video.get("url")
            if not url: raise RuntimeError(f"No artifact URL in successful {name} task")
            if url.startswith("/"): url = "https://market.frostfox.ai" + url
            parsed = urlsplit(url)
            if parsed.scheme != "https": raise RuntimeError("Artifact must use HTTPS")
            headers = {"Authorization": f"Bearer {KEY}"} if parsed.hostname == "market.frostfox.ai" else {}
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=180) as r: data = r.read()
            media_type = str(video.get("media_type", ""))
            suffix = ".mp4" if media_type in {"video/mp4", ""} else ".webm" if media_type == "video/webm" else ".video"
            clip = out / ("walk" + suffix); clip.write_bytes(data)
            (out / "artifact.json").write_text(json.dumps({k:v for k,v in video.items() if k != "url"}, indent=2, ensure_ascii=False), encoding="utf-8")
            return clip
        if state_name in {"failed", "error", "cancelled", "expired"}: raise RuntimeError(f"{name} task failed: {state}")
        time.sleep(5)
    raise TimeoutError(f"Timed out waiting for {name} task")

if __name__ == "__main__":
    for name in (sys.argv[1:] or list(PROMPTS)):
        submit(name)
