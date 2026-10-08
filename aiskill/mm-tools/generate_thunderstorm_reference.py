"""Generate the thunderstorm visual anchor through the configured Images gateway."""
import argparse
import os
import subprocess
import sys
from pathlib import Path

PROMPT = """为《最后的向日葵》俯视角2D温室防守游戏生成一张雷雨夜视觉参考图。严格保持现有战场的开阔构图、环形战场和暗绿植物防守美术风格；只增强真实的分层积雨云、远处雨幕、冷蓝夜色和一条短暂自然分叉闪电。雷光有真实曝光回闪但不刺眼，中心战斗区域和单位保持清晰，右上 HUD 安全区保持低对比暗部。画面无文字、无 UI 新元素、无水印、无人物，不改变建筑、道路、植物和战场物件的位置。自然纪录片质感，游戏可读性优先，16:9。"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sprite-gen-root", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--reference", type=Path, action="append", default=[])
    args = parser.parse_args()
    python = args.sprite_gen_root / ".venv" / "Scripts" / "python.exe"
    if not python.is_file():
        raise SystemExit(f"sprite-gen interpreter missing: {python}")
    command = [str(python), str(Path(__file__).with_name("sprite_gen_gateway.py")),
               "--sprite-gen-root", str(args.sprite_gen_root),
               "--api-base", "https://newapi.oairegbox.cc/v1", "--",
               "gen", "--provider", "openai", "--model", "gpt-image-2",
               "--prompt", PROMPT, "--aspect-ratio", "16:9", "--quality", "high",
               "--out", str(args.out)]
    if args.report:
        command += ["--report", str(args.report)]
    for reference in args.reference:
        command += ["--ref", str(reference)]
    env = os.environ.copy()
    if not env.get("OPENAI_API_KEY"):
        raise SystemExit("OPENAI_API_KEY is required; no request was sent")
    return subprocess.run(command, cwd=args.sprite_gen_root, env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
