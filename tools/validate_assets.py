#!/usr/bin/env python3
"""Read-only validation of the authored asset bundle; no engine/gameplay claims."""
from __future__ import annotations

import argparse
from array import array
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import wave

from PIL import Image

COURIER_DIRECTIONS = ("down", "left", "right", "up")
COURIER_STATES = {"idle": 4, "run": 6, "slash": 5, "special": 5, "roll": 4,
                  "dash": 2, "hurt": 2, "downed": 2, "revive": 2}
COURIER_CLIPS = {f"{state}_{direction}": count for direction in COURIER_DIRECTIONS
                 for state, count in COURIER_STATES.items()}
COURIER_TICKS = {"idle": [10, 10, 10, 10], "run": [5, 5, 5, 5, 5, 5],
                 "slash": [3, 3, 3, 3, 6], "special": [4, 4, 3, 4, 7],
                 "roll": [3, 3, 3, 3], "dash": [6, 6], "hurt": [5, 7],
                 "downed": [18, 18], "revive": [6, 10]}
ENEMY_CLIPS = {
    "spoolmite_v1": {"idle": 2, "walk": 4, "anticipation": 2, "charge": 2, "recovery": 2, "defeat": 4},
    "wickwing_v1": {"flap": 4, "anticipation": 2, "dive": 2, "recovery": 2, "defeat": 4},
    "spoolwarden_v1": {"idle": 4, **{f"{attack}_{phase}": 2 for attack in ("sweep", "strike", "charge")
                                                 for phase in ("anticipation", "active", "recovery")},
                        "stagger": 4, "defeat": 6},
}
SFX_NAMES = set("jump roll land slash hit hurt dash ember_arc spore_bolt enemy_warning enemy_defeat "
                "boss_stagger cross_stitch anchor_latched bridge_restored checkpoint downed revive loom_restored".split())
MUSIC_NAMES = {"exploration", "boss", "boss_final", "ending"}
EFFECT_NAMES = ("slash", "ember_arc", "spore_impact", "dash", "hit", "weave", "revive", "restoration", "enemy_warning")
TILE_IDS = ["floor_path_1", "floor_path_2", "floor_grass_1", "floor_grass_2"]
TILE_IDS += [f"wall_fill_{i}" for i in range(1, 5)]
TILE_IDS += [f"wall_edge_{side}" for side in ("north", "east", "south", "west")]
TILE_IDS += [f"wall_corner_{kind}_{corner}" for kind in ("outer", "inner") for corner in ("ne", "se", "sw", "nw")]
TILE_IDS += [f"water_fill_{i}" for i in range(1, 5)]
TILE_IDS += [f"water_edge_{side}" for side in ("north", "east", "south", "west")]
TILE_IDS += [f"water_corner_{corner}" for corner in ("ne", "se", "sw", "nw")]
TILE_IDS += ["bridge_plank_1", "bridge_plank_2", "bridge_rail_north", "bridge_rail_south"]
TILE_IDS += [f"seam_rune_{i}" for i in range(1, 5)]
TILE_IDS += ["background_earth_1", "background_earth_2", "background_roots_1", "background_roots_2"]
TILE_IDS += ["hazard_glass_1", "hazard_glass_2", "hazard_thread_1", "hazard_thread_2"]


def canonical_tile_alpha(tile_id):
    if tile_id not in TILE_IDS:
        return None
    # Overhead material boundaries lie inside an opaque ground tile.
    # Collision/water/damage are authored once in canonical room JSON.
    return bytes([255]) * 256


GLYPHS = list(range(32, 127)) + [65533]
IMAGE_KINDS = {"sprite_atlas", "tile_atlas", "image"}
KINDS = IMAGE_KINDS | {"font", "sfx", "music"}
HASH = re.compile(r"[0-9a-f]{64}\Z")


def integer(value):
    return type(value) is int


def integer_list(value, count, minimum=None):
    return (isinstance(value, list) and len(value) == count and all(integer(x) for x in value)
            and (minimum is None or all(x >= minimum for x in value)))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def visible_pixels(image):
    # RGB values under alpha zero do not create a different visible composition.
    clean = Image.new("RGBA", image.size)
    clean.alpha_composite(image)
    return clean.tobytes()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


