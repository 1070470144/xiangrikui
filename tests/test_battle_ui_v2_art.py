import importlib.util
import json
import tempfile
import unittest
from pathlib import Path, PurePosixPath, PureWindowsPath
from unittest import mock

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "art_source" / "manifests" / "battle_ui_v2.json"
PROCESSOR = ROOT / "art_source" / "process_battle_ui_v2.py"
EXPECTED_PROCESSOR = "res://art_source/process_battle_ui_v2.py"
EXPECTED_GENERATED_IDS = {
    "compact_status_frame",
    "phase_banner_frame",
    "resource_panel_frame",
    "phase_action_tray",
    "selection_detail_frame",
    "tactical_instrument_frame",
    "primary_action_button_normal",
    "primary_action_button_hover",
    "primary_action_button_pressed",
    "primary_action_button_disabled",
    "start_night_icon",
    "sunburst_icon",
    "pause_frame",
    "mother_choice_card_life",
    "mother_choice_card_network",
    "mother_choice_card_risk",
    "victory_frame",
    "defeat_frame",
    "victory_seal",
    "defeat_seal",
}
EXPECTED_DYNAMIC_IDS = {
    "dynamic_text",
    "dynamic_values",
    "dynamic_costs",
    "tactical_direction_markers",
}
BUTTON_IDS = {
    "primary_action_button_normal": "normal",
    "primary_action_button_hover": "hover",
    "primary_action_button_pressed": "pressed",
    "primary_action_button_disabled": "disabled",
}
BUTTON_NODES = {
    "PrimaryActionButton/StartNightButton",
    "PrimaryActionButton/SunburstButton",
}
CARD_BINDINGS = {
    "mother_choice_card_life": "MotherChoiceOverlay/MotherChoicePanel/MotherChoiceBox/MotherChoiceRow/LifeChoiceButton",
    "mother_choice_card_network": "MotherChoiceOverlay/MotherChoicePanel/MotherChoiceBox/MotherChoiceRow/NetworkChoiceButton",
    "mother_choice_card_risk": "MotherChoiceOverlay/MotherChoicePanel/MotherChoiceBox/MotherChoiceRow/RiskChoiceButton",
}


