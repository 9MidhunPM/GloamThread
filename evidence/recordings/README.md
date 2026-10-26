# Published video recordings

Videos on the [videos-2026-10-26 release](https://github.com/9MidhunPM/GloamThread/releases/tag/videos-2026-10-26), described for players in [docs/VIDEOS.md](../../docs/VIDEOS.md). No API/model calls were made. These are automated bot routes and scripted tours, not human playtests, and say nothing about physical devices, listening quality or enjoyment.

## Environment

- Godot 4.7.2.stable.arch_linux (Compatibility/OpenGL, Mesa Intel Graphics (ARL)), Arch Linux, Hyprland 0.56 with Xwayland. Godot ran with `--display-driver x11` on a hidden agent workspace so the user's screen was not disturbed.
- Movie Maker: `--write-movie FILE.ogv --fixed-fps 30 --disable-vsync --windowed --resolution 1920x1080`, 1920×1080 Theora video and Vorbis audio rendered frame by frame (not real-time screen capture). The game's own audio mix is recorded; it has not been listened to for this record.
- Source: the working tree of the accessibility/documentation change on top of `96ae418`, committed in the same commit as this file. The later edits before that commit (solo keyboard-side cycling and README/doc text) are not exercised by these scripts. The Story video used the final `tools/story_showcase.gd`.
- Transcode for publishing: `ffmpeg -i IN.ogv -c:v libx264 -preset slow -crf 24 -pix_fmt yuv420p -tune animation -c:a aac -b:a 128k -movflags +faststart OUT.mp4`.

## Videos

| File | Command (inside the wrapper above) | Movie length | Run report |
| --- | --- | --- | --- |
| `gloamthread-intro.mp4` | Not recorded here. Supplied by the project owner (`Gloamthread_Intro.mp4`, 1280×720, 24 FPS, H.264/AAC, 48.0 s, SHA-256 `f3697f20316b155ea1a77d03af46fa889117c32841bc4e6e429889d0e9c0f2f6`). Embedded title: *Gloamthread: Two Ends — Story Introduction*; embedded comment: *Original motion composition using Gloamthread repository assets; not gameplay footage.* Published unmodified; the repository copy is byte-identical. | 0:48 | — |
| `gloamthread-arena-highlights.mp4` | `--script tools/arena_showcase.gd -- --mode highlights --speed 1` | 2:23 (4,301 frames) | `completed: true`, no errors; all seven chapters succeeded; peak 32 live enemies in the crowd chapter. Chapters use labelled wave jumps and preset upgrades. |
| `gloamthread-arena-full25-4x.mp4` | `--script tools/arena_showcase.gd -- --mode full --speed 4` | 7:57 (14,318 frames) | Game reached endless wave 25 (`phase: clear`, `endless: true`) with no engine errors, zero downs, 16/16 chunks, 4 landmarks, 16 loot, kills 490/269, coins spent 699/695. Report `completed: false`: bot exploration legs after waves 1, 2, 5 and 15 timed out at 2,400 ticks (see below). |
| `gloamthread-story-full.mp4` | `--script tools/story_showcase.gd -- --mode full --speed 1` | 3:51 (6,934 frames) | `completed: true`, `interrupted: false`, 12,305 physics ticks, all eight rooms, final mode `ending`, hearts 4/3, zero recoveries/failures/errors, temporary save `ok`. |
| `gloamthread-accessibility.mp4` | `--script tools/accessibility_tour.gd` | 1:01 (1,831 frames) | Tour exits 0 with an empty engine-error list. Uses temporary settings/records. |

## Problems found while recording

- **Story framing.** Movie Maker scales the root viewport texture to cover the 16:9 movie, so the Story showcase's 960×420 canvas lost the outer edges of both views. In Movie Maker mode `tools/story_showcase.gd` now uses a 960×540 canvas (blank band under the banner); normal viewing is unchanged. The ending-card hold now counts frame time instead of the wall clock, so it lasts seven viewing seconds when rendering is slower than real time.
- **Project fullscreen overrides `--windowed`.** The window still reported fullscreen with `--windowed`; framing is unaffected because Movie Maker records the viewport texture, not the window.
- **First full-run attempt.** A first `--mode full --speed 4` recording reached endless wave 25 with no engine errors, zero downs, 16 chunks, 4 landmarks and 16 loot, but its route report said `completed: false` because four bot exploration legs (after waves 1, 2, 5 and 15) timed out at 2,400 ticks. Random critical hits and shop rolls make runs differ. A second recording also reached wave 25 without engine errors or downs but timed out five exploration legs and discovered only one landmark, so the first, more complete run is published. The same ordinary-input route passes headless at 60 Hz on this tree (`tools/arena_playthrough.gd -- --players 2 --waves 25 --seed 18427`: success, 35,916 ticks) and on `96ae418` (36,011 ticks), so the timeouts are specific to visible 4× Movie Maker playback (eight physics steps per rendered frame) and were not caused by this change. They are not fixed here.

## Published files

| File | Bytes | SHA-256 |
| --- | --- | --- |
| `gloamthread-intro.mp4` | 3,163,199 | `f3697f20316b155ea1a77d03af46fa889117c32841bc4e6e429889d0e9c0f2f6` |
| `gloamthread-arena-highlights.mp4` | 27,509,879 | `605876f53e6e07157755647cb2d9167eac7c9525d4654b2337493f5bcd96df28` |
| `gloamthread-arena-full25-4x.mp4` | 81,211,079 | `224621752ac969b3c83cb4cbfdb1d77a780bb4ab11d6ef6b9950b8acd20c6059` |
| `gloamthread-story-full.mp4` | 14,632,441 | `ccc97da11204a7b3dff5f3ed2161ea9ef0fc998883ab27af9e1006bb0760c8d4` |
| `gloamthread-accessibility.mp4` | 3,310,752 | `18a7861a3859c30812c8391d614df26f8b345dd3cbecd57934a8b40b73dc80be` |

Stills in `docs/media/` are single frames extracted from these files with ffmpeg and scaled to 960 px wide (the Story still is cropped to the views and banner). Frames from every gameplay video were inspected as contact sheets; the Story recording was re-made after the framing fix.