class AssetValidator:
    def __init__(self, root, stage):
        self.root = Path(root).resolve()
        self.stage = stage
        self.errors = []
        self.assets = {}
        self.images = {}

    def check(self, condition, label, message):
        if not condition:
            self.errors.append(f"{label}: {message}")
        return bool(condition)

    def safe_path(self, value, label, output=False):
        if not self.check(isinstance(value, str) and bool(value), label, "path must be nonempty text"):
            return None
        parts = value.split("/")
        safe = (not value.startswith("/") and not any(p in ("", ".", "..") for p in parts)
                and not any(c in value for c in ("\\", ":", "\0"))
                and PurePosixPath(value).suffix.lower() not in {".gd", ".tscn", ".tres", ".res", ".dll", ".so", ".exe"})
        if output:
            safe = safe and value.startswith("assets/generated/")
        if not self.check(safe, label, "unsafe path syntax"):
            return None
        path = (self.root / value).resolve()
        if not self.check(path.is_relative_to(self.root) and (not output or path.is_relative_to(self.root / "assets/generated")), label, "unsafe path or path outside bundle"):
            return None
        if not self.check(path.is_file(), label, "path does not resolve to a file"):
            return None
        return path

    def file_hash(self, path, expected, label):
        if self.check(isinstance(expected, str) and bool(HASH.fullmatch(expected)), label, "sha256 must be 64 lowercase hexadecimal characters"):
            if path is not None:
                self.check(sha256(path) == expected, label, "sha256 does not match file")

    def common(self, record, index):
        label = f"assets[{index}]"
        if not self.check(isinstance(record, dict), label, "record must be an object"):
            return
        identifier = record.get("id")
        if not self.check(isinstance(identifier, str) and bool(identifier), label + ".id", "missing asset ID"):
            return
        label = f"asset {identifier}"
        if self.check(identifier not in self.assets, label + ".id", "duplicate asset ID"):
            self.assets[identifier] = record
        kind = record.get("kind")
        if not self.check(isinstance(kind, str) and kind in KINDS, label + ".kind", "unsupported asset kind"):
            kind = ""
        self.check(type(record.get("diagnostic")) is bool, label + ".diagnostic", "must be boolean")
        if self.stage == "full":
            self.check(record.get("diagnostic") is False, label + ".diagnostic", "full bundle consumes a diagnostic asset")
            self.check(not str(record.get("path", "")).startswith("assets/generated/diagnostic/"),
                       label + ".path", "full bundle cannot consume diagnostic directory outputs")
        path = self.safe_path(record.get("path"), label + ".path", output=True)
        self.file_hash(path, record.get("sha256"), label + ".sha256")
        expected_suffix = ".png" if kind in IMAGE_KINDS else ".wav" if kind in {"sfx", "music"} else ".fnt" if kind == "font" else None
        if path is not None and expected_suffix:
            self.check(path.suffix.lower() == expected_suffix, label + ".path", f"expected {expected_suffix} file")
        sources = record.get("sources")
        if self.check(isinstance(sources, list) and bool(sources), label + ".sources", "must retain at least one original source"):
            seen = set()
            for i, source in enumerate(sources):
                source_label = f"{label}.sources[{i}]"
                if not self.check(isinstance(source, dict), source_label, "source must be an object"):
                    continue
                source_path = self.safe_path(source.get("path"), source_label + ".path")
                self.file_hash(source_path, source.get("sha256"), source_label + ".sha256")
                if source_path is not None:
                    self.check(source_path not in seen, source_label + ".path", "duplicate source path")
                    self.check(not source_path.is_relative_to(self.root / "assets/generated"), source_label + ".path", "retained source cannot be a generated output")
                    seen.add(source_path)
        if path is None:
            return
        if kind in IMAGE_KINDS:
            self.image(record, path)
        elif kind in {"sfx", "music"}:
            self.audio(record, path)

    def image(self, record, path):
        label = f"asset {record['id']}"
        try:
            with Image.open(path) as opened:
                self.check(opened.format == "PNG", label + ".path", "image must be PNG")
                image = opened.convert("RGBA")
        except (OSError, ValueError, Image.DecompressionBombError) as exc:
            self.errors.append(f"{label}.path: unreadable PNG: {exc}")
            return
        self.images[record["id"]] = image
        self.check(image.getchannel("A").getbbox() is not None, label + ".visibility",
                   "image must contain visible pixels")
        self.check(integer_list(record.get("size"), 2, 1) and tuple(record.get("size", [])) == image.size,
                   label + ".size", f"must match actual dimensions {image.size}")
        self.check(sum(image.getchannel("A").histogram()[1:255]) == 0, label + ".alpha", "pixel surfaces require binary alpha")
        if "palette" in record:
            palette = record["palette"]
            valid = isinstance(palette, list) and bool(palette) and all(isinstance(c, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", c) for c in palette)
            if self.check(valid, label + ".palette", "palette must contain RGB hexadecimal colours"):
                colours = {tuple(bytes.fromhex(c[1:])) for c in palette}
                self.check(all(pixel[:3] in colours for _, pixel in image.getcolors(image.width * image.height) if pixel[3]), label + ".palette", "image contains colours absent from declared palette")
        if record["kind"] not in {"sprite_atlas", "tile_atlas"}:
            return
        cell = record.get("cell_size")
        valid_cell = self.check(integer_list(cell, 2, 1), label + ".cell_size", "must contain two positive integers")
        origin = record.get("origin")
        self.check(integer_list(origin, 2, 0) and (not valid_cell or all(origin[i] < cell[i] for i in (0, 1))),
                   label + ".origin", "must be an integer point inside the unpadded cell")
        frames = record.get("frames")
        if not self.check(isinstance(frames, list) and bool(frames), label + ".frames", "must contain frame rectangles"):
            return
        valid_frames = []
        for i, frame in enumerate(frames):
            frame_label = f"{label}.frames[{i}]"
            if not self.check(integer_list(frame, 4) and frame[0] >= 0 and frame[1] >= 0 and frame[2] > 0 and frame[3] > 0,
                              frame_label, "must contain nonnegative coordinates and positive integer dimensions"):
                continue
            x, y, width, height = frame
            within_image = self.check(x + width <= image.width and y + height <= image.height, frame_label, "frame rectangle exceeds image bounds")
            if within_image:
                visible = image.crop((x, y, x + width, y + height)).getchannel("A").getbbox() is not None
                self.check(visible, frame_label + ".visibility", "frame must contain visible pixels")
            if valid_cell:
                self.check([width, height] == cell, frame_label, "frame dimensions differ from cell_size")
            for previous in valid_frames:
                px, py, pw, ph = previous
                self.check(x + width <= px or px + pw <= x or y + height <= py or py + ph <= y,
                           frame_label, "frame rectangles overlap")
            valid_frames.append(frame)
            if self.stage == "full" and valid_cell:
                stride_x, stride_y = cell[0] + 4, cell[1] + 4
                columns = image.width // stride_x
                self.check(columns > 0 and image.width % stride_x == 0 and image.height % stride_y == 0,
                           frame_label, "atlas dimensions must be whole padded cells")
                if columns:
                    self.check(frame == [2 + i % columns * stride_x, 2 + i // columns * stride_y, *cell],
                               frame_label, "frame must occupy its declared row-major padded atlas slot")
            if self.stage == "full":
                padded = (x >= 2 and y >= 2 and x + width + 2 <= image.width and y + height + 2 <= image.height)
                if self.check(padded, frame_label + ".gutter", "requires two transparent padding pixels on every side"):
                    strips = [(x - 2, y - 2, x + width + 2, y), (x - 2, y + height, x + width + 2, y + height + 2),
                              (x - 2, y, x, y + height), (x + width, y, x + width + 2, y + height)]
                    self.check(all(image.crop(box).getchannel("A").getbbox() is None for box in strips),
                               frame_label + ".gutter", "padding pixels must be transparent")
        animations = record.get("animations")
        if self.check(isinstance(animations, dict), label + ".animations", "must be an object"):
            for state, clip in animations.items():
                clip_label = f"{label}.animations.{state}"
                if not self.check(isinstance(state, str) and bool(state) and isinstance(clip, dict), clip_label, "clip must be a named object"):
                    continue
                indices, ticks = clip.get("frames"), clip.get("ticks")
                indices_ok = isinstance(indices, list) and bool(indices) and all(integer(i) and 0 <= i < len(frames) for i in indices)
                self.check(indices_ok, clip_label + ".frames", "frame indices must resolve within atlas")
                self.check(isinstance(ticks, list) and isinstance(indices, list) and len(ticks) == len(indices)
                           and all(integer(t) and t > 0 for t in ticks), clip_label + ".ticks", "one positive integer tick duration is required per frame")
                self.check(type(clip.get("loop")) is bool, clip_label + ".loop", "must be boolean")
        if record["kind"] == "tile_atlas":
            ids = record.get("tile_ids")
            valid_ids = self.check(isinstance(ids, list) and len(ids) == len(frames) and all(isinstance(i, str) and i for i in ids)
                                   and len(set(ids)) == len(ids), label + ".tile_ids", "requires unique IDs aligned with frames")
            if valid_ids:
                for i, (tile_id, frame) in enumerate(zip(ids, frames)):
                    expected_alpha = canonical_tile_alpha(tile_id)
                    if expected_alpha is None or not integer_list(frame, 4) or frame[2:] != [16, 16]:
                        continue
                    x, y, width, height = frame
                    if x < 0 or y < 0 or x + width > image.width or y + height > image.height:
                        continue
                    actual_alpha = image.crop((x, y, x + width, y + height)).getchannel("A").tobytes()
                    self.check(actual_alpha == expected_alpha, f"{label}.frames[{i}].canonical_mask",
                               f"{tile_id} must preserve its canonical physical silhouette")

    def audio(self, record, path):
        label = f"asset {record['id']}"
        try:
            with wave.open(str(path), "rb") as stream:
                actual = {"sample_rate": stream.getframerate(), "channels": stream.getnchannels(),
                          "sample_width_bytes": stream.getsampwidth(), "sample_frames": stream.getnframes()}
                self.check(stream.getcomptype() == "NONE", label + ".format", "must be uncompressed PCM")
                data = stream.readframes(stream.getnframes())
        except (OSError, EOFError, wave.Error) as exc:
            self.errors.append(f"{label}.path: unreadable WAV: {exc}")
            return
        for name, value in actual.items():
            self.check(integer(record.get(name)) and record.get(name) == value, label + "." + name, f"must match WAV header ({value})")
        self.check(actual["sample_rate"] == 44100, label + ".sample_rate", "must be 44100Hz")
        self.check(actual["sample_width_bytes"] == 2, label + ".sample_width_bytes", "must be 16-bit PCM")
        self.check(actual["channels"] == (1 if record["kind"] == "sfx" else 2), label + ".channels", "cues must be mono and music stereo")
        self.check(actual["sample_frames"] > 0, label + ".sample_frames", "audio cannot be empty")
        expected_bytes = actual["sample_frames"] * actual["channels"] * actual["sample_width_bytes"]
        self.check(len(data) == expected_bytes, label + ".sample_frames", "WAV contains truncated frame data")
        samples = array("h")
        if actual["sample_width_bytes"] == 2 and len(data) % 2 == 0:
            samples.frombytes(data)
            if sys.byteorder != "little":
                samples.byteswap()
            peak = max((abs(s) for s in samples), default=0) / 32768
            self.check(peak <= .9, label + ".peak", "PCM peak exceeds conservative 0.9 ceiling")
            self.check(peak >= .001, label + ".peak", "audio must contain a signal above the 0.001 full-scale minimum")
        start, end = record.get("loop_start"), record.get("loop_end")
        self.check("loop_start" in record and "loop_end" in record, label + ".loop", "loop fields are required, null for nonlooping audio")
        if start is None and end is None:
            return
        valid_loop = integer(start) and integer(end) and 0 <= start < end <= actual["sample_frames"]
        if self.check(valid_loop, label + ".loop", "loop requires valid sample-frame offsets, end exclusive") and samples and len(samples) >= end * actual["channels"]:
            channels = actual["channels"]
            seam = max(abs(samples[start * channels + channel] - samples[(end - 1) * channels + channel]) for channel in range(channels)) / 32768
            self.check(seam <= .04, label + ".loop", "loop endpoint discontinuity exceeds 0.04 full scale")

    def clips(self, identifier, expected, exact_count=True):
        record = self.assets.get(identifier)
        if record is None:
            return
        label = f"asset {identifier}.animations"
        clips = record.get("animations", {})
        if not isinstance(clips, dict):
            return
        for state, count in expected.items():
            clip = clips.get(state)
            if self.check(isinstance(clip, dict), label + "." + state, "required animation missing"):
                frames = clip.get("frames")
                self.check(isinstance(frames, list) and (len(frames) == count if exact_count else bool(frames)),
                           label + "." + state, f"requires {count} frames" if exact_count else "requires a frame")
        if exact_count:
            self.check(set(clips) == set(expected), label, "clip states differ from fixed animation contract")

    def dimensions(self, identifier, size=None, count=None, cell=None, origin=None):
        record = self.assets.get(identifier)
        if record is None:
            return
        for field, expected in (("size", size), ("cell_size", cell), ("origin", origin)):
            if expected is not None:
                self.check(record.get(field) == list(expected), f"asset {identifier}.{field}", f"must be {list(expected)}")
        if count is not None:
            self.check(isinstance(record.get("frames"), list) and len(record["frames"]) == count,
                       f"asset {identifier}.frames", f"requires exactly {count} frames")

    def courier_timing(self, identifier):
        clips = self.assets.get(identifier, {}).get("animations", {})
        if not isinstance(clips, dict):
            return
        offset = 0
        for direction in COURIER_DIRECTIONS:
            for state, count in COURIER_STATES.items():
                name = f"{state}_{direction}"
                clip = clips.get(name)
                if isinstance(clip, dict):
                    label = f"asset {identifier}.animations.{name}"
                    frames = clip.get("frames")
                    self.check(isinstance(frames, list) and bool(frames) and
                               all(integer(index) and offset <= index < offset + count for index in frames),
                               label + ".bank", "frames must stay within the declared facing/state bank")
                    self.check(clip.get("ticks") == COURIER_TICKS[state], label + ".timing",
                               "timing must match the overhead combat presentation contract")
                    self.check(clip.get("loop") is (state in {"idle", "run", "downed"}),
                               label + ".loop", "loop policy differs from the overhead state contract")
                offset += count

    def font(self, record):
        label = f"asset {record['id']}"
        glyphs = record.get("glyphs")
        self.check(isinstance(glyphs, list) and all(integer(g) for g in glyphs) and sorted(glyphs) == sorted(GLYPHS),
                   label + ".glyphs", "must contain 95 printable ASCII glyphs and replacement glyph exactly once")
        texture_id = record.get("texture_id")
        texture = self.assets.get(texture_id) if isinstance(texture_id, str) else None
        if not self.check(texture is not None and texture.get("kind") == "image", label + ".texture_id", "must resolve to a manifested PNG image"):
            return
        self.dimensions(texture_id, size=(96, 48))
        path = self.safe_path(record.get("path"), label + ".path", output=True)
        if path is None:
            return
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError) as exc:
            self.errors.append(f"{label}.path: unreadable BMFont: {exc}")
            return
        chars = {}
        pages = []
        common = None
        declared_count = None
        pattern = re.compile(r'(\w+)=("[^"]*"|[^\s]+)')
        for line in lines:
            fields = {name: value.strip('"') for name, value in pattern.findall(line)}
            if line.startswith("page "):
                pages.append(fields)
            elif line.startswith("common "):
                common = fields
            elif line.startswith("chars "):
                declared_count = fields.get("count")
            elif line.startswith("char "):
                try:
                    code = int(fields["id"])
                    values = {name: int(fields[name]) for name in ("x", "y", "width", "height", "xadvance", "page")}
                except (KeyError, ValueError):
                    self.errors.append(f"{label}.glyphs: malformed BMFont char entry")
                    continue
                self.check(code not in chars, label + ".glyphs", f"duplicate BMFont glyph {code}")
                chars[code] = values
        self.check(common is not None and common.get("scaleW") == "96" and common.get("scaleH") == "48"
                   and common.get("pages") == "1" and common.get("lineHeight") == "8", label + ".font", "BMFont requires one 96x48 page and 8px line height")
        self.check(declared_count == "96" and set(chars) == set(GLYPHS), label + ".glyphs", "BMFont must declare all 96 required glyphs")
        texture_name = PurePosixPath(texture.get("path", "")).name
        self.check(len(pages) == 1 and pages[0].get("id") == "0" and pages[0].get("file") == texture_name
                   and (path.parent / texture_name).resolve() == (self.root / texture.get("path", "")).resolve(),
                   label + ".texture_id", "BMFont page must reference its exact manifested texture beside the font")
        bitmap = self.images.get(texture_id)
        for code, char in chars.items():
            x, y, width, height = (char[name] for name in ("x", "y", "width", "height"))
            okay = 0 <= x <= 96 and 0 <= y <= 48 and 0 <= width <= 5 and 0 <= height <= 7 and x + width <= 96 and y + height <= 48
            self.check(okay and char["page"] == 0 and char["xadvance"] == 6, label + ".glyphs", f"glyph {code} violates 5x7/6x8 glyph layout")
            if code in GLYPHS:
                slot = GLYPHS.index(code)
                self.check((x, y) == (slot % 16 * 6, slot // 16 * 8),
                           label + ".glyphs", f"glyph {code} must occupy its own 6x8 atlas cell")
            if code != 32 and okay and bitmap is not None:
                self.check(bitmap.crop((x, y, x + width, y + height)).getchannel("A").getbbox() is not None,
                           label + ".glyphs", f"glyph {code} has no visible pixels")

    def references(self, manifest):
        for name, permitted, kind in (("sfx", SFX_NAMES, "sfx"), ("music", MUSIC_NAMES, "music")):
            mapping = manifest.get(name)
            if not self.check(isinstance(mapping, dict), "manifest." + name, "must be an object"):
                continue
            if self.stage == "full":
                self.check(set(mapping) == permitted, "manifest." + name,
                           f"semantic cue/track names mismatch; missing={sorted(permitted - set(mapping))}, unknown={sorted(set(mapping) - permitted)}")
                self.check(len(set(str(x) for x in mapping.values())) == len(mapping), "manifest." + name, "semantic cues/tracks require distinct assets")
            for cue, identifier in mapping.items():
                self.check(cue in permitted, f"manifest.{name}.{cue}", "unknown semantic cue/track name")
                target = self.assets.get(identifier) if isinstance(identifier, str) else None
                self.check(target is not None and target.get("kind") == kind, f"manifest.{name}.{cue}", "reference must resolve to matching audio asset")
                if kind == "music" and target is not None and self.stage == "full":
                    looping = cue != "ending"
                    self.check((target.get("loop_start") is not None and target.get("loop_end") is not None) if looping
                               else target.get("loop_start") is None and target.get("loop_end") is None,
                               f"manifest.music.{cue}.loop", "exploration/boss loop; ending does not loop")
        for record in self.assets.values():
            if record.get("kind") == "font":
                self.font(record)
        for identifier in ("fixed_tavi_v1", "fixed_neri_v1"):
            self.clips(identifier, COURIER_CLIPS, exact_count=self.stage == "full")
            if self.stage == "full":
                self.courier_timing(identifier)
        tavi, neri = self.images.get("fixed_tavi_v1"), self.images.get("fixed_neri_v1")
        if tavi is not None and neri is not None:
            self.check(tavi.size != neri.size or visible_pixels(tavi) != visible_pixels(neri), "couriers.visuals",
                       "Tavi and Neri require distinct decoded image pixels")
        if self.stage == "full":
            for theme in ("ember", "moss"):
                layers = [(layer, self.images.get(f"background_{theme}_{layer}_v1")) for layer in ("far", "middle", "near")]
                for index, (layer, image) in enumerate(layers):
                    if image is None:
                        continue
                    for other_layer, other in layers[:index]:
                        if other is not None:
                            self.check(image.size != other.size or visible_pixels(image) != visible_pixels(other),
                                       f"backgrounds.{theme}.{layer}",
                                       f"{layer} and {other_layer} must be distinct decoded compositions")
        ember, moss = self.assets.get("terrain_ember_v1"), self.assets.get("terrain_moss_v1")
        if ember is not None and moss is not None:
            self.check(ember.get("tile_ids") == moss.get("tile_ids"), "terrain.tile_ids", "both themes must use identical ordered tile IDs")
            a, b = self.images.get("terrain_ember_v1"), self.images.get("terrain_moss_v1")
            if a is not None and b is not None:
                self.check(a.size == b.size and a.getchannel("A").tobytes() == b.getchannel("A").tobytes(),
                           "terrain.mask", "both themes must preserve identical canonical alpha/edge masks")

    def inventory(self):
        diagnostic = {"fixed_tavi_v1", "fixed_neri_v1", "diagnostic_terrain_v1", "diagnostic_mover_v1", "font_v1", "font_texture_v1"}
        full = {"fixed_tavi_v1", "fixed_neri_v1", "terrain_ember_v1", "terrain_moss_v1", "oru_v1", "spoolmite_v1",
                "wickwing_v1", "spoolwarden_v1", "props_v1", "ui_v1", "font_v1", "font_texture_v1"}
        full |= {f"background_{theme}_{layer}_v1" for theme in ("ember", "moss") for layer in ("far", "middle", "near")}
        full |= {f"effect_{effect}_v1" for effect in EFFECT_NAMES}
        required = diagnostic if self.stage == "diagnostic" else full
        for identifier in sorted(required):
            self.check(identifier in self.assets, f"inventory.{identifier}", "required asset missing")
            if identifier not in self.assets:
                continue
            expected_kind = ("font" if identifier == "font_v1" else "image" if identifier == "font_texture_v1" or identifier.startswith("background_")
                             else "tile_atlas" if identifier.startswith("terrain_") or identifier == "diagnostic_terrain_v1" else "sprite_atlas")
            self.check(self.assets[identifier].get("kind") == expected_kind, f"asset {identifier}.kind", f"required kind is {expected_kind}")
        if self.stage == "diagnostic":
            expected_paths = {"diagnostic_terrain_v1": "tiles_diag.png", "diagnostic_mover_v1": "mover_diag.png",
                              "fixed_tavi_v1": "courier_tavi_diag.png", "fixed_neri_v1": "courier_neri_diag.png"}
            for identifier, filename in expected_paths.items():
                self.check(self.assets.get(identifier, {}).get("path") == "assets/generated/diagnostic/" + filename,
                           f"asset {identifier}.path", "diagnostic runtime path must match the fixed first-drop contract")
            self.dimensions("diagnostic_terrain_v1", size=(160, 120), cell=(16, 16), origin=(0, 0))
            terrain = self.assets.get("diagnostic_terrain_v1", {})
            self.check(isinstance(terrain.get("tile_ids"), list) and terrain["tile_ids"][:4] == TILE_IDS[:4],
                       "asset diagnostic_terrain_v1.tile_ids", "first four slots must match the canonical overhead floor order")
            for identifier in ("fixed_tavi_v1", "fixed_neri_v1"):
                self.dimensions(identifier, size=(32, 48), count=1, cell=(32, 48), origin=(16, 43))
            self.dimensions("diagnostic_mover_v1", size=(32, 32), count=1, cell=(32, 32), origin=(16, 28))
            return
        for identifier in ("fixed_tavi_v1", "fixed_neri_v1"):
            self.dimensions(identifier, size=(288, 832), count=128, cell=(32, 48), origin=(16, 43))
        self.dimensions("oru_v1", size=(288, 52), count=8, cell=(32, 48), origin=(16, 43))
        self.clips("oru_v1", {"idle": 4, "talk": 2, "acknowledge": 2})
        for identifier, count in (("spoolmite_v1", 16), ("wickwing_v1", 14)):
            self.dimensions(identifier, size=(288, 72), count=count, cell=(32, 32), origin=(16, 28))
            self.clips(identifier, ENEMY_CLIPS[identifier])
        wing = self.images.get("wickwing_v1")
        if wing is not None:
            self.check(wing.crop((6 * 36, 36, 8 * 36, 72)).getchannel("A").getbbox() is None,
                       "asset wickwing_v1.frames", "last two atlas cells must remain transparent")
        self.dimensions("spoolwarden_v1", size=(544, 272), count=32, cell=(64, 64), origin=(32, 59))
        self.clips("spoolwarden_v1", ENEMY_CLIPS["spoolwarden_v1"])
        for identifier in ("terrain_ember_v1", "terrain_moss_v1"):
            self.dimensions(identifier, size=(160, 120), count=48, cell=(16, 16), origin=(0, 0))
            self.check(self.assets.get(identifier, {}).get("tile_ids") == TILE_IDS,
                       f"asset {identifier}.tile_ids", "must implement exact stable 48-slot ordered terrain contract")
        props = self.assets.get("props_v1", {})
        families, prop_ids, frames = props.get("logical_props"), props.get("prop_ids"), props.get("frames")
        self.check(isinstance(families, list) and len(families) == 16 and all(isinstance(name, str) and name for name in families)
                   and len(set(families)) == 16 and {"anchor", "loom", "bell", "lantern", "sign", "checkpoint"} <= set(families),
                   "asset props_v1.logical_props", "requires 16 unique logical prop families including anchor, loom, bell, lantern, sign and checkpoint")
        self.check(isinstance(prop_ids, list) and isinstance(frames, list) and len(prop_ids) == len(frames) >= 16
                   and all(isinstance(name, str) and name for name in prop_ids) and len(set(prop_ids)) == len(prop_ids),
                   "asset props_v1.prop_ids", "requires unique prop/state IDs aligned with all frame rectangles")
        self.dimensions("ui_v1", size=(100, 80), count=20, cell=(16, 16))
        for effect in EFFECT_NAMES:
            identifier = f"effect_{effect}_v1"
            self.dimensions(identifier, count=6)
            self.clips(identifier, {"play": 6})
            cell = self.assets.get(identifier, {}).get("cell_size")
            self.check(cell == [32, 32] or effect == "restoration" and cell == [64, 64],
                       f"asset {identifier}.cell_size", "effect requires 32x32 cells; restoration may use 64x64")
            clips = self.assets.get(identifier, {}).get("animations", {})
            clip = clips.get("play", {}) if isinstance(clips, dict) else {}
            self.check(isinstance(clip, dict) and clip.get("loop") is False,
                       f"asset {identifier}.animations.play.loop", "effect playback must finish without looping")
            self.check(isinstance(clip, dict) and isinstance(clip.get("frames"), list)
                       and len(clip["frames"]) == 6 and all(integer(index) for index in clip["frames"])
                       and set(clip["frames"]) == set(range(6)),
                       f"asset {identifier}.animations", "effect must declare its complete six-frame sequence")
        for theme in ("ember", "moss"):
            for layer in ("far", "middle", "near"):
                identifier = f"background_{theme}_{layer}_v1"
                self.dimensions(identifier, size=(480, 360))
                record = self.assets.get(identifier, {})
                self.check(record.get("extent") == "finite" or record.get("finite_extent") == [480, 360] or record.get("seamless") is True,
                           f"asset {identifier}.extent", "background must declare finite extent or seamless scrolling")

    def run(self):
        path = self.root / "assets/manifest.json"
        try:
            manifest = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
        except (OSError, UnicodeError, ValueError) as exc:
            return [f"assets/manifest.json: {exc}"]
        if not self.check(isinstance(manifest, dict), "assets/manifest.json", "manifest must be an object"):
            return self.errors
        self.check(integer(manifest.get("schema_version")) and manifest.get("schema_version") == 1,
                   "manifest.schema_version", "unsupported schema; expected integer 1")
        self.check(manifest.get("content_version") == "overhead-v1", "manifest.content_version", "expected overhead-v1")
        self.check(isinstance(manifest.get("generator_version"), str) and bool(manifest["generator_version"]),
                   "manifest.generator_version", "generator version is required")
        self.check(integer(manifest.get("seed")), "manifest.seed", "seed must be an integer")
        self.check(manifest.get("stage") == self.stage, "manifest.stage", f"expected {self.stage} bundle")
        records = manifest.get("assets")
        if self.check(isinstance(records, list), "manifest.assets", "must be an array of asset records"):
            for i, record in enumerate(records):
                self.common(record, i)
        self.references(manifest)
        self.inventory()
        return self.errors


def validate(root: Path, stage="full") -> list[str]:
    """Return actionable failures; do not edit the bundle or invoke the engine."""
    if stage not in {"diagnostic", "full"}:
        return [f"stage: unsupported stage {stage!r}"]
    try:
        return AssetValidator(root, stage).run()
    except (OSError, ValueError, TypeError, KeyError, IndexError, OverflowError) as exc:
        return [f"assets/manifest.json: malformed asset data ({type(exc).__name__}: {exc})"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=("diagnostic", "full"), default="full")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    errors = validate(root, args.stage)
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    if errors:
        print(f"Asset validation ({args.stage}): {len(errors)} failure(s).", file=sys.stderr)
        return 1
    print(f"PASS assets ({args.stage}): provenance, images, frames, glyphs, references and audio structure.")
    print("Not checked: engine import, rendered animation, audio listening, physical traversal or gameplay.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
