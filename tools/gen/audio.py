"""Original Gloamthread synthesis from editable instruments, cues and scores.

Only generate() writes files. Scores express music in beats and cues in seconds;
all envelopes and oscillator parameters live in assets/source/audio/*.json.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np

SAMPLE_RATE = 44_100
SAMPLE_WIDTH = 2
SOURCE_PATHS = (
    "assets/source/audio/instruments.json",
    "assets/source/audio/cues.json",
    "assets/source/audio/score.json",
    "tools/gen/audio.py",
)
CUE_NAMES = (
    "jump", "land", "slash", "hit", "hurt", "dash", "ember_arc",
    "spore_bolt", "enemy_warning", "enemy_defeat", "boss_stagger",
    "cross_stitch", "anchor_latched", "bridge_restored", "checkpoint",
    "downed", "revive", "loom_restored",
)
MUSIC_NAMES = ("exploration", "boss", "ending")


def _read(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or value.get("schema_version") != 1:
        raise ValueError(f"{path}: expected an audio source object at schema_version 1")
    return value


def _number(value: object, context: str, low: float, high: float) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{context}: expected a finite number")
    result = float(value)
    if not math.isfinite(result) or not low <= result <= high:
        raise ValueError(f"{context}: expected {low}..{high}, got {value!r}")
    return result


def _rng(seed: int, identity: str) -> np.random.Generator:
    # An unrelated new event cannot change the random stream of an existing cue.
    digest = hashlib.sha256(f"{seed}:{identity}".encode("utf-8")).digest()
    return np.random.default_rng(int.from_bytes(digest[:8], "little"))


def _frequency(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def render_voice(
    instrument: dict, note: float, seconds: float, random: np.random.Generator,
    end_note: float | None = None,
) -> np.ndarray:
    """Render one bounded original additive/noise voice, with zero end samples."""
    seconds = _number(seconds, "voice duration", 0.002, 20.0)
    note = _number(note, "voice note", 12.0, 108.0)
    if end_note is not None:
        end_note = _number(end_note, "voice end_note", 12.0, 108.0)
    count = max(2, round(seconds * SAMPLE_RATE))
    time = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    start_hz = _frequency(note)
    end_hz = start_hz if end_note is None else _frequency(end_note)
    phase = 2.0 * np.pi * (start_hz * time + 0.5 * (end_hz - start_hz) * time * time / seconds)
    signal = np.zeros(count, dtype=np.float64)
    partials = instrument.get("partials", [])
    if not isinstance(partials, list):
        raise ValueError("instrument partials must be a list")
    decay = _number(instrument.get("decay", 1.0), "instrument decay", 0.005, 30.0)
    for partial in partials:
        if not isinstance(partial, list) or len(partial) != 3:
            raise ValueError("instrument partial must be [frequency_ratio, amplitude, decay_rate]")
        ratio = _number(partial[0], "partial ratio", 0.125, 12.0)
        gain = _number(partial[1], "partial gain", 0.0, 1.0)
        rate = _number(partial[2], "partial decay rate", 0.0, 16.0)
        # Omit a partial above Nyquist instead of folding it into an unrelated tone.
        if max(start_hz, end_hz) * ratio < SAMPLE_RATE * 0.45:
            signal += gain * np.sin(phase * ratio) * np.exp(-time * rate / decay)
    noise_gain = _number(instrument.get("noise", 0.0), "instrument noise", 0.0, 1.0)
    if noise_gain:
        smoothing = instrument.get("noise_smoothing", 9)
        if isinstance(smoothing, bool) or not isinstance(smoothing, int) or not 1 <= smoothing <= 127:
            raise ValueError("instrument noise_smoothing must be an integer in 1..127")
        noise = random.uniform(-1.0, 1.0, count + smoothing - 1)
        kernel = np.ones(smoothing, dtype=np.float64) / math.sqrt(smoothing)
        noise = np.convolve(noise, kernel, mode="valid")
        signal += noise_gain * noise * np.exp(-time / decay)
    attack = _number(instrument.get("attack", 0.005), "instrument attack", 0.001, 2.0)
    release = _number(instrument.get("release", 0.04), "instrument release", 0.002, 5.0)
    attack_frames = max(2, min(count, round(attack * SAMPLE_RATE)))
    release_frames = max(2, min(count, round(release * SAMPLE_RATE)))
    envelope = np.ones(count, dtype=np.float64)
    envelope[:attack_frames] *= np.sin(np.linspace(0.0, np.pi / 2.0, attack_frames)) ** 2
    envelope[-release_frames:] *= np.sin(np.linspace(np.pi / 2.0, 0.0, release_frames)) ** 2
    return signal * envelope


def _finish(signal: np.ndarray, peak: float, fade_seconds: float) -> np.ndarray:
    """Remove DC and leave a short smooth seam, then quantize without clipping."""
    peak = _number(peak, "output peak", 0.02, 0.4)
    if not np.isfinite(signal).all():
        raise ValueError("audio synthesis produced a non-finite sample")
    signal -= signal.mean(axis=0, keepdims=True)
    count = signal.shape[0]
    fade_count = max(2, min(count // 2, round(fade_seconds * SAMPLE_RATE)))
    fade = np.sin(np.linspace(0.0, np.pi / 2.0, fade_count)) ** 2
    if signal.ndim == 2:
        fade = fade[:, None]
    signal[:fade_count] *= fade
    signal[-fade_count:] *= fade[::-1]
    maximum = float(np.max(np.abs(signal)))
    if maximum < 1e-8:
        raise ValueError("audio source rendered silence")
    signal *= peak / maximum
    return np.rint(signal * 32767.0).astype("<i2")


def _event_voice(event: dict, instruments: dict, seconds: float, seed: int, identity: str) -> np.ndarray:
    instrument_id = event.get("instrument")
    if instrument_id not in instruments:
        raise ValueError(f"{identity}: unknown instrument {instrument_id!r}")
    return render_voice(instruments[instrument_id], event.get("note"), seconds,
                        _rng(seed, identity), event.get("end_note"))


def render_cue(name: str, source: dict, instruments: dict, seed: int) -> np.ndarray:
    duration = _number(source.get("duration_seconds"), f"{name} duration", 0.02, 5.0)
    output = np.zeros(round(duration * SAMPLE_RATE), dtype=np.float64)
    events = source.get("events")
    if not isinstance(events, list) or not events:
        raise ValueError(f"{name}: expected nonempty cue events")
    for index, event in enumerate(events):
        identity = f"cue:{name}:{index}"
        start = _number(event.get("at_seconds"), identity + " start", 0.0, duration)
        length = _number(event.get("duration_seconds"), identity + " duration", 0.002, duration)
        if start + length > duration + 1e-8:
            raise ValueError(f"{identity}: voice extends beyond cue duration")
        gain = _number(event.get("gain", 1.0), identity + " gain", 0.0, 1.0)
        voice = _event_voice(event, instruments, length, seed, identity) * gain
        offset = round(start * SAMPLE_RATE)
        end = min(len(output), offset + len(voice))
        output[offset:end] += voice[:end - offset]
    return _finish(output, source.get("peak", 0.3), 0.005)


def render_track(name: str, source: dict, instruments: dict, seed: int) -> np.ndarray:
    tempo = _number(source.get("bpm"), name + " bpm", 30.0, 200.0)
    beats = _number(source.get("beats"), name + " beats", 1.0, 200.0)
    seconds_per_beat = 60.0 / tempo
    output = np.zeros((round(beats * seconds_per_beat * SAMPLE_RATE), 2), dtype=np.float64)
    parts = source.get("parts")
    if not isinstance(parts, list) or not parts:
        raise ValueError(f"{name}: expected nonempty score parts")
    for part_index, part in enumerate(parts):
        instrument_id = part.get("instrument")
        if instrument_id not in instruments:
            raise ValueError(f"{name}: unknown instrument {instrument_id!r}")
        notes = part.get("notes")
        if not isinstance(notes, list) or not notes:
            raise ValueError(f"{name}: each part needs explicit [beat,note,length,gain,pan] notes")
        for index, row in enumerate(notes):
            identity = f"track:{name}:{part_index}:{index}"
            if not isinstance(row, list) or len(row) != 5:
                raise ValueError(f"{identity}: expected [beat,note,length,gain,pan]")
            start = _number(row[0], identity + " beat", 0.0, beats)
            length = _number(row[2], identity + " length", 0.002 / seconds_per_beat, 20.0 / seconds_per_beat)
            if start + length > beats + 1e-8:
                raise ValueError(f"{identity}: note extends beyond score duration")
            gain = _number(row[3], identity + " gain", 0.0, 1.0)
            pan = _number(row[4], identity + " pan", -1.0, 1.0)
            voice = render_voice(instruments[instrument_id], row[1], length * seconds_per_beat,
                                 _rng(seed, identity))
            offset = round(start * seconds_per_beat * SAMPLE_RATE)
            end = min(len(output), offset + len(voice))
            # Constant-power placement keeps the centre from becoming twice as loud.
            stereo_gain = np.array([math.sqrt((1.0 - pan) / 2.0), math.sqrt((1.0 + pan) / 2.0)])
            output[offset:end] += voice[:end - offset, None] * (stereo_gain * gain)
    return _finish(output, source.get("peak", 0.22), 0.03)


def _write_wave(path: Path, pcm: np.ndarray) -> None:
    channels = 1 if pcm.ndim == 1 else pcm.shape[1]
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(channels)
        stream.setsampwidth(SAMPLE_WIDTH)
        stream.setframerate(SAMPLE_RATE)
        stream.writeframes(pcm.tobytes(order="C"))


def _hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate(root: Path, seed: int) -> tuple[list[dict], dict[str, str], dict[str, str]]:
    """Write 18 cues and 3 scores, returning manifest records and semantic maps."""
    root = Path(root).resolve()
    instruments = _read(root / SOURCE_PATHS[0]).get("instruments", {})
    cues = _read(root / SOURCE_PATHS[1]).get("cues", {})
    tracks = _read(root / SOURCE_PATHS[2]).get("tracks", {})
    if set(cues) != set(CUE_NAMES):
        raise ValueError("cues.json: expected exactly the 18 Phase 1 semantic cues")
    if set(tracks) != set(MUSIC_NAMES):
        raise ValueError("score.json: expected exploration, boss and ending arrangements")
    source_records = [{"path": path, "sha256": _hash(root / path)} for path in SOURCE_PATHS]
    destination = root / "assets/generated/audio"
    destination.mkdir(parents=True, exist_ok=True)
    records: list[dict] = []
    sfx_map: dict[str, str] = {}
    music_map: dict[str, str] = {}
    for kind, names, sources, mapping, renderer in (
        ("sfx", CUE_NAMES, cues, sfx_map, render_cue),
        ("music", MUSIC_NAMES, tracks, music_map, render_track),
    ):
        for name in names:
            source = sources[name]
            pcm = renderer(name, source, instruments, seed)
            path = destination / f"{kind}_{name}.wav"
            _write_wave(path, pcm)
            asset_id = f"{kind}_{name}_v1"
            loop = kind == "music" and name in ("exploration", "boss")
            records.append({
                "id": asset_id,
                "kind": kind,
                "path": path.relative_to(root).as_posix(),
                "sha256": _hash(path),
                "diagnostic": False,
                "sources": [dict(item) for item in source_records],
                "sample_rate": SAMPLE_RATE,
                "channels": 1 if pcm.ndim == 1 else pcm.shape[1],
                "sample_width_bytes": SAMPLE_WIDTH,
                "sample_frames": len(pcm),
                "loop_start": 0 if loop else None,
                "loop_end": len(pcm) if loop else None,
            })
            mapping[name] = asset_id
    return records, sfx_map, music_map
