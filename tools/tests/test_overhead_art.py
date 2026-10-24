"""Original overhead art contracts, independent of runtime and the full generator."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from gen import art, actors


class OverheadArtTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.direction = json.loads((ROOT / "assets/source/art/direction.json").read_text())
        cls.actor_source = json.loads((ROOT / "assets/source/art/actors.json").read_text())

    def assert_pixel_surface(self, frame, size, opaque=False):
        self.assertEqual(frame.mode, "RGBA")
        self.assertEqual(frame.size, size)
        self.assertIsNotNone(frame.getbbox())
        alpha = frame.getchannel("A").histogram()
        self.assertEqual(sum(alpha[1:255]), 0, "pixel art cannot contain blended alpha")
        if opaque:
            self.assertEqual(alpha[255], size[0] * size[1])

    def test_courier_banks_are_complete_and_distinct(self):
        self.assertEqual(art.COURIER_DIRECTIONS, ("down", "left", "right", "up"))
        expected = {"idle": 4, "run": 6, "slash": 5, "special": 5, "roll": 4,
                    "dash": 2, "hurt": 2, "downed": 2, "revive": 2}
        self.assertEqual(art.COURIER_STATE_COUNTS, expected)
        self.assertEqual(len(art.COURIER_CLIPS), 36)
        for name in ("tavi", "neri"):
            palette = self.direction["couriers"][name]
            frames = []
            for key, count in art.COURIER_CLIPS.items():
                for index in range(count):
                    frame = art.courier(name, key, index, palette)
                    self.assert_pixel_surface(frame, (32, 48))
                    left, top, right, bottom = frame.getbbox()
                    self.assertGreater(left, 0, f"{name}/{key}/{index} clips left")
                    self.assertLess(right, 32, f"{name}/{key}/{index} clips right")
                    self.assertGreater(top, 0)
                    self.assertLess(bottom, 48, f"{name}/{key}/{index} clips feet")
                    frames.append(frame.tobytes())
            self.assertEqual(len(frames), 128)
            self.assertEqual(len(set(frames)), 128, "every authored pose must survive rasterization")
            right = art.courier(name, "idle_right", 0, palette)
            left = art.courier(name, "idle_left", 0, palette)
            self.assertNotEqual(left.tobytes(), right.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes(),
                                "asymmetric original equipment needs an authored side view")
            self.assertNotEqual(art.courier(name, "idle_up", 0, palette).tobytes(),
                                art.courier(name, "idle_down", 0, palette).tobytes())

    def test_courier_atlas_matches_frozen_playback_contract(self):
        expected_ticks = {"idle": [10] * 4, "run": [5] * 6,
                          "slash": [3, 3, 3, 3, 6], "special": [4, 4, 3, 4, 7],
                          "roll": [3] * 4, "dash": [6, 6], "hurt": [5, 7],
                          "downed": [18, 18], "revive": [6, 10]}
        frames = [art.courier("tavi", state, index, self.direction["couriers"]["tavi"])
                  for state, count in art.COURIER_CLIPS.items() for index in range(count)]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._copy_sources(root)
            record = art.atlas(root, "fixed_tavi_v1", frames, (32, 48), 8, 16,
                               (16, 43), art.COURIER_CLIPS)
            self.assertEqual(record["size"], [288, 832])
            self.assertEqual(record["origin"], [16, 43])
            self.assertEqual(len(record["frames"]), 128)
            for key, clip in record["animations"].items():
                state = key.rsplit("_", 1)[0]
                self.assertEqual(clip["ticks"], expected_ticks[state])
                self.assertEqual(clip["loop"], state in ("idle", "run", "downed"))
            with Image.open(root / record["path"]) as atlas:
                alpha = atlas.getchannel("A")
                for x, y, width, height in record["frames"]:
                    self.assertIsNone(alpha.crop((x - 2, y - 2, x + width + 2, y)).getbbox())
                    self.assertIsNone(alpha.crop((x - 2, y, x, y + height)).getbbox())
                    self.assertIsNone(alpha.crop((x + width, y, x + width + 2, y + height)).getbbox())
                    self.assertIsNone(alpha.crop((x - 2, y + height, x + width + 2, y + height + 2)).getbbox())
            self.assertEqual(record["sources"][1]["path"], "tools/gen/art.py")

    def test_actor_frames_are_original_overhead_poses(self):
        self.assertEqual(self.actor_source["content_version"], "overhead-v1")
        for name, clips in actors.CLIPS.items():
            source = self.actor_source["actors"][name]
            frames = []
            for state, count in clips.items():
                self.assertEqual(len(source["clips"][state]["poses"]), count)
                for pose in source["clips"][state]["poses"]:
                    frame = actors.DRAW[name](state, pose, source["palette"])
                    self.assert_pixel_surface(frame, actors.GEOMETRY[name][0])
                    frames.append(frame.tobytes())
            self.assertEqual(len(set(frames)), sum(clips.values()), name)
        self.assertEqual(sum(actors.CLIPS["spoolwarden"].values()), 32)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._copy_sources(root)
            records = {record["id"]: record for record in actors.generate(root)}
            self.assertEqual(records["spoolwarden_v1"]["size"], [544, 272])
            self.assertEqual(records["spoolwarden_v1"]["origin"], [32, 59])
            wing = records["wickwing_v1"]
            self.assertEqual(len(wing["frames"]), 14)
            with Image.open(root / wing["path"]) as sheet:
                self.assertIsNone(sheet.crop((216, 36, 288, 72)).getchannel("A").getbbox())
            for record in records.values():
                paths = {item["path"] for item in record["sources"]}
                self.assertTrue({"tools/gen/actors.py", "assets/source/art/actors.json"} <= paths)

    def test_terrain_has_exact_order_and_opaque_materials(self):
        expected = ["floor_path_1", "floor_path_2", "floor_grass_1", "floor_grass_2"]
        expected += [f"wall_fill_{i}" for i in range(1, 5)]
        expected += [f"wall_edge_{d}" for d in ("north", "east", "south", "west")]
        expected += [f"wall_corner_{kind}_{d}" for kind in ("outer", "inner") for d in ("ne", "se", "sw", "nw")]
        expected += [f"water_fill_{i}" for i in range(1, 5)]
        expected += [f"water_edge_{d}" for d in ("north", "east", "south", "west")]
        expected += [f"water_corner_{d}" for d in ("ne", "se", "sw", "nw")]
        expected += ["bridge_plank_1", "bridge_plank_2", "bridge_rail_north", "bridge_rail_south"]
        expected += [f"seam_rune_{i}" for i in range(1, 5)]
        expected += ["background_earth_1", "background_earth_2", "background_roots_1", "background_roots_2",
                     "hazard_glass_1", "hazard_glass_2", "hazard_thread_1", "hazard_thread_2"]
        self.assertEqual(art.TILE_IDS, expected)
        images = {}
        for theme in ("ember", "moss"):
            frames = [art.tile_image(key, self.direction[theme], i) for i, key in enumerate(expected)]
            for frame in frames:
                self.assert_pixel_surface(frame, (16, 16), opaque=True)
            self.assertEqual(len({frame.tobytes() for frame in frames}), 48)
            images[theme] = frames
        for ember, moss in zip(images["ember"], images["moss"]):
            self.assertEqual(ember.getchannel("A").tobytes(), moss.getchannel("A").tobytes())
        with self.assertRaises(ValueError):
            art.tile_image("one_way_middle", self.direction["ember"])

    def test_effects_have_six_binary_alpha_frames_and_local_heading(self):
        for name in art.EFFECT_IDS:
            frames = [art.effect_image(name, index) for index in range(6)]
            size = 64 if name == "restoration" else 32
            for frame in frames:
                self.assert_pixel_surface(frame, (size, size))
            self.assertEqual(len({frame.tobytes() for frame in frames}), 6, name)
            if name in ("slash", "ember_arc"):
                for frame in frames:
                    self.assertGreaterEqual(frame.getbbox()[0], 16,
                                            "directional arcs must stay on the +X side")
            for frame in frames:
                rotated = frame.transpose(Image.Transpose.ROTATE_90)
                self.assert_pixel_surface(rotated, (size, size))
                self.assertEqual(rotated.getchannel("A").histogram(), frame.getchannel("A").histogram())

    def test_enemy_warning_is_immediate_hollow_and_rotates_around_its_origin(self):
        warning = self.actor_source["effects"]["enemy_warning"]
        frames = [actors.enemy_warning_image(pose, warning["palette"]) for pose in warning["poses"]]
        self.assertEqual(len(frames), 6)
        self.assertEqual(len({frame.tobytes() for frame in frames}), 6)
        palette = {(34, 36, 51, 255), (240, 120, 101, 255), (255, 224, 161, 255)}
        first_pixels = [frames[0].getpixel((x, y)) for y in range(32) for x in range(32)]
        for frame in frames:
            self.assert_pixel_surface(frame, (32, 32))
            pixels = [frame.getpixel((x, y)) for y in range(32) for x in range(32)]
            visible = {pixel for pixel in pixels if pixel[3]}
            self.assertEqual(visible, palette)
            left, top, right, bottom = frame.getbbox()
            self.assertGreaterEqual(left, 16, "warning must point along local +X")
            self.assertLess(right, 32, "the arrow tip must not be clipped")
            self.assertGreater(top, 0)
            self.assertLess(bottom, 32)
            opaque = frame.getchannel("A").histogram()[255]
            self.assertGreater(opaque, 80, "every frame must immediately show the warning")
            self.assertLess(opaque, (right - left) * (bottom - top) / 2,
                            "the hollow marker must leave most covered ground transparent")
            changed = sum(a != b for a, b in zip(first_pixels, pixels))
            self.assertLessEqual(changed, 4, "the rim must stay steady, without flashing")
            for turns in range(4):
                rotated = frame.rotate(turns * 90, center=(16, 16), resample=Image.Resampling.NEAREST)
                self.assertEqual(rotated.getchannel("A").histogram(), frame.getchannel("A").histogram(),
                                 "quarter turns around the declared origin cannot clip the warning")
                opaque_positions = [(x - 16, y - 16) for y in range(32) for x in range(32)
                                    if rotated.getpixel((x, y))[3]]
                dx = sum(x for x, _ in opaque_positions)
                dy = sum(y for _, y in opaque_positions)
                forward, across = ((dx, dy), (-dy, dx), (-dx, dy), (dy, dx))[turns]
                self.assertGreater(forward, abs(across) * 4,
                                   "the marker must keep an unambiguous cardinal heading")
        legacy_slashes = {art.effect_image(name, index).tobytes()
                          for name in ("slash", "ember_arc") for index in range(6)}
        self.assertTrue(all(frame.tobytes() not in legacy_slashes for frame in frames))

    def test_enemy_warning_has_its_own_nonloop_atlas_and_editable_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._copy_sources(root)
            records = actors.generate(root)
            warnings = [record for record in records if record["id"] == "effect_enemy_warning_v1"]
            self.assertEqual(len(warnings), 1)
            record = warnings[0]
            self.assertEqual(record["cell_size"], [32, 32])
            self.assertEqual(record["origin"], [16, 16])
            self.assertEqual(record["size"], [216, 36])
            self.assertEqual(len(record["frames"]), 6)
            self.assertEqual(record["animations"], {"play": {
                "frames": list(range(6)), "ticks": [6] * 6, "loop": False}})
            paths = {source["path"] for source in record["sources"]}
            self.assertTrue({"tools/gen/actors.py", "assets/source/art/actors.json"} <= paths)
            for source in record["sources"]:
                self.assertEqual(source["sha256"], hashlib.sha256((root / source["path"]).read_bytes()).hexdigest())
            with Image.open(root / record["path"]) as sheet:
                for index, (x, y, width, height) in enumerate(record["frames"]):
                    crop = sheet.crop((x, y, x + width, y + height))
                    warning = self.actor_source["effects"]["enemy_warning"]
                    expected = actors.enemy_warning_image(warning["poses"][index], warning["palette"])
                    self.assertEqual(crop.tobytes(), expected.tobytes())
                    self.assertIsNone(sheet.crop((x - 2, 0, x, 36)).getchannel("A").getbbox())
                    self.assertIsNone(sheet.crop((x + width, 0, x + width + 2, 36)).getchannel("A").getbbox())

    def _copy_sources(self, root):
        for relative in ("assets/source/art/direction.json", "assets/source/art/actors.json",
                         "tools/gen/art.py", "tools/gen/actors.py"):
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)


if __name__ == "__main__":
    unittest.main()
