"""Publish freshly keyed magenta-background smoke walk frames."""
from pathlib import Path
import json, shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IDS = ("erosion_bug", "husk_ram", "shell_scarab")

for monster in IDS:
    dest = ROOT / "assets/enemies/animations" / monster
    frames = ROOT / "art_source/generated/monster_video_batch" / monster / "walk-smoke-frames/keyed"
    old = sorted(dest.glob("walk-frame-*.png"))
    if not old:
        raise RuntimeError(f"no existing walk frames for {monster}")
    sample = Image.open(old[0]); out_w, out_h = sample.size
    manifest_path = dest / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    row = manifest["animation"]["rows"]["walk"]
    ground = int(row.get("ground_y", out_h - 14))
    backup = ROOT / "art_source/generated/monster_video_batch" / monster / "previous-smoke-publish"
    backup.mkdir(parents=True, exist_ok=True)
    for p in old:
        q = backup / p.name
        if not q.exists(): shutil.copy2(p, q)
    keyed = sorted(frames.glob("*.png"))
    if len(keyed) != 121:
        raise RuntimeError(f"{monster}: expected 121 keyed frames, got {len(keyed)}")
    for i, source in enumerate(keyed):
        im = Image.open(source).convert("RGBA")
        bbox = im.getchannel("A").getbbox()
        if not bbox: raise RuntimeError(f"{monster}: empty frame {source.name}")
        x0,y0,x1,y1 = bbox
        pad_x = max(8, round((x1-x0)*0.08)); pad_y = max(8, round((y1-y0)*0.08))
        crop = im.crop((max(0,x0-pad_x), max(0,y0-pad_y), min(im.width,x1+pad_x), min(im.height,y1+pad_y)))
        scale = min((out_w-8)/crop.width, (ground-8)/crop.height)
        nw, nh = max(1,round(crop.width*scale)), max(1,round(crop.height*scale))
        crop = crop.resize((nw,nh), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (out_w,out_h))
        canvas.alpha_composite(crop, ((out_w-nw)//2, ground-nh))
        canvas.save(dest / f"walk-frame-{i}.png")
    row.update({"frames": len(keyed), "width": out_w, "height": out_h,
                "source": f"art_source/generated/monster_video_batch/{monster}/walk-smoke.mp4",
                "frame_variant": "spritegen-video-smoke-keyed-magenta",
                "pipeline_metadata": f"art_source/generated/monster_video_batch/{monster}/walk-smoke-frames/frames.report.json"})
    manifest["baked_effects"] = {"walk": "smoke-in-video-behind-subject"}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(monster, len(keyed), out_w, out_h)