class BattleUiV2ArtContractTests(unittest.TestCase):
    def _load_manifest(self):
        self.assertTrue(
            MANIFEST.is_file(),
            "Battle UI V2 manifest is intentionally required before implementation: "
            "art_source/manifests/battle_ui_v2.json is missing",
        )
        return json.loads(MANIFEST.read_text(encoding="utf-8"))

    def _runtime_entries(self, manifest):
        entries = []
        seen_paths = set()
        for asset in manifest.get("assets", []):
            generation = asset.get("generation", {})
            if not generation.get("enabled", False):
                continue

            asset_id = asset.get("id", "<unnamed>")
            runtime = asset.get("runtime")
            self.assertIsInstance(
                runtime,
                dict,
                f"generated asset {asset_id} must declare a runtime entry",
            )
            states = asset.get("states", [])
            if states:
                self.assertIn(
                    "path_pattern",
                    runtime,
                    f"generated asset {asset_id} with states must declare runtime path_pattern",
                )
                self.assertTrue(
                    all(isinstance(state, str) for state in states),
                    f"generated asset {asset_id} states must be strings",
                )
                self.assertEqual(
                    len(states),
                    len(set(states)),
                    f"generated asset {asset_id} must not declare duplicate states",
                )
                path_pattern = runtime["path_pattern"]
                self.assertIsInstance(
                    path_pattern,
                    str,
                    f"generated asset {asset_id} runtime path_pattern must be a string",
                )
                self.assertIn(
                    "{state}",
                    path_pattern,
                    f"generated asset {asset_id} runtime path_pattern must contain {{state}}",
                )
                try:
                    runtime_paths = [path_pattern.format(state=state) for state in states]
                except (IndexError, KeyError, ValueError) as error:
                    self.fail(f"generated asset {asset_id} has invalid runtime path_pattern: {error}")
            else:
                self.assertIn(
                    "path",
                    runtime,
                    f"generated asset {asset_id} without states must declare runtime path",
                )
                runtime_paths = [runtime["path"]]

            for resource_path in runtime_paths:
                self.assertIsInstance(
                    resource_path,
                    str,
                    f"generated asset {asset_id} runtime path must be a string",
                )
                self.assertNotIn(
                    resource_path,
                    seen_paths,
                    f"generated runtime path must be unique: {resource_path}",
                )
                seen_paths.add(resource_path)
                entries.append((asset_id, resource_path, runtime))
        return entries

    def _resolve_runtime_path(self, asset_id, resource_path):
        self.assertIsInstance(resource_path, str, f"{asset_id} runtime path must be a string")
        self.assertTrue(
            resource_path.startswith("res://"),
            f"{asset_id} runtime path must be a res:// path",
        )
        relative_text = resource_path.removeprefix("res://")
        normalized_parts = PurePosixPath(relative_text.replace("\\", "/")).parts
        self.assertNotIn("..", normalized_parts, f"{asset_id} runtime path must not traverse outside the project")
        windows_path = PureWindowsPath(relative_text)
        self.assertFalse(
            windows_path.is_absolute() or bool(windows_path.drive),
            f"{asset_id} runtime path must not contain an absolute drive or UNC path",
        )

        project_root = ROOT.resolve()
        runtime_path = (project_root / Path(relative_text)).resolve()
        self.assertTrue(
            runtime_path.is_relative_to(project_root),
            f"{asset_id} runtime path resolves outside the project: {resource_path}",
        )
        return runtime_path

    def test_generated_runtime_assets_match_manifest_contract(self):
        manifest = self._load_manifest()
        entries = self._runtime_entries(manifest)
        self.assertTrue(entries, "Battle UI V2 manifest must declare generated runtime assets")

        for asset_id, resource_path, runtime in entries:
            with self.subTest(asset=asset_id):
                self.assertEqual(
                    EXPECTED_PROCESSOR,
                    runtime.get("derived_by"),
                    f"{asset_id} must identify the deterministic V2 processor",
                )
                runtime_path = self._resolve_runtime_path(asset_id, resource_path)
                self.assertTrue(runtime_path.is_file(), f"missing runtime asset: {resource_path}")
                with Image.open(runtime_path) as image:
                    self.assertEqual("RGBA", image.mode, f"{resource_path} must be RGBA")
                    self.assertEqual(
                        tuple(runtime.get("size", [])),
                        image.size,
                        f"{resource_path} dimensions must match its manifest runtime size",
                    )
                    alpha_minimum, _ = image.getchannel("A").getextrema()
                    self.assertLess(
                        alpha_minimum,
                        255,
                        f"{resource_path} must contain at least one transparent pixel",
                    )

    def test_manifest_has_exact_generated_inventory_and_provenance(self):
        manifest = self._load_manifest()
        self.assertEqual(1, manifest.get("schema_version"))
        asset_ids = [asset.get("id") for asset in manifest.get("assets", [])]
        self.assertEqual(len(asset_ids), len(set(asset_ids)), "manifest asset IDs must be unique")
        generated = {
            asset["id"]: asset
            for asset in manifest.get("assets", [])
            if asset.get("generation", {}).get("enabled", False)
        }
        self.assertEqual(EXPECTED_GENERATED_IDS, set(generated))

        for asset_id, asset in generated.items():
            with self.subTest(asset=asset_id):
                generation = asset["generation"]
                self.assertEqual("openai_image", generation.get("provider"))
                self.assertEqual("gpt-image-2", generation.get("model"))
                self.assertIs(True, generation.get("transparent"))
                self.assertTrue(asset.get("bindings"), f"{asset_id} must declare node bindings")
                self.assertEqual(2, len(asset.get("display_size", [])))

                source = asset.get("source", {})
                self.assertTrue(
                    source.get("path", "").startswith("res://art_source/generated/battle_ui_v2/"),
                    f"{asset_id} source must stay in the V2 source directory",
                )
                self.assertEqual(2, len(source.get("size", [])))

                runtime = asset.get("runtime", {})
                self.assertTrue(
                    runtime.get("path", "").startswith("res://assets/ui/generated/battle_ui_v2/"),
                    f"{asset_id} runtime must stay in the V2 runtime directory",
                )
                self.assertEqual(2, len(runtime.get("size", [])))
                self.assertEqual(EXPECTED_PROCESSOR, runtime.get("derived_by"))
                for binding in asset["bindings"]:
                    self.assertFalse(binding["node"].startswith("BattleUiRoot/"))
                if asset_id in BUTTON_IDS:
                    self.assertEqual(
                        BUTTON_NODES,
                        {binding["node"] for binding in asset["bindings"]},
                    )
                    self.assertTrue(
                        all(binding["property"] == f"theme_override_styles/{BUTTON_IDS[asset_id]}" for binding in asset["bindings"])
                    )
                if asset_id in {"start_night_icon", "sunburst_icon"}:
                    self.assertEqual(BUTTON_NODES, {binding["node"] for binding in asset["bindings"]})
                    self.assertTrue(all(binding["property"] == "icon" for binding in asset["bindings"]))
                if asset_id in CARD_BINDINGS:
                    self.assertEqual(
                        [{"node": CARD_BINDINGS[asset_id], "property": "theme_override_styles/normal"}],
                        asset["bindings"],
                    )

                patch_margin = runtime.get("patch_margin")
                if patch_margin is not None:
                    width, height = runtime["size"]
                    self.assertEqual(4, len(patch_margin))
                    self.assertTrue(all(isinstance(value, (int, float)) and value >= 0 for value in patch_margin))
                    self.assertLess(patch_margin[0] + patch_margin[2], width)
                    self.assertLess(patch_margin[1] + patch_margin[3], height)

        dynamic = {
            asset["id"]: asset
            for asset in manifest.get("assets", [])
            if asset.get("id") in EXPECTED_DYNAMIC_IDS
        }
        self.assertEqual(EXPECTED_DYNAMIC_IDS, set(dynamic))
        for asset_id, asset in dynamic.items():
            self.assertFalse(
                asset.get("generation", {}).get("enabled", True),
                f"{asset_id} must remain runtime-drawn",
            )
        direction = dynamic["tactical_direction_markers"]
        self.assertEqual(
            [{"node": "TacticalInstrumentFrame/ThreatCompassFrame/ThreatCompass", "property": "direction_label_text"}],
            direction.get("bindings"),
        )
        self.assertEqual("N,E,S,W", direction.get("runtime", {}).get("direction_label_text"))

    def test_manifest_bindings_use_consumable_relative_paths(self):
        manifest = self._load_manifest()
        for asset in manifest["assets"]:
            for binding in asset.get("bindings", []):
                self.assertFalse(binding["node"].startswith("/"))
                self.assertNotIn("..", PurePosixPath(binding["node"]).parts)
                self.assertTrue(binding.get("property"), f"{asset['id']} binding needs a property")


