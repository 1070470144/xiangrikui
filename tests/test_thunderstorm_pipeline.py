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
import seedance_weather_video as weather


class ThunderstormPipelineTests(unittest.TestCase):
    def test_submit_body_and_single_task_guard(self):
        with tempfile.TemporaryDirectory() as directory:
            run = Path(directory)
            seen = {}
            class Reply:
                def __enter__(self): return self
                def __exit__(self, *args): return False
                def read(self): return b'{"id":"task-1"}'
            def opener(request, timeout):
                seen["request"] = request
                return Reply()
            with patch.dict(os.environ, {"ARK_API_KEY": "test-token"}), patch.object(weather.urllib.request, "urlopen", opener):
                with patch.object(sys, "argv", ["seedance", "submit", "--run-dir", str(run)]):
                    weather.main()
            body = json.loads(seen["request"].data)
            self.assertEqual("doubao-seedance-2-0-mini-260615", body["model"])
            self.assertEqual(4, body["duration"])
            self.assertEqual("16:9", body["ratio"])
            self.assertNotIn("test-token", json.dumps(body))
            with self.assertRaisesRegex(SystemExit, "Existing task report"):
                with patch.object(sys, "argv", ["seedance", "submit", "--run-dir", str(run)]):
                    weather.main()

    def test_missing_key_fails_before_network(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(SystemExit, "ARK_API_KEY is required"):
                weather.request("GET", weather.BASE)


if __name__ == "__main__":
    unittest.main()
