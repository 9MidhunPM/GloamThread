# Change log

Record each meaningful project change, newest first. Update this file in the same commit as the change. Use a real timestamp with timezone, for example `YYYY-MM-DDTHH:MM:SS+05:30`. Never backdate an entry.

## Build log

## Agent 1 — runtime and integration

### 2026-10-25T02:18:24+05:30 — Preserve tested overhead experiment before returning to side view

- Changed: Retained active overhead resource/App/save regressions and archived platform-only fixtures with explicit historical mapping; switched native QA observer to the new ordinary-input overhead route.
- Why: Preserve a complete reviewable experimental checkpoint before the user-requested return to the earlier side-view game.
- Validation: Full112Python tests, both validators, fresh import and40/40 active Godot scenarios pass. Native first-room split-screen rendered; full overhead native/export and human gates remain unverified.

### 2026-10-25T02:13:07+05:30 — Reject malformed room epochs without script errors

- Changed: Type-check the room content epoch before string comparison and retain overhead spawn/reference boundary checks.
- Why: Boolean and integer JSON epochs crashed parsing instead of returning useful validation errors; the expanded boundary scenario reproduced both failures.
- Validation: Focused room-loading scenario now passes incompatible string, boolean, integer and null epochs plus dry-footprint checks; whitespace and pack checks pass.

### 2026-10-25T02:06:20+05:30 — Teach current overhead controls at join

- Changed: Join source rows show each selected player's current movement, Roll, combat, interaction/revive and map bindings. Threadstep is visibly locked for New and reflects the saved team unlock for Continue.
- Why: Hardcoded platform jump instructions misled players and ignored remapping/device changes.
- Validation: Actual-App overhead control scenario passes remapped partner isolation and new/continued unlock states; clean editor import and documentation/whitespace checks pass.

### 2026-10-25T02:05:12+05:30 — Isolate overhead saves and identify development packages

- Changed: Versioned the new game 0.2.0-dev with a dedicated Gloamthread-overhead user-data directory. Linux packaging derives its archive/build version from the validated project identifier; updated the current launch guide for Roll and actual verification limits.
- Why: Preserve the published side-view campaign/settings and prevent a new export from masquerading as the old demo.
- Validation: Python packaging compilation, planning-pack links and whitespace pass. Native overhead play/export remains a separate pending gate.

### 2026-10-25T02:01:00+05:30 — Connect overhead rooms, per-player guidance and Oru's mission

- Changed: Integrated the authored overhead world/session/HUD with shared feet sorting, safe water-context cleanup, per-slot local hints/targets and permanent mission flow. Actual App Next/Skip/cancel closes introduction through complete_dialogue, committing met_oru before the first gate. Rewrote Oru's short introduction for clear overhead cooperation.
- Why: The new world gate must follow the production dialogue UI; fixture-only completion would leave actual players stuck. Nearby hints must belong to the courier who can act.
- Validation: Full content validator PASS;24overhead engine scenarios PASS, including three actual-App introduction closing paths and durable mission state. These include fixture-controlled physics/transactions and do not yet claim an ordinary complete overhead campaign or native quality.

### 2026-10-25T01:47:13+05:30 — Admit directional overhead media and fixed profiles

- Changed: Integrated original50asset overhead art/audio/home packet. Runtime now requires overhead-v1,courier_overhead_v1,36directional clips covering128hero frames, exact gameplay-matching visual ticks/pivots and the new48tile inventory. Migrated fixed profile/theme/dialogue headers; retained strict pre-play resource resolution.
- Why: Prevent a side-view or incomplete directional bundle from entering the new simulation while original media and runtime advance in separate lanes.
- Validation: Full media editor import clean; actual overhead catalog/profile/theme/resource scenario PASS, including missing-direction, bank overlap, timing, count, loop and pivot rejection. Producer103Python/asset validation/rebuild evidence retained. Full rooms/session/app integration remains in progress, not claimed by this boundary gate.

### 2026-10-25T01:03:41+05:30 — Freeze overhead gameplay/art contracts and parallel lanes

- Changed: Wrote overhead movement/combat/terrain/sprite/save contracts and playable checkpoint plan for the latest user direction. Defined exclusive worker lanes, clear player guidance and meaningful commit cadence; marked prior side-view MVP as historical.
- Why: Let runtime/world/input and original art/music/UI proceed in parallel without incompatible assumptions or manufactured commit history.
- Validation: Documentation links/consistency and whitespace checked. No overhead gameplay claim; implementation starts from the preserved verified main baseline.

### 2026-10-25T00:53:13+05:30 — Preserve the verified side-view candidate and record overhead direction

- Changed: Retained exact34ccb96build/checksums, full acceptance matrix, network isolation/real native route/captures/performance and submission/launch evidence. The20scenario/79Python release is preserved; the user's new overhead direction is explicit in current docs.
- Why: Keep a playable verified milestone while the requested perspective/music/UI/combat redesign proceeds through separate atomic commits and periodic tested main merges.
- Validation: Exact-source official release completes all8rooms/actual ending outside checkout with no network routes/addresses;11real captures,2,650r05samples at1920x720,120medianFPS/p95frame8.333ms. Archive integrity and GitHub uploaded digest match. Full validators/import/scenarios/Python/links pass; no script/resource errors in final native run.
- Limitations: Physical controllers, hardware rollover, listening, fresh pairs and human balance/fun remain unverified. Overhead gameplay is a new implementation effort; none of this evidence is relabeled for it.

### 2026-10-25T00:31:03+05:30 — Keep corrupted startup readable when the original font is missing

- Changed: Check the validated catalog before creating font-dependent menus/toasts. A required-resource failure now displays a bounded emergency diagnostic and Quit control, without creating a playable session or starting music. Only that failure screen uses the engine-default font.
- Why: Final sandbox review reproduced an invisible error screen when the required original font record was removed. The error UI had depended on the unavailable resource it was reporting.
- Validation: New startup-failure regression PASS; complete integrated suite PASS20/20 with no script errors. Valid startup/menu/campaign scenarios remain green. Final source is rebuilt and rechecked before publishing; earlier b96ad0e offline route passed, but its artifact is superseded by this correction.
- Limitations: The emergency screen is diagnostic only and never substitutes missing gameplay content. Physical controller/rollover, listening and fresh-pair acceptance remain unverified.

### 2026-10-25T00:17:08+05:30 — Polish original-font menus and prepare reproducible Linux packaging

- Changed: True-merged Agent2's complete native UI layout fixes/evidence. Critical values/bindings, scrollbars and long prompts are readable at1x/2x. Added the Linux package command, explicit license/provenance inventory, candidate launch guide, shipping exclusion of UI fixtures, and source/build identification for rendered QA. Toasts now have a readable backplate.
- Why: Make the candidate reproducible from a clean commit and retain the complete notices alongside its executable, with diagnostic tools excluded from the shipping package.
- Validation: Integrated suite PASS19/19 after full resource import; focused app scenarios PASS after toast styling. Packaging tool compiles and uses only the standard library; its clean-commit export/archive execution follows this commit. Private Xvfb UI captures pass24groups, exact2x pixels and owner-specific window actions; native actual-App campaign already reached ending with original art.
- Limitations: Final network-isolated export/package/checksum and exact build source are recorded in the subsequent release evidence. Physical controllers, hardware rollover, listening and fresh pairs remain unverified. The earlier release/X11 performance sample is preliminary, not asserted as the final binary.

### 2026-10-25T00:02:04+05:30 — Connect campaign menus and verify the complete route

