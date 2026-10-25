# Arena character and texture authoring

The active workflow is drawing/upload → bounded proposal → generated parts/theme → authored rig bake → preview/correction → accepted local fighter. Read [the current contract](WAVE_FIGHTER_SPEC.md), [worker commands](../evidence/arena-content/forge/README.md) and [Linux setup/play guide](ARENA_DEMO.md). The fixed campaign overlay notes formerly here belong to the preserved side-view experiment in Git history.

## Setup and privacy

Use the optional `requirements-authoring.txt` environment and put your key in ignored root `.env`; exported packages use `authoring/.env`. Godot never reads the key. The local Python process uses the official SDK with explicit `gpt-6-luna` vision and `gpt-image-1-mini` low square PNG edits. Both models must be enabled for the key's API project. No requests happen during combat, and accepted/built-in fighters work offline.

The user removed local total and per-character dollar admission caps. Legacy allowance settings and job limits are ignored, while request estimates, caches and uncertain attempts stay durable. Status reports `budget.limits_enabled=false`, null limit/remaining fields and numeric estimates; these are not actual billing. Generation remains explicit with no automatic retry or model fallback. Cached local correction does not call a provider.

## Real output and correction

The successful live input was an original project fox drawing. Luna identified its upright shape, ears, mask and chest light. Mini returned one transparent parts board and one opaque theme board. Its layout differed from the requested grid and included a large hero in the background; strict admission rejected it.

The creator now exposes an explicit hash-bound crop editor for those retained boards. Assign every required limb/master and scenery/material crop, review alpha cleanup, then **Save corrections & convert locally**. This copies verified raw receipts/source into a fresh local draft and calls SDK-free `bake`; earlier jobs, masks, candidates and the shared ledger remain intact. Changing crops on an existing rig requires a fresh correction draft so old pixels cannot be falsely relabelled. Part masks and pivots remain editable after conversion.

`source_layout.json` contains only bounded crop rectangles, a cutoff and hashes of the fixed input PNGs. It supplies no gameplay, scripts or file paths. The same three rig families and 32 authored clips bake all accepted appearances. Ability IDs/stats/timing/collision are game-owned. Themes decorate fixed geometry; they alternate by stage between players.

## Retained shipped generation

`assets/arena/source/generated_kiln_fox/` retains original/request sources, the real raw pair, approved proposal, genuine sanitized request metadata, crop recipe and editable rig/parts/themes. `assets/arena/builtin/kiln-fox-ai/` is the validated reviewed bundle. The original Cinderjack/Thistlepaw remain available; index defaults select Kiln Fox/Nature.

Rebuild without network or credentials:

```sh
python3 -m tools.forge.retained --validate
python3 -m tools.forge.content --build --validate
```

Every rebuilt PNG must match the retained inputs/recipe and current generator. Runtime acceptance validates hashes, dimensions, gutters, pivots and allowed identifiers before atomically installing a candidate with a recoverable backup. Structural checks do not replace animation/native/human review.
