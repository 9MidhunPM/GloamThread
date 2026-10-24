#!/usr/bin/env python3
"""Create labelled authoring contact sheets, never runtime/gameplay evidence."""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    manifest = json.loads((root / "assets/manifest.json").read_text())
    if manifest["stage"] != "full":
        raise ValueError("Authoring previews require the full asset manifest")
    assets = {item["id"]: item for item in manifest["assets"]}
    glyphs = json.loads((root / "assets/source/art/glyphs.json").read_text())["glyphs"]
    images = {}
    for key, item in assets.items():
        if item["kind"] in ("sprite_atlas", "tile_atlas", "image"):
            with Image.open(root / item["path"]) as image:
                images[key] = image.convert("RGBA")

    def label(image, text, x, y):
        draw = ImageDraw.Draw(image)
        for char in text:
            for gy, row in enumerate(glyphs[char].split("/")):
                for gx, pixel in enumerate(row):
                    if pixel == "1":
                        draw.point((x + gx, y + gy), fill="#D5D2B8")
            x += 6

    def frame(asset_id, index=0):
        x, y, width, height = assets[asset_id]["frames"][index]
        return images[asset_id].crop((x, y, x + width, y + height))

    def place(view, asset_id, position, index=0, offset=0, offset_y=0):
        ox, oy = assets[asset_id].get("origin", [0, 0])
        view.alpha_composite(frame(asset_id, index), (round(position[0] - ox - offset), round(position[1] - oy - offset_y)))

    directory = root / "evidence/content/authoring"
    directory.mkdir(parents=True, exist_ok=True)
    previews = (("r00", "r00", 0), ("r02", "r02", 640), ("r03", "r03", 700),
                ("r06", "r06", 960), ("r06_gap", "r06", 256))
    for preview_id, room_id, offset in previews:
        room = json.loads((root / f"content/rooms/{room_id}.json").read_text())
        offset_y = max(0, len(room["tiles"]) * 16 - 360)
        output = Image.new("RGBA", (960, 376), "#10141C")
        for half, theme in enumerate(("ember", "moss")):
            view = Image.new("RGBA", (480, 360), "#10141C")
            for layer in ("far", "middle", "near"):
                view.alpha_composite(images[f"background_{theme}_{layer}_v1"])
            for decor in room["decor"]:
                if decor["theme"] in ("common", theme) and decor["z"] < 0:
                    place(view, decor["asset_id"], decor["position_px"], decor["frame"], offset, offset_y)
            terrain = f"terrain_{theme}_v1"
            ids = assets[terrain]["tile_ids"]
            for y, row in enumerate(room["tiles"]):
                for x, tile in enumerate(row):
                    if not -16 <= x * 16 - offset < 480:
                        continue
                    name = "solid_fill" if tile == "#" and y > 0 and room["tiles"][y-1][x] == "#" else "solid_top"
                    name = {"=": "one_way_middle", "^": "hazard_middle"}.get(tile, name)
                    if tile != ".":
                        view.alpha_composite(frame(terrain, ids.index(name)), (x * 16 - offset, y * 16 - offset_y))
            for decor in room["decor"]:
                if decor["theme"] in ("common", theme) and decor["z"] >= 0:
                    place(view, decor["asset_id"], decor["position_px"], decor["frame"], offset, offset_y)
            actor_ids = {"npc": "oru_v1", "spoolmite": "spoolmite_v1", "wickwing": "wickwing_v1", "spoolwarden": "spoolwarden_v1"}
            for entity in room["entities"]:
                if entity["type"] in actor_ids:
                    x, y = entity["tile"]
                    place(view, actor_ids[entity["type"]], ((x + .5) * 16, (y + 1) * 16), offset=offset, offset_y=offset_y)
                elif entity["type"] == "anchor_pair":
                    for anchor in entity["anchors"]:
                        x, y = anchor["tile"]
                        place(view, "props_v1", ((x + .5) * 16, (y + 1) * 16), offset=offset, offset_y=offset_y)
            if room_id == "r00":
                for index, (x, y) in enumerate(room["spawns"]["start"]):
                    place(view, f"fixed_{('tavi', 'neri')[index]}_v1", ((x + .5) * 16, (y + 1) * 16), offset=offset, offset_y=offset_y)
            output.alpha_composite(view, (half * 480, 16))
            label(output, f"AUTHORING ONLY / {room_id} / {theme.upper()} / NO PHYSICS", half * 480 + 5, 4)
        output.save(directory / f"{preview_id}_themes.png")
    for name, ids in (("couriers", ["fixed_tavi_v1", "fixed_neri_v1", "oru_v1"]),
                      ("enemies", ["spoolmite_v1", "wickwing_v1", "spoolwarden_v1"]),
                      ("terrain", ["terrain_ember_v1", "terrain_moss_v1"]),
                      ("props", ["props_v1", "ui_v1"])):
        width = max(images[key].width for key in ids)
        height = sum(images[key].height + 16 for key in ids)
        output = Image.new("RGBA", (width, height), "#10141C")
        y = 0
        for key in ids:
            label(output, key.upper(), 3, y + 4)
            output.alpha_composite(images[key], (0, y + 16))
            y += images[key].height + 16
        output.save(directory / f"{name}.png")
    print("Created nine labelled authoring previews; no engine, collision, motion or audio is exercised.")


if __name__ == "__main__":
    main()