- Changed: True-merged Agent 2's owner-controlled menu component and connected title/New/Continue, explicit join, source/character selection, pause/map/dialogue, controls/remapping/deadzone, volume/reduced effects, recovery, reconnect and ending/replay. Added queued notices plus persistent save errors, per-player prompts and readable HUD backplates. Permanent room visuals refresh immediately.
- Why: Make the shared campaign reachable through complete player-facing flows and prove authored rooms with real movement/combat rather than debug progression.
- Validation: 18 engine scenarios PASS; complete actual-App normal-input route reaches ending with both couriers alive and no recovery. Six-hundred-tick movement replay matches at30/60/144; boundary tests found and fixed a one-tick coyote defect. Secret tests caught/fixed simultaneous reward cue duplication. Native 960x360 logical captures show original themes/boss/ending. Engine logger negative probe correctly exits1 on runtime exception. Full source render performance is below target and under investigation against export.
- Review corrections: Title/quit retain unsaved campaigns for retry or explicit discard; missing pads fall back to a free keyboard zone, disconnected remapping cancels, and available players own reconnect menus. All18 integrated scenarios pass.
- Limitations: Export/offline/performance verification and newer UI layout QA continue. Gamepad hardware, physical rollover, listening, fresh pairs, human duration/balance/fun remain unverified. NoPhase2 work added.

### 2026-10-24T23:36:24+05:30 — Integrate original production content and campaign core

- Changed: True-merged the complete eight-room content branch. Added strict runtime catalogs, shared terrain/bridge/prop consumers, physics-driven sprite/effect animation and one audio mix. Implemented owned-input combat, both enemy types and boss, cooperative room/recovery/progression transactions, validated campaign backups and independent settings.
- Why: Replace diagnostic-only consumers with the original authored adventure and real shared gameplay, while retaining one authoritative simulation.
- Validation: Fresh full editor import had no script/resource errors; full asset/content validators PASS; all 79 Python tests PASS; integrated Godot suite PASS 12/12 from a fresh staged-file copy. Focused combat, catalog and persistence runs pass. Tests caught and fixed simultaneous anchor-edge loss, prop state aliases, orphan-backup handling and invalid save combinations.
- Limitations: Global menu integration, ordinary-input route, visible motion/listening, packaged offline export, performance and human/controller acceptance are still pending. Accelerated suite audio teardown warnings are recorded separately. Approved official template archive was checksum-verified and Linux templates installed.

### 2026-10-24T22:50:16+05:30 — Refresh diagnostic setup and handoff status

- Changed: Updated setup, decisions, implementation/test plan and submission to reflect the actual integrated diagnostic room instead of stale missing-boot claims. Recorded Agent 2's later cumulative content tip as queued for integration, preserving the distinction between authored content and implemented gameplay.
- Why: Keep the published agent handoff and launch instructions consistent with the first runtime milestone while both workstreams advance independently.
- Validation: Documentation/link/example checker and diff whitespace pass; Git remote refs confirm preparation `2fea1ef`, runtime diagnostic merge `b1ff5d6` and queued content `e56d714`. The prior 4 engine scenarios and 15 Python cases remain the current code verification; this change adds no gameplay.
- Limitations: Full adventure and visible/physical-input acceptance remain incomplete; final assets/rooms require further runtime consumers and integrated checks.

### 2026-10-24T22:40:57+05:30 — Integrate Agent 2's diagnostic packet and measure movement

- Changed: Merged content checkpoint `34e14c9` through a true merge, retaining both agents' log sections. Imported its original diagnostic sprites/terrain/font and added an engine scenario consuming the actual r00/manifest. Published the measured motor envelope, updated launch/validation instructions and retained an actual initial window capture.
- Why: Close the first runtime/content seam early and give the level author measured limits rather than theoretical jump assumptions.
- Validation: Diagnostic asset/content validators PASS; 15 Python tests PASS; clean resource import and bounded normal headless boot PASS; all 4 engine scenarios PASS. Actual-content session measured full jump rise 41.74 px, running feet travel 55.00 px, 30 airborne ticks and 66 px full-jump body clearance. Initial X11/Compatibility window capture shows both characters/tints. Hidden XWayland input was refused; native-Wayland background key delivery returned success but capture was black, so visible input/motion acceptance is unverified. Pack/whitespace checks passed; evidence is excluded from engine resource imports.
- Limitations: M0's visible simultaneous-control gate is still outstanding. No dash measurement, complete gameplay route, human/device/audio/performance acceptance or full-bundle claim. Content packet remains diagnostic; complete schemas and later runtime mechanics are still planned.

### 2026-10-24T22:32:31+05:30 — Add the shared session and motor before content integration

- Changed: Added boot/session scenes, one authoritative world with two viewports/cameras/HUDs, a manifest image boundary, owned player motor and stable sprite pivot, diagnostic mover, shared focus/pause overlay and an explicit test-only room fixture. Production boot reports missing content rather than substituting test geometry.
- Why: Complete the runtime side of the first parallel handoff and test real physics/session ownership before merging Agent 2's first packet.
- Validation: Fresh headless editor import exited 0 without resource/script errors. The real-session fixture smoke scenario passed: one world/room/mover, two independent nonblocking players, stable grounding, diverging cameras, masks, jump and shared pause/resume. The isolated motor/camera harness passed 19 checks. Visual, actual device and production-content checks remain pending.
- Limitations: This pre-merge checkpoint has no production content/assets yet. The explicit fixture disables art only for engine tests; it cannot satisfy rendered or ordinary-input acceptance. Full manifest/entity validation, one-way drop-through, combat and later milestones are outstanding.

### 2026-10-24T22:23:11+05:30 — Start runtime verification and harden input/room data

- Changed: Added the built-in scenario runner/filter/timeout and shell wrapper, input and room boundary scenarios, generated script UID metadata and runtime evidence. Validated saved controls and analog remapping, neutralized disconnected inputs, prevented duplicate identical-pad reconnect claims, and latched held movement/actions across flush. Room parsing rejects malformed geometry/fractional coordinates/oversized layouts and unsafe or duplicated paired spawns without indexing invalid rows or treating outside-room sentinels as real floors. Updated current setup/status/command instructions.
- Why: Give Agent 1 reproducible engine checks and repair scaffold defects before the parallel content pipeline supplies real rooms/assets.
- Validation: Final Godot run: 2 scenarios passed / 0 failed; wrapper's room filter passed; nonexistent-filter run correctly exited 1. A new held-stick regression first failed and then passed after directional latching was fixed. Editor scan registered 13 scripts but reported the still-missing boot scene despite exit 0; not a complete import/launch pass. Exact commands/configuration and remaining gaps are in `evidence/runtime/commands.md`; pack and whitespace checks run before commit.
- Limitations: Synthetic input only; no physical devices, visible split screen, gameplay, audio, performance or human playtest. Boot/session/player/cameras and Agent 2's authored content remain outstanding; full entity schema validation is not yet implemented.

### 2026-10-24T22:10:33+05:30 — Prepare two-agent parallel execution

- Changed: Added runtime and content agent briefs with exclusive files, shared JSON/asset/audio/room contracts, staged deliverables, separate checkouts/branches and integration gates. Linked the briefs from the agent guide, handoff, README, decisions, task list and original plan. Allocated independent changelog/AI-usage sections; made the pack checker require both briefs.
- Why: Let the second agent start the original content pipeline immediately while Agent 1 completes the playable Godot foundation without competing writes or incompatible formats.
- Validation: Documentation/link/example checks and diff whitespace are run before committing this setup. Checkout/branch creation and remote publication are verified after that commit.
- Limitations: This checkpoint sets up the work; it does not implement or verify the game. Agent 2 must deliver its diagnostic packet before integrated M0 acceptance can pass.

