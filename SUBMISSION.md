# Project submission

Complete this file as the build progresses and use it to prepare the submission through the method announced by the organizers. Every field below must stay truthful; entries marked TODO are genuinely not yet available.

## Project

- **Project name:** Gloamthread: Two Ends
- **Short description:** Two players on one computer carry opposite ends of the last living thread through a kingdom each sees differently (Ember and Moss themes over one shared physical world). They fight readable enemies, revive each other, restore bridges from paired anchors, defeat the Spoolwarden to earn a shared dash, and reopen the Lantern Loom so a stranded district can cross home. It is for pairs who enjoy responsive action, exploration and cooperating on a small, complete problem.
- **Code repository URL:** TODO — no remote has been authorized yet (the template remote was removed).
- **Final submitted implementation commit SHA:** TODO — recorded when the Phase 1 candidate is packaged.
- **Working demo URL or local demo steps:** local desktop build; steps in [README.md](README.md#run-the-project). An exported Linux binary is planned for milestone M7.
- **Demo access requirements:** a Linux machine with Godot 4.7.2 standard (or the exported binary once it exists) and a keyboard; two gamepads are optional. No accounts, keys or network.

## Participants

| Participant name | GitHub handle | Contribution |
| --- | --- | --- |
| Midhun P M | 9MidhunPM | Design pack, direction, review and playtesting; coding-agent supervision |

## Run and demonstrate

- **Prerequisites and versions:** Arch Linux, Godot 4.7.2 standard, Python ≥ 3.10 with Pillow and numpy, Git. See [docs/SETUP.md](docs/SETUP.md).
- **Install command:** `sudo pacman -Syu --needed godot git python python-pillow python-numpy`
- **Required environment variable names:** none.
- **Start command:** `godot --path .` *(available from milestone M0)*; exported build `./build/gloamthread.x86_64` *(planned, M7)*.
- **Demo walkthrough:** TODO — to be written from the three-minute sequence in [docs/TRACK_ALIGNMENT.md](docs/TRACK_ALIGNMENT.md) once the slice is playable: two players join → same landmark in Ember and Moss → paired-anchor bridge → combat and a rescue → restoration payoff and ending card.
- **Checks performed and results:** `python3 tools/preflight.py` → exit 0; `python3 tools/check_pack.py` → PASS (documents, links, example contracts). No engine, gameplay, rendering, audio or playtest checks exist yet; see [docs/STATUS.md](docs/STATUS.md) and [CHANGELOG.md](CHANGELOG.md) for the running record.
- **Known limitations or incomplete features:** no implemented game yet. Gamepad input will be implemented but hardware-verified only if a controller becomes available; keyboard + keyboard is the primary tested mode. Two-human fresh playtests and performance measurements are reported only when they actually happen.
- **Libraries, APIs, and public datasets used:** [Godot Engine 4.7.2](https://godotengine.org/) (MIT), [Pillow](https://python-pillow.org/) (MIT-CMU), [NumPy](https://numpy.org/) (BSD-3). No datasets, APIs, game-content packs, stock art, fonts, music or sound libraries.
- **AI usage record:** [AI_USAGE.md](AI_USAGE.md)
- **Development change log:** [CHANGELOG.md](CHANGELOG.md)

## Submission checklist

- [ ] The project implementation is built from scratch in this repository (the only pre-existing material is the design documentation and example contracts).
- [x] I participated solo or with no more than 4 team members in total.
- [x] Coding-agent usage is documented honestly in [AI_USAGE.md](AI_USAGE.md).
- [ ] The code repository URL, short description, and working demo are provided.
- [ ] README setup and demo instructions match the submitted code.
- [ ] Actual checks and known limitations are documented.
- [x] Meaningful changes are documented and committed throughout development.
- [ ] The final implementation is committed and pushed, and its SHA is recorded above.
- [x] No credentials or private data are included in the repository or demo instructions.
- [ ] The organizers' announced submission method and timing have been followed.

Event reference: [DevDay Exchange Community: Kochi on Luma](https://luma.com/z10nz8gp). The organizer text in [RULES.md](RULES.md) is kept verbatim from the template.
