"""Seedance transport for the thunderstorm overlay; keys stay in the environment."""
import argparse
import json
import os
import time
from pathlib import Path
import urllib.request
import urllib.error

BASE = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"
MODEL = "doubao-seedance-2-0-mini-260615"
PROMPT = """为俯视角2D温室防守游戏制作一段真实、克制的雷雨天气闪电覆盖特效。固定镜头，纯色洋红色背景 #FF00FF，全程背景必须单一均匀，不得出现渐变、地面、场景、文字、UI、水印、人物或其它物体。画面中央到上方是分层积雨云的半透明暗影质感，仅作为闪电的载体，不要画出完整天空背景。0.35秒内完成一次自然的远近层次闪电事件：约0.06秒极弱预闪，随后一条真实分叉主闪电和一到两条细小支线瞬间出现，带轻微冷白蓝色环境回闪，最后自然衰减；闪电边缘锐利、分叉不规则、亮度有真实曝光变化，不要卡通霓虹，不要重复几何图案。特效集中在画面中央宽度70%区域并保留四边空白，避免覆盖游戏单位和HUD。无音频，镜头不动、不缩放、不平移，首尾回到纯洋红背景。"""


def request(method, url, body=None):
    key = os.environ.get("ARK_API_KEY", "")
    if not key:
        raise SystemExit("ARK_API_KEY is required")
    headers = {"Content-Type": "application/json", "Authorization": "Bearer " + key}
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body else None,
                                 headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        # Never print raw service bodies (they may contain credentials or prompts).
        try:
            code = json.load(exc).get("error", {}).get("code", "unknown")
        except Exception:
            code = "unknown"
        raise SystemExit(f"Seedance HTTP {exc.code}, error code {code}")


def _read_report(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"Missing task report: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _save_report(path: Path, report: dict) -> None:
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["submit", "poll", "download"])
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--reference", type=Path, help="Optional gpt-image-2 reference PNG")
    parser.add_argument("--poll-seconds", type=float, default=0.0,
                        help="Sleep before polling; one-shot by default")
    args = parser.parse_args()
    args.run_dir.mkdir(parents=True, exist_ok=True)
    report_path = args.run_dir / "seedance.report.json"
    if args.action == "submit":
        if report_path.exists():
            raise SystemExit("Existing task report: poll it instead of submitting twice")
        content = [{"type": "text", "text": PROMPT}]
        if args.reference:
            if not args.reference.is_file():
                raise SystemExit(f"Reference image does not exist: {args.reference}")
            import base64
            data_url = "data:image/png;base64," + base64.b64encode(args.reference.read_bytes()).decode()
            content.append({"type": "image_url", "image_url": {"url": data_url},
                            "role": "reference_image"})
        body = {"model": MODEL, "content": content,
                "generate_audio": False, "ratio": "16:9", "duration": 4,
                "watermark": False, "resolution": "720p"}
        reply = request("POST", BASE, body)
        task_id = reply.get("id")
        if not task_id:
            raise SystemExit("Seedance returned no task ID")
        report = {"provider": "volcengine-seedance", "model": MODEL,
                  "task_id": task_id, "status": "submitted", "request": body,
                  "duration_requested": 4, "ratio": "16:9", "resolution": "720p"}
        _save_report(report_path, report)
        print(json.dumps({"task_id": task_id, "status": "submitted"}))
        return
    report = _read_report(report_path)
    if args.poll_seconds:
        time.sleep(max(0.0, args.poll_seconds))
    reply = request("GET", BASE + "/" + report["task_id"])
    report["status"] = reply.get("status", "unknown")
    if reply.get("error"):
        report["error_code"] = reply["error"].get("code", "unknown")
    for field in ("usage", "resolution", "duration", "ratio", "framespersecond"):
        if field in reply:
            report[field] = reply[field]
    if args.action == "download" and report["status"] == "succeeded":
        url = reply.get("content", {}).get("video_url")
        if not url or not url.startswith("https://"):
            raise SystemExit("No HTTPS video URL in successful task")
        # Signed download URLs never receive the generation Authorization header.
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read()
        if data[4:8] != b"ftyp":
            raise SystemExit("Downloaded data is not MP4")
        target = args.run_dir / "thunderstorm.mp4"
        staging = target.with_suffix(".part")
        staging.write_bytes(data)
        staging.replace(target)
        report["video"] = str(target)
        report["bytes"] = len(data)
    _save_report(report_path, report)
    print(json.dumps({key: report[key] for key in ("task_id", "status", "error_code", "video") if key in report}))


if __name__ == "__main__":
    main()