## Agent 2 — content and assets

### 2026-10-25T01:49:29+05:30 — Repair the authoring tool for overhead content

- Changed: Replaced side-view preview assumptions with explicit overhead material/pose studies, correct feet/crop/sort rules, strict epoch guards, selected-room/output options and original manifested captions. Versioned the default study directory to preserve old side-view evidence; added nine public-CLI tests and a hashed r00 working-snapshot example.
- Why: The existing preview command crashed on new terrain names and could overwrite historical authoring proof. A one-room milestone needs a useful study before every room is migrated.
- Validation: 112 Python tests PASS, including nine CLI cases; Python compilation, independent review, pack/link and whitespace PASS. Evidence-preservation regression first failed then passed. Actual old checkout correctly rejects before output; a read-only Agent 1 r00 snapshot renders a labelled study successfully.
- Limitations: Pillow studies show basic materials/poses only; no engine/camera/collision/gameplay/audio/performance is exercised. Snapshot hashes identify inputs without claiming a released build or new normal-control route.

### 2026-10-25T01:29:53+05:30 — Separate enemy warnings from attack artwork

- Changed: Added the original six-frame hollow +X warning arrow, editable source, retained atlas/provenance and focused tests. Required transient effect playback to be nonlooping. Generator 2.1.0 produces 50 assets.
- Why: Agent 1's actor lane needs a readable overhead warning rather than reusing slash artwork; a marker must show danger direction immediately without hiding ground or flashing.
- Validation: 103 Python tests PASS, two complete deterministic rebuilds, full50asset validation, Godot media import, pack/link and whitespace PASS. New finite-effect regression first failed then passed. Static marker/rotation sheet inspected; all previous49 media files remain byte-identical to e85fc2f.
- Limitations: Runtime marker placement/rotation/windup holding and ordinary/boss encounter readability remain integration work. A direction arrow is not an exact hitbox contour or a human playtest result.

### 2026-10-25T01:18:03+05:30 — Author the overhead art and active original soundtrack

- Changed: Rebuilt both couriers as four-direction 128-frame sets, radial actors/boss, all eight effects and 48 opaque overhead terrain slots. Added four original keyboard/bass/percussion arrangements including boss_final, plus a grounded roll cue while retaining 18 legacy SFX. Versioned the 49-asset packet as overhead-v1/generator 2.0.0 with source/output provenance. Updated asset admission, focused regressions, pipeline docs and branch integration notice.
- Why: Implement the user-authorized overhead direction and stronger animation/music while preserving clear movement, attack phases and original content. Broad reference qualities inform energy and perspective; no copied art, melodies, samples or maps are used.
- Validation: 100 Python tests PASS, including two deterministic full rebuilds, art/source/PCM/headroom tests and negative admission cases; full asset validator PASS; Godot 4.7.2 headless media import PASS; pack/link and whitespace PASS. Static 1× attack/terrain/effect/boss contact sheets inspected; independent source/admission review completed. Two clip-alias regressions first failed then passed after exact Oru/effect names were enforced. Original 18 SFX bytes independently match 34ccb96.
- Limitations: This is a content packet, not an overhead gameplay completion claim. The old checkout content gate rejects the new epoch/terrain until Agent 1 integrates matching rooms/runtime. New in-engine motion, complete ordinary-control route, exported playback/performance, listening, hardware and human acceptance remain separate. Evidence and actual audio metrics are retained under evidence/content/overhead.

### 2026-10-25T00:55:01+05:30 — Give the home screen an original illustrated composition

- Changed: Added a render-only animated loom/courier vignette, compact home choices, live bound-key guides, operational-menu owner badge and a regression scenario for layout/remapping. Kept the shared menu intent API and owner input rules.
- Why: The user requested a stronger home screen, clearer controls and continued verified integration. A native overlap and a long-detail overflow were found and fixed before delivery.
- Validation: Baseline import/20 scenarios PASS; final 21 scenarios PASS including three UI cases. Private native X11 helper PASS at 1×/2×; actual captures retained in evidence/content/ui/polish. Pack/link, design scan and whitespace PASS.
- Limitations: Captures use a UI fixture and original fixed art before the overhead asset replacement. No overhead gameplay, listening, controller hardware or human playtest claim; Agent 1 owns integrated runtime/main packaging.
### 2026-10-25T00:28:37+05:30 — Prepare the drawing-to-character and texture experiment

- Changed: Added a separate future-phase preparation brief, primary-source research note and read-only profile/theme boundary audit. Corrected the roadmap's implication that fixed catalogs already support generated bundles.
- Why: The user asked for further coordinated work and gradual preparation for player-drawing characters/textures. Agent 1 froze the Phase 1 release source at b96ad0e; this branch adds no runtime, backend, upload flow or generated assets.
- Validation: Both full validators and all 79 Python tests PASS on the baseline; documentation/link and whitespace checks PASS. Sandbox headless probes reproduced admission differences and a missing-font startup diagnostic defect; Agent 1 reported a focused guard/regression scenario and is verifying it separately. Official Pillow/Godot sources support the proposed intake/render guidance. Independent standards and scope reviews found no blocking documentation issue.
- Limitations: Sketch corpora, recognition scores, animated previews, generated characters/textures and human acceptance are proposed, not implemented or measured. Phase 1 physical-device/listening/fresh-pair gates remain separate.

### 2026-10-25T00:15:26+05:30 — Verify every UI capture and expected process lifetime

- Changed: QA now checks the exact nine fixture kinds, fresh expected paths/dimensions, distinct nonblank pixels, and live preview processes before intentional shutdown.
- Why: Peer review found that record counts could mask repeated/stale captures and cleanup could mask an unexpected preview exit.
- Validation: Full native helper and Python compilation PASS; regenerated screenshots are byte-identical. Pack/link and whitespace checks PASS.
- Limitations: This strengthens UI fixture evidence only; production code and full-game acceptance are unchanged.

### 2026-10-25T00:13:18+05:30 — Guard native UI evidence against blank captures

- Changed: Added explicit window/framebuffer pixel equality and rendered-colour assertions to the private UI QA helper; recorded the result in its evidence.
- Why: Equal before/after or 2x captures alone could also match blank windows. The inspected capture contains eight colours and matches the engine framebuffer exactly.
- Validation: Re-ran the complete native helper, pack/link and whitespace checks before commit.
- Limitations: UI fixture evidence remains separate from full application, physical devices and human acceptance. No production game code changed.

### 2026-10-25T00:06:44+05:30 — Complete UI layout and native-window verification

- Changed: Added the extended UI layout/mouse scenario, explicit preview scene and reproducible private-Xvfb QA helper with real captures. Improved value/binding font size, scrollbar visibility/inset, long-row navigation and two-line footer prompts. Recoverable validation now warns instead of raising engine errors, preserving compatibility with Agent 1's strict error logger.
- Why: Native review exposed invisible overflow and small critical values; the UI assignment also requires proof that global widget focus cannot bypass player ownership and that pixel scaling remains stable.
- Validation: Six engine scenarios PASS, including two UI scenarios with 24 behavior groups. Native X11/Godot captures cover eight assigned kinds plus controls; non-owner input left pixels/actions unchanged, owner keyboard/mouse payloads matched, cancel/title/quit exited 0, 2x scaling matched pixels exactly, and the long footer wrapped into two lines. Pack, compilation and diff whitespace PASS. Debug-title matching in the new harness was corrected before its successful run. Temporary GUI processes were stopped.
- Limitations: Native QA uses software llvmpipe and an isolated UI fixture with Dummy audio. It does not establish full application/campaign semantics, physical gamepads, keyboard rollover, performance or human playtests. Agent 1 owns integration and final release evidence; no application/session/storage files or global import sidecars changed.

