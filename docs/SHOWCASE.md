# Watch the game play

From the source checkout, with Godot 4.7.2 standard available:

```sh
./showcase.sh
./showcase.sh --speed 2
```

The fullscreen tour shows wave 1, boss waves 5/10/15/20/25, then a staged 64-foe crowd budget with the normal 32-enemy live cap. The headless smoke run reached that cap and exercised all six enemy roles. Chapters use a fixed seed, explicit wave jumps and preset legal upgrades so you can watch the mechanics quickly. These are staged gameplay demonstrations, not proof of completing a normal run or of human balance/enjoyment.

| Key | Action |
| --- | --- |
| Space | Pause/resume, including returning from focus-loss pause |
| 1 / 2 / 4 | Change simulation speed |
| N | Next highlight chapter; disabled in full mode |
| Escape | Quit |

For the full ordinary-input 25-wave route:

```sh
./showcase.sh --full --speed 2
```

Full mode uses the existing automated gameplay driver and normal progression instead of jumping to boss chapters or applying highlight presets. It is automated input, not a human playtest. Chapter skipping is disabled in this mode.

## Record a video

Add `--record FILE` to save what the showcase shows as a 1920×1080, 30 FPS video with sound, using Godot's Movie Maker:

```sh
./showcase.sh --record arena-highlights.ogv
./showcase.sh --full --speed 4 --record arena-full25.ogv
```

Movie Maker renders every frame at a fixed rate, so the video is smooth even if your computer cannot keep up in real time; recording simply takes longer. `.ogv` (Theora/Vorbis) is compact; `.avi` (MJPEG/PCM) is larger. Convert for sharing with, for example, `ffmpeg -i arena-highlights.ogv -c:v libx264 -crf 24 -pix_fmt yuv420p -c:a aac -movflags +faststart arena-highlights.mp4`. Recording needs a display, so it cannot be combined with `--smoke`. The published videos and their exact commands are listed in [Videos](VIDEOS.md).

For a fast headless check of the highlight chapters and crowd finale:

```sh
./showcase.sh --smoke --report /tmp/gloamthread-showcase.json
```

Smoke mode runs at fixed 60 Hz and returns the runtime result. It cannot establish native rendering quality, scanout FPS or enjoyable play. The JSON report records the actual outcome; an interrupted or failed run must not be reported as a pass.

`--seed INT` selects a deterministic seed (default `18427`). The report defaults to `/tmp/gloamthread-showcase.json`; `--report PATH` selects another location. Use `--help` for all options or set `GODOT_BIN=/path/to/godot` for another executable. The launcher works from another directory when called by its path and selects Wayland when `WAYLAND_DISPLAY` is set. It performs no installation, export or model request. For source setup, see [the launch guide](ARENA_DEMO.md).
