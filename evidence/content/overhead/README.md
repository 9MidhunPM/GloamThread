# Original overhead art and active soundtrack packet

25 October 2026 · Agent 2 separate-checkout delivery. Asset header `overhead-v1`, generator 2.0.0, seed 18427. The preserved side-view milestone and its game evidence remain separate. Matching overhead runtime/content are owned by Agent 1.

## Delivered content

- Tavi/Neri: four explicitly authored directions, 128 unique frames each, 36 clips, 32×48 cells, origin `[16,43]`, padded 288×832 atlases. Cleave/cast windup, release, follow-through, grounded run, roll, dash, hurt, downed and revive retain fixed feet. Clip timing matches the agreed 18-tick slash and 22-tick special; art never executes hit logic.
- Overhead Oru, Spoolmite, Wickwing and radial four-strut Spoolwarden retain their semantic clip names and frame/pivot contracts. Boss sweep/strike/charge have separate tell/active/recovery poses; stagger exposes the bright stitch. Directed attack warnings remain runtime-owned.
- Both terrain families implement the exact 48 new slots as opaque 16×16 cells. Floor/wall/water/bridge/hazard materials have distinct authored patterns. Canonical room JSON controls walkability. All eight six-frame effect sequences retain binary alpha; directional effects face +X before cardinal rotation.
- Four fully original arrangements use authored keyboard, bass, counterline and percussion instruments, deterministic synthesis and retained notes/envelopes. No external samples, game transcriptions, soundfonts or downloaded content are used. Named references guided broad energy and contrast only.

| Arrangement | Duration | Note events | Peak full scale | Loop |
| --- | --- | --- | --- | --- |
| Exploration | 48 s | 804 | 0.235 | yes |
| Boss | 51.2 s | 1,345 | 0.270 | yes |
| Boss final | 51.2 s | 1,877 | 0.270 | yes |
| Ending | 20 s | 130 | 0.245 | no |

Boss variants share a 150 BPM, 32-bar grid and the project's original hook. The final arrangement adds independent counterlead, octave bass replies and tighter percussion; it increases activity without increasing the master peak. Exploration has a buoyant groove; the ending resolves the hook. [Audio metrics](audio_metrics.json) include actual source WAV hashes, RMS and configuration. These measurements do not establish listening comfort or musical preference.

Static [courier attacks at 1×](contact_sheets/couriers_attacks_1x.png), [boss](contact_sheets/spoolwarden_contact.png), [effects](contact_sheets/effects_contact.png), [Ember](contact_sheets/ember_terrain.png) and [Moss](contact_sheets/moss_terrain.png) contact sheets were inspected. They are authored asset contact sheets, not screenshots of running gameplay. Prepared GIF playback was not watched. Full new animation timing and readability still need the actual overhead game.

## Validation and integration boundary

Commands:

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
godot --headless --path . --editor --import --quit
python3 tools/check_pack.py
git diff --check
```

The final full packet passes **100 Python tests** (40.870 seconds), including two complete seeded rebuilds with equal manifests/output hashes, asset rejection fixtures, audio format/seam/headroom/determinism checks, score structure and art contracts. The earlier 99-test packet preceded the added roll cue. Godot 4.7.2 standard headless import passes with no script/engine error. Asset validation passes for all **49 assets**. Independent art/admission and audio/source review found no produced-media blocker. Review exposed permissive Oru/effect clip aliases; two new regressions first failed, then passed after requiring `acknowledge`/`play` exactly. Correct existing producer names were retained.

The original 18 SFX WAVs are byte-identical to `34ccb96`, checked against Git blobs; an additional original 0.18-second cloth/foot roll cue fits the 12-tick move. It is mono/nonlooping, with a 0.21 peak; it is not a renamed jump or dash. Inventory is 19 cues plus four music arrangements. Headroom tests cover named synthetic mixes, not every possible speaker/device combination. All audio is 44.1 kHz/16-bit, mono cues and stereo music. The first three tracks have explicit loop metadata.

At the source base in this checkout, the old actual-content validator correctly rejects the new epoch and terrain. Its three errors are the old expected `phase1-v1` header and two old terrain mappings. Its legacy fixture tests remain in the Python suite; they do not establish that new overhead rooms are valid. Agent 1 must integrate the matching new validator, catalogs, rooms, movement and views, then run the complete ordinary-input route and native 1×/2× review before a playable main merge. Headless media import does not prove any of those gates.

Physical controllers/rollover, listening, exported playback/performance and fresh two-person enjoyment remain unverified. No generated-character backend or new scope beyond the agreed overhead adventure is included.