### 2026-10-24T23:40:29+05:30 — Add the shared owner-controlled GameMenus component

- Changed: Added the typed CanvasLayer menu renderer and public intent API, original-font layout, scrolling rows/body, owner-specific navigation, disabled/adjustable actions, repeat timing, guarded mouse events and shared-boundary input flushing. Added a real-engine UI scenario and a separate UI integration/evidence record.
- Why: Agent 1 assigned this exclusive UI vertical to unblock title/join/pause/map/dialogue/settings/reconnect/ending wiring while other workers implement gameplay and persistence. The component emits intents and leaves application decisions with Agent 1.
- Validation: Baseline import, four existing engine scenarios and 15 Python tests PASS. New UI scenario first failed on missing implementation; final engine suite passes five scenarios including 13 UI behavior groups. Pack/link and diff checks PASS; independent source review found no blocker. Invalid-row fixtures intentionally emit error diagnostics. Direct standalone script checking lacked autoload globals; normal project scenario loading compiles/runs successfully.
- Limitations: Native rendered layout, extended scrolling/mouse checks and real window input are still pending this core checkpoint. No full application, controller, rollover or human-playtest acceptance is claimed. Global importer sidecars and central application integration remain with Agent 1.
### 2026-10-24T23:06:44+05:30 — Tighten asset acceptance and improve room approaches

- Changed: Reject invisible images/frames, changed canonical terrain silhouettes, duplicated decoded courier/background pixels and silent or near-silent PCM, with regression fixtures that update hashes correctly. Widened/inset east footholds in r02/r06, raised r03's optional hazard shelf for 80 px combat clearance, and restricted r06's catch shelf to westward recovery. Expanded labelled authoring previews and updated current content evidence.
- Why: Manifest counts and matching hashes previously accepted visually empty/cloned bundles. Layout review also exposed narrow boundary approaches, a 48 px combat ceiling and a lower-route ordinary-jump bypass.
- Validation: All 79 Python tests PASS, both full validators PASS, temporary diagnostic generation/validation PASS, pack/event/link checks and diff whitespace PASS. The transparent-background regression first reproduced the failure, then passed after the fix. Native authoring views inspected; generated asset recipes/outputs remain unchanged and earlier deterministic hashes still apply.
- Limitations: Geometry corrections use measured ordinary movement as a constraint; real both-character traversal, Threadstep reach, combat readability, listening and the remaining runtime/human MVP gates remain unverified. Source-art views exercise no physics.

### 2026-10-24T23:00:02+05:30 — Correct the project documentation for Devin Hack Kochi

- Changed: Aligned README, event guidance, agent instructions, submission checklist, AI record and PR checklist with the user-linked corrected template at `cb4db78169a8d199b43b077fbcc8f2ff4b798a14`. Removed inherited logistics, participation limits and credit promises; clarified provider-neutral event guidance and the project's own documentation conventions. Refreshed stale setup/status/prompt references against the separate content delivery and runtime checkpoint. Added a read-only event-consistency gate to `tools/check_pack.py`.
- Why: The organizer-shared template carried the wrong event identity and requirements. The user explicitly requested project-wide correction while preserving truthful project facts and actual tool attribution.
- Validation: Fetched the corrected template through GitHub at the pinned commit and independently reviewed its event text. The new gate first failed on the stale README, then passed after correction; pack checks PASS with 106 relative links, Python compilation and diff whitespace PASS. Runtime checkpoint `b1ff5d6` evidence was read, not rerun by Agent 2.
- Limitations: Current organizers still determine eligibility, logistics, deadline and credits. Historical log entries and Git history are preserved. These are documentation/consistency changes; no additional runtime, hardware or human acceptance is claimed.

### 2026-10-24T22:46:23+05:30 — Align the room handoff with measured movement

- Changed: Recorded the exact full-content packet SHA and Agent 1's committed jump/headroom measurements, command and test conditions in content evidence.
- Why: Replace reliance on source-only ballistic estimates with the available real-physics evidence while keeping diagnostic measurements distinct from full-route acceptance.
- Validation: Read runtime commit `b1ff5d6` and its traversal evidence; pack/link checks and diff whitespace PASS. No asset or room data changed; previous 69-test and deterministic asset results still apply.
- Limitations: Dash remains unmeasured at that runtime checkpoint. Both-character room traversal, animation/readability, audio listening and remaining integrated MVP gates are pending Agent 1 verification.

### 2026-10-24T22:43:33+05:30 — Author the eight-room cooperative story bundle

- Changed: Authored r00-r07 with canonical bidirectional rally exits, two checkpoints, Oru, both anchor pairs, enemy lessons, secret charm, Spoolwarden arena, dash branch, loom and return. Added shared data-only fixtures, 29 content tests, read-only content validation hardening, labelled authoring previews and exact traversal/presentation requests.
- Why: Complete Agent 2's Phase 1 content inventory and give Agent 1 explicit integration data without guessing entrance, progression or asset references. Revised ascent stairs against current motor constants, widened rally rectangles to include standing feet, and fixed malformed spawn/path handling plus bridge distribution enforcement.
- Validation: Both full validators PASS; all 69 Python tests PASS. Pack and diff whitespace PASS. Native r00/r02 authoring compositions and actor sheets inspected. Earlier seed-18427 twice-rebuild hashes remain valid because this drop does not change asset sources.
- Limitations: Physical traversal, dash tuning, real engine presentation/animation, audio listening, ordinary-input playthrough, gamepads, performance, export and human acceptance remain with integrated runtime verification. Room previews are explicitly labelled authoring-only and exercise no physics. Agent 1 owns true-merge integration and main publication.

### 2026-10-24T22:40:32+05:30 — Author the complete original art and audio inventory

- Changed: Completed the full generator with courier animation, Oru, two ordinary enemies, Spoolwarden, both terrain themes, layered backgrounds, props/states, effects and UI. Added editable original audio instruments/cues/scores and synthesis for 18 cues and three arrangements. Hardened asset validation and added reproducible rebuild evidence.
- Why: Give the runtime stable production assets and semantic sound mappings while room geometry and gameplay integration continue independently.
- Validation: Full generation produces 47 manifested assets; full asset validation PASS. Asset/audio/generator suites pass 40 tests. Two rebuilds at seed 18427 produced identical output and manifest hashes. Native authoring/contact-sheet inspection performed; inner-corner orientation corrected. PCM format, peaks, loop joins and a representative simultaneous-event mix checked structurally.
- Limitations: Final room delivery follows separately. Authoring previews do not establish Godot rendering/animation; audio has not been listened to, and runtime mix, traversal, gamepads, performance, exports and human review remain unverified. Diagnostic files are retained for early-runtime compatibility but excluded from the full manifest.

### 2026-10-24T22:29:31+05:30 — Deliver Drop A diagnostic content tracer

