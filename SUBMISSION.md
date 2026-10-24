# Project submission

Complete this file as the build progresses and use it to prepare the submission through the method announced by the organizers. Every field below must stay truthful; entries marked TODO are genuinely not yet available.

## Project

- **Project name:** Gloamthread: Two Ends
- **Short description:** Two players on one computer carry opposite ends of the last living thread through a kingdom each sees differently (Ember and Moss themes over one shared physical world). They fight readable enemies, revive each other, restore bridges from paired anchors, defeat the Spoolwarden to earn a shared dash, and reopen the Lantern Loom so a stranded district can cross home. It is for pairs who enjoy responsive action, exploration and cooperating on a small, complete problem.
- **Code repository URL:** [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread).
- **Final submitted implementation commit SHA:** TODO — recorded when the Phase 1 candidate is packaged.
- **Working demo URL or local demo steps:** Agent 1's `feat/phase1-runtime` checkpoint `b1ff5d6` runs the diagnostic split-screen tracer with `godot --path .`. Full content is published separately on `feat/phase1-content`; a complete MVP demo/export is not available yet. See [README.md](README.md#run-the-project) and [docs/STATUS.md](docs/STATUS.md).
- **Demo access requirements:** a Linux machine with Godot 4.7.2 standard (or the exported binary once it exists) and a keyboard; two gamepads are optional. No accounts, keys or network.

## Participants

| Participant name | GitHub handle | Contribution |
| --- | --- | --- |
| Midhun P M | 9MidhunPM | Project direction, specifications and coding-agent supervision; human playtesting remains pending |

## Run and demonstrate

- **Prerequisites and versions:** Arch Linux, Godot 4.7.2 standard, Python ≥ 3.10 with Pillow and numpy, Git. See [docs/SETUP.md](docs/SETUP.md).
- **Install command:** `sudo pacman -Syu --needed godot git python python-pillow python-numpy`
- **Required environment variable names:** none.
- **Start command:** `godot --path .` from the runtime/integrated checkout. The content checkout supports `python3 tools/generate_assets.py --seed 18427` and both validators. An exported executable remains planned.
- **Demo walkthrough:** TODO — to be written from the three-minute sequence in [docs/TRACK_ALIGNMENT.md](docs/TRACK_ALIGNMENT.md) once the slice is playable: two players join → same landmark in Ember and Moss → paired-anchor bridge → combat and a rescue → restoration payoff and ending card.
- **Checks performed and results:** full asset/content validators and 79 Python tests PASS after content QA; all 47 output hashes and manifest matched across two seed-18427 rebuilds. Agent 1 separately recorded diagnostic engine scenarios, a first window snapshot and 41.74 px jump rise / 55 px running feet travel at `b1ff5d6`. These results do not establish the complete route or continuous presentation. See [content evidence](evidence/content/README.md), [docs/STATUS.md](docs/STATUS.md) and [CHANGELOG.md](CHANGELOG.md).
- **Known limitations or incomplete features:** production content/runtime integration, complete combat/recovery/cooperation/boss/dash/loom/save flow, normal-input route, motion/readability, listening, controller hardware, export, performance and human playtests are unfinished or unverified. Keyboard + keyboard is primary; ordinary jump measurements do not certify the authored dash gaps.
- **Libraries, APIs, and public datasets used:** [Godot Engine 4.7.2](https://godotengine.org/) (MIT), [Pillow](https://python-pillow.org/) (MIT-CMU), [NumPy](https://numpy.org/) (BSD-3). No datasets, APIs, game-content packs, stock art, fonts, music or sound libraries.
- **AI usage record:** [AI_USAGE.md](AI_USAGE.md)
- **Development change log:** [CHANGELOG.md](CHANGELOG.md)

## Submission checklist

- [ ] The project follows the organizers' current project-start and eligibility instructions.
- [ ] The participation format follows the organizers' current instructions.
- [x] The maintained [AI_USAGE.md](AI_USAGE.md) identifies actual tools and contributions; event eligibility does not require a particular provider.
- [ ] The code repository URL, short description, and working demo are provided.
- [ ] README setup and demo instructions match the submitted code.
- [ ] Actual checks and known limitations are documented.
- [x] Meaningful changes are documented and committed throughout development.
- [ ] The final implementation is committed and pushed, and its SHA is recorded above.
- [x] No credentials or private data are included in the repository or demo instructions.
- [ ] The organizers' announced submission method and timing have been followed.

Event: **Devin Hack Kochi**. Use the organizers' current submission method and deadline. The [corrected template guidance](https://github.com/anima-regem/devin-hack-kochi-thanushreesuresh-SEOpilot/tree/cb4db78169a8d199b43b077fbcc8f2ff4b798a14) removes the older event's logistics, participation limits and credit promises; [RULES.md](RULES.md) records our current baseline.
