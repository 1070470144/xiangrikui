import json
import subprocess
import sys
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "art_source" / "process_battle_hud.py"
RUNTIME = ROOT / "assets" / "ui" / "generated" / "battle_hud"


class BattleHudRuntimeArtTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, str(SCRIPT), "--check"], cwd=ROOT, check=True)

    def test_primary_states_are_same_size_and_alpha_mask(self):
        images = [Image.open(RUNTIME / f"runtime_primary_action_{state}_v2.png").convert("RGBA")
                  for state in ("normal", "hover", "pressed", "disabled")]
        self.assertEqual(1, len({image.size for image in images}))
        masks = [image.getchannel("A").tobytes() for image in images]
        self.assertTrue(all(mask == masks[0] for mask in masks[1:]))
        self.assertEqual(images[0].getchannel("A").getbbox(), images[1].getchannel("A").getbbox())

    def test_runtime_frames_are_tightly_cropped_and_margins_reach_art(self):
        manifest = json.loads((ROOT / "art_source/manifests/battle_hud.json").read_text(encoding="utf-8"))
        assets = {asset["id"]: asset for asset in manifest["assets"]}
        for asset_id, filename in (("phase_action_tray", "runtime_phase_action_tray_v2.png"),
                                   ("compact_status_frame", "runtime_compact_status_frame_v2.png")):
            image = Image.open(RUNTIME / filename).convert("RGBA")
            bbox = image.getchannel("A").getbbox()
            self.assertIsNotNone(bbox)
            self.assertLessEqual(max(bbox[0], bbox[1], image.width - bbox[2], image.height - bbox[3]), 8)
            runtime = assets[asset_id]["runtime"]
            self.assertEqual(f"res://assets/ui/generated/battle_hud/{filename}", runtime["path"])
            self.assertEqual("res://art_source/process_battle_hud.py", runtime["derived_by"])
            left, top, right, bottom = runtime["patch_margin"]
            alpha = image.getchannel("A")
            self.assertIsNotNone(alpha.crop((0, 0, left + 1, image.height)).getbbox())
            self.assertIsNotNone(alpha.crop((0, 0, image.width, top + 1)).getbbox())
            self.assertIsNotNone(alpha.crop((image.width - right - 1, 0, image.width, image.height)).getbbox())
            self.assertIsNotNone(alpha.crop((0, image.height - bottom - 1, image.width, image.height)).getbbox())


if __name__ == "__main__":
    unittest.main()