- Changed: Added original diagnostic courier/terrain/mover sources and generator, a retained 96-glyph font source and PNG/BMFont export, provenance manifest, real fixed profiles/themes/world/dialogue and the exact r00 tracer layout. Added read-only staged asset/content validators and Python boundary tests; recorded setup and limitations in `evidence/content/README.md`.
- Why: Unblock Agent 1's one-room co-op foundation while preserving stable IDs and strict producer/consumer contracts for final art.
- Validation: Diagnostic generation and both diagnostic validators PASS; 15 Python tests PASS; preflight, pack/link checks and diff whitespace PASS. The full asset validator deliberately fails on the incomplete diagnostic bundle. Native PNG inspection covered both courier silhouettes.
- Limitations: This is diagnostic content. Full assets/rooms/audio, engine import, animation playback, listening, traversal, controllers, performance and human playtests remain unverified or unfinished. Agent 1 owns integration and main publication.

<!-- Agent 2 inserts its newest timestamped entries here. -->

## Earlier development

## 2026-10-24T21:51:38+05:30 — Prepare the template-first GitHub publication

- Changed: Kept the original organizer template commit and corrected the two unpublished project commits to `Midhun P M <midhun.titan@gmail.com>`, preserving their file trees, messages, AI attribution and author dates; retained the original local history under `refs/backup/pre-publication-20261024`. Configured the authorized `https://github.com/9MidhunPM/GloamThread.git` origin. Corrected current-state text in the README, agent guide, first build prompt, setup/decision/implementation docs, status, handoff and submission sheet; marked the original environment table as historical context.
- Why: Publish the existing development sequence under the user's normal account identity, with the template first and an accurate description of the incomplete M0 checkpoint.
- Validation: `python3 tools/preflight.py` exit 0; `python3 tools/check_pack.py` PASS; `git fsck --full` and `git diff --check` passed on the reviewed history. Account profile matches the configured name/email. Targeted credential-pattern and filename scan covered all 3 original commits / 52 unique tracked blobs with no matches; it was not a gitleaks or entropy scan. Replacement commit trees, messages and author dates match their originals.
- Limitations: Publication verification follows the push. No game implementation changed; no Godot import, gameplay, rendered, audio, controller or human-playtest check was performed.

## 2026-10-24T21:42:00+05:30 — wip: M0 engine shell started; handoff written for the next agent

- Changed: Added `project.godot` (Compatibility renderer, 60 Hz physics, 960×360 composite, integer scaling, autoloads, named render/physics layers) and the first scripts: `scripts/input/{command_snapshot,device_source,bindings,input_router}.gd`, `scripts/audio/audio_director.gd`, `scripts/world/{room_definition,collision_builder,room}.gd`, `scripts/presentation/graybox_skin.gd`. Added `HANDOFF.md` (state, decisions, exact remaining M0 steps, milestone plan, subagent split) and `docs/PLAN_PHASE1.md` (full plan). Updated `docs/STATUS.md`.
- Why: The implementing agent's session budget ran low mid-M0; a precise handoff lets the next agent (Codex) continue without re-deriving decisions.
- Validation: `python3 tools/check_pack.py` → PASS. **No Godot command has been run against the new files**; they are unparsed and unverified. The main scene, player, cameras, split presentation, session, scenario runner, diagnostic assets and `content/rooms/r00.json` do not exist yet.
- Limitations: `run/main_scene` points at `res://scenes/app/boot.tscn`, which is not created; `godot --path .` will fail until M0 step 4–8 in `HANDOFF.md` are done.

## 2026-10-24T21:25:00+05:30 — Adopt the hackathon template workflow and add the Gloamthread planning pack

- Changed: Repository history now starts from the DevDay Kochi template commit. Added the Gloamthread design pack (`MVP.md`, `PRD.md`, `FIRST_AGENT_PROMPT.md`, `docs/`, `examples/`, `tools/preflight.py`, `tools/check_pack.py`). Merged the template `README.md` (project overview, run and status sections) with the game README; appended the template's repository workflow to the game-specific `AGENTS.md`; kept `RULES.md`, `SUBMISSION.md`, `AI_USAGE.md`, the pull request template and extended `.gitignore` for Godot. Removed the template `origin` remote so nothing can be pushed to the template repository by accident.
- Why: The user asked to build on the template's rules and documentation while keeping the game's own design contract; one repository must carry both.
- Validation: `python3 tools/preflight.py` → exit 0 (Python 3.14.8, Pillow 13.0.0, Git 2.56.0, Godot 4.7.2.stable.arch_linux). `python3 tools/check_pack.py` → PASS for required documents, relative links and example contracts. No Godot project exists yet, so no import, gameplay or rendering was tested.
- Limitations: Documentation and examples only. No `project.godot`, gameplay code, assets, tests or export. Gamepads were not connected on the development machine; the primary input plan is keyboard + keyboard.

## Template setup — 10 October 2026

- Changed: Added the event README, rules, agent guide, change log, AI usage record, submission checklist, Git ignore rules, and pull request checklist.
- Why: Give participants a consistent starting point for event rules, basic coding patterns, documented changes, and regular commits.
- Validation: Checked local Markdown links, event detail consistency, required documents, and diff whitespace before publishing.
- Limitations: Documentation scaffolding only; no participant project, application, or working demo is included. GitHub publication and template status are verified separately after creation.


## Overhead actor lane

<!-- overhead-actors -->

### 2026-10-25T02:08:28+05:30 — Actors against production overhead content

- Changed: Added real-profile/atlas actor checks in authored Atrium, Causeway and Gallery geometry, including both-direction shore crossings at three offsets, blocked-roll recovery and simultaneous combat against one actual enemy.
- Why: Verify the frozen actor seams against integrated room collision and original resources rather than relying only on diagnostic fixtures.
- Validation: Focused Godot 4.7.2 scenario passes with the full overhead content bundle. Both profiles cross both gap axes, recover into an immediate newly faced attack after wall contact, select the proper original idle bank and produce one Gallery enemy outcome. Exact-neutral assertion was corrected to allow the engine safe margin settling less than 0.1px away from water.
- Limitations: Controlled starts and progress setup; this does not claim a full campaign route, rendered quality or human combat feel. No runtime actor defect was reproduced.


### 2026-10-25T01:37:34+05:30 — Match traversal fixture to atomic boss rewards

- Changed: Threadstep fixture now grants boss_spoolwarden, threadstep and shortcut_bell together and asserts the reward commit succeeds.
- Why: The integrated progress boundary correctly rejects partial boss rewards; a movement test must use a valid team outcome.
- Validation: Focused Threadstep scenario passes in the isolated actor project using the current integrator TeamProgress source.
- Limitations: This remains a controlled unlock fixture, not evidence of defeating the boss through ordinary inputs.


### 2026-10-25T01:37:07+05:30 — Authored enemy direction warning consumer

- Changed: Enemy windups show effect_enemy_warning_v1 through its non-loop play clip, rotated in quarter turns around its declared pivot. The final frame holds through the warning; active/recovery/stagger/death clears it. A new windup starts a new clip serial.
- Why: Supply a readable authored direction hint while keeping damage geometry and simulation independent from the marker.
- Validation: Focused Godot 4.7.2 scenario passes against an explicit atlas fixture: cardinal rotation, pivot, frame progression/hold, pause, new-windup restart and immediate state/death cleanup.
- Limitations: The production authored warning packet is still pending integration/native review; this marker is not an exact damage-area outline.


### 2026-10-25T01:35:23+05:30 — Buffered directional animation regression

