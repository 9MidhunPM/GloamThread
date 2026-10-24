"""Public CLI checks for labelled overhead authoring studies, not gameplay."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
VERSION = "overhead-v1"
MATERIALS = ["floor_path_1", "wall_fill_1", "water_fill_1",
             "hazard_glass_1", "bridge_plank_1"]
COLOURS = [(70, 90, 40, 255), (130, 100, 60, 255), (20, 70, 150, 255),
           (230, 50, 60, 255), (190, 150, 80, 255)]


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "project"
        self.output = Path(self.temp.name) / "studies"
        script = self.root / "tools/gen/preview.py"
        script.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "tools/gen/preview.py", script)
        self.assets = []
        for theme in ("ember", "moss"):
            atlas = Image.new("RGBA", (16 * len(MATERIALS), 16))
            for index, colour in enumerate(COLOURS):
                atlas.paste(colour, (16 * index, 0, 16 * (index + 1), 16))
            self.asset("terrain_" + theme + "_v1", atlas, "tile_atlas",
                       frames=[[16 * i, 0, 16, 16] for i in range(len(MATERIALS))],
                       origin=[0, 0], tile_ids=MATERIALS)
        for identifier in ("fixed_tavi_v1", "fixed_neri_v1", "oru_v1",
                           "spoolmite_v1", "wickwing_v1", "spoolwarden_v1"):
            self.asset(identifier, Image.new("RGBA", (4, 12), (30, 220, 230, 255)),
                       "sprite_atlas", frames=[[0, 0, 4, 12]], origin=[2, 11])
        self.asset("props_v1", Image.new("RGBA", (12, 24), (230, 30, 120, 255)),
                   "sprite_atlas", frames=[[0, 0, 12, 24]], origin=[6, 23])
        self.asset("ui_v1", Image.new("RGBA", (4, 4), "white"), "sprite_atlas",
                   frames=[[0, 0, 4, 4]], origin=[0, 0])
        # Deliberately synthetic font pixels: fixtures test composition, not art.
        self.asset("font_texture_v1", Image.new("RGBA", (96, 48), "white"), "image")
        self.assets.append({"id": "font_v1", "kind": "font",
                            "texture_id": "font_texture_v1", "glyphs": list(range(32, 127))})
        self.write("assets/manifest.json", {"schema_version": 1, "content_version": VERSION,
                   "stage": "full", "assets": self.assets})
        self.write("content/world.json", {"schema_version": 1, "content_version": VERSION,
                   "start_room": "r00", "rooms": [{"id": "r00"}]})
        tiles = [list("." * 60) for _ in range(45)]
        for x, marker in zip(range(28, 32), "#~^="):
            tiles[20][x] = marker
        self.room = {"schema_version": 1, "content_version": VERSION, "id": "r00",
                     "tiles": ["".join(row) for row in tiles],
                     "spawns": {"start": [[30, 22], [32, 22]]},
                     "entities": [], "decor": []}
        self.write("content/rooms/r00.json", self.room)

    def write(self, relative, data):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))

    def asset(self, identifier, image, kind, **metadata):
        relative = "assets/generated/" + identifier + ".png"
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
        self.assets.append({"id": identifier, "kind": kind, "path": relative,
                            "size": list(image.size), **metadata})

    def cli(self, explicit=True, room=None):
        args = [sys.executable, str(self.root / "tools/gen/preview.py")]
        if explicit:
            args += ["--output", str(self.output)]
        if room is not None:
            args += ["--room", room]
        return subprocess.run(args, capture_output=True, text=True, timeout=15)

    def image(self):
        with Image.open(self.output / "r00_themes.png") as image:
            image.load()
            return image.copy()

    def test_opaque_materials_spawn_crop_and_repeatability(self):
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("NO PHYSICS", result.stdout)
        image = self.image()
        self.assertEqual(image.size, (960, 392))
        self.assertEqual(image.getchannel("A").getextrema(), (255, 255))
        self.assertEqual(image.info["Crop"], "264,185")
        self.assertIn("AUTHORING ONLY", image.info["Description"])
        self.assertIn("OVERHEAD", image.info["Description"])
        for half in (0, 480):
            for x, colour in zip(range(28, 32), COLOURS[1:]):
                self.assertEqual(image.getpixel((half + x * 16 + 8 - 264, 20 * 16 + 8 - 185 + 32)), colour)
            self.assertEqual(image.getpixel((half + 100, 100)), COLOURS[0])
            # The actor's last pixel is on tile*16+(8,13), not the old +16 baseline.
            self.assertEqual(image.getpixel((half + 224, 180 + 32)), (30, 220, 230, 255))
            self.assertEqual(image.getpixel((half + 224, 181 + 32)), COLOURS[0])
        before = {p.name: p.read_bytes() for p in self.output.glob("*.png")}
        self.assertEqual(self.cli().returncode, 0)
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.output.glob("*.png")})

    def test_foreground_props_and_actors_share_feet_order(self):
        self.room["entities"] = [{"type": "npc", "tile": [28, 24]},
                                 {"type": "npc", "tile": [34, 24]}]
        self.room["decor"] = [
            {"asset_id": "props_v1", "frame": 0, "position_px": [456, 401], "theme": "common", "z": 0},
            {"asset_id": "props_v1", "frame": 0, "position_px": [552, 393], "theme": "common", "z": 0}]
        self.write("content/rooms/r00.json", self.room)
        result = self.cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        image = self.image()
        for half in (0, 480):
            self.assertEqual(image.getpixel((half + 456 - 264, 390 - 185 + 32)), (230, 30, 120, 255))
            self.assertEqual(image.getpixel((half + 552 - 264, 390 - 185 + 32)), (30, 220, 230, 255))

    def test_legacy_epochs_reject_before_output_creation_or_clobber(self):
        for relative in ("assets/manifest.json", "content/world.json", "content/rooms/r00.json"):
            with self.subTest(relative=relative):
                path = self.root / relative
                original = path.read_text()
                data = json.loads(original)
                data["content_version"] = "phase1-v1"
                self.write(relative, data)
                self.output.mkdir(exist_ok=True)
                sentinel = self.output / "r00_themes.png"
                sentinel.write_bytes(b"previous evidence must survive")
                result = self.cli()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(relative, result.stderr)
                self.assertIn("overhead-v1", result.stderr)
                self.assertIn("Integrate", result.stderr)
                self.assertEqual(sentinel.read_bytes(), b"previous evidence must survive")
                self.assertEqual(list(self.output.iterdir()), [sentinel])
                sentinel.unlink()
                self.output.rmdir()
                self.assertNotEqual(self.cli().returncode, 0)
                self.assertFalse(self.output.exists())
                path.write_text(original)

    def test_missing_asset_reports_id_and_writes_nothing(self):
        path = self.root / "assets/generated/terrain_moss_v1.png"
        path.unlink()
        result = self.cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("terrain_moss_v1", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(self.output.exists())

    def test_late_missing_sheet_preserves_existing_studies(self):
        manifest = json.loads((self.root / "assets/manifest.json").read_text())
        manifest["assets"] = [asset for asset in manifest["assets"] if asset["id"] != "ui_v1"]
        self.write("assets/manifest.json", manifest)
        self.output.mkdir()
        sentinel = self.output / "r00_themes.png"
        sentinel.write_bytes(b"retained earlier study")
        result = self.cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ui_v1", result.stderr)
        self.assertEqual(sentinel.read_bytes(), b"retained earlier study")
        self.assertEqual(list(self.output.iterdir()), [sentinel])

    def test_crop_uses_room_centre_or_clamps_spawn_focus_on_both_axes(self):
        for spawns, expected in (({}, "240,180"),
                                 ({"start": [[0, 0], [1, 0]]}, "0,0"),
                                 ({"start": [[58, 43], [59, 43]]}, "480,360")):
            with self.subTest(spawns=spawns):
                self.room["spawns"] = spawns
                self.write("content/rooms/r00.json", self.room)
                result = self.cli()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.image().info["Crop"], expected)

    def test_later_legacy_room_cannot_leave_a_partial_study_set(self):
        self.write("content/world.json", {"schema_version": 1, "content_version": VERSION,
                   "rooms": [{"id": "r00"}, {"id": "r01"}]})
        self.write("content/rooms/r01.json", {**self.room, "id": "r01", "content_version": "phase1-v1"})
        result = self.cli()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("content/rooms/r01.json", result.stderr)
        self.assertFalse(self.output.exists())

    def test_explicit_room_selects_only_migrated_data_and_keeps_epoch_guard(self):
        self.write("content/world.json", {"schema_version": 1, "content_version": VERSION,
                   "rooms": [{"id": "r00"}, {"id": "r01"}]})
        self.write("content/rooms/r01.json", {**self.room, "id": "r01", "content_version": "phase1-v1"})
        result = self.cli(room="r00")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / "r00_themes.png").exists())
        self.assertFalse((self.output / "r01_themes.png").exists())
        before = {p.name: p.read_bytes() for p in self.output.glob("*.png")}
        result = self.cli(room="r01")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("content/rooms/r01.json", result.stderr)
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.output.glob("*.png")})
        result = self.cli(room="r07")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not listed", result.stderr)

    def test_default_output_preserves_historical_authoring_evidence(self):
        historical = self.root / "evidence/content/authoring/r00_themes.png"
        historical.parent.mkdir(parents=True)
        historical.write_bytes(b"preserved side-view authoring evidence")
        snapshot = self.root / "evidence/content/overhead/authoring_snapshot/r00_themes.png"
        snapshot.parent.mkdir(parents=True)
        snapshot.write_bytes(b"frozen overhead authoring snapshot")
        result = self.cli(explicit=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(historical.read_bytes(), b"preserved side-view authoring evidence")
        self.assertEqual(snapshot.read_bytes(), b"frozen overhead authoring snapshot")
        self.assertTrue((self.root / "evidence/content/overhead/authoring/r00_themes.png").is_file())


if __name__ == "__main__":
    unittest.main()
