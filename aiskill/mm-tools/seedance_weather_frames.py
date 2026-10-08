"""Use sprite-gen's canonical YCbCr matte for Seedance's shaded pink key.

No duplicate extraction or crop algorithm: video.frames owns ffmpeg extraction
and alpha/edge QA; frames.extract owns the chrominance matte. The RGB video
default cannot detect Seedance's muted pink, so this adapter selects YCbCr.
"""
import argparse
import json
import os
from pathlib import Path
from PIL import Image
from sprite_gen.video import frames
from sprite_gen.frames.extract import remove_chroma_background_ycbcr, detect_background_key_ycc
from sprite_gen.frames import extract as chroma
import numpy as np

# Seedance's pastel key is much closer to the pale green subject in chroma
# than the saturated Grok key. Calibrated on the raw drop and splash frames.
chroma._YCC_FLOOD_TOL = 24.0
chroma._YCC_CHROMA_IN = 12.0
chroma._YCC_CHROMA_OUT = 42.0


def keyed_cutout(source, target, **kwargs):
    image = Image.open(source).convert("RGBA")
    warnings = []
    key = detect_background_key_ycc(image, (255, 0, 255))
    result = remove_chroma_background_ycbcr(image, (255, 0, 255), warnings)
    pixels = np.array(result)
    pixels[pixels[:, :, 3] == 0] = 0
    result = Image.fromarray(pixels)
    result.save(target)
    return {"route": "extract:ycbcr", "chroma_key": list(key),
            "chroma_key_painted": list(key), "warnings": warnings}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clip", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--tools", type=Path, required=True)
    args = parser.parse_args()
    directories = sorted({str(p.parent) for p in args.tools.rglob("*.exe")
                          if p.name in ("ffmpeg.exe", "ffprobe.exe", "img2webp.exe")})
    os.environ["PATH"] = os.pathsep.join(directories) + os.pathsep + os.environ["PATH"]
    frames.cutout = keyed_cutout
    report = frames.run_frames(args.clip, args.out_dir, key="magenta",
                              allow_edge_contact=False, allow_subject_edge_contact=True,
                              report_path=None)
    report["matte_adapter"] = "canonical sprite-gen YCbCr, explicit Seedance shaded-key route"
    report["matte_parameters"] = {"flood_tolerance": 24, "chroma_in": 12, "chroma_out": 42}
    (args.out_dir / "frames.report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({"frames": report.get("frames"), "report": str(args.out_dir / "frames.report.json")}))


if __name__ == "__main__":
    main()
