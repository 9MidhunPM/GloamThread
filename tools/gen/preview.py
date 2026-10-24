#!/usr/bin/env python3
"""Labelled overhead material/pose studies from an existing validated PNG pack.

This does not execute Godot, collision, movement, restoration, or camera logic.
Use the content/asset validators for the selected milestone; these studies do
not replace their checks.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

from PIL import Image
from PIL.PngImagePlugin import PngInfo

VERSION = "overhead-v1"
VIEW = (480, 360)
HEADER = 32
CAPTION = "AUTHORING ONLY / NO PHYSICS"
MATERIALS = {"#": "wall_fill_1", ".": "floor_path_1", "~": "water_fill_1",
             "^": "hazard_glass_1", "=": "bridge_plank_1"}
ACTORS = {"npc": "oru_v1", "spoolmite": "spoolmite_v1", "wickwing": "wickwing_v1",
          "spoolwarden": "spoolwarden_v1"}
SHEETS = {"couriers": ["fixed_tavi_v1", "fixed_neri_v1", "oru_v1"],
          "enemies": ["spoolmite_v1", "wickwing_v1", "spoolwarden_v1"],
          "terrain": ["terrain_ember_v1", "terrain_moss_v1"],
          "props": ["props_v1", "ui_v1"]}


class PreviewError(ValueError):
    """An actionable preparation failure; existing studies are left alone."""


def read_json(root: Path, relative: str) -> dict:
    try:
        data = json.loads((root / relative).read_text())
    except (OSError, ValueError) as exc:
        raise PreviewError(f"Cannot read {relative}: {exc}") from exc
    if not isinstance(data, dict):
        raise PreviewError(f"{relative}: expected a JSON object")
    if data.get("schema_version") != 1 or data.get("content_version") != VERSION:
        raise PreviewError(f"{relative}: requires schema 1 / content_version {VERSION}; "
                           f"found {data.get('content_version')!r}. Integrate matching overhead "
                           "rooms and manifest, then run content/asset validation. No outputs written.")
    return data


def read_rooms(root: Path, selected: str | None = None) -> list[dict]:
    world = read_json(root, "content/world.json")
    if not isinstance(world.get("rooms"), list) or not world["rooms"]:
        raise PreviewError("content/world.json: rooms must be a nonempty array")
    rooms = []
    seen = set()
    for entry in world["rooms"]:
        identifier = entry.get("id") if isinstance(entry, dict) else None
        if not isinstance(identifier, str) or not re.fullmatch(r"r0[0-7]", identifier) or identifier in seen:
            raise PreviewError("content/world.json: expected unique room IDs r00-r07")
        seen.add(identifier)
        if selected is not None and identifier != selected:
            continue
        room = read_json(root, f"content/rooms/{identifier}.json")
        tiles = room.get("tiles")
        if room.get("id") != identifier or not isinstance(tiles, list) or not tiles or not isinstance(tiles[0], str) or not tiles[0]:
            raise PreviewError(f"Room {identifier}: missing ID or tile rows; run validate_content.py")
        if any(not isinstance(row, str) or len(row) != len(tiles[0]) or set(row) - MATERIALS.keys() for row in tiles):
            raise PreviewError(f"Room {identifier}: expected rectangular overhead # . ~ ^ = tiles")
        rooms.append(room)
    if selected is not None and selected not in seen:
        raise PreviewError(f"Room {selected} is not listed in content/world.json")
    return rooms


class Pack:
    def __init__(self, root: Path, manifest: dict):
        if manifest.get("stage") != "full":
            raise PreviewError("Authoring studies require the full overhead asset manifest")
        self.assets = {}
        self.images = {}
        records = manifest.get("assets")
        if not isinstance(records, list):
            raise PreviewError("assets/manifest.json: assets must be an array")
        for record in records:
            key = record.get("id") if isinstance(record, dict) else None
            if not isinstance(key, str) or key in self.assets:
                raise PreviewError("assets/manifest.json: asset IDs must be unique strings")
            self.assets[key] = record
            if record.get("kind") not in ("sprite_atlas", "tile_atlas", "image"):
                continue
            relative = record.get("path", "")
            try:
                path = (root / relative).resolve()
                if not path.is_relative_to((root / "assets/generated").resolve()) or path.suffix != ".png":
                    raise ValueError("expected a PNG inside assets/generated")
                with Image.open(path) as image:
                    if image.format != "PNG" or list(image.size) != record.get("size"):
                        raise ValueError("PNG format/dimensions differ from the manifest")
                    self.images[key] = image.convert("RGBA")
            except (OSError, ValueError, TypeError) as exc:
                raise PreviewError(f"Asset {key} ({relative}): {exc}. Restore the matching PNG "
                                   "and run tools/validate_assets.py before previewing.") from exc
        font = self.record("font_v1")
        self.font_image = self.image(font.get("texture_id"))
        glyphs = font.get("glyphs")
        if self.font_image.size != (96, 48) or not isinstance(glyphs, list):
            raise PreviewError("font_v1: expected the original 6x8-cell bitmap alphabet")
        self.glyphs = {code: index for index, code in enumerate(glyphs)}

    def record(self, key: str) -> dict:
        if key not in self.assets:
            raise PreviewError(f"Required asset {key!r} is missing from assets/manifest.json; run tools/validate_assets.py")
        return self.assets[key]

    def image(self, key: str) -> Image.Image:
        if key not in self.images:
            raise PreviewError(f"Required PNG asset {key!r} is missing; restore the full overhead pack")
        return self.images[key]

    def frame(self, key: str, index: int = 0) -> Image.Image:
        record = self.record(key)
        try:
            x, y, width, height = record["frames"][index]
            image = self.image(key)
            if min(x, y) < 0 or min(width, height) <= 0 or x + width > image.width or y + height > image.height:
                raise ValueError("frame is outside its PNG")
            return image.crop((x, y, x + width, y + height))
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise PreviewError(f"Asset {key}, frame {index}: invalid frame; run tools/validate_assets.py") from exc

    def label(self, image: Image.Image, text: str, x: int, y: int) -> None:
        # Reuse the manifested original bitmap pixels, never a system font.
        for character in text:
            slot = self.glyphs.get(ord(character), self.glyphs.get(ord("?")))
            if slot is None:
                raise PreviewError("font_v1: caption glyphs are missing")
            gx, gy = slot % 16 * 6, slot // 16 * 8
            image.alpha_composite(self.font_image.crop((gx, gy, gx + 5, gy + 7)), (x, y))
            x += 6

    def place(self, view: Image.Image, key: str, feet: tuple, index: int, crop: tuple) -> None:
        ox, oy = self.record(key)["origin"]
        view.alpha_composite(self.frame(key, index),
                             (round(feet[0] - ox - crop[0]), round(feet[1] - oy - crop[1])))


def feet_position(tile: list) -> tuple:
    return tile[0] * 16 + 8, tile[1] * 16 + 13


def study_crop(room: dict) -> tuple[tuple[int, int], list]:
    spawns = room.get("spawns", {})
    entrance = "start" if "start" in spawns else next(iter(sorted(spawns)), None)
    pair = spawns[entrance] if entrance is not None else []
    width, height = len(room["tiles"][0]) * 16, len(room["tiles"]) * 16
    positions = [feet_position(tile) for tile in pair]
    centre = tuple(sum(p[axis] for p in positions) / len(positions) for axis in (0, 1)) if positions else (width / 2, height / 2)
    crop = tuple(round(max(0, min(centre[axis] - VIEW[axis] / 2, extent - VIEW[axis])))
                 for axis, extent in enumerate((width, height)))
    return crop, pair


def room_study(pack: Pack, room: dict) -> tuple[Image.Image, tuple]:
    crop, pair = study_crop(room)
    output = Image.new("RGBA", (960, VIEW[1] + HEADER), "#10141C")
    for half, theme in enumerate(("ember", "moss")):
        view = Image.new("RGBA", VIEW, "#10141C")
        terrain = f"terrain_{theme}_v1"
        slots = pack.record(terrain)["tile_ids"]
        try:
            material = {marker: pack.frame(terrain, slots.index(slot)) for marker, slot in MATERIALS.items()}
        except ValueError as exc:
            raise PreviewError(f"{terrain}: missing overhead material slot; run tools/validate_assets.py") from exc
        if any(tile.size != (16, 16) or tile.getchannel("A").getextrema() != (255, 255) for tile in material.values()):
            raise PreviewError(f"{terrain}: overhead materials must be opaque 16x16 tiles")
        for y, row in enumerate(room["tiles"]):
            for x, marker in enumerate(row):
                position = x * 16 - crop[0], y * 16 - crop[1]
                if -16 < position[0] < VIEW[0] and -16 < position[1] < VIEW[1]:
                    view.alpha_composite(material[marker], position)
        foreground = []
        for decor in room.get("decor", []):
            if decor["theme"] not in ("common", theme):
                continue
            item = (decor["asset_id"], decor["position_px"], decor["frame"])
            if decor["z"] < 0:
                pack.place(view, *item, crop)
            else:
                foreground.append(item)
        for entity in room.get("entities", []):
            if entity["type"] in ACTORS:
                foreground.append((ACTORS[entity["type"]], feet_position(entity["tile"]), 0))
            elif entity["type"] == "anchor_pair":
                for anchor in entity["anchors"]:
                    foreground.append(("props_v1", feet_position(anchor["tile"]), 0))
        for key, tile in zip(("fixed_tavi_v1", "fixed_neri_v1"), pair):
            foreground.append((key, feet_position(tile), 0))
        # Props and actors share one feet sort. Stable ties preserve authored order.
        for item in sorted(foreground, key=lambda item: item[1][1]):
            pack.place(view, *item, crop)
        output.alpha_composite(view, (half * VIEW[0], HEADER))
        pack.label(output, CAPTION, half * VIEW[0] + 5, 4)
        pack.label(output, f"OVERHEAD MATERIAL/POSE STUDY {room['id'].upper()} {theme.upper()}", half * VIEW[0] + 5, 17)
    return output, crop


def create_studies(root: Path, output: Path, room_id: str | None = None) -> list[Path]:
    manifest = read_json(root, "assets/manifest.json")
    # Default checks every room; OH0 may explicitly select one migrated room.
    # Every selected epoch is checked before opening assets or touching evidence.
    rooms = read_rooms(root, room_id)
    pack = Pack(root, manifest)
    prepared = []
    for room in rooms:
        image, crop = room_study(pack, room)
        prepared.append((f"{room['id']}_themes.png", image, crop))
    for name, ids in SHEETS.items():
        images = [pack.image(key) for key in ids]
        image = Image.new("RGBA", (max(360, *(item.width for item in images)),
                                    HEADER + sum(item.height + 16 for item in images)), "#10141C")
        pack.label(image, CAPTION, 3, 4)
        pack.label(image, "OVERHEAD MATERIAL/POSE STUDY", 3, 17)
        y = HEADER
        for key, sheet in zip(ids, images):
            pack.label(image, key.upper(), 3, y + 4)
            image.alpha_composite(sheet, (0, y + 16))
            y += sheet.height + 16
        prepared.append((name + ".png", image, None))
    # Complete all decoding/composition first: a missing late asset cannot clobber
    # existing evidence or leave an apparently complete partial study set.
    output.mkdir(parents=True, exist_ok=True)
    written = []
    for filename, image, crop in prepared:
        metadata = PngInfo()
        metadata.add_text("Description", CAPTION + " / OVERHEAD MATERIAL/POSE STUDY")
        if crop is not None:
            metadata.add_text("Crop", f"{crop[0]},{crop[1]}")
        path = output / filename
        image.save(path, pnginfo=metadata)
        written.append(path)
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="study directory (default: evidence/content/overhead/authoring)")
    parser.add_argument("--room", choices=[f"r0{i}" for i in range(8)],
                        help="study one overhead room (default: require all world rooms to be overhead)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    try:
        written = create_studies(root, args.output or root / "evidence/content/overhead/authoring", args.room)
    except (PreviewError, OSError, KeyError, TypeError, ValueError) as exc:
        print(f"Authoring study failed: {exc}", file=sys.stderr)
        return 1
    print(f"Created {len(written)} overhead material/pose studies. {CAPTION}; no engine, collision, motion or audio exercised.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
