"""Negative fixtures exercise the public read-only asset boundary."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import wave

from PIL import Image

SPEC = importlib.util.spec_from_file_location("validate_assets", Path(__file__).parents[1] / "validate_assets.py")
validator = importlib.util.module_from_spec(SPEC)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class AssetValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        SPEC.loader.exec_module(validator)

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "assets/generated/diagnostic").mkdir(parents=True)
        (self.root / "assets/source").mkdir()
        source = self.root / "assets/source/original.json"
        source.write_text('{"author":"project fixture"}\n')
        self.source = {"path": str(source.relative_to(self.root)), "sha256": digest(source)}
        self.records = []
        for name in ("fixed_tavi_v1", "fixed_neri_v1"):
            self.image(name, (32, 48), "sprite_atlas", (32, 48), [(0, 0, 32, 48)], (16, 43))
            self.records[-1]["animations"] = {
                state: {"frames": [0], "ticks": [6], "loop": True}
                for state in validator.COURIER_CLIPS
            }
        self.image("diagnostic_mover_v1", (32, 32), "sprite_atlas", (32, 32), [(0, 0, 32, 32)], (16, 28))
        self.image("diagnostic_terrain_v1", (160, 120), "tile_atlas", (16, 16),
                   [(2 + x * 20, 2, 16, 16) for x in range(4)], (0, 0))
        self.records[-1]["tile_ids"] = ["solid_fill", "solid_top", "one_way_middle", "hazard_middle"]
        self.image("font_texture_v1", (96, 48), "image")
        font_path = self.root / "assets/generated/diagnostic/font.fnt"
        glyphs = list(range(32, 127)) + [65533]
        lines = ['info face="Original Fixture" size=7', 'common lineHeight=8 base=7 scaleW=96 scaleH=48 pages=1 packed=0',
                 'page id=0 file="font_texture_v1.png"', 'chars count=96']
        lines += [f'char id={code} x={(i % 16) * 6} y={(i // 16) * 8} width=5 height=7 xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15'
                  for i, code in enumerate(glyphs)]
        font_path.write_text("\n".join(lines) + "\n")
        self.records.append({"id": "font_v1", "kind": "font", "path": str(font_path.relative_to(self.root)),
                             "sha256": digest(font_path), "diagnostic": False, "sources": [self.source],
                             "texture_id": "font_texture_v1", "glyphs": glyphs})
        self.manifest = {"schema_version": 1, "content_version": "phase1-v1", "generator_version": "test-1",
                         "seed": 18427, "stage": "diagnostic", "assets": self.records, "sfx": {}, "music": {}}

    def image(self, identifier, size, kind, cell=None, frames=None, origin=None):
        relative = f"assets/generated/diagnostic/{identifier}.png"
        path = self.root / relative
        image = Image.new("RGBA", size)
        if frames:
            for x, y, width, height in frames:
                image.paste((120, 170, 90, 255), (x, y, x + width, y + height))
        if identifier == "font_texture_v1":
            for i in range(1, 96):
                image.putpixel(((i % 16) * 6, (i // 16) * 8), (255, 255, 255, 255))
        image.save(path)
        record = {"id": identifier, "kind": kind, "path": relative, "sha256": digest(path),
                  "diagnostic": True, "sources": [self.source], "size": list(size)}
        if frames:
            record.update(cell_size=list(cell), origin=list(origin), frames=[list(frame) for frame in frames],
                          animations={"idle": {"frames": [0], "ticks": [6], "loop": True}})
        self.records.append(record)
        return record

    def validate(self):
        (self.root / "assets/manifest.json").write_text(json.dumps(self.manifest))
        return validator.validate(self.root, "diagnostic")

    def assert_error(self, phrase):
        errors = self.validate()
        self.assertTrue(any(phrase in error for error in errors), f"No {phrase!r} in {errors!r}")

    def test_valid_diagnostic_is_read_only_and_full_rejects_missing_inventory(self):
        self.assertEqual(self.validate(), [])
        before = {str(p): digest(p) for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(validator.validate(self.root, "diagnostic"), [])
        self.assertEqual(before, {str(p): digest(p) for p in self.root.rglob("*") if p.is_file()})
        self.assertTrue(validator.validate(self.root, "full"))

    def test_missing_and_duplicate_ids(self):
        self.records.pop(0)
        self.assert_error("fixed_tavi_v1")
        self.records.append(copy.deepcopy(self.records[0]))
        self.assert_error("duplicate")

    def test_bad_schema(self):
        self.manifest["schema_version"] = True
        self.assert_error("schema_version")

    def test_path_escape_and_executable_paths(self):
        for bad in ("../escape.png", "/tmp/escape.png", "https://example.test/a.png", "assets/generated/../a.png", "assets/generated/evil.tres", "C:\\escape.png"):
            with self.subTest(path=bad):
                self.records[0]["path"] = bad
                self.assert_error("path")

    def test_symlink_escape(self):
        with tempfile.TemporaryDirectory() as other:
            target = Path(other) / "outside.png"
            Image.new("RGBA", (32, 48)).save(target)
            (self.root / "assets/generated/escape.png").symlink_to(target)
            self.records[0]["path"] = "assets/generated/escape.png"
            self.assert_error("path")

    def test_wrong_hash_dimensions_and_source(self):
        self.records[0]["sha256"] = "0" * 64
        self.assert_error("sha256")
        self.records[0]["size"] = [31, 48]
        self.assert_error("size")
        self.records[0]["sources"] = []
        self.assert_error("sources")

    def test_bad_frames_and_animation_ticks(self):
        self.records[0]["frames"][0][0] = -1
        self.assert_error("frames")
        self.records[0]["animations"]["run"]["ticks"] = [0]
        self.assert_error("ticks")

    def test_overlapping_frames(self):
        self.records[2]["frames"].append([1, 0, 31, 32])
        self.assert_error("overlap")

    def test_missing_animation(self):
        del self.records[0]["animations"]["downed"]
        self.assert_error("downed")

    def test_missing_glyph_and_font_texture(self):
        self.records[-1]["glyphs"].remove(65)
        self.assert_error("glyphs")
        self.records[-1]["texture_id"] = "missing_texture"
        self.assert_error("texture_id")

    def test_cue_reference_must_resolve(self):
        self.manifest["sfx"]["jump"] = "missing_jump"
        self.assert_error("jump")

    def test_non_binary_alpha_rejected(self):
        record = self.records[0]
        path = self.root / record["path"]
        image = Image.open(path).convert("RGBA")
        image.putpixel((10, 10), (0, 0, 0, 128))
        image.save(path)
        record["sha256"] = digest(path)
        self.assert_error("alpha")

    def test_malformed_audio_header_and_loops(self):
        path = self.root / "assets/generated/diagnostic/cue.wav"
        with wave.open(str(path), "wb") as output:
            output.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
            output.writeframes(b"\x00\x00" * 441)
        record = {"id": "cue_test", "kind": "sfx", "path": str(path.relative_to(self.root)), "sha256": digest(path),
                  "diagnostic": True, "sources": [self.source], "sample_rate": 44100, "channels": 1,
                  "sample_width_bytes": 2, "sample_frames": 441, "loop_start": 0, "loop_end": 999}
        self.records.append(record)
        self.assert_error("loop")
        record.update(loop_start=None, loop_end=None, sample_rate=22050)
        self.assert_error("sample_rate")

    def test_theme_masks_are_identical(self):
        for theme in ("ember", "moss"):
            record = self.image(f"terrain_{theme}_v1", (160, 120), "tile_atlas", (16, 16),
                                [(2 + x * 20, 2, 16, 16) for x in range(4)], (0, 0))
            record["tile_ids"] = ["solid_fill", "solid_top", "one_way_middle", "hazard_middle"]
        record = self.records[-1]
        path = self.root / record["path"]
        image = Image.open(path).convert("RGBA")
        image.putpixel((2, 2), (0, 0, 0, 0))
        image.save(path)
        record["sha256"] = digest(path)
        self.assert_error("mask")


if __name__ == "__main__":
    unittest.main()
