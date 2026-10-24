"""Score and PCM checks for active arrangements; listening quality stays separate."""
from collections import Counter
import json
from pathlib import Path
import unittest

import numpy as np

from tools.gen import audio

ROOT = Path(__file__).resolve().parents[2]


class MusicPolishTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tracks = json.loads((ROOT / 'assets/source/audio/score.json').read_text())['tracks']
        cls.instruments = json.loads((ROOT / 'assets/source/audio/instruments.json').read_text())['instruments']

    def test_boss_is_a_driving_full_length_ensemble(self):
        track = self.tracks['boss']
        self.assertGreaterEqual(track['bpm'], 132)
        self.assertTrue(45 <= track['beats'] * 60 / track['bpm'] <= 60)
        roles = {part.get('role') for part in track['parts']}
        self.assertTrue({'lead', 'harmony', 'bass', 'percussion', 'countermelody'} <= roles)
        self.assertGreater(sum(len(part['notes']) for part in track['parts']) / track['beats'], 4)

    def test_piano_has_breadth_chords_and_countermotion(self):
        track = self.tracks['boss']
        keyboards = [part for part in track['parts'] if part.get('family') == 'keyboard']
        self.assertGreaterEqual(len(keyboards), 2, 'both keyboard hands need an authored score')
        pitches = [row[1] for part in keyboards for row in part['notes']]
        self.assertGreaterEqual(max(pitches) - min(pitches), 30)
        chords = Counter(row[0] for part in keyboards for row in part['notes'])
        self.assertGreaterEqual(sum(count >= 3 for count in chords.values()), 12)
        counter = [row for part in track['parts'] if part.get('role') == 'countermelody' for row in part['notes']]
        lead = [row for part in track['parts'] if part.get('role') == 'lead' for row in part['notes']]
        lead_onsets = {row[0] for row in lead}
        self.assertGreaterEqual(len(counter), 24)
        self.assertGreater(sum(row[0] not in lead_onsets for row in counter), len(counter) * .2)

    def test_bass_is_syncopated_and_sections_have_real_density_contrast(self):
        track = self.tracks['boss']
        bass = [row for part in track['parts'] if part.get('role') == 'bass' for row in part['notes']]
        self.assertGreater(len(bass), 80)
        self.assertGreater(sum(abs(row[0] - round(row[0])) > .01 for row in bass), len(bass) * .35)
        density = [sum(begin <= row[0] < begin + 16 for part in track['parts'] for row in part['notes'])
                   for begin in range(0, int(track['beats']), 16)]
        self.assertGreater(max(density), min(density) * 1.4)

    def test_original_hook_returns_after_a_contrasting_passage(self):
        lead_parts = [part for part in self.tracks['boss']['parts'] if part.get('role') == 'lead']
        self.assertEqual(len(lead_parts), 1)
        notes = lead_parts[0]['notes']
        phrase = [(round(row[0] - notes[0][0], 4), row[1], row[2]) for row in notes[:8]]
        returns = []
        for begin in range(8, len(notes) - 7):
            group = notes[begin:begin + 8]
            if group[0][0] < self.tracks['boss']['beats'] / 2:
                continue
            candidate = [(round(row[0] - group[0][0], 4), row[1], row[2]) for row in group]
            if candidate == phrase:
                returns.append(group[0][0])
        self.assertTrue(returns, 'the lead hook must recur as notes and rhythm, not just a section label')

    def test_percussion_has_distinct_pitched_and_noisy_timbres(self):
        track = self.tracks['boss']
        instruments = {part['instrument'] for part in track['parts'] if part.get('role') == 'percussion'}
        self.assertGreaterEqual(len(instruments), 3)
        timbres = [self.instruments[name] for name in instruments]
        self.assertTrue(any(instrument.get('pitch_drop_semitones', 0) >= 12 for instrument in timbres))
        self.assertTrue(any(instrument.get('noise_highpass') is True and instrument.get('noise', 0) > .5 for instrument in timbres))

    def test_final_phase_intensifies_the_arrangement_without_raising_master_peak(self):
        base, final = self.tracks['boss'], self.tracks['boss_final']
        self.assertEqual((base['bpm'], base['beats']), (final['bpm'], final['beats']))
        self.assertLessEqual(final['peak'], base['peak'])
        for role in ('bass', 'percussion', 'countermelody'):
            first = sum(len(part['notes']) for part in base['parts'] if part.get('role') == role)
            second = sum(len(part['notes']) for part in final['parts'] if part.get('role') == role)
            self.assertGreater(second, first * 1.2, role)
        base_hook = next(part for part in base['parts'] if part.get('role') == 'lead')['notes'][:8]
        final_hook = next(part for part in final['parts'] if part.get('role') == 'lead')['notes'][:8]
        self.assertEqual(base_hook, final_hook)

    def test_new_instrument_and_room_parameters_fail_explicitly_when_malformed(self):
        for field, value in (('pitch_drop_semitones', True), ('inharmonicity', float('nan')),
                             ('detune_cents', -1), ('noise_decay', float('inf')), ('noise_highpass', 'yes')):
            with self.subTest(field=field):
                instrument = dict(self.instruments['loom_piano'])
                instrument[field] = value
                with self.assertRaises(ValueError):
                    audio.render_voice(instrument, 60, .2, np.random.default_rng(1))
        for taps in ('external impulse', [[.02, True]], [[-1, .1]], [[.01, .1]] * 5):
            with self.subTest(taps=taps):
                source = {'bpm':120,'beats':1,'parts':[{'instrument':'loom_piano','notes':[[0,60,.8,.5,0]]}], 'room_taps':taps}
                with self.assertRaises(ValueError):
                    audio.render_track('invalid-room', source, self.instruments, 18427)

    def test_rendered_boss_has_body_brightness_and_section_dynamics(self):
        track = self.tracks['boss']
        pcm = audio.render_track('boss', track, self.instruments, 18427)
        mono = pcm.astype(np.float64).mean(axis=1) / 32767
        windows = mono[:len(mono) // 22050 * 22050].reshape(-1, 22050)
        rms = np.sqrt(np.mean(windows * windows, axis=1))
        self.assertGreater(float(np.quantile(rms, .9)), float(np.quantile(rms, .1)) * 1.3)
        self.assertGreater(float(np.quantile(rms, .1)), .006)
        # A representative active passage must contain bass body and bright
        # percussion; these broad bands do not assert a subjective quality score.
        passage = mono[44100 * 8:44100 * 12]
        spectrum = np.abs(np.fft.rfft(passage * np.hanning(len(passage)))) ** 2
        frequencies = np.fft.rfftfreq(len(passage), 1 / 44100)
        total = spectrum.sum()
        self.assertGreater(float(spectrum[(frequencies > 45) & (frequencies < 220)].sum() / total), .04)
        self.assertGreater(float(spectrum[(frequencies > 3000) & (frequencies < 12000)].sum() / total), .002)


if __name__ == '__main__':
    unittest.main()
