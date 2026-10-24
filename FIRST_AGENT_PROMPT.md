# First Devin / Codex prompt

This is the original build request. Before resuming, read [STATUS.md](docs/STATUS.md) and the current two-agent briefs: runtime and content delivery have advanced beyond this prompt's initial-state description. Follow current [Devin Hack Kochi guidance](RULES.md) for the event.

Copy the block below into an agent working in the extracted project folder. It is the build request, not a claim that the Godot game already exists.

```text
Build Phase 1 of GLOAMTHREAD: TWO ENDS in this repository. This is a real playable implementation task, not another planning task.

Read AGENTS.md, README.md, MVP.md and docs/DECISIONS.md first. Then inspect docs/ARCHITECTURE.md, docs/IMPLEMENTATION_PLAN.md, docs/TASKS.md, docs/ART_AUDIO_PIPELINE.md, docs/STORY_BIBLE.md and docs/TEST_PLAN.md as needed. Follow the current fixed-character scope; the later generation roadmap is context only.

Target Godot 4.7.2 standard with typed GDScript, Compatibility renderer, Linux desktop, fixed 60 Hz physics. Use Python for original asset and content tooling. Run tools/preflight.py and record the environment. A partial M0 project and input/audio/room scaffolding exist; read HANDOFF.md and docs/STATUS.md, then finish and verify the one-room foundation. Do not switch engines to avoid a missing dependency. If Godot is unavailable, report the exact missing tool, continue authoring inspectable code and original assets, and keep all import/gameplay claims unverified until the engine actually runs.

Deliver a complete eight-room, 15–20 minute target co-op adventure with fixed characters Tavi and Neri, fixed vertical split screen, two 480×360 views inside a 960×360 logical composite, two original theme presets, independent assigned inputs, one shared physical world, readable combat, partner revival, two paired-anchor bridge interactions, a Spoolwarden miniboss, a team dash unlock, a return shortcut, checkpoint/save/continue, settings, map and a story ending. Use the exact scope and route in MVP.md.

Begin with the smallest real tracer: one room, two controllable characters, two cameras, one shared collision layout and original generated placeholder sprites. Demonstrate simultaneous independent input, both players seeing the same moving enemy/object, a shared pause, and correct pixel scaling. Then implement the milestones in dependency order and continue through Phase 1. Do not spend the entire run generating documents or a giant empty map.

All shipped game content must be original and authored in this repository: pixel sprites, animations, tiles, backgrounds, props, effects, interface glyphs, dialogue, sound and music. Do not buy/download resource packs, stock fonts, ripped sprites, music loops, map packs or game-content templates. Engine and tool dependencies are allowed. Create deterministic code-native art and synthesized audio sources with a provenance manifest. If original image-generation tools are available, you may use them for source art only after checking dimensions, frame alignment, palette, transparency and coherence. Never substitute downloaded assets. Avoid copied characters or signature art from reference games.

Implement one simulation. Theme-specific drawing layers contain no gameplay bodies or triggers. Both SubViewports share the same World2D. Assign inputs to player/device slots explicitly; test keyboard plus controller and two controllers where hardware exists. Use one global pause/menu state and one audio mix. Do not add networking, dynamic camera merging, independently loaded rooms, a drawing/upload screen, an AI backend, skill trees or arbitrary rope physics in this phase.

Keep profile/theme/asset definitions data-driven so later generated bundles can use the same validated interface, but only implement the fixed bundles now. Shared required traversal unlocks remain independent of character profiles. Generated images will never determine collision or executable ability code.

Use the provided examples as contract illustrations, not as already functional scenes or an asset pack. Build the actual content and validators; update the examples/docs deliberately if a practical contract revision is necessary.

Add the planned generate_assets.py, validate_assets.py, validate_content.py and tests/run_tests.gd interfaces as they become necessary. Verify an actual headless Godot import and high-level scenario tests. Inspect the rendered game, play through the complete route using ordinary controls, test save/reload and the important failure paths, and measure performance on a named environment. Use test hooks only for isolated checks. Do not claim a two-human test, gamepad test, audio check or performance result unless it happened.

Keep docs/STATUS.md updated at integration points. When parallelizing, agree on interfaces first and give workers exclusive files; integrate early. Make routine implementation and tuning decisions without asking for confirmation. Preserve unrelated user changes. If a capability is unavailable, describe the limitation honestly and continue useful work that does not depend on it.

The task is complete when the Phase 1 acceptance gate passes, a Linux release export and reproducible sources are packaged where the environment permits, and launch/test instructions are accurate. Export templates must match the engine. If export hardware/tooling or human playtesting is unavailable, distinguish completed work from those remaining checks. Stop at Phase 1: do not begin runtime generation or populate the 96-room production world.

Finish with a concise report: playable features, exact launch command, verification actually performed, remaining limitations, and artifact paths. Do not promise fun or a hackathon win; provide a real playable slice and evidence.
```
