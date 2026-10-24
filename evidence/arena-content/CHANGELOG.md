# Agent 2 arena content changelog

## 2026-10-25T02:54:46+05:30 — Original wave content and deterministic fighter rigs

- Authored six ability-family descriptions,30run upgrades,20ordered waves/fourbosses and four reachable arena layouts. Runtime owns mechanics and final stat bounds.
- Added original Cinderjack upright/Ember and Thistlepaw quadruped/Nature bundles, editable separated parts and source profiles, plus an editable floating lantern-manta fixture. Authored three rig motion templates; all32animation slots bake deterministically into padded64pixel cells. Added themed original background/material recipes.
- Added strict shared bundle/content admission, editable-mask/pivot rebaking and generated3×3parts/theme-board conversion. Conversion makes no API calls and retains rejected candidates.
- Validation: python3 -m unittest tools.tests.test_forge_content -v —11/11PASS; python3 -m tools.forge.content --build --validate and --validate PASS (6kits,30upgrades,20waves,4arenas,2bundles); git diff --check PASS. Static native-resolution atlases and background inspected with view_image.
- Limitations: no real provider output, animated native game playback, hardware/human controls, audio listening or full new-game playthrough verified by this content packet. Twopalette fixtures perrig prove structural compatibility, not user-drawing recognition.

## 2026-10-25T02:59:00+05:30 — Original enemy tells and retained generated master

- Added six original32pixel enemy atlases and four64pixel boss atlases, each with16authored walk/windup/active/recovery/defeat poses. Freeze consumer layout and independent damage geometry with runtime actor worker. Index includes dimensions, file hashes and source provenance.
- Generated-board conversion now requires and retains a full master design from slot8 for identity comparison; masks/pivots still bake new candidates while preserving prior output. Documented rebake theme/provenance staging needs to provider/UI workers.
- Validation:13content/conversion tests PASS; full local content validator PASS including10enemy/boss atlases; actual contact sheet inspected at3×/2×, no native animation or playthrough claim. No paid calls.

## 2026-10-25T03:00:06+05:30 — Accept every documented palette size before paid conversion

- Provider-worker review found that valid4/5colour proposals could reach six-swatch artwork helpers and fail after a paid request. Added local derived highlights without mutating the retained4–8colour proposal. Rebuilt source-hash provenance.
- Validation:14content/conversion tests PASS including real4/5colour board conversion, all three rig families and master rejection. Local content validator PASS; no API calls made.

## 2026-10-25T03:02:56+05:30 — Original arcade score and useful general healing branch

- Added editable original Copper Rush, The Loom Bites Back and Pocketful of Sparks arrangements, synthesized with the project's own instruments. Added coin,purchase,wave-clear,ready andcombo cues with deliberate headroom and zero endpoints. Audio index records PCM dimensions, loops, source/output hashes.
- Replaced cosmetic-only coin magnet shop offer with Field Stitch regeneration (.35HP/sec/rank,price8), agreed with runtime integration; retained12general/18kit branches.
- Validation:15content/art/conversion/audio tests PASS; local rebuild/validator PASS for6kits,30upgrades,20waves,4arenas,2bundles,10enemy atlases,5cues and3scores; git diff --check PASS. Waveform RMS/peaks/format/endpoints checked. Listening, native mix and human rhythm acceptance remain unverified. No paid calls.

## 2026-10-25T03:05:44+05:30 — Six distinct creator drawings across all three rigs

- Added original Kiln Fox/Bucket Knight, Seed Stag/Pebbleback and Lantern Manta/Clock Orb drawings with retained separated parts, expected distinctive features, hashes and deterministic rebuild source. These vary silhouette/anatomy within each supported rig rather than only palette.
- Replaced the earlier two-palette rig check with six distinct authored designs and exercised all six through the actual generated-board conversion/retained-master boundary.
- Validation:16content/art/rig/conversion/audio tests PASS; full local rebuild/validator PASS; actual six-design contact sheet inspected. No provider recognition, native animation, human gameplay or audio listening acceptance is claimed by these local fixtures.

## 2026-10-25T03:11:29+05:30 — Preserve generated themes and fingerprint every rebake input

- Peer review reproduced two defects: missing retained theme images silently selected authored art, and changed mask/part pixels could retain the same manifest identity and provenance. Generated rebakes now require both retained theme files and their generation provenance; failures occur before a new candidate directory is created. New generated rigs retain an explicit source marker, while earlier raw-hash provenance remains compatible.
- Bake provenance now binds source/decoded part hashes, source/applied-alpha mask hashes, source/applied rig hashes, pivots, edit JSON, retained/generated theme files/pixels and converter/animation source versions. Manifest identity derives from the full bake fingerprint. Parent generation metadata and its exact provenance hash remain linked; unchanged rebakes remain stable.
- Validation:22content/art/conversion/audio tests PASS, including actual mask-pixel mutation without JSON changes, part/pivot changes, unchanged rebake identity, missing background/material rejection, preserved original candidates and parent provenance. Local retained-content validator and git diff --check PASS. No shipped artwork or provider orchestration changed; no paid calls made.

## 2026-10-25T03:42:41+05:30 — Correct reviewed real image layouts without weakening admission

- Reproduced local failure against Root's retained successful provider images: the parts board used a different layout and translucent haze, so strict3×3cell admission correctly rejected a clipped torso. The theme also included a giant hero. No provider request was made and original job/raw/provenance/ledger files were not modified.
- Added explicit source_layout.json v1: exact raw-image hashes, allowlisted part crop rectangles, reviewed alpha cutoff, master/background crops and optional four material crops. Coordinates are bounded1024image integers, no paths. Default grid admission remains strict. Layout recipe/filehash enters generation and bake provenance/identity; changed/removed annotations require reconversion rather than falsely relabelling old pixels.
- Prepared a new temporary reviewed fox candidate from source pixels only: separated body/limbs/master, alpha cutoff192, safe16:9forest crop[0,140,576,324] excluding the giant avatar, four actual material panels. Retained the hash-bound recipe in reviewed_fox_source_layout.json. Master/all32poses/background/materials were inspected with view_image; ears,chest light and sword remain recognizable and coherent. Native in-game readability and human art review remain pending.
- Validation:25lane tests PASS, including non-grid/haze fixture, unchanged strict rejection, annotation hash/bounds/IDs/cutoff validation, background avatar exclusion and changed-layout reconversion. Retained-content validator and git diff --check PASS. No shipped built-ins or provider orchestration changed.
