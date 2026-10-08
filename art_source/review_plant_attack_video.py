"""Preview the published Godot atlases at their actual combat playback speed."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/effects/plants"
OUT = ROOT / "tmp/plant-attack-video-review"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    assets = []
    for name in ("vine", "pollen", "frost"):
        meta = json.loads((ASSETS / (name + ".strip.json")).read_text())
        runtime = json.loads((ASSETS / (name + ".runtime.json")).read_text())
        atlas = Image.open(ASSETS / (name + ".atlas.png")).convert("RGBA")
        cells = []
        for i in range(meta["frames"]):
            x = i % runtime["columns"] * meta["w"]
            y = i // runtime["columns"] * meta["h"]
            cells.append(atlas.crop((x, y, x + meta["w"], y + meta["h"])))
        assert len({cell.tobytes() for cell in cells}) >= 24, name + " lacks distinct motion frames"
        assert all(cell.getchannel("A").getextrema()[0] == 0 for cell in cells)
        assets.append((name, meta, runtime, cells))
    sequence = []
    for tick in range(60):
        canvas = Image.new("RGB", (800, 420), (32, 39, 36))
        draw = ImageDraw.Draw(canvas)
        for row, (name, meta, runtime, cells) in enumerate(assets):
            draw.text((20, row * 140 + 15), name, fill=(237, 242, 236))
            seconds = tick * 0.02
            if seconds >= runtime["duration"]:
                continue
            frame = cells[min(len(cells)-1, int(seconds / runtime["duration"] * len(cells)))].copy()
            frame.thumbnail((650, 105), Image.Resampling.LANCZOS)
            canvas.paste(frame, ((800-frame.width)//2, row*140+28), frame)
        sequence.append(canvas)
    sequence[14].save(OUT / "contact.png")
    sequence[0].save(OUT / "combat-speed.gif", save_all=True, append_images=sequence[1:],
                     duration=20, loop=0, disposal=2)
    print("PLANT_ATTACK_VIDEO_REVIEW_PASS")
    for name, meta, runtime, cells in assets:
        print(name, "frames", len(cells), "runtime seconds", runtime["duration"])


if __name__ == "__main__":
    main()
