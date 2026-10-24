"""Exercise rendered PCM and the source-to-manifest audio boundary."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
import wave

import numpy as np

from tools.gen import audio


ROOT = Path(__file__).resolve().parents[2]


def read_pcm(path: Path) -> tuple[wave._wave_params, np.ndarray]:
    with wave.open(str(path), "rb") as stream:
        params = stream.getparams()
        samples = np.frombuffer(stream.readframes(params.nframes), dtype="<i2")
    return params, samples.reshape(-1, params.nchannels)


class AudioGenerationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sandbox = tempfile.TemporaryDirectory(prefix="gloamthread-audio-test-")
        cls.root = Path(cls.sandbox.name)
        for source in audio.SOURCE_PATHS:
            target = cls.root / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / source, target)
        cls.records, cls.sfx, cls.music = audio.generate(cls.root, 18427)
        cls.by_id = {record["id"]: record for record in cls.records}
        cls.instruments = json.loads((cls.root / audio.SOURCE_PATHS[0]).read_text())["instruments"]
        cls.cues = json.loads((cls.root / audio.SOURCE_PATHS[1]).read_text())["cues"]
        cls.tracks = json.loads((cls.root / audio.SOURCE_PATHS[2]).read_text())["tracks"]

    @classmethod
    def tearDownClass(cls) -> None:
        cls.sandbox.cleanup()

    def test_complete_distinct_semantic_inventory(self) -> None:
        self.assertEqual(set(self.sfx), set(audio.CUE_NAMES))
        self.assertEqual(set(self.music), {"exploration", "boss", "ending"})
        self.assertEqual(len(self.by_id), 21)
        self.assertEqual(len({item["sha256"] for item in self.records}), 21)
        self.assertEqual(set(self.by_id), set(self.sfx.values()) | set(self.music.values()))

    def test_actual_wave_format_frames_and_provenance(self) -> None:
        for record in self.records:
            with self.subTest(asset=record["id"]):
                path = self.root / record["path"]
                params, samples = read_pcm(path)
                self.assertEqual(params.framerate, 44100)
                self.assertEqual(params.sampwidth, 2)
                self.assertEqual(params.comptype, "NONE")
                self.assertEqual(params.nchannels, 1 if record["kind"] == "sfx" else 2)
                self.assertEqual(params.nframes, record["sample_frames"])
                self.assertEqual(params.nchannels, record["channels"])
                self.assertEqual(params.framerate, record["sample_rate"])
                self.assertEqual(params.sampwidth, record["sample_width_bytes"])
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record["sha256"])
                self.assertFalse(record["diagnostic"])
                self.assertGreater(len(samples), 0)
                self.assertEqual({entry["path"] for entry in record["sources"]}, set(audio.SOURCE_PATHS))
                for entry in record["sources"]:
                    self.assertEqual(hashlib.sha256((self.root / entry["path"]).read_bytes()).hexdigest(), entry["sha256"])

    def test_conservative_non_silent_output_and_smooth_ends(self) -> None:
        for record in self.records:
            with self.subTest(asset=record["id"]):
                _, pcm = read_pcm(self.root / record["path"])
                signal = pcm.astype(np.float64) / 32767.0
                self.assertLessEqual(float(np.max(np.abs(signal))), 0.321)
                self.assertGreater(float(np.sqrt(np.mean(signal * signal))), 0.008)
                self.assertTrue(np.all(pcm[0] == 0))
                self.assertTrue(np.all(pcm[-1] == 0))
                # Check samples adjacent to the join too, not only equal endpoints.
                self.assertLessEqual(int(np.max(np.abs(pcm[:3].astype(np.int32)))), 3)
                self.assertLessEqual(int(np.max(np.abs(pcm[-3:].astype(np.int32)))), 3)

    def test_music_lengths_stereo_and_real_loop_seams(self) -> None:
        for name, seconds in (("exploration", 48), ("boss", 36), ("ending", 18)):
            record = self.by_id[self.music[name]]
            _, pcm = read_pcm(self.root / record["path"])
            self.assertEqual(len(pcm), 44100 * seconds)
            self.assertFalse(np.array_equal(pcm[:, 0], pcm[:, 1]))
            if name == "ending":
                self.assertIsNone(record["loop_start"])
                self.assertIsNone(record["loop_end"])
                continue
            self.assertEqual((record["loop_start"], record["loop_end"]), (0, len(pcm)))
            join = np.concatenate((pcm[-128:], pcm[:128])).astype(np.int32)
            jumps = np.abs(np.diff(join, axis=0))
            self.assertLessEqual(int(jumps[127].max()), 1)
            self.assertLessEqual(int(jumps[126:129].max()), 3)

    def test_non_looping_cues(self) -> None:
        for asset_id in self.sfx.values():
            self.assertIsNone(self.by_id[asset_id]["loop_start"])
            self.assertIsNone(self.by_id[asset_id]["loop_end"])

    def test_rebuilding_same_seed_is_byte_identical(self) -> None:
        records, sfx, music = audio.generate(self.root, 18427)
        self.assertEqual(records, self.records)
        self.assertEqual(sfx, self.sfx)
        self.assertEqual(music, self.music)

    def test_seed_controls_noise_without_changing_score_or_duration(self) -> None:
        first = audio.render_cue("slash", self.cues["slash"], self.instruments, 18427)
        again = audio.render_cue("slash", self.cues["slash"], self.instruments, 18427)
        other = audio.render_cue("slash", self.cues["slash"], self.instruments, 18428)
        self.assertTrue(np.array_equal(first, again))
        self.assertFalse(np.array_equal(first, other))
        self.assertEqual(first.shape, other.shape)

    def test_representative_simultaneous_boss_events_have_headroom(self) -> None:
        # A bounded offline mix check; this is not proof of the runtime voice mix.
        _, music = read_pcm(self.root / self.by_id[self.music["boss"]]["path"])
        mixed = music[44100 * 8:44100 * 10].astype(np.float64) / 32767.0
        for name in ("ember_arc", "spore_bolt", "enemy_warning", "hit", "hurt"):
            _, cue = read_pcm(self.root / self.by_id[self.sfx[name]]["path"])
            mixed[:len(cue)] += cue.astype(np.float64) / 32767.0
        self.assertLess(float(np.max(np.abs(mixed))), 0.9)

    def test_unknown_instrument_fails_with_context(self) -> None:
        source = copy.deepcopy(self.cues["jump"])
        source["events"][0]["instrument"] = "downloaded_sample"
        with self.assertRaisesRegex(ValueError, "cue:jump:0: unknown instrument"):
            audio.render_cue("jump", source, self.instruments, 18427)

    def test_overlong_event_and_score_note_fail_before_truncation(self) -> None:
        cue = copy.deepcopy(self.cues["jump"])
        cue["events"][0]["at_seconds"] = 0.15
        with self.assertRaisesRegex(ValueError, "extends beyond cue"):
            audio.render_cue("jump", cue, self.instruments, 18427)
        track = copy.deepcopy(self.tracks["ending"])
        track["parts"][0]["notes"][0][0] = 23.9
        with self.assertRaisesRegex(ValueError, "extends beyond score"):
            audio.render_track("ending", track, self.instruments, 18427)

    def test_nonfinite_or_boolean_audio_numbers_are_rejected(self) -> None:
        for value in (float("nan"), float("inf"), True):
            with self.subTest(value=value), self.assertRaises(ValueError):
                audio.render_voice(self.instruments["soft_bell"], value, 0.2, np.random.default_rng(1))


if __name__ == "__main__":
    unittest.main()
