"""Tests at the public generator seam, independent of the validators."""
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))


class GenerationTests(unittest.TestCase):
    def test_full_bundle_rebuilds_byte_identically_and_validates(self):
        from generate_assets import generate
        from validate_assets import validate
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            shutil.copytree(ROOT / "assets/source", output / "assets/source")
            shutil.copytree(ROOT / "tools", output / "tools")
            first = generate(output, 18427, "full")
            manifest_bytes = (output / "assets/manifest.json").read_bytes()
            self.assertEqual(validate(output, "full"), [])
            second = generate(output, 18427, "full")
            self.assertEqual(first, second)
            self.assertEqual(manifest_bytes, (output / "assets/manifest.json").read_bytes())
            self.assertEqual(validate(output, "full"), [])
            self.assertEqual(len(first["sfx"]), 18)
            self.assertEqual(len(first["music"]), 3)
            self.assertTrue(all(not item["diagnostic"] for item in first["assets"]))

    def test_diagnostic_contract_and_repeatability(self):
        from generate_assets import generate
        from PIL import Image
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            shutil.copytree(ROOT / "assets/source", output / "assets/source")
            shutil.copytree(ROOT / "tools", output / "tools")
            first = generate(output, 18427, "diagnostic")
            second = generate(output, 18427, "diagnostic")
            self.assertEqual(first, second)
            assets = {asset["id"]: asset for asset in first["assets"]}
            self.assertEqual(assets["diagnostic_terrain_v1"]["size"], [160, 120])
            for courier in ("tavi", "neri"):
                asset = assets[f"fixed_{courier}_v1"]
                self.assertEqual(asset["origin"], [16, 43])
                self.assertEqual(len(asset["animations"]), 11)
                with Image.open(output / asset["path"]) as image:
                    self.assertEqual(image.size, (32, 48))
            self.assertEqual(len(assets["font_v1"]["glyphs"]), 96)


if __name__ == "__main__":
    unittest.main()
