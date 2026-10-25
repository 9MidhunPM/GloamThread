# Agent 2 forge changelog

## 2026-10-25T06:26:42+05:30 — Remove local generation dollar caps

- Implemented the user's explicit instruction to remove dollar limits. Shared/per-character admission checks and obsolete configuration parsing are removed; legacy draft budget fields and ledger cap metadata no longer block work. Existing request/uncertain history stays intact.
- Added the agreed status contract: `budget.limits_enabled` is false, limit/remaining values are null, and historical request estimates remain numeric accounting only. Updated the CLI and public template without reading or changing private credentials. Explicit Generate, no automatic retries, validated caches, cancellation, duplicate-job locks and atomic publication remain intact.
- Validation: full Python suite 187/187 PASS; focused forge suites 65/65 PASS, including 14 revised migration/preflight cases. Tests prove continued generation beyond former caps, concurrent request recording, ignored legacy zero/invalid limits, old/uncertain history preservation, free cache conversion and unchanged retry/corruption guards. Independent review and a temporary ledger probe above the old $100 parser ceiling pass. Compilation and whitespace PASS; no live requests or actual job/ledger access occurred.
- Limitations: numeric request estimates are not billing receipts; the user's reported $0.0012 was not independently verified. Root owns creator/UI messaging, live/cached end-to-end generation, game checks and final integration.

## 2026-10-25T04:05:02+05:30 — Check the complete missing-image allowance before dispatch

- Added a non-mutating generation preflight that verifies both image caches, sums only missing reservations and checks remaining shared/job allowances under the ledger lock. It also refuses an already-attempted image lacking a valid cache; per-request reservations still enforce concurrency after the check.
- Why: with $0.35 already allocated, a new two-image job could previously reserve/start its first $0.10 request before discovering the second would exceed the shared cap. It now makes zero calls and leaves ledger bytes unchanged.
- Validation: isolated old commit 98d42a6 reproduces that regression; the patched worker passes all four new cases, including exact $0.20 fresh generation, cached-parts reuse with $0.10 remaining and corrupted-cache rejection. Full Python suite 167/167 and combined forge suites 55/55 PASS; independent source review/mock probe, compilation and whitespace PASS. No actual SDK, job, ledger or credentials were accessed.
- Limitations: the check does not reserve or lock the whole generation. Another job may consume budget later; the unchanged per-request reservation remains authoritative. Amounts are conservative allocations, not billing measurements.

## 2026-10-25T03:47:24+05:30 — Recover retained image boards without another request

- Added safe source-layout staging and a no-rig `bake` bootstrap for received, hash-verified raw boards. Recovery verifies the original/normalized source, frozen approved proposal, received request identity, raw PNGs and output hashes without loading provider settings or constructing the SDK.
- Both generation and recovery convert immutable staging copies. Existing rig rebakes preserve their normal path; changed source-layout hashes require a separate local correction job instead of silently reusing old parts. Project conversion reasons now reach failed status messages while SDK bodies remain hidden.
- Candidate and editable-art publication retain rollback protection. Invalid layouts, modified caches, mismatched approvals, conversion errors and publication faults preserve previous previews/provenance and add no reservation.
- Validation: full Python suite 163/163 PASS; combined provider/recovery suite 51/51 PASS, including 13 recovery scenarios, real authored non-grid/hazy-board rejection → reviewed-layout conversion → unchanged local rebake, bad-layout/cache subcases and publication rollback. Compilation, pack/link and whitespace checks PASS. Independent read-only review found no P0/P1 issue and separately passed all 13 recovery tests; no live API calls or real job/ledger access occurred in this lane.
- Limitations: synthetic authored fixtures establish the local recovery boundary, not acceptance of the live generated artwork, its drawing fidelity, animation quality or the rendered ROI UI. Root owns those checks and final integration.

## 2026-10-25T03:11:00+05:30 — Exercise the real offline CLI boundary

- Added a subprocess regression for the same shell-free `bake --job` command launched by Godot, including an absolute job path containing spaces.
- The fixture checkout deliberately rejects SDK/dotenv imports and has unsupported paid settings. Its authored floating rig still bakes and passes shared bundle validation with zero reservation and no ledger creation.
- Validation: forge suite 38/38 passes; targeted CLI process case, compilation and whitespace pass. This proves the Python process boundary with a local fixture, not a rendered creator interaction, provider success or accepted generated art.

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