- Changed: Added a diagnostic atlas fixture and real player/SpriteAnimator scenario proving that a queued same-facing slash returns through idle and restarts its first windup frame; finished same-state non-loop clips remain held.
- Why: Test the suspected last-frame restart defect before changing animation guards. The defect did not reproduce, so production play API and guards remain unchanged.
- Validation: Focused Godot 4.7.2 animation scenario passes, checking actual AtlasTexture regions and physics attack serial timing. New fixture/scenario UIDs generated through isolated import.
- Limitations: In-memory colour labels prove sequencing only, not authored-art appearance or readability.


### 2026-10-25T01:31:49+05:30 — Immediate damage and revive presentation

- Changed: Accepted hurt/down/revive transitions now select their directional pose immediately; revive follows the authored sixteen-tick clip and reset/damage clear stale revival presentation.
- Why: Keep visual response aligned with the authoritative health transition and ground-plane knockback.
- Validation: New real-physics damage scenario passes: planar knockback, interrupted windup, exactly-once signals, bounded immunity, steady reduced-flash cue, pause, stationary downed state and two-heart revive timing. Own-clone import generated its UID; sandbox editor socket warnings remain environmental.
- Limitations: Null-catalog physics/presentation-state assertions; original frame rendering still requires integrated QA.


### 2026-10-25T01:30:41+05:30 — Preserve the bounded evasion window

- Changed: Enemy hit sets now record accepted damage, allowing a lingering attack to connect after an initially immune contact expires.
- Why: A six-tick roll evasion must not accidentally grant immunity for an entire longer boss attack. Accepted damage remains once per attack and player.
- Validation: Focused boss scenario passes with an immune first contact, later accepted contact and no duplicate damage after artificial immunity removal.
- Limitations: Controlled active-strike fixture; normal-input difficulty tuning remains pending.


### 2026-10-25T01:28:41+05:30 — Shared boss phase and concurrent feedback

- Changed: Half health advances Spoolwarden to phase two, with faster subsequent pursuit/charge and a shorter next idle gap; existing warning/recovery durations stay explicit. Partner-strike feedback takes the first line while slow resistance remains visible below it. Defeat clears stale notices.
- Why: Add encounter escalation and readable simultaneous feedback without cancelling a co-op stagger opening or changing an already-active charge speed.
- Validation: Focused boss scenario passes, including half-health transition during stagger, preserved opening timer, concurrent slow-resist notice and cleared defeat text.
- Limitations: Escalation values need the integrated normal-input route and human balance review; no rendered readability claim yet.


### 2026-10-25T01:27:48+05:30 — Overhead boss acceptance and stable script IDs

- Changed: Added a boss-specific scenario covering real sweep/strike/charge clocks, ground-plane reach, immutable walls, shared stagger/Cross-stitch state and exactly-once defeat; retained generated UID sidecars for new actor fixtures/scenarios.
- Why: Establish runtime evidence for the translated three-pattern encounter and stable imports before parallel integration.
- Validation: Actor clone Godot 4.7.2 run passes all 8 overhead actor scenarios. Boss ordinary-hit/bonus checks are explicitly controlled API fixtures; pattern geometry/timing use actual physics. Import parsed scripts but reported restricted editor socket/config-write warnings; its unrelated font-import rewrite was restored.
- Limitations: This is not a normal-input boss route, native art inspection or human balance review.


### 2026-10-25T01:25:13+05:30 — Planar enemy movement and room ownership

- Changed: Enemy bodies now use floating ground-plane footprints, XY target/attack vectors and two-axis bounds. Spoolmites telegraph locked charges; Wickwing hover is visual-only and its explicit water flight returns toward dry courier approaches. Added matching set_room_context seam. Boss movement/attack geometry is translated onto the same plane.
- Why: Remove platform gravity/ground checks and keep flying traversal separate from solid-wall collision.
- Validation: Focused real-physics enemy scenario passes: vertical charge, locked warning, recovery, pause, slow, Wickwing water/wall collision, dry close-range recovery and exactly-once defeat. Existing six actor scenarios remain green.
- Limitations: Boss-specific timing, geometry and Cross-stitch checks are the next slice; original enemy art/telegraph rendering is pending the content packet.


### 2026-10-25T01:22:30+05:30 — End roll at its declared travel distance

- Changed: Clear roll velocity on its last movement tick instead of letting ordinary motor deceleration add unrequested drift.
- Why: Keep the promised thirty-six-pixel roll distance true after the action ends, particularly beside water.
- Validation: Focused roll scenario passes, including three neutral ticks after roll completion with no extra travel.
- Limitations: Headless physics fixture; human controller feel review remains pending.


### 2026-10-25T01:21:52+05:30 — Explicit projectile water flight

- Changed: Couriers pass their known room water body to Spore Bolt; each projectile excepts only that body while retaining wall collision.
- Why: Allow Neri shots across water without global terrain-mask changes or shots through walls.
- Validation: The focused real-physics Spore scenario passes, including an owned emitted shot traversing a water span and retiring at the next wall without hitting an enemy beyond it.
- Limitations: Dedicated water/wall fixtures; full content integration remains pending.


### 2026-10-25T01:21:06+05:30 — Safe team Threadstep crossings

- Changed: Threadstep now travels sixty pixels over twelve ticks with a forty-five-tick cooldown; room callbacks validate dry departure, full-footprint landing and swept walls. Only the known water body is excepted for that courier.
- Why: Allow forgiving bounded water traversal while preserving walls, partner collision and safe interruption/recovery.
- Validation: Isolated Godot 4.7.2 actor scenarios pass 6/6, including two-tile crossing, unlock/cooldown, partial landing rejection, paused crossing, damage/geometry rollback and room-reset exception cleanup.
- Limitations: Dedicated callback/physics fixtures; complete authored-room integration remains with the world/session lanes.


### 2026-10-25T01:19:15+05:30 — Swept overhead Spore Bolt

- Changed: Spore Bolt follows a normalized two-axis direction, chooses earliest swept hurtbox contact before terrain, starts at the courier ground centre and expires after forty-eight physics ticks.
- Why: Prevent tree-order hits, vertical-shot errors, duplicate impacts and close-wall spawn bypasses while retaining Neri slow.
- Validation: Isolated Godot 4.7.2 actor scenarios pass 5/5: nearest ordering, vertical/diagonal hits, wall rejection, bounded lifetime and owned tick-eight/twenty-two-tick special emission.
- Limitations: Null-catalog fixtures; water-flight policy and original effect presentation await integration.


### 2026-10-25T01:17:53+05:30 — Ground-plane Ember Arc

- Changed: Ember Arc emits one 120-degree close fan on tick eight, with bounded reach, whole-hurtbox intersection, wall line-of-sight and a twenty-two-tick special sequence.
- Why: Give Tavi a distinct directional close-range stagger tool on the overhead plane.
- Validation: Isolated Godot 4.7.2 actor scenarios pass 4/4, including fan shoulders, excluded rear/flank/distant targets, emission/recovery ticks, damage/stagger values and wall rejection.
- Limitations: Null-catalog fixture; Spore Bolt remains the next projectile migration.


### 2026-10-25T01:17:03+05:30 — Directional slash and input buffer

- Changed: Slash now uses cardinal ground-plane reach, six windup/active/recovery ticks, a six-tick press buffer and unique per-swing hit sets; directed effects rotate instead of mirroring.
- Why: Preserve responsive combos and readable four-direction combat without diagonal or shared-player hit ambiguity.
- Validation: Isolated Godot 4.7.2 scenarios pass 3/3: four facing directions, exact timing, one hit per swing, no held-button repetition, buffer expiry, independent simultaneous swings and no friendly fire.
- Limitations: Stationary enemy fixtures; directional original-art review and planar special/enemy migration remain pending.


