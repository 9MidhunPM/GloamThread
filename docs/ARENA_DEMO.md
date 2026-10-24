# Gloamthread — arena playtest candidate

A solo or two-player local side-view wave fighter. Clear 20 waves across four five-wave stages, with a boss at each stage's end, then optionally continue into endless. Coins and upgrades belong to each player and reset with the run. Saved characters, settings and scores persist.

## Play the Linux package

Extract the complete ZIP into a writable directory. Keep `authoring/` beside the executable if you want optional character generation. From the extracted directory:

```sh
chmod +x Gloamthread.x86_64
./Gloamthread.x86_64
```

On Hyprland/Wayland you may use `./Gloamthread.x86_64 --display-driver wayland`; on X11 use `--display-driver x11`. The target is Linux x86_64 with OpenGL Compatibility rendering. The packaged game needs no installed Godot, Python, key, account or network connection to play its built-in and accepted fighters. F11 toggles fullscreen; the game uses a 640×360 shared arena, integer scaling and a 1920×1080 UI.

Choose **Solo Run** or **Local Co-op**, select fighters and distinct input sources, then **Start Run**. Player 1 controls shared title/lobby menus; mouse selection is available. The roster stays fixed during a run.

| Action | Keyboard left (P1) | Keyboard right (P2) | Gamepad default |
| --- | --- | --- | --- |
| Move | WASD | Arrow keys | Left stick / D-pad |
| Jump | Space | Period | A |
| Basic attack, hold to repeat | F | Comma | X |
| Special | G | Slash | B |
| Dodge | Shift | Apostrophe | RB |
| Hold to revive nearby partner | E | M | Y |
| Pause | Escape | Enter | Start |

Use Down + Jump to drop through platforms. Combat powers come from the selected ember, frost, storm, stone, nature or shadow family; upright, four-legged and floating bodies change appearance and animation. Floating art does not grant flight.

Last hits award personal coins, including damage-over-time and projectile kills. Every active player gets the wave-clear bonus. Between waves, each player operates their own shop: Up/Down selects, Attack/Jump confirms, one reroll is free per wave, and every active player must become ready to continue. Confirm Ready again to resume shopping while the other player is not ready. Nearby partners hold revive for 1.5 seconds; downed players also return on wave completion. Solo death or a team wipe ends the run.

## Draw or import a fighter

**Character Forge** offers saved fighters and **Draw & forge**. Draw on the canvas or import an original PNG/JPEG, add an optional description, then analyse the drawing or enter your own settings. Review the name, body shape, ability family and arena theme before generating. Inspect every animation, correct part masks/joints and apply a local rebake before accepting. Acceptance validates the complete bundle; rejected candidates preserve the previous fighter. In co-op, the arena theme alternates between the players each five-wave stage.

Optional generation needs Python 3.10+ with venv/pip support and an internet connection for dependency installation and model requests:

```sh
bash setup_authoring.sh
# Edit authoring/.env locally and set OPENAI_API_KEY; do not share this file.
authoring/.venv/bin/python authoring/tools/fighter_forge.py status
```

The helper installs only inside `authoring/.venv`, creates `authoring/.env` only if absent and sets its permissions to `600`. It preserves an existing key. The `status` command reports key presence and model names without contacting a model or printing credentials. Keep the configured reviewed models; the worker does not silently retry or choose another model.

Analyse and Generate can incur provider charges. The worker reserves costs against the configured total authoring allowance before sending requests, with a $0.50 maximum per character. Set `FORGE_TOTAL_BUDGET_USD=2.00` in `authoring/.env` for the approved $2 total; an unconfigured installation retains a conservative $0.50 total. The creator displays separate total/job limits, remaining amounts and the next request requirement. Cancellation prevents later requests but cannot guarantee an in-flight request was unbilled; uncertain reservations remain retained. Starting a new job does not reset that shared ledger. Local mask/pivot rebakes make no model calls. Original inputs, drafts and accepted characters remain local unless you explicitly analyse or generate, which sends the chosen drawing/description to OpenAI.

**Reviewed generated starter:** Kiln Fox and its forest/materials are retained real model outputs, with explicit local crop correction and authored animation. It is the default P1 preset; Cinderjack and Thistlepaw remain available. Generation was tested with one live character/theme pair, not every possible upload or body family. If an image model returns the wrong layout, use **Correct cached layout**: crop each part/master and scenery/materials, then convert in a fresh local draft without another model request. Existing previews and accepted fighters remain intact. All poses still require inspection before acceptance.

The earlier experiment retained $0.35 in conservative reservations. The selected $2 total preserves that history; a resumed image pair succeeded, bringing the development ledger to $0.55 reserved. This is not a billing receipt or an unlimited generation allowance. Local corrections and accepted fighters are reusable offline. A valid budget-blocked draft can explicitly resume after configuration changes without another analysis. Model access initially returned 403 and was fixed in the API project. Required allowed models are `gpt-6-luna` and `gpt-image-1-mini`.

Accepted fighters and drafts live in Godot's per-user application-data directory (`fighters/` and `forge_jobs/`); settings and scores are separate from run power. The optional helper's budget ledger is under `authoring/build/forge/`. These local files and your key are not part of the distributed archive.

## Source checks and packaging

From a source checkout with Godot 4.7.2 standard, its matching Linux export template and the Python authoring dependencies installed:

```sh
godot --headless --path . --editor --import --quit
godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd
godot --headless --fixed-fps 60 --path . --script tests/forge/run_tests.gd
python3 tools/package_arena.py --dry-run
python3 tools/package_arena.py
```

Packaging requires a clean committed checkout, including untracked source outside `build/`. It derives the version from `project.godot`; version `0.2.0-arena` produces `build/packages/Gloamthread-0.2.0-arena-linux-x86_64.zip` and its `.sha256` checksum. The archive includes an explicit helper-file allowlist, provenance inventories and engine notices. It excludes actual `.env` files, environments, raw model jobs, saves and local test keys. `BUILD.json` records the exact source commit/tree, engine version, executable hash and every payload-file hash.

This is a playtest candidate. Automated checks do not prove physical gamepad behavior, keyboard rollover, listening quality, human balance, a 10–15 minute clear or performance on other hardware. Native/export evidence must be recorded for the packaged revision separately from source checks. Fullscreen UI layout and model-generated artwork require visual inspection; structural validation alone does not establish art quality.

Source and editable assets: [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread). See `THIRD_PARTY_NOTICES.md` and `docs/licenses/` for bundled engine notices.
