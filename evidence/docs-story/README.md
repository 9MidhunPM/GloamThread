# Illustrated player guide and restored Story Mode

The [player guide](../../docs/PLAYER_GUIDE.md) covers reliable launch, mode selection, both control schemes, wave combat and shops, the original eight-room story, save recovery and optional character authoring. It is written for players rather than as an implementation plan. Event identity remains **Devin Hack Kochi**.

## Capture method

New menu, creator and local crop-editor illustrations are real Godot 4.7.2 Compatibility/OpenGL viewport PNGs. `tools/capture_player_guide.gd` opens the production application, selects menus and renders retained public Kiln Fox boards in the production crop editor. The story sequence selects the actual Story Mode button, opens New journey and Begin journey, captures Lantern Rest, then uses the production save-and-return flow. UI method calls select these states; this is a documentation capture session, not a normal-input playthrough or a human playtest.

The capture process used a separate checkout without a private `.env`, an empty `OPENAI_API_KEY` and a throwaway `XDG_DATA_HOME`. It did not read or overwrite the player's campaign, accepted fighters, jobs, request ledger or private environment file. No model requests were made. Layout-editor figures use the project's retained original generated artwork; no screenshot is generated or painted.

Source-only reproduction from the repository, in an available native display session:

```sh
OPENAI_API_KEY= XDG_DATA_HOME=/tmp/gloamthread-guide-userdata \
  godot --path . --display-driver wayland --windowed --resolution 1920x1080 \
  --script tools/capture_player_guide.gd -- --output /tmp/gloamthread-guide-captures
```

Use `--display-driver x11` on X11. Native captures were taken on a Hypruse background workspace with explicit `RenderingServer.force_draw`, so they establish rendered viewport content rather than physical display scanout or performance. The command is a development aid, not a requirement for playing or a packaged-game entry point.

## Reused illustrations

The scrolling split-screen and independent-shop images are copied byte-for-byte from the already retained [scrolling-world native captures](../scrolling-world/README.md). These are controlled scene placements to make the camera/shop behavior legible; they do not prove a new ordinary-input run. The anchor-bridge image is copied from the [original campaign's exported route](../release/README.md). It illustrates the retained campaign mechanic, not a newly completed story route.

`captures.json` records image dimensions, SHA256, original paths, source revision and capture limitations. Screenshots are inspected directly before publication. Existing full-game evidence remains in its original directories; this docs task does not relabel those results as new tests. Broad tests are skipped at the user's request. No new hardware, audio-listening, balance or human-completion claim is made.
