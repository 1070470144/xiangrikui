"""Animate the approved menu background through the explicit Seedance API."""
import argparse
import base64
import json
import urllib.request
from pathlib import Path
from seedance_weather_video import request, BASE, MODEL

PROMPT = """为暗黑童话植物防守游戏《最后的向日葵》制作精致的主菜单背景循环动画。严格使用首帧图片的原有构图和全部美术设计，首尾帧为同一张图。镜头完全固定，无推拉、无平移、无旋转、无景别切换，不增添物体、文字或UI。破败玻璃温室的午夜，左侧金色向日葵是最后的光源，右侧深绿黑暗空间留给菜单，左上空白留给标题，保持这些区域暗而平静。花瓣和叶片仅被微风轻轻摇动，位移极小、花茎与根部牢牢固定，不变形、不生长、不更换花朵形状。花心温暖金色辉光缓慢轻微呼吸，亮度变化不超过百分之八，不闪烁。两三颗极小的金色花粉在花旁缓慢飘动，不能满屏粒子。地面贴地薄雾极慢流动，冷蓝月光穿过玻璃窗，月亮和温室骨架完全静止，湿润地面的细微反光轻轻流动。植物、道路、屋顶、月亮及所有物体保持原来位置和外观。只做环境微动，保持幽静、希望与守夜的氛围，暗部层次清晰、冷蓝月光与暖金向日葵形成对比。整个六秒是一段缓慢微动的完整呼吸周期，结尾自然回到开头状态，适合无限循环。禁止大风、大幅晃动、强光、闪电、雨滴、镜头运动、模糊和任何文字。无音频。"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["submit", "poll", "download"])
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--image", type=Path)
    args = parser.parse_args()
    args.run_dir.mkdir(parents=True, exist_ok=True)
    target = args.run_dir / "seedance.report.json"
    if args.action == "submit":
        if target.exists():
            raise SystemExit("Task already exists; poll it instead of submitting twice")
        if args.image is None or not args.image.is_file():
            raise SystemExit("An existing PNG first/last frame is required")
        data_url = "data:image/png;base64," + base64.b64encode(args.image.read_bytes()).decode()
        body = {"model": MODEL, "content": [{"type":"text", "text": PROMPT},
                    {"type":"image_url", "image_url":{"url":data_url}, "role":"first_frame"},
                    {"type":"image_url", "image_url":{"url":data_url}, "role":"last_frame"}],
                "generate_audio": False, "ratio": "16:9", "duration": 6,
                "watermark": False, "resolution": "720p"}
        reply = request("POST", BASE, body)
        if not reply.get("id"):
            raise SystemExit("Seedance returned no task ID")
        report = {"provider":"volcengine-seedance", "model": MODEL,
                  "task_id":reply["id"], "status":"submitted", "prompt":PROMPT,
                  "first_frame":str(args.image.resolve()), "last_frame":str(args.image.resolve()),
                  "duration_requested":6, "ratio":"16:9", "resolution":"720p"}
    else:
        report = json.loads(target.read_text(encoding="utf-8"))
        reply = request("GET", BASE + "/" + report["task_id"])
        report["status"] = reply.get("status", "unknown")
        if reply.get("error"):
            report["error_code"] = reply["error"].get("code", "unknown")
        for field in ("usage", "resolution", "duration", "ratio", "framespersecond"):
            if field in reply: report[field] = reply[field]
        if args.action == "download" and report["status"] == "succeeded":
            url = reply.get("content", {}).get("video_url")
            if not url or not url.startswith("https://"):
                raise SystemExit("No HTTPS video URL")
            with urllib.request.urlopen(url, timeout=120) as response:
                data = response.read()
            if data[4:8] != b"ftyp":
                raise SystemExit("Downloaded data is not MP4")
            video = args.run_dir / "main_menu.mp4"
            staging = video.with_suffix(".part")
            staging.write_bytes(data)
            staging.replace(video)
            report.update(video=str(video), bytes=len(data))
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("task_id", "status", "error_code", "video") if key in report}))


if __name__ == "__main__":
    main()
