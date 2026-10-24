# Setup before the first coding run

Version 2.0 · verified sources on 24 October 2026. These instructions prepare the user's machine; no system packages have been installed by this starter pack.

## 1. Minimal Arch Linux installation

Run on your Arch machine:

```sh
sudo pacman -Syu --needed godot git python python-pillow python-numpy
```

This performs a normal full-system upgrade while installing the needed packages. Review pacman's transaction before accepting. On Arch, avoid updating the package database alone and then selectively upgrading dependencies.

- **godot:** standard engine/editor, not the Mono/.NET package.
- **git:** source control and agent workflow.
- **python:** asset, audio and data tooling.
- **python-pillow:** PNG/pixel asset generation and validation.
- **python-numpy:** original audio synthesis (pure Python is too slow to render the music arrangements). Tool dependency only; the packaged game does not need Python.

The Godot baseline for this pack is **4.7.2 standard**. The official Linux download and Arch's package page listed this version when checked. Arch is rolling release: if your install provides another version, either use the matching official archived 4.7.2 binary for this project, or deliberately update the baseline and rerun all checks. Record `godot --version` in the actual implementation repository. The setup checker flags drift instead of silently accepting it.

No CMake, Raylib, C++ compiler, Node/npm, .NET SDK, database, Docker, game-content pack, model download or API key is required for Phase 1. Your existing editor is enough; Godot also has a script editor. Those tools may exist for other projects but they are not prerequisites here.

Official packages: [Godot](https://archlinux.org/packages/extra/x86_64/godot/), [Pillow](https://archlinux.org/packages/extra/x86_64/python-pillow/). Official binary route: [Godot Linux downloads](https://godotengine.org/download/linux/), [release archive](https://godotengine.org/download/archive/). The binary is self-contained; make it executable and put its directory on PATH, or pass its path to the checker with `--godot`.

## 2. Hardware and environment

- Two gamepads are preferred. Keyboard plus one gamepad is the required alternative. Two people on one keyboard is optional because simultaneous key combinations may be dropped by keyboard hardware.
- Connect the devices before the first input test. Confirm distinct device IDs in the Godot debug output once the game exists. Do not allow one controller to steer both players.
- Target the user's Arch/Hyprland laptop first; test actual window focus, controller hotplug and audio on that machine. This document does not certify hardware compatibility.
- Use the Compatibility renderer for the first 2D slice. Start windowed at 1920×720 if the desktop has room, otherwise a 960×360 integer-scaled window. Fullscreen letterboxes to preserve the 8:3 composite aspect; a 1920×1080 monitor will have vertical unused space. A two-half 16:9 window would give different camera framing and needs a separate deliberate design pass.

## 3. Check this planning pack now

From the extracted folder containing README.md:

```sh
python3 tools/preflight.py
python3 tools/check_pack.py
```

`preflight.py` is read-only: checks Python, Pillow, Git and the Godot version. It does not install dependencies, download assets, initialize Git or test controllers/display/audio. Exit 1 means a missing requirement or version mismatch; fix the reported item. An official binary outside PATH can be selected:

```sh
python3 tools/preflight.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
```

`check_pack.py` checks the bundled documents, links and example data. It does not import Godot or claim gameplay tests.

## 4. Give the folder to Devin or Codex

1. Extract the whole ZIP; keep AGENTS.md at the root where the agent starts.
2. Open that folder in your coding agent. For a remote agent, place the folder's contents in the repository/workspace it actually uses; your local installed tools are not automatically installed in its cloud environment.
3. This repository's history starts from the DevDay Kochi hackathon template; its `.gitignore` (extended with Godot's `.godot/` cache and build output) covers transient project files. Do not nest a repository inside an existing checkout.
4. Paste FIRST_AGENT_PROMPT.md's prompt block and start the build.
5. Ask for the first one-room two-input proof early, then let the agent continue through the scoped MVP. Inspect visible output at each integration gate.

The M0 diagnostic room now integrates boot/session/player/cameras and the first original asset/content packet. Import with `godot --headless --path . --editor --import --quit`, then launch with `godot --path .`. Four engine scenarios cover the current component/session boundaries; visible simultaneous input and the complete Phase 1 adventure remain unverified/incomplete. Use [STATUS.md](STATUS.md) for exact evidence.

## 5. Command contract after implementation

The current generator/validators accept `--stage diagnostic` for the first packet. Their default full-stage commands below require the later complete bundle and currently report incomplete content. Import, diagnostic launch and the current scenario runner work; full gameplay acceptance remains a separate gate:

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 tools/validate_content.py
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd
godot --path .
```

The scenario runner must return a nonzero process status on failure and finish, not hang in an empty main loop. Import success alone cannot validate cameras, audio, controllers or playability.

## 6. Exporting a playable Linux build

Once the game exists, install **matching 4.7.2 standard export templates** through Editor → Manage Export Templates, selecting Linux x86_64 as available. These are engine templates, not art/resource packs. In Project → Export, add a Linux preset and name it exactly `Linux`. Include the project's JSON/CSV data in export filters if it is loaded as plain files; test that the exported build can find it.

The planned export commands are:

```sh
mkdir -p build
godot --headless --path . --export-release "Linux" build/gloamthread.x86_64
./build/gloamthread.x86_64
```

Package the executable with any companion `.pck` produced by the preset. A PCK/ZIP data export alone is not an executable game. Try the resulting package outside the source tree and offline before calling it shipped.

## 7. Optional later tools

- Image generation and image interpretation: Phase 2 only. Choose a provider and budget after fixed-character art, movement, split screen and the whole route work.
- A Python HTTP backend may be introduced for pregame generation then. Do not install a provider SDK, create API credentials or expose keys in the game client for Phase 1.
- An art editor or audio workstation is optional for inspecting generated sources, not a prerequisite or source of purchased packs.

## References

- [Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Exporting projects](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)
- [Pixel presentation and resolution](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [Controller input](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html)
