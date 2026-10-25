# Gloamthread — arena playtest candidate

A solo or two-player local scrolling side-view wave fighter. Views merge nearby and split vertically when partners explore apart, with P1 always left and P2 right. Clear 20 waves across four five-wave stages, with a boss at each stage's end, then optionally continue into endless. Coins and upgrades belong to each player and reset with the run. Saved characters, settings and scores persist.

## Play the Linux package

Extract the complete ZIP into a writable directory. Keep `authoring/` beside the executable if you want optional character generation. From the extracted directory:

```sh
chmod +x Gloamthread.x86_64
./Gloamthread.x86_64
```

On Hyprland/Wayland you may use `./Gloamthread.x86_64 --display-driver wayland`; on X11 use `--display-driver x11`. The target is Linux x86_64 with OpenGL Compatibility rendering. The packaged game needs no installed Godot, Python, key, account or network connection to play its built-in and accepted fighters. F11 toggles fullscreen; the game uses a 640×360 shared view or two 320×360 views, integer 3× scaling and a 1920×1080 UI. The world starts four screens wide and expands to sixteen after waves 5/10/15. Raised paths, shallow caves and earlier discoveries remain connected; wave transitions preserve player positions. The pause screen displays the world seed.

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

Last hits award personal coins, including damage-over-time and projectile kills. Every active player gets the wave-clear bonus. Between waves, each player operates their own shop: Up/Down selects, Attack/Jump confirms, one reroll is free per wave, and every active player must become ready to continue. Choose Explore to close your panel, move and discover loot while your partner keeps shopping. E/M/Y reopens your own shop and clears your Ready status; every active player must explicitly Ready before continuing. Nearby views merge; separated partners receive independent scrolling views; downed bodies remain camera targets. Four caches per region pay three coins to each active player exactly once; attacks open them. Two healing plants per region restore 20% health to the collector when needed. Passive regeneration is combat-only. Nearby partners hold revive for 1.5 seconds; downed players also return on wave completion. Solo death or a team wipe ends the run.

Chargers show a fixed rush lane and recover after a miss or wall impact. Heavies guard their front; bait the swing, attack from behind with a partner or break their stance with freeze/strong stagger. Shooters announce a fixed three-shot line; move or use cover. Flyers mark a landing point before diving, leaving a retreat window afterward. Amber warns, red means activation is near, and teal broken-shield brackets show heavy vulnerability.

## Draw or import a fighter

**Character Forge** offers saved fighters and **Draw & forge**. Draw on the canvas or import an original PNG/JPEG, add an optional description, then analyse the drawing or enter your own settings. Review the name, body shape, ability family and arena theme before generating. Inspect every animation, correct part masks/joints and apply a local rebake before accepting. Acceptance validates the complete bundle; rejected candidates preserve the previous fighter. In co-op, the arena theme alternates between the players each five-wave stage.

Optional generation needs Python 3.10+ with venv/pip support and an internet connection for dependency installation and model requests:

```sh
bash setup_authoring.sh
# Edit authoring/.env locally and set OPENAI_API_KEY; do not share this file.
authoring/.venv/bin/python authoring/tools/fighter_forge.py status
```

The helper installs only inside `authoring/.venv`, creates `authoring/.env` only if absent and sets its permissions to `600`. It preserves an existing key. The `status` command reports key presence and model names without contacting a model or printing credentials. Keep the configured reviewed models; the worker does not silently retry or choose another model.

Analyse and Generate use your API account. There is no local total or per-character dollar cap; old allowance settings no longer block requests. The creator shows recorded request estimates separately from actual billing. Explicit user actions, durable attempt history, cache integrity, cancellation and no automatic retries/fallback remain. An uncertain request stays recorded, and cancellation cannot guarantee an in-flight request was unbilled. Local mask/pivot rebakes and cached layout corrections make no model calls. Original inputs, drafts and accepted fighters remain local unless you explicitly analyse or generate, which sends the chosen drawing/description to OpenAI.

**Correcting a returned board:** choose a target and drag around its visible artwork; a simple click leaves the existing crop intact. Save checks every body part and the whole-character master at the selected opacity cutoff before starting conversion. An empty/translucent crop stays in the editor with its target selected and a useful message. Adjust that crop or its cutoff and try again. Successful conversion opens the animation preview; **Accept fighter & play** then saves the fighter to **Your fighters** and selects it in the lobby. Neither correction nor acceptance sends another image request.

**Reviewed generated starter:** Kiln Fox and its forest/materials are retained real model outputs, with explicit local crop correction and authored animation. It is the default P1 preset; Cinderjack and Thistlepaw remain available. Generation was tested with one live character/theme pair, not every possible upload or body family. If an image model returns the wrong layout, use **Correct cached layout**: crop each part/master and scenery/materials, then convert in a fresh local draft without another model request. Existing previews and accepted fighters remain intact. All poses still require inspection before acceptance.

Earlier request estimates and uncertain attempts remain intact after removing the local caps; they are not provider billing receipts. Existing accepted fighters and valid cached output remain reusable offline. Model access initially returned 403 and was fixed in the API project. Required allowed models are `gpt-6-luna` and `gpt-image-1-mini`.

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

Packaging requires a clean committed checkout, including untracked source outside `build/`. It derives the version from `project.godot`; version `0.4.0-counterplay` produces `build/packages/Gloamthread-0.4.0-counterplay-linux-x86_64.zip` and its `.sha256` checksum. The archive includes an explicit helper-file allowlist, provenance inventories and engine notices. It excludes actual `.env` files, environments, raw model jobs, saves and local test keys. `BUILD.json` records the exact source commit/tree, engine version, executable hash and every payload-file hash.

This is a playtest candidate. Automated checks do not prove physical gamepad behavior, keyboard rollover, listening quality, human balance, a 10–15 minute clear or performance on other hardware. Native/export evidence must be recorded for the packaged revision separately from source checks. Fullscreen UI layout and model-generated artwork require visual inspection; structural validation alone does not establish art quality.

Source and editable assets: [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread). See `THIRD_PARTY_NOTICES.md` and `docs/licenses/` for bundled engine notices.

## Illustrated characters and attack identity

New source generations use one complete detailed transparent character as the actual sprite source, followed by environment artwork. Thirty-two authored whole-body cutout poses preserve its design and proportions; this is not independent limb animation. Older parts-based jobs and fighters remain valid. To use a detailed version from an old background, extract it to an RGBA PNG, open its retained draft and choose **Use detailed character cutout PNG**. The fixed source/hash is retained, masks/pivots remain editable, and local conversion makes no API-key requests. Background/material crops can be adjusted separately.

Wizard/mage/other magical identities use projectile kits (Frost or Nature); physical sword/spear/axe identities use melee kits (Stone/Ember/Storm). Incompatible dropdown choices are corrected, and older mislabeled accepted fighters are corrected at runtime without rewriting their saved art/manifests.
