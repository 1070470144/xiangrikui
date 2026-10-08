import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "aiskill" / "mm-tools" / "mm_manifest.py"


def load_module():
    spec = importlib.util.spec_from_file_location("mm_manifest", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def minimal_manifest():
    return {
        "schema_version": 1,
        "feature": "test_hud",
        "scene": "res://scenes/main.tscn",
        "root_node": "Game/HUD",
        "style": {
            "reference_images": ["res://tmp/main-menu-review/menu00000000.png"],
            "prompt_prefix": "末日温室绘本风游戏 UI",
            "evidence": [
                {
                    "source": "res://Design/Sunflower-Defense-Art-Style-Guide.md",
                    "kind": "art_guide",
                    "reason": "项目批准的色彩、材质与 UI 语言",
                }
            ],
            "sprite_gen_contract": "sprite-gen/docs/gen.md",
            "visual_anchor": "深墨绿旧纸，氧化黄铜细边，克制暖金高光，可见手绘笔触",
            "comfort_constraints": ["中央保持低细节", "高亮只服务主操作", "避免持续高饱和发光"],
            "avoid": ["现代科技 HUD", "霓虹赛博风", "玻璃拟态", "伪文字", "水印"],
        },
        "assets": [
            {
                "id": "button",
                "kind": "button",
                "role": "Action button",
                "states": ["normal", "hover"],
                "ui_spec": {
                    "purpose": "主操作按钮边框",
                    "display_size": [160, 48],
                    "content_safe_area": [24, 10, 24, 10],
                    "layout": "低矮横向按钮，边缘装饰，中央文字区域留空",
                    "state_contract": "所有状态保持相同轮廓和装饰位置，只改变亮度、高光和按压深度",
                    "negative": ["文字", "字母", "数字", "图标", "投影底板", "厚重外发光"],
                },
                "generation": {
                    "enabled": True,
                    "provider": "mm-api",
                    "model": "gpt-image-2",
                    "prompt": "button frame without text",
                    "transparent": True,
                },
                "output": {
                    "path_pattern": "res://art_source/generated/mm_tools/test_hud/button_{state}.png",
                    "size": [64, 32],
                    "mode": "nine_patch",
                    "patch_margin": [8, 8, 8, 8],
                },
                "bindings": [{"node": "Button", "property_map": {"normal": "theme_override_styles/normal", "hover": "theme_override_styles/hover"}}],
            },
            {
                "id": "label",
                "kind": "text",
                "role": "Action label",
                "generation": {"enabled": False},
                "runtime": {"text": "Action", "font_size": 18, "color": "#FFFFFF"},
                "bindings": [{"node": "Button", "property": "text"}],
            },
        ],
    }


def create_style_evidence(project_root):
    evidence = project_root / "Design" / "Sunflower-Defense-Art-Style-Guide.md"
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text("# Test style guide\n", encoding="utf-8")


class ManifestPlanningTests(unittest.TestCase):
    def test_checked_in_ui_manifests_have_production_migration_metadata(self):
        module = load_module()
        for manifest_name in ("main_menu", "deck_builder", "battle_hud"):
            with self.subTest(manifest=manifest_name):
                manifest = module.load_manifest(
                    ROOT / "art_source" / "manifests" / f"{manifest_name}.json"
                )
                self.assertEqual([], module.validate_manifest(manifest, ROOT))

                style = manifest["style"]
                self.assertEqual("sprite-gen/docs/gen.md", style["sprite_gen_contract"])
                self.assertTrue(style["visual_anchor"].strip())
                self.assertTrue(style["comfort_constraints"])
                self.assertTrue(style["avoid"])

                evidence = style["evidence"]
                self.assertTrue(any(item["kind"] == "art_guide" for item in evidence))
                self.assertTrue(
                    any(item["kind"] in {"runtime_screenshot", "accepted_manifest"} for item in evidence)
                )
                for item in evidence:
                    if item["kind"] in module.PROJECT_EVIDENCE_KINDS:
                        self.assertTrue((ROOT / item["source"].removeprefix("res://")).is_file())

                for asset in manifest["assets"]:
                    if asset["generation"]["enabled"] and asset["kind"] in module.UI_KINDS:
                        self.assertIn("ui_spec", asset, asset["id"])
                        if len(asset.get("states", [])) > 1:
                            self.assertTrue(asset["ui_spec"]["state_contract"].strip(), asset["id"])

    def test_deck_builder_manifest_covers_collection_ui(self):
        module = load_module()
        manifest = module.load_manifest(ROOT / "art_source" / "manifests" / "deck_builder.json")
        self.assertEqual([], module.validate_manifest(manifest, ROOT))
        required = {
            "deck_background", "library_panel", "detail_panel", "deck_panel",
            "card_frame_common", "card_frame_rare", "card_frame_legendary",
            "lock_overlay", "energy_badge", "action_button_states",
            "cost_curve_ornament", "page_title_text", "validation_text",
        }
        self.assertTrue(required.issubset({asset["id"] for asset in manifest["assets"]}))

    def test_checked_in_battle_hud_manifest_covers_generated_and_text_assets(self):
        module = load_module()
        manifest = module.load_manifest(ROOT / "art_source" / "manifests" / "battle_hud.json")
        self.assertEqual([], module.validate_manifest(manifest, ROOT))
        self.assertEqual("BattleHudRoot", manifest["root_node"])
        required = {
            "primary_action_button", "primary_action_button_pressed_single", "phase_action_tray", "compact_status_frame",
            "tactical_instrument_frame", "start_night_icon", "sunburst_icon",
            "phase_title", "resource_text", "selection_detail_text",
            "countdown_and_enemy_text", "action_cost_text", "tactical_direction_letters",
        }
        assets = {asset["id"]: asset for asset in manifest["assets"]}
        self.assertEqual([162, 120], assets["primary_action_button"]["ui_spec"]["display_size"])
        self.assertEqual([162, 120], assets["primary_action_button_pressed_single"]["ui_spec"]["display_size"])
        self.assertEqual([44, 44], assets["start_night_icon"]["ui_spec"]["display_size"])
        self.assertEqual([44, 44], assets["sunburst_icon"]["ui_spec"]["display_size"])
        self.assertEqual(required, set(assets))
        enabled = [asset for asset in manifest["assets"] if asset["generation"]["enabled"]]
        text = [asset for asset in manifest["assets"] if asset["kind"] == "text"]
        self.assertTrue(all(asset["generation"]["provider"] == "mm-api" for asset in enabled))
        self.assertTrue(all(asset["generation"]["model"] == "gpt-image-2" for asset in enabled))
        self.assertTrue(all(asset["generation"]["transparent"] for asset in enabled))
        self.assertTrue(all(not asset["generation"]["enabled"] for asset in text))
        expected_outputs = {
            "primary_action_button": ("path_pattern", "res://art_source/generated/mm_tools/battle_hud/primary_action_button_{state}.png", [324, 240], "nine_patch", [40, 34, 40, 34]),
            "primary_action_button_pressed_single": ("path", "res://art_source/generated/mm_tools/battle_hud/primary_action_button_pressed_single.png", [324, 240], "nine_patch", [40, 34, 40, 34]),
            "phase_action_tray": ("path", "res://art_source/generated/mm_tools/battle_hud/phase_action_tray.png", [1240, 228], "nine_patch", [52, 38, 52, 38]),
            "compact_status_frame": ("path", "res://art_source/generated/mm_tools/battle_hud/compact_status_frame.png", [600, 164], "nine_patch", [42, 30, 42, 30]),
            "tactical_instrument_frame": ("path", "res://art_source/generated/mm_tools/battle_hud/tactical_instrument_frame.png", [352, 352], "full_image", None),
            "start_night_icon": ("path", "res://art_source/generated/mm_tools/battle_hud/start_night_icon.png", [96, 96], "full_image", None),
            "sunburst_icon": ("path", "res://art_source/generated/mm_tools/battle_hud/sunburst_icon.png", [96, 96], "full_image", None),
        }
        for asset_id, (path_key, path, size, mode, margins) in expected_outputs.items():
            output = assets[asset_id]["output"]
            self.assertEqual(path, output[path_key])
            self.assertEqual(size, output["size"])
            self.assertEqual(mode, output["mode"])
            if margins is not None:
                self.assertEqual(margins, output["patch_margin"])
        expected_states = {state: f"theme_override_styles/{state}" for state in ["normal", "hover", "disabled"]}
        self.assertEqual(["normal", "hover", "disabled"], assets["primary_action_button"]["states"])
        self.assertEqual(
            ["PrimaryActionButton/StartNightButton", "PrimaryActionButton/SunburstButton"],
            [binding["node"] for binding in assets["primary_action_button"]["bindings"]],
        )
        self.assertTrue(all(binding["property_map"] == expected_states for binding in assets["primary_action_button"]["bindings"]))
        self.assertEqual(
            [
                {"node": "PrimaryActionButton/StartNightButton", "property": "theme_override_styles/pressed"},
                {"node": "PrimaryActionButton/SunburstButton", "property": "theme_override_styles/pressed"},
            ],
            assets["primary_action_button_pressed_single"]["bindings"],
        )
        jobs = module.build_jobs(manifest, ROOT)
        self.assertEqual(9, len(jobs))
        self.assertNotIn(
            ROOT / "art_source" / "generated" / "mm_tools" / "battle_hud" / "primary_action_button_pressed.png",
            [job["output_path"] for job in jobs],
        )
        expected_text_nodes = {
            "phase_title": ["PhaseBanner/PhaseContent/PhaseLabel"],
            "resource_text": ["ResourcePanel/ResourceRow/EnergyValue", "ResourcePanel/ResourceRow/SeedLabel"],
            "selection_detail_text": ["SelectionDetailPanel/SelectionContent/SelectionValue", "SelectionDetailPanel/SelectionContent/SelectionTitle"],
            "countdown_and_enemy_text": ["PhaseBanner/PhaseContent/PhaseDetailRow/WaveLabel", "PhaseBanner/PhaseContent/PhaseDetailRow/TimerLabel", "PhaseBanner/PhaseContent/PhaseDetailRow/EnemyCountLabel"],
            "action_cost_text": ["PrimaryActionButton/CostOverlay/SunburstCostLabel"],
        }
        for asset_id, nodes in expected_text_nodes.items():
            self.assertEqual(nodes, [binding["node"] for binding in assets[asset_id]["bindings"]])
            self.assertTrue(all(binding["property"] == "text" for binding in assets[asset_id]["bindings"]))
        self.assertFalse(any(binding.get("property") == "tooltip_text" for asset in assets.values() for binding in asset["bindings"]))
        direction_asset = assets["tactical_direction_letters"]
        self.assertEqual({"direction_label_text": "N,E,S,W"}, direction_asset["runtime"])
        self.assertEqual(
            [{"node": "TacticalInstrumentFrame/ThreatCompassFrame/ThreatCompass", "property": "direction_label_text"}],
            direction_asset["bindings"],
        )
        self.assertNotIn("mouse_filter", direction_asset["runtime"])

    def test_valid_manifest_expands_states_and_omits_text(self):
        module = load_module()
        manifest = minimal_manifest()
        self.assertEqual([], module.validate_manifest(manifest, ROOT))
        jobs = module.build_jobs(manifest, ROOT)
        self.assertEqual(["normal", "hover"], [job["state"] for job in jobs])
        self.assertTrue(jobs[0]["output_path"].endswith("button_normal.png"))

    def test_binding_scope_rejects_unknown_values(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["assets"][0]["bindings"][0]["scope"] = "runtime_guess"
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("bindings[0].scope" in error for error in errors), errors)

    def test_content_margin_requires_four_nonnegative_integers(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["assets"][0]["output"]["content_margin"] = [8, -1, 8]
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("output.content_margin" in error for error in errors), errors)

    def test_generated_ui_requires_project_style_evidence(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"] = []
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("style.evidence" in error for error in errors))

    def test_generated_ui_rejects_external_only_style_evidence(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"] = [{
            "source": "https://example.com/game-ui.png",
            "kind": "external_reference",
            "reason": "layout reference",
        }]
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("project evidence" in error for error in errors))

    def test_generated_ui_requires_sprite_gen_contract(self):
        module = load_module()
        manifest = minimal_manifest()
        del manifest["style"]["sprite_gen_contract"]
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("sprite_gen_contract" in error for error in errors))

    def test_any_generated_asset_requires_complete_style_profile(self):
        module = load_module()
        for field in ("visual_anchor", "comfort_constraints", "avoid"):
            with self.subTest(field=field):
                manifest = minimal_manifest()
                manifest["assets"][0]["kind"] = "illustration"
                manifest["style"][field] = [] if field != "visual_anchor" else ""
                errors = module.validate_manifest(manifest, ROOT)
                self.assertTrue(any(field in error for error in errors), errors)

    def test_project_evidence_is_identified_by_kind(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"] = [{
            "source": "res://reference/external.png",
            "kind": "external_reference",
            "reason": "layout reference copied into the project",
        }]
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("project evidence" in error for error in errors), errors)

    def test_unknown_evidence_kind_is_rejected(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"][0]["kind"] = "runtime_capture"
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("evidence[0].kind" in error and "unsupported" in error for error in errors), errors)

    def test_generated_manifest_reference_images_require_existing_project_paths(self):
        module = load_module()
        for reference, expected in (
            ("https://example.com/layout.png", "res://"),
            ("res://output/imagegen/previews/missing-layout.png", "does not exist"),
            ("res://../outside.png", "escapes project"),
        ):
            with self.subTest(reference=reference):
                manifest = minimal_manifest()
                manifest["style"]["reference_images"] = [reference]
                errors = module.validate_manifest(manifest, ROOT)
                self.assertTrue(
                    any("style.reference_images[0]" in error and expected in error for error in errors),
                    errors,
                )

    def test_project_evidence_requires_nonempty_source_and_reason(self):
        module = load_module()
        for field in ("source", "reason"):
            with self.subTest(field=field):
                manifest = minimal_manifest()
                manifest["style"]["evidence"][0][field] = ""
                errors = module.validate_manifest(manifest, ROOT)
                self.assertTrue(any(f"evidence[0].{field}" in error for error in errors), errors)

    def test_project_evidence_source_must_use_res_path(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"][0]["source"] = "https://example.com/style-guide.png"
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("evidence[0].source" in error and "res://" in error for error in errors), errors)

    def test_project_evidence_source_must_remain_inside_project(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"][0]["source"] = "res://../style-guide.md"
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("evidence[0].source" in error and "escapes project" in error for error in errors), errors)

    def test_project_evidence_source_must_exist(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["evidence"][0]["source"] = "res://Design/missing-style-guide.md"
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("evidence[0].source" in error and "does not exist" in error for error in errors), errors)

    def test_generated_ui_requires_engineering_semantics(self):
        module = load_module()
        manifest = minimal_manifest()
        del manifest["assets"][0]["ui_spec"]["content_safe_area"]
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("content_safe_area" in error for error in errors))

    def test_generated_ui_requires_state_contract_only_for_multiple_states(self):
        module = load_module()
        manifest = minimal_manifest()
        del manifest["assets"][0]["ui_spec"]["state_contract"]
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("state_contract" in error for error in errors), errors)
        manifest["assets"][0]["states"] = ["normal"]
        self.assertEqual([], module.validate_manifest(manifest, ROOT))

    def test_generated_ui_rejects_invalid_safe_area(self):
        module = load_module()
        for safe_area in ([-1, 0, 0, 0], [80, 0, 80, 0], [0, 24, 0, 24]):
            with self.subTest(safe_area=safe_area):
                manifest = minimal_manifest()
                manifest["assets"][0]["ui_spec"]["content_safe_area"] = safe_area
                errors = module.validate_manifest(manifest, ROOT)
                self.assertTrue(any("content_safe_area" in error for error in errors), errors)

    def test_generated_ui_requires_nonempty_negative_constraints(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["assets"][0]["ui_spec"]["negative"] = []
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("negative" in error for error in errors), errors)

    def test_ui_prompt_contains_game_style_engineering_and_negative_constraints(self):
        module = load_module()
        job = module.build_jobs(minimal_manifest(), ROOT)[0]
        prompt = job["prompt"]
        for expected in (
            "末日温室绘本风游戏 UI",
            "氧化黄铜细边",
            "主操作按钮边框",
            "160x48",
            "中央文字区域留空",
            "所有状态保持相同轮廓",
            "文字、字母、数字、图标、投影底板、厚重外发光",
            "真实透明 PNG",
        ):
            self.assertIn(expected, prompt)

    def test_prompt_deduplicates_prohibitions_and_jobs_expose_provenance(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["style"]["avoid"].append("文字")
        job = module.build_jobs(manifest, ROOT)[0]
        self.assertEqual(1, job["prompt"].split("不得生成：", 1)[1].split("。", 1)[0].split("、").count("文字"))
        self.assertIn("禁止任何可读或伪造的文字", job["prompt"])
        self.assertEqual("sprite-gen/docs/gen.md", job["sprite_gen_contract"])
        self.assertEqual(manifest["style"]["evidence"], job["style_evidence"])
        self.assertEqual(manifest["assets"][0]["ui_spec"], job["ui_spec"])

    def test_ui_prompt_sections_follow_provider_contract_order(self):
        module = load_module()
        prompt = module.build_jobs(minimal_manifest(), ROOT)[0]["prompt"]
        markers = (
            "资源功能：",
            "游戏内实际显示尺寸：",
            "视觉锚点：",
            "布局：",
            "舒适度约束：",
            "不得生成：",
            "输出为真实透明 PNG",
        )
        positions = [prompt.index(marker) for marker in markers]
        self.assertEqual(sorted(positions), positions)

    def test_duplicate_expanded_outputs_are_rejected(self):
        module = load_module()
        manifest = minimal_manifest()
        duplicate = json.loads(json.dumps(manifest["assets"][0]))
        duplicate["id"] = "button_copy"
        manifest["assets"].append(duplicate)
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("duplicate output" in error for error in errors))

    def test_duplicate_outputs_reject_normalized_aliases(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["assets"][0]["states"] = ["normal"]
        manifest["assets"][0]["output"]["path_pattern"] = "res://out/x/../button_{state}.png"
        duplicate = json.loads(json.dumps(manifest["assets"][0]))
        duplicate["id"] = "button_copy"
        duplicate["output"]["path_pattern"] = "res://out/button_{state}.png"
        manifest["assets"].append(duplicate)
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("duplicate output" in error for error in errors), errors)

    def test_duplicate_outputs_reject_windows_case_aliases(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["assets"][0]["states"] = ["normal"]
        manifest["assets"][0]["output"]["path_pattern"] = "res://out/Button_{state}.png"
        duplicate = json.loads(json.dumps(manifest["assets"][0]))
        duplicate["id"] = "button_copy"
        duplicate["output"]["path_pattern"] = "res://out/button_{state}.png"
        manifest["assets"].append(duplicate)
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("duplicate output" in error for error in errors), errors)

    def test_malformed_generation_manifest_aggregates_without_throwing(self):
        module = load_module()
        manifest = minimal_manifest()
        asset = manifest["assets"][0]
        manifest["style"]["prompt_prefix"] = 123
        manifest["style"]["visual_anchor"] = None
        manifest["style"]["sprite_gen_contract"] = []
        asset["role"] = 42
        asset["states"] = ["", 3]
        asset["generation"].update({"prompt": [], "transparent": "yes"})
        asset["output"].update({"path_pattern": "", "size": [1, True, 3]})
        errors = module.validate_manifest(manifest, ROOT)
        self.assertGreaterEqual(len(errors), 8)
        self.assertTrue(any("prompt" in error for error in errors))

    def test_generation_enabled_requires_style_object_without_throwing(self):
        module = load_module()
        for malformed_style in ([], {}):
            with self.subTest(style=malformed_style):
                manifest = minimal_manifest()
                manifest["style"] = malformed_style
                errors = module.validate_manifest(manifest, ROOT)
                self.assertTrue(errors)
                if isinstance(malformed_style, list):
                    self.assertTrue(any("style" in error and "object" in error for error in errors), errors)
                with self.assertRaises(ValueError):
                    module.build_jobs(manifest, ROOT)

    def test_legacy_generating_manifest_cannot_bypass_full_contract(self):
        module = load_module()
        manifest = minimal_manifest()
        for field in ("evidence", "sprite_gen_contract", "visual_anchor", "comfort_constraints", "avoid"):
            del manifest["style"][field]
        del manifest["assets"][0]["ui_spec"]
        errors = module.validate_manifest(manifest, ROOT)
        for expected in ("evidence", "sprite_gen_contract", "visual_anchor", "comfort_constraints", "avoid", "ui_spec"):
            self.assertTrue(any(expected in error for error in errors), (expected, errors))
        with self.assertRaises(ValueError):
            module.build_jobs(manifest, ROOT)

    def test_path_traversal_is_rejected(self):
        module = load_module()
        manifest = minimal_manifest()
        manifest["assets"][0]["output"]["path_pattern"] = "res://../outside_{state}.png"
        errors = module.validate_manifest(manifest, ROOT)
        self.assertTrue(any("project" in error for error in errors))


