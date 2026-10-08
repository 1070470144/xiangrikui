"""Create smoke-in-video monster walks, then sprite-gen extracts them again."""
import io
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art_source/generated/monster_video_batch"
SMOKE = ROOT / "assets/core/generated/monster_smoke_animation"
IDS = ["erosion_bug", "husk_ram", "spore_moth", "shell_scarab"]


def puff(i: int, size: tuple[int, int]) -> Image.Image:
    p = Image.open(SMOKE / f"puff-{i % 12:02d}.png").convert("RGBA")
    p.thumbnail((round(size[0] * 0.27), round(size[1] * 0.14)), Image.Resampling.LANCZOS)
    # Neutralize the source puff so chroma-key spill cannot tint the smoke green.
    alpha = p.getchannel("A")
    neutral = ImageOps.colorize(p.convert("L"), black=(46, 47, 44), white=(196, 198, 190)).convert("RGBA")
    neutral.putalpha(alpha)
    p = neutral
    p = p.filter(ImageFilter.GaussianBlur(1.8))
    # Semi-transparent pixels blend with the chroma background in a video;
    # threshold the soft alpha so sprite-gen can recover neutral smoke cleanly.
    p.putalpha(p.getchannel("A").point(lambda a: 255 if a > 36 else 0))
    return p


def compose(frame: Image.Image, i: int) -> Image.Image:
    # Magenta leaves neutral smoke edges clean after sprite-gen chroma extraction.
    canvas = Image.new("RGBA", frame.size, (255, 0, 255, 255))
    ground = round(frame.height * 0.79)
    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((frame.width * .31, ground - 5, frame.width * .69, ground + 13), fill=(46, 47, 43, 255))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(7)))
    for n, dx in enumerate((-0.13, 0.08, 0.22)):
        smoke = puff(i + n * 3, frame.size)
        x = round(frame.width * (0.5 + dx) - smoke.width / 2)
        y = round(ground - smoke.height * (0.80 + n * 0.04))
        canvas.alpha_composite(smoke, (x, y))
    canvas.alpha_composite(frame)
    return canvas.convert("RGB")


def main() -> None:
    for monster in IDS:
        src = SOURCE / monster / "walk-frames-spritegen/keyed"
        files = sorted(src.glob("frame-*.png"))
        if not files:
            continue
        out = SOURCE / monster / "walk-smoke-video-frames"
        out.mkdir(exist_ok=True)
        for old in out.glob("frame-*.png"):
            old.unlink()
        for i, path in enumerate(files):
            compose(Image.open(path).convert("RGBA"), i).save(out / f"frame-{i+1:04d}.png")
        video = SOURCE / monster / "walk-smoke.mp4"
        subprocess.run([
            r"D:\mm\data\ffmpeg-bin\ffmpeg.exe", "-y", "-framerate", "24", "-i", str(out / "frame-%04d.png"),
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-vf", "format=yuv420p", str(video)
        ], check=True, capture_output=True)
        print(video)


if __name__ == "__main__":
    main()
