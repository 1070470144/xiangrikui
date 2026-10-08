"""Offline gateway compatibility checks: never opens a network connection."""
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "aiskill" / "mm-tools"
sys.path.insert(0, str(TOOLS))
from sprite_gen_gateway import configure_engine, normalize_api_base


class GatewayTests(unittest.TestCase):
    def test_manifest_selects_gateway_without_reading_legacy_config(self):
        from test_mm_manifest import load_module, minimal_manifest, create_style_evidence
        module = load_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            create_style_evidence(root)
            calls = []
            module.generate_jobs(minimal_manifest(), root, confirm=True,
                                 sprite_gen_root=root / "installed-skill",
                                 api_base="https://newapi.oairegbox.cc/",
                                 python_executable="skill-venv-python",
                                 runner=lambda command, **kwargs: calls.append((command, kwargs)))
            command, options = calls[0]
            self.assertEqual("skill-venv-python", command[0])
            self.assertEqual("openai", command[command.index("--provider") + 1])
            self.assertEqual("gpt-image-2", command[command.index("--model") + 1])
            self.assertEqual(root / "installed-skill", options["cwd"])
            self.assertEqual("https://newapi.oairegbox.cc/v1", command[command.index("--api-base") + 1])
            self.assertNotIn("MM_API_CONFIG", options["env"])

    def test_base_validation(self):
        self.assertEqual("https://newapi.oairegbox.cc/v1",
                         normalize_api_base("https://newapi.oairegbox.cc/"))
        self.assertEqual("https://newapi.oairegbox.cc/v1",
                         normalize_api_base("https://newapi.oairegbox.cc/v1/"))
        for bad in ("http://example.test", "https://user:secret@example.test",
                    "https://example.test/v1?key=secret", "https://example.test/images"):
            with self.subTest(url=bad), self.assertRaises(ValueError):
                normalize_api_base(bad)

    def test_engine_receives_endpoint_model_and_native_alpha_without_network(self):
        # Run with the installed skill's venv; skip elsewhere rather than use
        # arbitrary dependencies or the project's obsolete bundled engine.
        import sprite_gen
        skill_root = Path(sprite_gen.__file__).resolve().parents[1]
        provider = configure_engine(skill_root, "https://newapi.oairegbox.cc/")
        from sprite_gen.gen.base import GenRequest
        calls = []

        def fake_http(url, token, data, content_type, *, timeout):
            calls.append((url, token, json.loads(data), content_type))
            return 500, {}

        with tempfile.TemporaryDirectory() as directory:
            request = GenRequest(prompt="offline UI test", model="gpt-image-2",
                                 native_alpha=True, raw=Path(directory) / "raw.png")
            with patch.dict(os.environ, {"OPENAI_API_KEY": "offline-test-token"}), \
                    patch.object(provider, "http_image", fake_http):
                with self.assertRaisesRegex(SystemExit, "no retry or provider fallback"):
                    provider.OpenAIProvider().generate(request, Path(directory))
        self.assertEqual(1, len(calls))
        self.assertEqual("https://newapi.oairegbox.cc/v1/images/generations", calls[0][0])
        self.assertEqual("offline-test-token", calls[0][1])
        self.assertEqual("gpt-image-2", calls[0][2]["model"])
        self.assertEqual("transparent", calls[0][2]["background"])
        self.assertNotIn("offline-test-token", json.dumps(calls[0][2]))


if __name__ == "__main__":
    unittest.main()
