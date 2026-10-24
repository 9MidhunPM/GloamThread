# Agent 2 forge changelog

## 2026-10-25T03:07:52+05:30 — Accept manually approved visual settings

- Allowed an empty visual-features array, matching the approved array contract and the creator's manual body/kit/theme mode. Analysis still proposes descriptive features when used.
- Why: drawing and approving settings without analysis previously failed local validation before image generation, with no UI field to repair the mismatch.
- Validation: the new mocked-provider regression uses the real rig converter, completes with two image calls and no analysis call, and reserves exactly $0.20. The full forge suite passes 37/37; compilation and whitespace pass. No live request or artwork acceptance is claimed.

## 2026-10-25T03:02:25+05:30 — Bound local drawing-to-fighter jobs

- Added the CLI and official OpenAI adapter, strict proposal approval, bounded/snapshotted drawings, two reference-image edits, exact retained prompts/settings and safe request metadata.
- Added per-job process locks, an atomic shared $0.50 reservation ledger, cancellation around dispatch/return, hash-verified caches, no automatic retries and offline local rebaking.
- Candidates use the existing authored rigs and shared validator. Staging and rollback preserve the previous preview through provenance/status publication; generated themes and editable parts survive rebaking. The worker never installs accepted fighters.
- Validation: 36/36 mock provider/job/SDK tests pass, including actual conversion/rebaking for all three rigs, concurrent duplicate-job/shared-budget races and publication fault injection. The full expanded 137-test Python suite passes. Python compilation, safe CLI status, pack/link and whitespace checks pass. Independent review found and corrected a pre-dispatch cancellation race, paid-settings dependency in offline bake, unbounded cache reads and preview rollback after a metadata failure. A real-converter test exposed the four-color palette bug; the rig owner supplied commit 2d65e88, imported without duplicating its history.
- Limitations: no live OpenAI requests, new generated artwork, native creator interaction, human drawing-fidelity or animation review is claimed by this packet. Conservative reservations are not billing measurements; physical disk/power-loss faults remain untested.
