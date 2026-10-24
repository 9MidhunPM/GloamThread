# Implementation status

Updated 2026-10-24T22:40:57+05:30. Keep planned work distinct from verified behaviour.

## Parallel execution

- Preparation commit `2fea1ef` is published on `main`. Agent 1 uses `feat/phase1-runtime` in `/home/midhun/Coading/Gloamthread`; Agent 2 is active on `feat/phase1-content` in its separate `/home/midhun/Coading/GloamThread-content` clone.
- The [runtime brief](AGENT_1_RUNTIME.md) and [content brief](AGENT_2_CONTENT.md) define exclusive ownership and the shared data boundary. Cumulative content packet `34e14c9` is the first diagnostic integration; each agent's log sections are preserved.
- Agent 2 subsequently published full content tip `e56d714` (verified remote on 2026-10-24T22:50:16+05:30). Its later production assets/eight-room data are queued, not yet consumed or independently accepted by this runtime checkpoint. Integrate them through a true merge after the entity/animation/theme/audio/gameplay consumers are ready; do not describe the bundle count as a completed game.

## Implemented and verified

- Boot/session, one authoritative room/world, two 480×360 viewports/cameras/HUDs, two owned-input player bodies, canonical collision, diagnostic mover and shared focus/pause handling exist. Fresh headless import succeeds, and normal boot with the diagnostic packet exits cleanly in a bounded headless smoke run.
- Engine scenarios cover input/binding/reconnect safety, room/spawn validation, a shared-session physics fixture and the actual authored diagnostic r00/assets. They verify stable grounded feet, separate movement/jump, nonblocking partners, one world/room/mover, masks and shared pause/resume. Synthetic inputs do not certify physical devices.
- Agent 2's diagnostic asset/content validators and 15 Python tests pass. The packet supplies original source, diagnostic sprites/terrain, a printable-ASCII bitmap font, manifests and r00. Full validators intentionally require later content.
- An actual X11/Compatibility window capture shows both original diagnostic couriers, the two terrain tints and the equal divider/letterboxing. The window was on a hidden agent workspace: this is an initial rendered snapshot, not continuous animation or ordinary-input acceptance. Background XWayland input was refused safely; native-Wayland key delivery was accepted but its hidden-window capture was black, so no successful visible input check is claimed.
- [Movement measurements](../evidence/runtime/traversal.md): 41.74 px full feet rise, 55.00 px running same-height feet travel, 30 airborne physics ticks, 12×24 collider and 66 px measured full-jump body clearance. Dash is not yet implemented or measured.

## Implemented, not fully verified

- M0's runtime and first diagnostic packet are integrated for engine/structural checks. Visible simultaneous controls, moving-object playback in both views, native-resolution motion/pixel stability and physical keyboard rollover remain outstanding before the full M0 gate is claimed.
- The manifest loader currently validates image IDs/kinds/paths/dimensions/frames needed by the tracer. Complete production manifest/profile/entity/decor/audio consumption and equivalent Python/GDScript contract coverage remain M1/integration work.
- Coyote time, jump buffer, variable height and camera following exist. Isolated motor/camera checks passed, but integrated boundary scenarios and manual feel still need expansion. One-way landing exists; explicit drop-through is not implemented.

## Planned; not implemented

- Join/reassignment/remapping UI; combat, enemies, down/revive/recovery; paired anchors, rally exits and checkpoint progression; finished theme/animation/audio integration; eight-room boss/dash/loom route, secret and ending; persistence/settings; export and final evidence.
- All human fun/full-route playtests, actual gamepad hotplug, audio listening and named-machine performance acceptance.

## Blocked or unavailable checks

- No physical gamepads are connected. Keyboard/keyboard remains the primary mode to verify; gamepad paths remain hardware-unverified.
- Matching export templates are not installed; the existing approval boundary for their large download applies at M7.
- Two-human fresh playtests require actual participants. Hidden-window capture/input limitations do not count as a visible interaction pass; source and headless checks are reported separately.

Exact commands and historical checkpoint results are in [runtime evidence](../evidence/runtime/commands.md). The earlier single-player HTML proof is separate evidence and passes no co-op gate.