### 2026-10-25T01:15:39+05:30 — Bounded overhead roll

- Changed: The former jump bit starts a twelve-tick, 36px cardinal roll with six invulnerable ticks and a 36-tick cooldown; damage, restore and pause retain explicit interruption semantics.
- Why: Replace platform jumping with a readable, short defensive action that respects water and wall collision.
- Validation: Isolated Godot 4.7.2 actor scenarios pass 2/2, including exact displacement, direction lock, six-tick evasion, paused timers and real water/wall bodies.
- Limitations: Null-catalog fixture; the new roll cue is pending the parallel authored audio packet.


### 2026-10-25T01:12:16+05:30 — Overhead courier motor and room context

- Changed: Replaced gravity/platform movement with floating XY movement, 12x10 feet collision, cardinal facing and directional animation keys; introduced set_room_context(bounds, can_stand, can_threadstep, water_body).
- Why: Establish the actor-side ground-plane contract before world integration. Existing health/revive APIs and owned snapshots remain intact.
- Validation: Godot 4.7.2 isolated import and overhead_actor_motor scenario pass; actual bodies prove equal diagonal speed, analogue magnitude, wall/bounds collision, owner isolation, pause and stationary downing.
- Limitations: Null-catalog physics fixture only; roll, new attack timing, water dash and planar enemies remain subsequent actor slices. No overhead art/rendered/full-route claim.




## Overhead world lane

<!-- overhead-world -->

### 2026-10-25 02:08:22 +0530 — Budget the campaign for real-time execution

- Declared a 300-second scenario timeout for the ordinary-input campaign, whose verified route takes about 99 seconds at actual 60 Hz. This uses the input worker's coordinated runner API; explicit CLI timeout remains authoritative. Only the budget changes, not route commands, success criteria or test discovery. Whitespace check passes; native timing remains the integrator's pending gate.


### 2026-10-25 02:07:36 +0530 — Full overhead campaign passes through ordinary owned input

- Integrated overhead core 5162c34 and completed the campaign acceptance driver against the actual App/catalog/media. Corrected the test's unit-vector dash mask and waited for captured audio playbacks to retire before exit; no production movement/combat tuning was needed.
- Validation: `XDG_DATA_HOME=/tmp/gloamthread-world-route-data godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd -- --filter overhead_campaign_route` PASS. Fresh New/Join, completed Oru dialogue, eight rooms, four Gallery enemies, Spoolwarden, secret, both paired repairs, both twelve-tick water dashes, Loom, actual ending card and real save all pass in 5,941 physics ticks (99.02 simulated seconds). Final hearts [5,3], zero checkpoint recovery; no actor warps, forced flags, private room loads or direct damage.
- Combined overhead gate PASS 25/25 with isolated writable XDG_DATA_HOME; public content validation PASS. An initial combined run without writable user-data isolation failed four file-writing fixtures due sandbox permissions. Focused route exit is clean after explicit asynchronous audio retirement; earlier accelerated standalone runs had intermittent shutdown resource warnings.
- Limits: headless scripted owned input at fixed 60 FPS, not native rendering, physical controllers, listening or human play. Root retains native/export validation and separate user-data identity changes.


### 2026-10-25 01:50:17 +0530 — Pending ordinary-input overhead campaign gate

- Added a bounded fresh-App campaign driver through all eight rooms, secret, paired repairs, both two-tile Threadstep crossings, ordinary combat, ending and real save boundary. It emits owned inputs in _physics_process before input polling; test-only floor-path searches choose commands without changing actors, rooms, damage or progression.
- Validation: scenario loads/compiles through the real runner with no script errors. Its current run FAILS at App startup because this branch still has the previous catalog/art versions; traversal/combat/ending assertions therefore remain unexecuted. The driver is an explicit work-in-progress acceptance gate, not a successful playthrough record.
- Next dependency: merge the integrator's overhead consumer metadata and original directional media, then run/debug `--filter overhead_campaign_route`. No final art, campaign or demo-completion claim.


### 2026-10-25 01:42:11 +0530 — Guide each courier to their remaining paired end

- Filtered transient anchor/Loom targets per living slot while retaining the pure QuestDirector/map result. A courier who has claimed an end receives no second assignment; their partner is guided only to the unclaimed end. Nearby ownership hints distinguish your held end from your partner's.
- Validation: overhead_session PASS 3/3. New guidance scenario uses real authored coordinates and world metadata to verify both anchor/station assignments, compass direction, immediate onward guidance after repair and passive downed rescue status. The preceding combined actor/input/world/session suite passed 21/21 after the actor fixture correction.
- Limits: metadata-only controlled placements; final catalog/art and ordinary-input campaign are still independent gates.


### 2026-10-25 01:39:12 +0530 — Clear water ownership before recovery replacement

- Fixed a stale physics RID when recovery replaced a room during Threadstep: couriers now cancel their water exceptions while the previous water body still exists, before that room is freed. Null-catalog fixtures also avoid requesting unavailable background music.
- Validation: both overhead_session scenarios PASS. New controlled regression proves ninety-tick revive completion wins at the 720-tick timeout boundary, rescuer damage interrupts the hold, timeout/wipe recover once, boss/unlock/shortcut commit before a same-tick wipe, cleared boss stays absent, and mid-water recovery clears its exception and restores a complete dry footprint.
- Limits: explicitly controlled coordinator fixtures and synthetic owned movement; no claim of complete normal-input campaign or final rendered assets.


### 2026-10-25 01:36:43 +0530 — Overhead session and per-courier guidance

- Integrated actor/input branch ancestry, wired every courier/enemy to the room's planar collision queries and separate water body, and placed props with actors under shared feet sorting. Hazards use the real planar hurt rectangle and knockback; the camera follows the ground-plane centre.
- Added explicit dialogue completion that commits met_oru once, QuestDirector objective/local-target consumers, separate living/proximity hints, bound Roll and locked-Dash HUD, boss phase/feedback and downed rescue guidance. Existing coordinator/save/revival transaction entry points remain intact.
- Validation: new overhead_session_foundation scenario PASS, covering dialogue, paired same-tick repair, actor/enemy context, actual owned-input 60px Atrium dash, hazards, pause and local HUD ownership. Combined overhead suite: 17/18 PASS; the remaining actor Threadstep fixture commits an incomplete reward group rejected by the newer save contract (reported to its owner). Editor import has no script errors; sandbox socket-listen errors remain.
- Limits: fixture placements and null art are explicit; final catalog/art integration, normal-input campaign and native presentation remain pending.


### 2026-10-25 01:28:24 +0530 — Overhead content admission and route guards

- Migrated the public content validator to overhead-v1, the planar collider and exact opaque terrain slots. It now rejects unsafe floor entrances, missing cross-room references, disconnected rallies/interactions, bypassable paired repairs and removed Threadstep lessons. Both bridges require dry banks separated by at least four water tiles in Python and the runtime parser.
- Kept opaque terrain below feet-sorted props/actors independently of sibling order and retained generated scenario UIDs. Removed obsolete diagnostic-mover parsing.
- Validation: `python3 -m unittest discover -s tools/tests -p test_content.py` PASS 29 tests using temporary overhead catalog metadata; `godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd -- --filter overhead_world` PASS 2/2; `git diff --check` PASS. Editor import produced no script errors, but sandbox TCP-listen errors remain separate from the clean runtime run.
- Limits: the branch's full `python3 tools/validate_content.py` correctly fails on eight outstanding manifest/profile/theme/dialogue version or mapping mismatches owned by other lanes. No integrated campaign, native art or controller-quality claim.


