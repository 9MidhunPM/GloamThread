# Watch the entire Story campaign

Run the sequential Tavi/Neri showcase from the source checkout with Godot 4.7.2 standard:

```sh
./story_showcase.sh
./story_showcase.sh --speed 2
```

The route starts a new temporary campaign and covers all eight rooms: shared-world split views, dialogue, checkpoints, co-op anchors, the Spoolwarden, the unlocked dash, the secret route and the ending. Temporary campaign saves protect your personal Story progress. No API key, model request or installation is part of the launcher.

| Key | Action |
| --- | --- |
| Space | Pause/resume |
| 1 / 2 / 4 | Change simulation speed |
| Escape | Quit |

The full campaign plays sequentially. N has no chapter-skip action.

For the headless route check:

```sh
./story_showcase.sh --smoke
```

Smoke mode uses fixed 60 Hz and returns the runtime outcome. The JSON report defaults to `/tmp/gloamthread-story-showcase.json`; choose another path with `--report PATH`.

This is an automated, sequential playthrough using owned keyboard commands and real menu actions. It does not teleport actors, jump rooms, grant progression, refill health or disable enemy damage. Bots clear surviving Gallery enemies before the normal-input secret detour; both characters must rally at each exit. Every active dialogue line advances through the actual Next action, with reading time in visible mode. Pause/focus recovery releases held bot commands before resuming.

The complete headless route passes all eight rooms, both bridges, the secret, boss, dash and return-home ending, with a valid temporary save and zero recoveries. [Verification details](../evidence/story-showcase/README.md) distinguish native viewing/control checks from headless route evidence. Physical devices, human enjoyment and listening have not been verified.

Use `--help` for options. `GODOT_BIN=/path/to/godot` selects another executable. Calling the launcher by its path works from another directory; native mode selects Wayland when `WAYLAND_DISPLAY` is set. Source setup is covered in [the launch guide](ARENA_DEMO.md); the separate wave-fighter tour is described in [SHOWCASE.md](SHOWCASE.md).
