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

    def image(self, identifier, size, kind, cell=None, frames=None, origin=None, folder="diagnostic"):
        names = {"diagnostic_terrain_v1": "tiles_diag", "diagnostic_mover_v1": "mover_diag",
                 "fixed_tavi_v1": "courier_tavi_diag", "fixed_neri_v1": "courier_neri_diag"}
        filename = names.get(identifier, identifier) if folder == "diagnostic" else identifier
        relative = f"assets/generated/{folder}/{filename}.png"
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
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
        return validator.validate(self.root, self.manifest["stage"])

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

    def test_malformed_fields_report_their_location(self):
        cases = [("kind", []), ("sources", 17), ("frames", [None]), ("animations", []),
                 ("cell_size", [None, 48]), ("origin", [16.5, 43])]
        record = self.records[0]
        for field, value in cases:
            with self.subTest(field=field):
                old = copy.deepcopy(record[field])
                record[field] = value
                errors = self.validate()
                self.assertTrue(any(f"fixed_tavi_v1.{field}" in error for error in errors), errors)
                self.assertFalse(any("malformed asset data" in error for error in errors), errors)
                record[field] = old

    def test_duplicate_json_keys_rejected(self):
        (self.root / "assets/manifest.json").write_text('{"schema_version":1,"schema_version":2}')
        errors = validator.validate(self.root, "diagnostic")
        self.assertTrue(any("duplicate JSON key" in error for error in errors), errors)

    def test_bad_schema(self):
        self.manifest["schema_version"] = True
        self.assert_error("schema_version")

    def test_path_escape_and_executable_paths(self):
        for bad in ("../escape.png", "/tmp/escape.png", "https://example.test/a.png", "assets/generated/../a.png", "assets/generated/evil.tres", "C:\\escape.png", "assets/generated/a\0.png"):
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

    def test_diagnostic_runtime_path_is_fixed(self):
        record = self.records[3]
        old = self.root / record["path"]
        new = old.with_name("renamed_tiles.png")
        new.write_bytes(old.read_bytes())
        record["path"] = str(new.relative_to(self.root))
        self.assert_error("diagnostic runtime path")

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

    def full_fixture(self):
        """An independently assembled full inventory proves full-mode acceptance."""
        font_records = copy.deepcopy(self.records[-2:])
        self.records.clear()
        for record in font_records:
            old = self.root / record["path"]
            new = self.root / "assets/generated/font" / old.name
            new.parent.mkdir(parents=True, exist_ok=True)
            new.write_bytes(old.read_bytes())
            record.update(path=str(new.relative_to(self.root)), diagnostic=False)
            self.records.append(record)

        def sprite(identifier, cell, columns, count, origin, clips=None):
            rows = (count + columns - 1) // columns
            size = (columns * (cell[0] + 4), rows * (cell[1] + 4))
            frames = [(2 + i % columns * (cell[0] + 4), 2 + i // columns * (cell[1] + 4), *cell) for i in range(count)]
            record = self.image(identifier, size, "sprite_atlas", cell, frames, origin, folder="full")
            record["diagnostic"] = False
            if clips is not None:
                offset = 0
                record["animations"] = {}
                for state, length in clips.items():
                    record["animations"][state] = {"frames": list(range(offset, offset + length)), "ticks": [6] * length, "loop": False}
                    offset += length
            return record

        for identifier in ("fixed_tavi_v1", "fixed_neri_v1"):
            sprite(identifier, (32, 48), 8, 32, (16, 43), validator.COURIER_CLIPS)
        sprite("oru_v1", (32, 48), 8, 8, (16, 43), {"idle": 4, "talk": 2, "acknowledge": 2})
        for identifier, count in (("spoolmite_v1", 16), ("wickwing_v1", 14)):
            sprite(identifier, (32, 32), 8, count, (16, 28), validator.ENEMY_CLIPS[identifier])
        sprite("spoolwarden_v1", (64, 64), 8, 32, (32, 59), validator.ENEMY_CLIPS["spoolwarden_v1"])
        props = sprite("props_v1", (32, 48), 8, 16, (16, 43))
        props["logical_props"] = ["anchor", "loom", "bell", "lantern", "sign", "checkpoint"] + [f"dressing_{i}" for i in range(10)]
        props["prop_ids"] = props["logical_props"].copy()
        sprite("ui_v1", (16, 16), 5, 20, (8, 8))
        for theme in ("ember", "moss"):
            record = sprite(f"terrain_{theme}_v1", (16, 16), 8, 48, (0, 0))
            record.update(kind="tile_atlas", tile_ids=validator.TILE_IDS.copy(), animations={})
            for layer in ("far", "middle", "near"):
                record = self.image(f"background_{theme}_{layer}_v1", (480, 360), "image", folder="full")
                record.update(diagnostic=False, extent="finite")
        for effect in validator.EFFECT_NAMES:
            sprite(f"effect_{effect}_v1", (32, 32), 6, 6, (16, 16), {"play": 6})
        self.manifest["stage"] = "full"
        for family, names, channels in (("sfx", validator.SFX_NAMES, 1), ("music", validator.MUSIC_NAMES, 2)):
            for name in sorted(names):
                path = self.root / f"assets/generated/full/{family}_{name}.wav"
                with wave.open(str(path), "wb") as output:
                    output.setparams((channels, 2, 44100, 0, "NONE", "not compressed"))
                    output.writeframes(b"\x00\x00" * 441 * channels)
                loops = family == "music" and name != "ending"
                record = {"id": f"{family}_{name}", "kind": family, "path": str(path.relative_to(self.root)),
                          "sha256": digest(path), "diagnostic": False, "sources": [self.source],
                          "sample_rate": 44100, "channels": channels, "sample_width_bytes": 2, "sample_frames": 441,
                          "loop_start": 0 if loops else None, "loop_end": 441 if loops else None}
                self.records.append(record)
                self.manifest[family][name] = record["id"]

    def test_full_inventory_passes(self):
        self.full_fixture()
        self.assertEqual(self.validate(), [])

    def test_full_marker_and_directory_cannot_hide_diagnostic_dependency(self):
        self.full_fixture()
        self.records[0]["diagnostic"] = True
        self.assert_error("diagnostic")
        self.records[0]["diagnostic"] = False
        self.records[0]["path"] = "assets/generated/diagnostic/font_texture_v1.png"
        self.assert_error("diagnostic directory")

    def test_full_slot_layout_and_gutters(self):
        self.full_fixture()
        record = next(record for record in self.records if record["id"] == "fixed_tavi_v1")
        record["frames"][0][0] += 1
        self.assert_error("row-major")
        record["frames"][0][0] -= 1
        path = self.root / record["path"]
        image = Image.open(path).convert("RGBA")
        image.putpixel((0, 0), (255, 0, 0, 255))
        image.save(path)
        record["sha256"] = digest(path)
        self.assert_error("gutter")

    def test_full_clip_budget_and_expected_kind(self):
        self.full_fixture()
        record = next(record for record in self.records if record["id"] == "fixed_tavi_v1")
        record["animations"]["run"]["frames"] = [0]
        record["animations"]["run"]["ticks"] = [6]
        self.assert_error("requires 6 frames")
        record["kind"] = "image"
        self.assert_error("required kind")

    def test_full_prop_families_and_states(self):
        self.full_fixture()
        record = next(record for record in self.records if record["id"] == "props_v1")
        record["logical_props"][-1] = "anchor"
        self.assert_error("logical_props")
        record["prop_ids"][0] = record["prop_ids"][1]
        self.assert_error("prop_ids")

    def test_font_duplicate_cells_rejected(self):
        record = self.records[-1]
        path = self.root / record["path"]
        text = path.read_text().replace("char id=33 x=6 y=0", "char id=33 x=0 y=0")
        path.write_text(text)
        record["sha256"] = digest(path)
        self.assert_error("own 6x8 atlas cell")

    def test_full_effect_requires_a_playable_sequence(self):
        self.full_fixture()
        record = next(record for record in self.records if record["id"] == "effect_slash_v1")
        record["animations"] = {}
        self.assert_error("six-frame sequence")

    def test_full_missing_semantic_cue(self):
        self.full_fixture()
        del self.manifest["sfx"]["jump"]
        self.assert_error("jump")

    def test_font_bitmap_must_contain_visible_glyph(self):
        record = self.records[-2]
        path = self.root / record["path"]
        Image.new("RGBA", (96, 48)).save(path)
        record["sha256"] = digest(path)
        self.assert_error("no visible pixels")

    def test_bad_audio_peak_and_loop_seam(self):
        self.full_fixture()
        record = next(record for record in self.records if record["id"] == "music_boss")
        path = self.root / record["path"]
        with wave.open(str(path), "wb") as output:
            output.setparams((2, 2, 44100, 0, "NONE", "not compressed"))
            output.writeframes(b"\xff\x7f" * 2 + b"\x00\x00" * 440 * 2)
        record["sha256"] = digest(path)
        self.assert_error("peak")
        self.assert_error("discontinuity")

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