### 2026-10-25 01:21:27 +0530 — Authored overhead district route

- Reauthored r01-r07 as planar rooms: the remembered Atrium branch, separate Spindle anchor approaches, Gallery encounter/secret alcove, checkpoint respite, roomy Bell arena, vertical Causeway dash lesson and opposing Loom stations. Added dry bank markers, recognizable original props, two-tile mandatory water crossings and four-tile paired repair barriers.
- Validation: overhead_world scenarios PASS 2/2. All eight strict room definitions/paired entrances and eighteen directed exits resolve; safe route searches reach both anchors/secret/Loom stations and cannot bypass unrepaired spans. Six actual CharacterBody2D probes cross the required water gaps at three launch offsets per axis using exactly 60px motion.
- Limits: structural reachability plus isolated collision probes; integrated ordinary-input overhead campaign, final directional art and native quality review remain pending.


### 2026-10-25 01:14:36 +0530 — Overhead world foundation

- Added strict overhead-v1 room parsing, planar feet/footprint queries, separate immutable wall and water bodies, named bridge blocker removal, shared sortable prop/NPC branch and opaque terrain slot selection. Reauthored Lantern Rest as a safe overhead plaza and gated the Atrium introduction with met_oru.
- Why: establish the real one-room ground-plane contract before expanding the eight-room route.
- Validation: Godot 4.7.2 focused overhead_world_foundation scenario PASS 1/1; actual bodies stop at water, cross a restored bridge, bypass only water during the optional three-tile boundary probe, and remain blocked by walls. Strict spawn/version, diagonal swept footprint, persistent bridge replay and both collision-free skins pass.
- Limits: null-catalog geometry/prototype rendering only; directional original art and integrated overhead actors/session remain separate lanes. r01-r07 and whole-bundle Python validation are still being migrated. Editor import completed without script errors but reported sandbox TCP/editor-preference write restrictions; focused runtime exited cleanly.




## Overhead input and persistence lane

<!-- overhead-input -->

### 2026-10-25T01:24:34+05:30 — Derive overhead objectives and local route targets

- Changed: Added pure QuestDirector queries for Oru, Spindle, Spoolwarden, Causeway, Loom and home objectives. Breadth-first routing uses only unlocked declared world connections, including the post-boss shortcut. Local targets expose authored NPC/boss/anchor/station identities and safe exit feet positions; unreachable routes are explicit and yield no invented targets.
- Why: The integrator needs one reliable guidance boundary for HUD/map/proximity hints without making presentation own progression.
- Validation: Godot4.7.2 overhead_quest_guidance PASS1/1 using pure fixtures: six stages, backtracking, locked/unlocked shortcuts, unreachable/malformed gates, local targets, canonical feet and no world/progress mutation. Import and whitespace checks pass.
- Limitations: Root wiring, rendered guidance and ordinary overhead traversal are not acceptance evidence from these fixtures.


### 2026-10-25T01:18:32+05:30 — Preserve foreign backup data before rotation

- Changed: Normal save rotation now retains rejected copies of unsupported/newer or damaged existing backup files before installing a validated previous save. Failed preservation keeps the prior active save intact and returns a visible error. Primary replacement uses the same small preservation helper.
- Why: A valid active campaign must not silently erase unknown backup data during its next autosave.
- Validation: Godot4.7.2 overhead save scenarios PASS2/2, including actual newer/damaged backup-byte retention and all existing recovery/fault checks; whitespace check passes.
- Limitations: No physical power-loss testing is claimed.


### 2026-10-25T01:16:49+05:30 — Require a live gamepad index for input ownership

- Changed: InputRouter rejects negative gamepad indices during assignment/reconnect and keeps invalid indices neutral during polling. Added synthetic reconnect/reassignment checks proving held Roll suppression until release and independent partner ownership.
- Why: A disconnected index must remain a recovery state, never an admitted input source.
- Validation: Godot4.7.2 overhead input scenarios PASS3/3, covering Roll migration, planar normalization and device lifecycle; editor import and whitespace checks pass.
- Limitations: Synthetic notifications/events do not certify physical controller hotplug or menu recovery visuals.


### 2026-10-25T01:15:46+05:30 — Protect live overhead reward transactions

- Changed: TeamProgress validates dependency consistency before changing live flags, sharing the same rule with save admission. Incomplete boss/traversal outcomes leave progress untouched. Added actual-file overhead recovery, fault-boundary and settings-separation regressions.
- Why: A boss-only live reward could otherwise remove its encounter before granting required team traversal, even though a later save would reject that state.
- Validation: Godot4.7.2 overhead save scenarios PASS2/2: all four save/recovery failure stages preserve active/backup bytes, orphan backup recovery works, side-view backups are refused, rejected originals are retained, and settings/legacy Roll/device identity remain separate. Negative transaction warnings are expected; import and whitespace checks pass.
- Limitations: Fault injection verifies local file boundaries, not hardware power-loss behavior.


### 2026-10-25T01:13:15+05:30 — Normalize owned ground-plane commands

- Changed: CommandSnapshot now sanitizes and caps the full two-axis vector while retaining gentle analogue magnitude. Added synthetic keyboard/gamepad checks for diagonal limits, independent devices, simultaneous actions, two-axis release latching and disconnect neutrality.
- Why: Overhead diagonal movement must not gain speed or lose analogue control.
- Validation: Godot4.7.2 input scenarios PASS3/3 (existing routing plus two overhead scenarios); non-finite/oversized axis checks and fresh editor import pass. Expected malformed-binding/duplicate-assignment warnings are retained in the legacy negative scenario.
- Limitations: No actor-motion or physical-controller acceptance is claimed.


### 2026-10-25T01:11:22+05:30 — Separate overhead campaign saves

- Changed: Added public TeamProgress.SAVE_SCHEMA_VERSION=2, content version overhead-v1 and the shared met_oru introduction flag. Campaign reads distinguish schema2 from unsupported newer formats and visibly reject/preserve side-view data; backup notices retain the primary failure explanation.
- Why: Overhead progress must never silently adopt the preserved side-view campaign format. The separate application data directory remains an integrator setting.
- Validation: Godot4.7.2 overhead_save_version PASS1/1 with actual temporary files, swapped profile/checkpoint/met_oru round trip, partial boss reward rejection, schema1/newer protection and explicit replacement retaining rejected bytes; editor import and whitespace checks pass.
- Limitations: This lane does not change project settings or certify full overhead gameplay.


### 2026-10-25T01:10:20+05:30 — Migrate the overhead Roll action

- Changed: Introduced canonical Roll at bit16, retained the transitional Jump alias, migrated legacy saved jump controls, and made canonical roll mappings win independent of JSON key order. Default keyboard/gamepad controls are preserved and the action appears once in polling/settings.
- Why: The overhead contract replaces jumping with a roll without losing remapped controls or duplicating menu actions.
- Validation: Clean Godot4.7.2 editor import in the isolated lane; focused `overhead_input_roll` scenario PASS1/1 in the relocated worktree; actual legacy settings serialization, owned action edges and release latching checked.
- Limitations: This checks input/settings semantics, not overhead actor motion, physical controllers or rendered menus.
