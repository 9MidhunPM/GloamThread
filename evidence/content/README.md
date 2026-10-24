# Agent 2 content delivery evidence

This directory records authored content checks. It is not evidence of Godot gameplay.

## Tool setup

Verified on 24 October 2026: Python 3.14.8, Pillow 13.0.0, NumPy 2.5.4,
Godot 4.7.2.stable.arch_linux.ed1daf0bf. No content downloads or runtime services.
Install the system prerequisites described in the central setup document; no
additional Python packages are needed beyond Pillow and NumPy.

## Drop A — diagnostic tracer

Branch: `feat/phase1-content`. Preparation base: `2fea1ef`.
The exact packet SHA is recorded in the next drop's history entry and Git history
(`feat: deliver diagnostic content tracer`); the commit cannot contain its own SHA.

Commands actually run from the content checkout:

```sh
python3 tools/preflight.py
python3 tools/generate_assets.py --seed 18427 --stage diagnostic
python3 tools/validate_assets.py --stage diagnostic
python3 tools/validate_content.py --stage diagnostic
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/check_pack.py
git diff --check
```

Results: generation produced six manifested assets; diagnostic asset/content
checks passed; 15 Python tests passed. Planning-pack checks passed. The full
asset validator correctly exited 1 for the diagnostic stage and absent final
inventory. Full generation explicitly reports that final authoring is in progress.

Inventory: 160x120 padded diagnostic terrain, 32x48 Tavi/Neri silhouettes at
feet origin (16,43), 32x32 mover, original 96-glyph PNG/BMFont pair, fixed profiles,
both theme definitions with stable ordered 48 terrain IDs, initial full world
graph and concise dialogue. r00 is 60x23 with the specified spawn/mover contract.

Directly inspected both diagnostic courier PNGs at native resolution. Their
hood, scarf and spool shapes differ. This inspection does not establish animation,
combat readability or a finished art direction. Every output has source hashes.

Runtime integration: load the exact diagnostic paths and fixed profile visual
IDs. Font ID `font_v1` references PNG `font_texture_v1`. Final theme terrain and
background references are explicitly deferred in diagnostic validation. Agent 1
must supply strict entity/entrance/decor consumers and measured jump/dash bounds.

Remaining: complete animation/actor/prop/background/effect/UI inventory, 18 cues,
three arrangements, final eight-room content, traversal and runtime review.
Godot imports, animation playback, listening, gamepads, physical traversal,
performance, exports and human playtests are unverified by Agent 2.

## Drop B — complete original asset inventory