class ManifestGenerationTests(unittest.TestCase):
    def test_generation_runs_bundled_sprite_gen_with_mm_api_environment(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            create_style_evidence(root)
            (root / "sprite-gen" / "sprite_gen").mkdir(parents=True)
            (root / "aiskill" / "mm-tools").mkdir(parents=True)
            (root / "aiskill" / "mm-tools" / "config.json").write_text(
                json.dumps({"api_key": "secret"}), encoding="utf-8"
            )
            manifest = minimal_manifest()
            manifest["assets"][0]["states"] = ["normal"]
            manifest["assets"][0]["output"]["path_pattern"] = "res://out/button_{state}.png"
            calls = []

            def runner(command, **kwargs):
                calls.append((command, kwargs))
                return type("Result", (), {"returncode": 0})()

            module.generate_jobs(manifest, root, confirm=True, runner=runner)
            command, kwargs = calls[0]
            self.assertEqual("mm-api", command[command.index("--provider") + 1])
            self.assertEqual(root / "sprite-gen", kwargs["cwd"])
            self.assertEqual(str(root / "aiskill" / "mm-tools" / "config.json"), kwargs["env"]["MM_API_CONFIG"])

    def test_mm_api_provider_uses_configured_endpoint_and_never_retries(self):
        import os
        import sys

        root = Path(__file__).resolve().parents[1] / "sprite-gen"
        sys.path.insert(0, str(root))
        from sprite_gen.gen import base, mm_api_provider

        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.json"
            config.write_text(json.dumps({
                "api_key": "test-secret",
                "endpoint": "https://example.test/v1/images/generations",
            }), encoding="utf-8")
            previous = os.environ.get("MM_API_CONFIG")
            os.environ["MM_API_CONFIG"] = str(config)
            calls = []

            def respond(url, token, body, content_type, *, timeout):
                calls.append((url, token, json.loads(body)))
                return 500, {}

            previous_request = mm_api_provider.http_image
            mm_api_provider.http_image = respond
            try:
                request = base.GenRequest(
                    prompt="test image", model="gpt-image-2", raw=Path(directory) / "raw.png",
                )
                provider = mm_api_provider.MmApiProvider()
                with self.assertRaisesRegex(SystemExit, "no retry or provider fallback"):
                    provider.generate(request, Path(directory))
            finally:
                mm_api_provider.http_image = previous_request
                if previous is None:
                    os.environ.pop("MM_API_CONFIG", None)
                else:
                    os.environ["MM_API_CONFIG"] = previous
            self.assertEqual(1, len(calls))
            self.assertEqual("https://example.test/v1/images/generations", calls[0][0])
            self.assertEqual("test-secret", calls[0][1])
            self.assertEqual("gpt-image-2", calls[0][2]["model"])

    def test_generation_requires_confirmation(self):
        module = load_module()
        with self.assertRaisesRegex(ValueError, "confirmation"):
            module.generate_jobs(minimal_manifest(), ROOT, confirm=False, runner=lambda _: None)

    def test_generation_uses_fixed_provider_and_model(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            create_style_evidence(root)
            manifest = minimal_manifest()
            manifest["assets"][0]["output"]["path_pattern"] = "res://out/button_{state}.png"
            calls = []
            module.generate_jobs(manifest, root, confirm=True, runner=lambda command, **_: calls.append(command))
            self.assertEqual(2, len(calls))
            self.assertIn("mm-api", calls[0])
            self.assertIn("gpt-image-2", calls[0])
            self.assertIn("--alpha-mode", calls[0])
            self.assertIn("native", calls[0])
            self.assertNotIn("chroma", calls[0])
            self.assertIn("gpt-image-2", calls[0])

    def test_generation_refuses_existing_output(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            create_style_evidence(root)
            manifest = minimal_manifest()
            manifest["assets"][0]["states"] = ["normal"]
            manifest["assets"][0]["output"]["path_pattern"] = "res://out/button_{state}.png"
            output = root / "out" / "button_normal.png"
            output.parent.mkdir()
            output.write_bytes(b"existing")
            with self.assertRaisesRegex(FileExistsError, "overwrite"):
                module.generate_jobs(manifest, root, confirm=True, runner=lambda _, **__: None)

    def test_verify_checks_dimensions_and_alpha(self):
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            create_style_evidence(root)
            manifest = minimal_manifest()
            manifest["assets"][0]["states"] = ["normal"]
            manifest["assets"][0]["output"]["path_pattern"] = "res://out/button_{state}.png"
            output = root / "out" / "button_normal.png"
            output.parent.mkdir()
            Image.new("RGB", (32, 32), "red").save(output)
            errors = module.verify_outputs(manifest, root)
            self.assertTrue(any("dimensions" in error for error in errors))
            self.assertTrue(any("alpha" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