class BattleUiV2ProcessorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not PROCESSOR.is_file():
            raise AssertionError(f"missing deterministic processor: {PROCESSOR}")
        spec = importlib.util.spec_from_file_location("process_battle_ui_v2", PROCESSOR)
        if spec is None or spec.loader is None:
            raise AssertionError(f"cannot import processor: {PROCESSOR}")
        cls.processor = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.processor)

    def test_derive_asset_accepts_transparency_and_matches_runtime_size(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.png"
            output = root / "runtime.png"
            image = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
            for x in range(24, 40):
                for y in range(14, 30):
                    image.putpixel((x, y), (120, 90, 35, 220))
            image.save(source)

            asset = {
                "id": "fixture",
                "source": {"path": "res://source.png", "size": [64, 48]},
                "runtime": {
                    "path": "res://runtime.png",
                    "size": [12, 8],
                    "derived_by": EXPECTED_PROCESSOR,
                },
            }
            report = self.processor.derive_asset(asset, source, output)

            with Image.open(output) as derived:
                self.assertEqual("RGBA", derived.mode)
                self.assertEqual((12, 8), derived.size)
                self.assertLess(derived.getchannel("A").getextrema()[0], 255)
            self.assertEqual("res://source.png", report["source"])
            self.assertEqual("res://runtime.png", report["runtime"])
            self.assertEqual([12, 8], report["dimensions"])
            self.assertTrue(report["alpha"]["has_transparency"])
            self.assertEqual(EXPECTED_PROCESSOR, report["derived_by"])

    def test_tight_crop_removes_transparent_border_before_aspect_preserving_fit(self):
        image = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
        for x in range(24, 40):
            for y in range(14, 30):
                image.putpixel((x, y), (120, 90, 35, 220))
        cropped = self.processor.tight_crop(image, pad=2)
        self.assertEqual((20, 20), cropped.size)
        self.assertEqual((0, 220), cropped.getchannel("A").getextrema())

    def test_validate_rgba_rejects_fully_transparent_and_non_rgba_images(self):
        with self.assertRaisesRegex(ValueError, "fully transparent"):
            self.processor.validate_rgba(Image.new("RGBA", (4, 4), (0, 0, 0, 0)), "transparent.png")
        with self.assertRaisesRegex(ValueError, "must be RGBA"):
            self.processor.validate_rgba(Image.new("RGB", (4, 4), (0, 0, 0)), "rgb.png")

    def test_derive_asset_rejects_missing_and_fully_opaque_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            missing = root / "missing.png"
            opaque = root / "opaque.png"
            output = root / "runtime.png"
            asset = {
                "id": "fixture",
                "source": {"path": "res://source.png", "size": [8, 8]},
                "runtime": {
                    "path": "res://runtime.png",
                    "size": [8, 8],
                    "derived_by": EXPECTED_PROCESSOR,
                },
            }

            with self.assertRaises(FileNotFoundError):
                self.processor.derive_asset(asset, missing, output)

            Image.new("RGBA", (8, 8), (10, 20, 30, 255)).save(opaque)
            with self.assertRaisesRegex(ValueError, "fully opaque"):
                self.processor.derive_asset(asset, opaque, output)
            self.assertFalse(output.exists())

    def test_derive_rejects_paths_outside_declared_v2_directories(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_directory = root / "art_source" / "generated" / "battle_ui_v2"
            manifest_path = root / "art_source" / "manifests" / "battle_ui_v2.json"
            source_directory.mkdir(parents=True)
            manifest_path.parent.mkdir(parents=True)
            Image.new("RGBA", (8, 8), (10, 20, 30, 128)).save(source_directory / "safe.png")
            manifest_path.write_text(
                json.dumps(
                    {
                        "report": {"path": "res://assets/ui/generated/battle_ui_v2/report.json"},
                        "assets": [
                            {
                                "id": "escape",
                                "generation": {"enabled": True},
                                "source": {
                                    "path": "res://art_source/generated/battle_ui_v2/safe.png",
                                    "size": [8, 8],
                                },
                                "runtime": {
                                    "path": "res://assets/ui/generated/battle_ui_v2/../../../../escape.png",
                                    "size": [8, 8],
                                    "derived_by": EXPECTED_PROCESSOR,
                                },
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            with (
                mock.patch.object(self.processor, "ROOT", root),
                mock.patch.object(self.processor, "MANIFEST", manifest_path),
            ):
                with self.assertRaisesRegex(ValueError, "runtime path"):
                    self.processor.derive()
            self.assertFalse((root / "escape.png").exists())

    def test_derive_rejects_duplicate_asset_ids_before_resolving_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = root / "art_source" / "manifests" / "battle_ui_v2.json"
            manifest_path.parent.mkdir(parents=True)
            base_asset = {
                "id": "duplicate",
                "generation": {"enabled": True},
                "source": {"path": "res://art_source/generated/battle_ui_v2/../../outside.png", "size": [8, 8]},
                "runtime": {"path": "res://assets/ui/generated/battle_ui_v2/one.png", "size": [8, 8], "derived_by": EXPECTED_PROCESSOR},
            }
            manifest_path.write_text(json.dumps({"report": {"path": "res://assets/ui/generated/battle_ui_v2/report.json"}, "assets": [base_asset, dict(base_asset)]}), encoding="utf-8")
            with mock.patch.object(self.processor, "ROOT", root), mock.patch.object(self.processor, "MANIFEST", manifest_path):
                with self.assertRaisesRegex(ValueError, "duplicate asset id"):
                    self.processor.derive()

    def test_derive_rejects_source_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = root / "art_source" / "manifests" / "battle_ui_v2.json"
            manifest_path.parent.mkdir(parents=True)
            asset = {
                "id": "escape",
                "generation": {"enabled": True},
                "source": {"path": "res://art_source/generated/battle_ui_v2/../../outside.png", "size": [8, 8]},
                "runtime": {"path": "res://assets/ui/generated/battle_ui_v2/safe.png", "size": [8, 8], "derived_by": EXPECTED_PROCESSOR},
            }
            manifest_path.write_text(json.dumps({"report": {"path": "res://assets/ui/generated/battle_ui_v2/report.json"}, "assets": [asset]}), encoding="utf-8")
            with mock.patch.object(self.processor, "ROOT", root), mock.patch.object(self.processor, "MANIFEST", manifest_path):
                with self.assertRaisesRegex(ValueError, "source path"):
                    self.processor.derive()

    def test_derive_rejects_invalid_patch_margins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_dir = root / "art_source" / "generated" / "battle_ui_v2"
            manifest_path = root / "art_source" / "manifests" / "battle_ui_v2.json"
            source_dir.mkdir(parents=True)
            manifest_path.parent.mkdir(parents=True)
            Image.new("RGBA", (8, 8), (10, 20, 30, 128)).save(source_dir / "panel.png")
            asset = {
                "id": "panel",
                "generation": {"enabled": True},
                "source": {"path": "res://art_source/generated/battle_ui_v2/panel.png", "size": [8, 8]},
                "runtime": {"path": "res://assets/ui/generated/battle_ui_v2/panel.png", "size": [8, 8], "mode": "nine_patch", "patch_margin": [4, 1, 4, 1], "derived_by": EXPECTED_PROCESSOR},
            }
            manifest_path.write_text(json.dumps({"report": {"path": "res://assets/ui/generated/battle_ui_v2/report.json"}, "assets": [asset]}), encoding="utf-8")
            with mock.patch.object(self.processor, "ROOT", root), mock.patch.object(self.processor, "MANIFEST", manifest_path):
                with self.assertRaisesRegex(ValueError, "patch_margin"):
                    self.processor.derive()

    def test_derive_successfully_processes_manifest_and_writes_report(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_dir = root / "art_source" / "generated" / "battle_ui_v2"
            manifest_path = root / "art_source" / "manifests" / "battle_ui_v2.json"
            runtime_dir = root / "assets" / "ui" / "generated" / "battle_ui_v2"
            source_dir.mkdir(parents=True)
            manifest_path.parent.mkdir(parents=True)
            Image.new("RGBA", (8, 8), (10, 20, 30, 128)).save(source_dir / "icon.png")
            asset = {
                "id": "icon",
                "generation": {"enabled": True},
                "source": {"path": "res://art_source/generated/battle_ui_v2/icon.png", "size": [8, 8]},
                "runtime": {"path": "res://assets/ui/generated/battle_ui_v2/icon.png", "size": [12, 8], "derived_by": EXPECTED_PROCESSOR},
            }
            manifest_path.write_text(json.dumps({"report": {"path": "res://assets/ui/generated/battle_ui_v2/report.json"}, "assets": [asset]}), encoding="utf-8")
            with mock.patch.object(self.processor, "ROOT", root), mock.patch.object(self.processor, "MANIFEST", manifest_path):
                report = self.processor.derive()
            output = runtime_dir / "icon.png"
            self.assertTrue(output.is_file())
            with Image.open(output) as derived:
                self.assertEqual((12, 8), derived.size)
                self.assertEqual((2, 0, 10, 8), derived.getchannel("A").getbbox())
            self.assertEqual(["icon"], [entry["id"] for entry in report["assets"]])
            self.assertEqual(report, json.loads((runtime_dir / "report.json").read_text(encoding="utf-8")))
            self.assertEqual([], list(runtime_dir.parent.glob(".battle_ui_v2-staging-*")))

    def test_derive_writes_report_and_rolls_back_when_later_asset_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_dir = root / "art_source" / "generated" / "battle_ui_v2"
            manifest_path = root / "art_source" / "manifests" / "battle_ui_v2.json"
            runtime_dir = root / "assets" / "ui" / "generated" / "battle_ui_v2"
            source_dir.mkdir(parents=True)
            manifest_path.parent.mkdir(parents=True)
            runtime_dir.mkdir(parents=True)
            Image.new("RGBA", (8, 8), (10, 20, 30, 128)).save(source_dir / "good.png")
            existing = runtime_dir / "good.png"
            existing.write_bytes(b"old-runtime")
            report_path = runtime_dir / "report.json"
            report_path.write_text("old-report", encoding="utf-8")
            assets = [
                {"id": "good", "generation": {"enabled": True}, "source": {"path": "res://art_source/generated/battle_ui_v2/good.png", "size": [8, 8]}, "runtime": {"path": "res://assets/ui/generated/battle_ui_v2/good.png", "size": [8, 8], "derived_by": EXPECTED_PROCESSOR}},
                {"id": "missing", "generation": {"enabled": True}, "source": {"path": "res://art_source/generated/battle_ui_v2/missing.png", "size": [8, 8]}, "runtime": {"path": "res://assets/ui/generated/battle_ui_v2/missing.png", "size": [8, 8], "derived_by": EXPECTED_PROCESSOR}},
            ]
            manifest_path.write_text(json.dumps({"report": {"path": "res://assets/ui/generated/battle_ui_v2/report.json"}, "assets": assets}), encoding="utf-8")
            with mock.patch.object(self.processor, "ROOT", root), mock.patch.object(self.processor, "MANIFEST", manifest_path):
                with self.assertRaises(FileNotFoundError):
                    self.processor.derive()
            self.assertEqual(b"old-runtime", existing.read_bytes())
            self.assertEqual("old-report", report_path.read_text(encoding="utf-8"))
            self.assertFalse((runtime_dir / "missing.png").exists())


if __name__ == "__main__":
    unittest.main()