Previous packet: `34e14c96d9c2e78d94007b55ac7af5794b5157ec` (Drop A).
Drop B supplies assets independently of the final room/story packet. The retained
diagnostic image files remain available to the early runtime; they are absent
from the full manifest and are not full-content dependencies.

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 tools/gen/rebuild_check.py --seed 18427
python3 -m unittest discover -s tools/tests -p test_assets.py
python3 -m unittest discover -s tools/tests -p test_audio.py
python3 -m unittest discover -s tools/tests -p test_generation.py
```

Results: 47 full-stage manifested assets; asset validation PASS; 27 asset,
11 audio and two generator tests PASS (40 tests). Two full rebuilds produced
identical hashes for all 47 listed outputs and the manifest, recorded in
`rebuild.json`. The generator's default stage is now usable and complete.

Inventory: 64 courier frames, 70 Oru/enemy/boss frames, both 48-slot terrain
atlases, six finite 480x360 backgrounds, 16 logical props with 21 state frames,
48 effect frames, 20 UI glyphs, the original font, 18 distinct semantic cues,
and 48/36/18-second exploration/boss/ending arrangements. Every asset retains
source paths/hashes. Sources include explicit palettes, pixel/pose recipes,
glyph matrices, instruments, envelopes, cues and note scores.

Native atlas/contact-sheet inspection covered both couriers, Oru, both normal
enemies, boss phases and Ember/Moss authoring compositions. A review corrected
inner-corner highlight orientation. Audio tests cover actual PCM format, peaks,
loop seams and a representative simultaneous-event combination. These checks
do not establish runtime mixing or listening comfort.

Integration: map full manifest frame/tick tables into runtime animation and
register all semantic audio names once through the shared mix. Props expose
`prop_ids` aligned to frames and `logical_props` for inventory checks; the first
16 frame indices remain stable. Full room delivery follows separately. No
finished-room, physical-traversal, engine-import or motion gate is claimed.

## Drop C — full story bundle and integration support

Previous packet: `8495efa74c5e1eaefcdbf8305457a9231ca4c42f` (Drop B).
Full room/story implementation packet: `48fb0626809dcfa52f0139c03b907c689cc3b9c8`.
All eight final room files are now authored; r00's diagnostic mover is replaced
by Lantern Rest while its start/checkpoint/entrance IDs remain stable. The exact
earlier diagnostic room survives as a data-only contract fixture.

```sh
python3 tools/validate_content.py
python3 tools/validate_assets.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/gen/preview.py
python3 tools/check_pack.py
git diff --check
```

Results: both full validators PASS; all 69 Python tests PASS (27 asset, 29
content, 11 audio, two generator tests). Pack and whitespace checks PASS.
The asset rebuild result remains in `rebuild.json`; this drop changes room
data and validation, not the generated asset inputs.

The bundle includes the canonical nine links/18 directed exits, Oru, both
checkpoints, two distinct-anchor bridge pairs, both normal enemy lessons,
Spoolwarden, charm, dash-gated return branch, loom stations and ending dialogue.
Layouts have at most two-tile ascent steps after comparison with the current
motor source; no engine traversal measurement is implied. An optional marked
hazard shelf has a safe route beneath it. Review also fixed exit rectangles to
include standing feet and tightened malformed-data/required-bridge validation.

`traversal_requests.md` lists exact room checks and presentation changes needed
from Agent 1. The r01/r06 dash gaps require their measured dash envelope. Both
anchor approaches, secret ladder, encounter spacing, rally zones and return
spawns still need normal-input runtime checks. Gameplay, timing and story pacing
are not established by these structural tests.

`python3 tools/gen/preview.py` rebuilds six PNG contact/composition previews in
`authoring/`. Each composed room image is labelled **AUTHORING ONLY / NO PHYSICS**.
They are source-art reviews, never screenshots of the running game. Native
inspection covered r00/r02 in Ember/Moss and the actor sheets. Motion, shared
viewport masks, UI fit, audio listening, hardware and human gates remain pending.

Agent 1 should true-merge the cumulative content branch at the appropriate
runtime checkpoint, run authoritative imports/scenarios, update central setup
and status documentation, and record actual review findings for focused content
corrections. Agent 2 has not modified runtime scripts, entry points, import
sidecars, central status documents or `main`.

### Measured motor handoff

Agent 1's runtime commit `b1ff5d6` records a real-physics jump rise of 41.74 px,
running same-height feet travel of 55.00 px and 30 airborne ticks. The exact
command and configuration are quoted in `traversal_requests.md`. These are
Agent 1's diagnostic-room results, read by Agent 2 after room publication.
They support the conservative two-tile ascent target; they do not validate the
full authored route. Dash, production-room motion/readability and integrated
acceptance remain pending. This receipt changes documentation only.

## Event documentation correction

The user requested project-wide alignment with the corrected **Devin Hack Kochi**
template. The reference branch was read through GitHub at commit
`cb4db78169a8d199b43b077fbcc8f2ff4b798a14`; [RULES.md](../../RULES.md) pins that source.
Active documentation now follows its provider-neutral guidance and delegates
unconfirmed logistics/eligibility to current organizers. Historical development
records and actual tool attribution remain intact.

This later user request extends the earlier content-only documentation boundary:
central setup/status/event docs were corrected on the content branch, with Agent 1
notified to preserve newer runtime facts when merging. `tools/check_pack.py` now
rejects inherited event names/registration references in active guidance; it first
failed on the old README and passed after correction. This gate and link checks
do not add engine or gameplay evidence.

## Content QA follow-up

The next content review reproduced invalid bundles that still passed after their
hashes were updated: blank terrain in both themes, invisible UI, duplicated
couriers/background layers and silent PCM. Validation now checks frozen canonical
terrain alpha masks, visible images/frames, decoded visible-pixel differences and
nonzero audio signal. A further regression caught an individually transparent
background layer; that case first failed as an accepted bad bundle, then passed
after the visibility check. Intentional animation-frame reuse remains permitted.

Room QA widens/insets east approaches in r02/r06, raises r03's optional hazard
shelf for 80 px of ground-combat clearance, and gives r06's safe catch bed a
west-only recovery shelf. `traversal_requests.md` records coordinates and the
remaining need for measured Threadstep/ordinary-input verification. Entities,
spawns, exits and permanent progression flags are preserved.

Actual commands and outcomes:

```sh
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/validate_assets.py
python3 tools/validate_content.py
python3 tools/gen/preview.py
python3 tools/check_pack.py
git diff --check
```

All **79 tests PASS** (37 asset, 29 content, 11 audio, two generator). Both full
validators PASS; event/document/link/example checks and whitespace PASS. A fresh
temporary diagnostic generation/validation also passed during validator review.
The preview helper now writes nine labelled source-art views/sheets, including
the raised hazard, east approaches and catch bed, with room-height-aware framing.
These were inspected at native resolution; they remain **authoring-only**.

No shipped asset recipe/output changed, so the prior 47-output deterministic
rebuild record remains applicable. No engine, listening, controller, performance,
export or human-playtest result is added by this follow-up.
