> Historical experiment: the user restored the side-view game on 25 October 2026. This document no longer governs active implementation.

# Overhead adventure implementation and polish plan

User goal: an original overhead adventure, continued coordination with Agent2, better UI/screens/music/combat/experience and clear direction, atomic commits and regular tested main merges. Broad Minish Cap qualities inform perspective and exploration; all content remains original. The side-view milestone is preserved asv0.1.0-demo, not relabeled as overhead evidence.

Read [OVERHEAD_CONTRACT](OVERHEAD_CONTRACT.md) first. Keep the fixed local two-player premise and eight-room story while replacing platform traversal. The user-authorized view change supersedes older side-view MVP/motor/terrain requirements. Drawing preparation remains future, separately versioned work.

## Playable checkpoints

1. **OH0 — One overhead room.** Safe XY movement, facing, roll, walls/water, camera/HUD/feet sorting, original directional art, explicit join and actual controls. Native both-player input and a first readable room before expanding content.
2. **OH1 — A good teaching encounter.** Four-way slash/fan/projectile, buffered attacks, fair enemy tells, planar damage/revival, grounded hit feedback and shared audio. Prove both player roles and pause/room/recovery invariants.
3. **OH2 — Cooperative traversal and direction.** Named water blockers/bridge restore, gated Threadstep, nearby-player prompts, objective/destination guidance, map/landmarks, checkpoints and one coherent route.
4. **OH3 — Full overhead story.** Eight original layouts/encounters, optional secret, stronger three-pattern boss with clear phase/stagger display, original active boss music, shortcut and restoration/ending. An ordinary-input complete route must work, with no forced state.
5. **OH4 — Screens, comfort and release.** Branded home, useful join/settings/pause/map/dialogue/ending, current binding summaries, saved profiles/backup handling, clear save/device failures and accessible effects. Export/run offline/native QA, stage accurate releases and preserve evidence.
6. **OH5 — Experience polish.** Iterate meaningful encounter, route, visual/audio and usability improvements with actual captures/tests/playtests when available. Track real regressions/feedback; do not inflate world size or build a speculative backend to fill the commit target.

Merge main after a complete playable checkpoint or a safely reviewed independent asset/UI/tool milestone. Incomplete simulation branches stay isolated. Every claim names its source/artifact and evidence level.

## Atomic work lanes

Actor slices: ground-plane motor/bounds; cardinal facing; directional animation; roll; damage/knockback; down/revive; attack queue; slash geometry/dedup; Ember fan; swept Spore Bolt; dry dash; validated water corridor; interruption landing; player feedback; planar Spoolmite patrol/tell/charge/recovery; Wickwing hover/dive/recovery; boss pursuit/sweep/strike/charge/stagger/phase/Cross-stitch; role-symmetric encounter tuning and ordinary-control regressions.

World slices: strict overhead parser; safe paired spawns; separate wall/water geometry; dynamic named blocker removal; opaque material tile selection; actor/prop interleaving; landmarked r00 tutorial; Atrium remembered gate; Spindle distinct-anchor paths; Gallery teaching encounter/secret; Landing respite; Bell arena; Causeway dash lesson/repair; Loom cooperation/restoration/return; graph/rally/gate/recovery checks and full route.

UX/persistence slices: Roll/legacy binding migration; normalized ownership; contextual prompts; locked/unlocked action guides; settings/deadzone/conflict messages; reconnect ownership; versioned overhead progress; backup/recovery/fault paths; objective stages; current/destination map; dialogue/tutorial pacing; boss phase/stagger display; save/quit safety; pause/recovery/ending/replay clarity.

Art/audio/UI slices: directional pose families per character; radial enemy/boss tell families; each material/edge family; scenery/landmarks/props; readable effects; interface glyphs/contrasts; original exploration/boss/final/ending arrangements and instruments/cues; home vignette, menu hierarchy, wrapping/navigation/current binding guides; native1x/2x quality review. Agent2 defines coherent art/audio checkpoints and their retained provenance.

## Commit target

The user's target is **more than200commits by the end of the effort**. Count real commits reachable from main and report progress honestly. Preserve the organizer root and all real development history. A commit is ready when a coherent behavior/content/tool improvement has appropriate verification and matching CHANGELOG/AI_USAGE. Small independent features may each earn a commit; do not create empty commits, cosmetic churn, artificial test/implementation splits, backdates, forced history or test-count padding. Periodically integrate rather than accumulating a huge final merge.

The current snapshot has a playable side-view baseline; overhead implementation is newly starting. A commit count does not replace a good game or acceptance evidence.

## Verification

Use focused tests during a lane, then integrated checks at each playable merge. Actual physics, per-device snapshots, strict data/asset tests, complete ordinary-control route, original animation/effect/music review, native1x/2x views, offline official release and measured busy-room timing remain separate. Side-view tests are historical; replace their platform assumptions and explicitly label fixture/debug-assisted checks. Do not count old scenario totals as overhead progress. Fresh-pair/hardware/listening gates remain unverified until actually observed.
