# Your first adventure.

Everything you need to play, save your progress, and bring a fighter of your own.

<span id="start-playing"></span>
<span id="1-launch-the-game"></span>

## Start playing

1. **Open the game**

   Visit **[gloamthread.midhunpm.in](https://gloamthread.midhunpm.in)** in desktop Chrome/Chromium or Firefox. Select **Play Gloamthread** to load the game. No account or installation needed.

2. **Choose your way through**

   Go solo, share a keyboard in **LOCAL CO-OP**, or take a friend into **STORY MODE (2 PLAYERS)**. Give each player a distinct keyboard zone or connected controller.

3. **Keep your progress safe**

   Settings, scores and Story checkpoints stay in this browser. Refresh ends the current run. Download accepted fighter ZIPs to keep a backup of your creations.

## A keyboard. A friend. A fair fight.

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | A / D | Left / Right arrows |
| Jump | Space | Period `.` |
| Attack | F | Comma `,` |
| Special | G | Slash `/` |

[View all controls](#controls)

### Browser setup and saves

![Home screen with Arena, Character Forge and Story Mode choices.](screenshots/title.png)

The browser needs WebAssembly and WebGL 2. Two players share this computer; there is no online multiplayer. You can read the website on a phone, but the game has no mobile touch controls. Browser checks cover desktop Chromium and Firefox; Safari and physical controllers remain unverified.

### Browser controls and returning to the website

- **Fullscreen** in the game toolbar expands the game. Use the toolbar again to leave fullscreen; browser-reserved shortcuts can behave differently from the native game's F11.
- **Home** pauses the game and returns to the website. **Resume game** reopens the same game; use the game's Resume action if its pause screen is showing.
- Switching tabs or leaving the window pauses combat. Release held keys or buttons before resuming; the game does not catch up on missed time.
- **Refreshing or closing the tab ends an Arena run.** Home retains it only while that page remains open. Save Story progress through its checkpoint/pause flow before leaving.
- The website's motion control changes its 3D scene and page animations. In-game **REDUCED FLASH** and **REDUCED SHAKE** are separate settings.

If a download stalls, **Retry loading** appears after 30 seconds without progress. You can keep waiting or explicitly retry; Retry reloads the page. See [browser troubleshooting](#8-troubleshooting) for startup and save problems.

<span id="modes"></span>

## 2. Choose a mode

Choose a mode, give each player a distinct input, and start playing. **Arena** is a solo or two-player wave fighter with custom characters, exploration and personal upgrades. **Story Mode** restores the original two-player adventure with Tavi and Neri, paired bridges and the Lantern Loom.

| Choice | Players | What you do | What carries forward |
| --- | --- | --- | --- |
| **SOLO RUN** | One | Choose an Arena fighter and survive waves. | Accepted fighters, settings and recorded scores. |
| **LOCAL CO-OP** | Two | Share the scrolling Arena, with separate coins and shops. | Accepted fighters, settings and recorded scores. |
| **STORY MODE (2 PLAYERS)** | Two | Play the eight-room Tavi/Neri adventure. | Saved checkpoint and shared story progress. |
| **CHARACTER FORGE** | Menu workflow | Draw/import, generate, correct and accept an Arena fighter. | Accepted creations in **Your fighters**. |

Arena coins and purchased run upgrades reset when the run ends or restarts. Story has its own checkpoint progression. A generated fighter belongs to Arena; Story keeps its fixed couriers and shared traversal unlocks.

In Story, **Return to title** opens the Story menu. **Back to arena** on that menu returns to the Arena home. During a journey, **Save and return to arena** is the direct route back; resolve any visible save error before leaving.

<span id="controls"></span>

## 3. Inputs, menus and joining

One person can use the left keyboard zone and another the right zone. You can instead select connected gamepads, or combine a keyboard zone with a gamepad. **Each active player needs a different input source.** Two players cannot own the same gamepad or keyboard zone.

Arena home/lobby menus belong to Player 1. In the lobby, use **CHANGE FIGHTER**, **DRAW / IMPORT** and each **P1/P2 INPUT** button, then choose **START RUN**. The roster stays fixed during that run. Mouse selection is available.

![Arena lobby with fighter and input selection.](screenshots/arena-lobby.png)

Story's **New journey** or **Continue** opens its join screen. Choose the inputs, optionally swap Tavi/Neri for a new journey, then select **Begin journey** or **Continue journey**. The displayed menu owner operates shared Story menus; use Up/Down, Jump or Interact to confirm, and Pause to go back.

![Restored Story title with New journey, Continue and Back to arena.](screenshots/story-title.png)

![Story join screen for distinct inputs and courier assignment.](screenshots/story-join.png)

The tables below show defaults. Remapped controls shown in-game take precedence: Arena **SETTINGS & CONTROLS → P1/P2 CONTROLS** and Story **Settings → Player N controls** let each player move any action except Pause to another key or button. In Solo Run, the lobby's **P1 INPUT** button also offers the right-hand (arrow) keyboard side. See the [Accessibility guide](ACCESSIBILITY.md). Gamepad names use Xbox-style labels; your controller may print different symbols. If simultaneous keyboard actions fail, try another binding or a gamepad: some keyboards cannot report every key combination.

### Arena controls

| Action | P1: left keyboard | P2: right keyboard | Gamepad |
| --- | --- | --- | --- |
| Move | A / D | Left / Right arrows | Left stick / D-pad |
| Jump | Space | Period `.` | A |
| Drop through a plank | S + Space | Down + Period | Down + A |
| Basic attack: hold to repeat (or press-to-toggle in settings) | F | Comma `,` | X |
| Special ability | G | Slash `/` | B |
| Dodge | Left Shift | Apostrophe `'` | RB / right trigger |
| Hold to revive; reopen your shop during a break | E | M | Y |
| Pause | Escape | Enter | Start |

### Story controls

| Action | P1: left keyboard | P2: right keyboard | Gamepad |
| --- | --- | --- | --- |
| Move | A / D | Left / Right arrows | Left stick / D-pad |
| Jump | Space | Period `.` | A |
| Slash: press for a swing | F | Comma `,` | X |
| Courier special | G | Slash `/` | B |
| Interact / activate an anchor / hold revive | E | M | Y |
| Threadstep: after the boss unlock | Left Shift | Apostrophe `'` | RB / right trigger |
| Pause | Escape | Enter | Start |
| Map and current objective | Tab | Semicolon `;` | Select / Back |

**Shift means different things in the two modes:** Arena dodge is available during a run; Story Threadstep unlocks after defeating the Spoolwarden. Pressing it before that story unlock does not open the gated route.

<span id="accessibility"></span>

### Accessibility and comfort

Arena settings include remapping, press-to-toggle attack, game speed (100/80/60%) and damage taken (100/75/50/25%) assists, high contrast, menu narration through system text-to-speech, reduced flash/shake and separate master/music/effects volume. Left/Right changes a value in place; the focused option explains itself on screen. Story shares volume, reduced flash/shake and remapped controls. Full details and limits: [Accessibility guide](ACCESSIBILITY.md).

## 4. Arena: your first run

Start with a built-in fighter and learn movement, a held basic attack and the manual special. Appearance and body shape do not grant extra movement: a floating-looking fighter still follows the game's jump and collision rules.

Six ability families give you different starting tools:

| Family | Play around |
| --- | --- |
| Ember | Cleaves, flame and burn. |
| Frost | Bolts, freezing and shatter opportunities. |
| Storm | Fast strikes, chains and charge. |
| Stone | Heavy hits, slams and armour. |
| Nature | Thorns, roots and regeneration. |
| Shadow | Slashes, piercing and marks. |

### Waves, the HUD and finding the last enemy

Clear **20 waves**, with bosses at **5, 10, 15 and 20**. After the twentieth wave, the victory flow offers endless play. Watch your HP, personal coin count, special recharge and the current wave; a boss has its own health display.

The wave number is progression, not a count of enemies standing on-screen. Living enemies can be outside your view, while queued enemies or visible arrival warnings can still be pending. A wave clears only when the queue, arrivals and living enemies are all finished. Use the minimap, offscreen/final-enemy cues and nearby paths if the screen looks empty. Moving far away does not erase an enemy or award its coins.

### Explore the growing world

The world starts four screens wide and adds four more after waves **5, 10 and 15**, reaching sixteen. Earlier terrain and discoveries remain. Explore raised paths and shallow caves; the frontier marks the current boundary.

Nearby co-op partners share a view. Exploring apart splits it into **P1 left / P2 right** without teleporting either player. A downed partner remains a camera target. Personal shops can also force a split while open.

![Illustrative controlled native setup showing separate main-ground and cave views.](screenshots/arena-split.png)

*This retained native scene illustrates the scrolling views; it is not a fresh human playthrough.*

Each region contains **four caches** and **two healing plants**. Attack a cache to open it: it pays **three coins to each active player**, once per run. A plant restores **20% health to its collector** when healing is needed. Loot does not refill just because a camera moves away. Passive regeneration applies during combat, not free intermission exploration.

### Coins, shops and Ready

Enemy last hits award personal coins; projectiles, chains and damage over time keep their source player. Everyone receives a wave-clear bonus. A cosmetic coin trail does not let your partner steal the reward.

Between waves, each player gets an independent panel with four upgrade offers, healing, a free reroll, Explore and Ready. Read the shown effect, price and rank before buying. Upgrades change this run's build; they do not permanently change your saved fighter.

![Illustrative controlled native setup with one player's shop open while the partner explores.](screenshots/arena-shop.png)

*This retained native scene illustrates independent shopping and exploration.*

1. Use your own Up/Down to select; Attack or Jump confirms.
2. Buy an upgrade or **HEAL +35% / 5C** if affordable and needed.
3. Use your one free reroll for that wave if the offers do not fit your build.
4. Choose **EXPLORE - KEEP SHOPPING LATER** to move around without starting the next wave.
5. Press your Interact key to reopen your shop; doing so clears your Ready state.
6. Choose **READY FOR NEXT WAVE** when finished. Every active player must explicitly become ready.

### Read enemy attacks

| Enemy | Response to practise |
| --- | --- |
| Swarm / chaser | Keep space and avoid getting surrounded. |
| Charger | Leave its marked rush lane, then punish the miss or wall recovery. |
| Heavy | Bait its swing, flank its guarded front, or use control/stagger. Teal broken brackets indicate vulnerability. |
| Shooter | Move off the announced burst line or use solid cover; it commits to its aim. |
| Flyer | Leave the marked landing point before the dive, then punish its retreat. Open planks do not stop it; solid terrain does. |

Amber indicates a tell; red indicates approaching activation. Read a boss's tell before closing in. More detail is in [Enemy mechanics and counterplay](ENEMY_MECHANICS.md).

### Arena defeat and revival

In co-op, stand near a downed partner and hold Interact for **1.5 seconds**. Downed players also return on wave completion. Arena has **no Story-style twelve-second downed timeout**. Solo death or a team wipe ends the run. Restarting resets run coins and upgrades; accepted fighters remain saved.

## 5. Story Mode: the road to the Lantern Loom

Story is a **two-player** adventure with a fixed split screen and two colour treatments of one shared world. Tavi has the short-range **Ember Arc** special; Neri sends a **Spore Bolt**. Your character selection can be swapped at the start of a new journey. Your input source still belongs to your player slot.

![The original Story adventure with both couriers in their fixed split-screen views.](screenshots/story-play.png)

*Fresh restored-mode capture in Lantern Rest. The title → join → first room → save-and-return flow was exercised; this image does not establish a new full eight-room playthrough.*

### Cooperation essentials

- **Leaving a room:** both living couriers must stand in the exit rally area; then one presses Interact. One courier alone cannot replace the room.
- **Restoring a bridge:** take two different anchors, one per courier, and press Interact at your own end. Each activation latches while the partner reaches the other end. There is no frame-perfect synchronisation requirement. Both players can use either anchor.
- **Reviving:** stand close and hold Interact for 1.5 seconds. Taking damage interrupts the rescuer. A downed courier has **12 seconds of simulation time**; both players down, or the timer expiring, returns the team to its checkpoint.
- **Pause and Map:** these hold the shared story world. Check the current objective and checkpoint if you lose the route.

![An original Story bridge restoration with a courier at each anchor.](screenshots/story-bridge.png)

*Retained original campaign route capture; bridge progress belongs to the team.*

### Eight-room walkthrough

| Room | What to do | What opens next |
| --- | --- | --- |
| **r00 — Lantern Rest** | Meet Oru, read the arrival guidance and activate checkpoint A. Practise jump, slash and specials before leaving together. | Mossfoot Atrium. |
| **r01 — Mossfoot Atrium** | Continue toward Spindle Steps. Remember the branch that needs Threadstep; you will return after the boss. | The first bridge route. |
| **r02 — Spindle Steps** | Climb the forgiving steps and restore the bridge with two distinct anchors. Rally together beyond it. | Glasswing Gallery. |
| **r03 — Glasswing Gallery** | Learn the ground and flying enemies; use both specials. Explore the optional lantern-charm pocket if you wish. | Warden's Landing. The charm is optional, not an ending requirement. |
| **r04 — Warden's Landing** | Activate checkpoint B before the boss route. Regroup and make sure both players are ready. | Broken Bell. |
| **r05 — Broken Bell** | Defeat the Spoolwarden by respecting its tells and striking during openings. | Shared Threadstep and the shortcut back toward the Atrium. |
| **r06 — Severed Causeway** | Return through the shortcut, take the Atrium's remembered dash route, practise Threadstep and restore the second anchor pair. | Lantern Loom. |
| **r07 — Lantern Loom** | Each courier takes a different restoration station and interacts. After restoration, take the return route together. | Return to Lantern Rest for the ending. |

**Boss teamwork:** when one courier staggers the Spoolwarden, a hit from the other courier can trigger the optional **Cross-stitch** follow-up. It uses your normal attacks; there is no separate secret key. The bonus is helpful, not required to unlock Threadstep.

**After the ending:** keep exploring, return to the Story title, or start a new journey with the characters swapped. Checkpoint recovery keeps permanent shared restorations. **Continue** resumes at a validated checkpoint, not an arbitrary mid-jump position.

<span id="create-a-fighter"></span>

## 6. Make an Arena fighter

![Character Forge with creation controls and animation preview.](screenshots/character-forge.png)

Built-ins and accepted fighters need no generation service to play. Optional **Analyse** and **Generate** send model requests only when chosen. Cached crop/mask/pivot corrections, cutout conversion and acceptance do not send another model request.

### Create in your browser

Open **CHARACTER FORGE** and enter your personal creator invitation. An invite unlocks creation; it is not required for playing or importing an accepted fighter. The hosted service keeps its provider credentials on the server. Never enter an API key into a drawing, fighter name or description.

Draw or choose an original PNG/JPEG with the browser file picker, then follow the review and acceptance steps below. Analysis and generation send your selected drawing and description to the hosted worker and its model provider. Private drafts remain on the server for recovery; accepted fighters are stored in your browser. Closing the page does not automatically retry a paid request. Reopen Forge to inspect its retained status before starting another request.

The creator shows request **estimates**, not a provider receipt. Current labels separate Analyse ($0.05), new artwork ($0.20 for two image requests) and saved conversion ($0.00). No local dollar caps are applied. Cancellation cannot guarantee that an already dispatched request was unbilled. An unavailable or revoked invite does not prevent play with built-in or already accepted fighters.

For native play, use the [desktop authoring setup](#set-up-native-desktop-authoring) below.

### Draw, review, generate and accept

1. Open **CHARACTER FORGE**, or **DRAW / IMPORT** for the desired lobby player.
2. Enter your preferred **Fighter name** and describe its body, colours and **weapon concept (guides art)**. Draw on the canvas or import your own PNG/JPEG. Keep the preferred name explicit so it can be retained in the proposal.
3. Choose Analyse for a suggested design, or enter the settings yourself. Review the name, upright/four-legged/floating body, theme and suggested ability family before generating.
4. Choose Generate when those settings are right. New generations create a complete illustrated character followed by environment artwork. The character cutout becomes the sprite and portrait; 32 authored whole-body poses preserve its design. Combat still uses the six supported families. A weapon description does not create arbitrary new attack code or grant flight.
5. Inspect the returned animation preview, including run, attacks, downed and revive poses. Check that the silhouette and theme remain readable in motion.
6. If needed, edit the Master mask/pivot with **Erase**, **Restore** or **Joint**, then **Apply edits · local bake**. Older parts-based fighters still expose their individual parts. Inspect the new animation again.
7. Choose **Accept fighter & play**. This saves the validated bundle in **Your fighters** and opens the lobby with that fighter selected. Choose **START RUN** to enter combat.

Conversion and acceptance are separate. A successful conversion creates a preview; it does not by itself install the fighter. Cancelling or rejecting a candidate preserves accepted fighters.

A swordsman/spearman concept uses melee kits such as **Stone**; a wizard uses projectile kits such as **Frost**. You can select a compatible family before generating. These remain the six game-owned combat families. Older named fighters with incompatible kits are corrected at runtime without rewriting their accepted artwork.

### Correct a retained drawing or image layout

For an older draft, **Use detailed character cutout PNG** imports a transparent full-character PNG (32–2048 pixels per side, at most 8 MB). It creates a fresh correction draft and retains the older job. An opaque background crop needs a genuine transparent cutout first. Edit the Master mask/pivot in the preview; background and material crops can be corrected separately. Whole-body poses transform the cutout rather than animating independent limbs.

![Cached image-layout correction with crop targets and opacity controls.](screenshots/layout-correction.png)

If a generated board does not match the expected arrangement, use **Correct cached layout** instead of generating it again:

1. Select the complete-character **Master** crop and drag around its visible artwork. For older parts-based jobs, check every body part as well.
2. Review the background and material crops. Keep scenery out of the character pieces.
3. Adjust the opacity cutoff if faint haze surrounds the artwork. Every part and the master must still contain visible pixels above that cutoff.
4. Save and convert. A simple click without dragging preserves the previous crop. An empty crop remains selected in the editor with an explanation; correct it rather than repeatedly saving unchanged inputs.
5. Review the animation preview, make any part-mask/joint edits, then **Accept fighter & play**.

This uses retained raw images in a new correction draft and makes no new image request. In the browser, correction uploads go to the hosted worker's conversion service; native correction runs locally. If parts have already been converted, changing their original crop recipe requires a new correction draft. Keep the earlier preview until the corrected one is ready.

### Back up and import a fighter ZIP

1. In **CHARACTER FORGE → Your fighters**, choose **Download fighter ZIP** on the fighter you want to keep. Store the downloaded ZIP somewhere you control.
2. In the destination browser, open **CHARACTER FORGE** and choose **Import fighter ZIP**.
3. Select the original ZIP. The game validates the complete six-file bundle; after success, select the fighter from **Your fighters** in the lobby.

A fighter ZIP preserves that accepted fighter's playable bundle. It does **not** include Story checkpoints, settings, scores, an active run, private source drawings or hosted drafts. Import rejects invalid or oversized archives and preserves previous fighters. Do not unpack or modify the ZIP before importing it.

<span id="saves"></span>

## 7. Saves, offline play and leaving safely

| Data | Browser | Native desktop |
| --- | --- | --- |
| Arena coins, upgrades, current wave and run power | End on refresh/close or a new/restarted run; Home retains the current page's paused game. | End with a new/restarted run or closing the game; no mid-run Continue. |
| Accepted fighters | Stored in this browser; use fighter ZIP download/import for a portable backup. | Stored in the local fighter library and reusable offline. |
| Forge drafts and cached images | Private hosted jobs remain on the server for review/recovery. | Retained in local authoring data for review/recovery. |
| Settings and recorded scores | Browser storage, separate from temporary run power. | Per-user application data, separate from temporary run power. |
| Story campaign | Checkpoint progress in this browser; Continue validates it before loading. | Checkpoint progress in per-user application data; Continue validates it before loading. |

### Browser saves and offline limits

Saves belong to this browser profile and website origin. Other browsers, private windows and other computers do not automatically share them. Clearing site data removes local settings, scores, Story checkpoints and accepted fighters. There is no cloud save synchronization or whole-save export. Download each accepted fighter ZIP before clearing data or switching browsers.

If browser storage is blocked or unavailable, the game shows a persistence warning and can still be played; do not rely on that session surviving a refresh. Allow storage for the site and restart before expecting durable saves. Reimport accepted fighter ZIPs if necessary.

The game must finish loading before it can play without the network. There is no service worker or guaranteed offline reload. Hosted Forge operations need a network connection even when the loaded game remains playable.

### Native save locations

Godot stores player data in its per-user application-data directory, not beside the executable. Forge's `fighters/` and `forge_jobs/` contain accepted characters and drafts. Optional authoring keeps its request-accounting history below its own `build/forge/` folder. Preserve these files when moving installations; never upload private drawings or a key file as a bug-report attachment.

Story saves keep a validated previous-save backup. If the game offers backup recovery, read the message and choose it explicitly. If a save fails, play can remain open: retry after fixing storage permissions/space. The Story title/exit flow distinguishes retrying from explicitly discarding unsaved progress. Starting a new journey can replace the current campaign, so use Continue when you intend to resume.

<span id="troubleshooting"></span>

## 8. Troubleshooting

| Problem | What to check |
| --- | --- |
| Browser says WebAssembly or WebGL 2 is unavailable | Use a current desktop Chromium/Firefox browser with graphics acceleration available. The website remains readable without launching the game. |
| Game loading stalls or the loader cannot download | Read the visible error. Wait for progress or choose **Retry loading** explicitly; it reloads the page. Check your connection before retrying. |
| Browser controls scroll the page or the fighter does not respond | Select the game canvas to focus it, confirm the assigned player input and release held keys before resuming. |
| Fullscreen is unavailable or exits unexpectedly | Keep playing in the browser window or retry the toolbar's **Fullscreen** button. Browser Escape/F11 behavior may differ from native play. |
| Browser warns that saves will not persist | Allow site storage and check available space. Play is possible, but do not expect progress to survive refresh while the warning remains. |
| Browser saves disappeared | Check the same browser profile and website address. Clearing site data removes local saves; import previously downloaded fighter ZIPs to restore those fighters. |
| Website movement is uncomfortable | Use the website motion control or your system's reduced-motion preference. Set **REDUCED FLASH/SHAKE** separately inside the game. |
| Creator invite is rejected or hosted Forge is unavailable | Read the service message and contact the invitation issuer if needed. Built-in and accepted fighters remain playable; avoid resubmitting an uncertain paid job. |
| Fighter ZIP import is rejected | Choose the original downloaded fighter ZIP, not a general archive or extracted files. Previous fighters remain intact; read the validation message. |
| Godot opens another project or says no project exists | Pass the folder that contains `project.godot`: `--path .` from inside it, or the full path from elsewhere. |
| A fight is too fast or too punishing | Use the Game speed, Damage taken or press-to-toggle attack options in Arena settings. See the [Accessibility guide](ACCESSIBILITY.md). |
| Read menus aloud stays off | Native Linux needs a system voice such as speech-dispatcher plus espeak-ng, then a restart. Browser voice availability depends on the browser/OS; read the in-game message. |
| Story Mode is missing | You may be running an older arena-only package. Use the build whose home has **STORY MODE (2 PLAYERS)**. |
| One player cannot move or confirm | Check that player's assigned input. Shared menus have an owner; personal shops use each player's own controls. |
| Two keyboard players lose simultaneous actions | Test different bindings or use a controller; keyboard rollover varies by hardware. |
| A controller disconnects | Reconnect it or select a free input on the recovery screen, then resume deliberately. Held buttons may need releasing first. |
| Arena has not cleared although your view is empty | Check for offscreen enemies and arrival warnings. A wave needs no queued, arriving or living enemies. |
| An Arena player cannot move between waves | Their own shop is still open. Choose Explore; Interact reopens it later. |
| Story exit or bridge does nothing | For an exit, rally both living couriers. For a bridge, activate two different anchors, one per courier. |
| Story dash does nothing | Defeat the Spoolwarden first. Threadstep is a shared story unlock. |
| Native Forge says tools/Python are unavailable | Keep `authoring/` beside the package and run its setup helper, or install the source authoring dependencies. |
| Analysis/generation reports key, model, account or quota failure | Native: check your private configuration and provider account. Browser: contact the service operator. Do not repeatedly submit an uncertain request; built-ins and accepted fighters remain playable. |
| Save/convert keeps returning to the crop editor | Read the visible crop error, select its part/master and adjust the rectangle or cutoff. Saving unchanged empty pixels cannot fix it. |
| Converted fighter is not in the lobby | Finish preview review and choose **Accept fighter & play**; conversion alone is not acceptance. |
| Required assets fail validation or scenery is missing | Re-extract a complete matching package. For source, import resources with Godot 4.7.2; do not mix files from different releases. |

## Native desktop setup

This guide covers the current browser release and source build with **STORY MODE (2 PLAYERS)** on the home screen. The older **v0.4.0-counterplay Linux download** lacks Story Mode, the newer accessibility settings and the latest fighter creation. Check a build's `BUILD.json` for its source revision.

### Run the native source

Install Godot **4.7.2 standard** (not the .NET build) from [godotengine.org](https://godotengine.org/download) or your package manager, then get the game:

```sh
git clone https://github.com/9MidhunPM/GloamThread.git
cd GloamThread
```

Import its resources once after a fresh download, then launch. Run these from inside the `GloamThread` folder:

```sh
godot --headless --path . --editor --import --quit
godot --path .
```

From any other folder, replace `.` with the full path to your copy, for example `godot --path ~/Games/GloamThread`. For an Arena window instead of fullscreen:

```sh
godot --path . --windowed --resolution 1920x1080
```

### Run an extracted Linux package

Extract the **whole ZIP** into a writable folder. Open a terminal in that folder:

```sh
chmod +x ./Gloamthread.x86_64
./Gloamthread.x86_64
```

You can also run the executable by its absolute path from another directory. Keep `authoring/` beside it if you want optional generation. Playing built-in or already accepted fighters needs no installed Godot, Python, account, API key or network connection.

The package targets Linux x86_64 with OpenGL Compatibility rendering. If automatic display selection fails, try `./Gloamthread.x86_64 --display-driver wayland` on Wayland or `--display-driver x11` on X11. Arena supports **F11** to toggle fullscreen. Story uses its original 960×360 logical split-screen layout; returning to Arena restores its 1920×1080 presentation. Letterboxing preserves the pixel-art proportions.

### Set up native desktop authoring

For an extracted package, run this from its folder:

```sh
bash setup_authoring.sh
authoring/.venv/bin/python authoring/tools/fighter_forge.py status
```

Add your own `OPENAI_API_KEY` locally in `authoring/.env`. Setup preserves an existing file and never prints its key. For this source checkout:

```sh
cd GloamThread
python3 -m venv --system-site-packages .venv
.venv/bin/python -m pip install -r requirements-authoring.txt
.venv/bin/python tools/fighter_forge.py status
```

Source authoring reads the private `.env` in that checkout. Keep an existing key file intact. The status command reports configuration safely without making a model request.

There is **no local total or per-character dollar cap**. Earlier allowance settings no longer block generation. Recorded request estimates and uncertain outcomes remain history, not billing receipts. Analyse/Generate are deliberate actions; automatic retries and model fallback remain disabled. Provider account limits can still reject a request. Cancellation stops later work but cannot guarantee that a request already in flight was unbilled.

## Evidence and feedback

Screenshots illustrate real captured game states. The retained Arena shop/split scenes are controlled native setups. Story title/join/Lantern Rest images cover the freshly restored entry flow; the bridge image comes from the original campaign route. They do not establish a fresh full human playthrough of the combined mode-switch build.

For the current implementation, exact checks and limitations, see [STATUS.md](STATUS.md). Physical gamepads/hotplug, keyboard hardware rollover, fresh-human balance, listening quality and other hardware/distributions remain separate acceptance questions. When reporting a problem, include browser/OS or native platform, mode, source revision from `BUILD.json`, player/input assignments, what you pressed and what happened. Keep credentials, invitation codes and private artwork out of shared logs or screenshots.
