# Accessibility guide

Gloamthread offers remapping, assists and comfort settings for different ways of playing. Open **SETTINGS & CONTROLS** from the home screen or pause menu. Assists, toggle attack, high contrast and narration start off; game speed and damage taken start at 100%. Settings are saved separately from run progress.

![Arena settings with sight/sound and assist/control columns.](media/accessibility-settings.jpg)

*Real Movie Maker capture of the Arena settings screen with high contrast on and three assists selected. Watch the one-minute [accessibility tour](VIDEOS.md#accessibility-tour).*

## Quick reference

| Need | Option | Where |
| --- | --- | --- |
| One hand, a different layout or a non-standard keyboard | **P1/P2 CONTROLS: REMAP KEYS** | Arena settings; Story **Player N controls** |
| Holding a button is tiring or painful | **P1/P2 ATTACK: PRESS TO TOGGLE** | Arena settings |
| More time to react | **GAME SPEED: 100% / 80% / 60%** | Arena settings |
| Fights are too punishing | **DAMAGE TAKEN: 100% / 75% / 50% / 25%** | Arena settings |
| Low vision or glare | **HIGH CONTRAST** | Arena settings |
| Blind or low vision | **READ MENUS ALOUD** (system text-to-speech) | Arena settings |
| Photosensitivity | **REDUCED FLASH** | Arena and Story settings |
| Motion sickness | **REDUCED SHAKE** | Arena and Story settings |
| Hearing or noise sensitivity | **MASTER / MUSIC / EFFECTS VOLUME** | Arena and Story settings |
| Drifting stick or unsteady hands | **STICK DEADZONE** | Gamepad remap screen (both modes) |

## Website motion and browser play

The website's motion control pauses its 3D scenery and decorative page animations. It also respects your operating system's reduced-motion preference. This setting belongs to the website; use **REDUCED FLASH** and **REDUCED SHAKE** inside the game to change combat effects and camera movement.

Website links and controls support keyboard focus, and the player guide can be read without starting the game. Browser zoom changes the website and guide; in-game text remains part of the game canvas. The mobile website is readable, but gameplay still needs a desktop/laptop keyboard or controller.

Use the game toolbar's **Fullscreen** control in the browser. **Home** pauses and retains the game on the same page; **Resume game** brings it back. Leaving the tab pauses combat and clears held input. Refresh ends the current run. Browser storage warnings, save limits and recovery steps are in the [Player Guide](PLAYER_GUIDE.md#saves).

## Moving around the menus

- **Keyboard / gamepad:** Up/Down (W/S, arrows or the stick) moves; Jump, Attack or Interact confirms. On a value such as volume or game speed, **Left/Right** changes it in place without losing your position.
- **Mouse:** every button can be clicked. Clicking a value steps it forward and wraps around.
- **Hints:** the focused option explains itself in the line above **BACK**, and as a mouse tooltip.
- Changing a setting keeps the cursor where it was, so you never have to navigate back from the top.

## Remap controls

Choose **P1 CONTROLS: REMAP KEYS** (or P2), select an action, then press the new key or button on **that player's** input. Escape (or Start on a gamepad) cancels.

- Actions you can move: Move Left/Right, Up, Down/Drop, Jump, Attack, Special, Dodge and Revive/Shop.
- **Pause stays fixed** (Escape / Enter / Start) so a menu is always reachable.
- A key that already does something else for you, or that belongs to the other keyboard player, is **refused with a message**. Nobody silently loses a control.
- A gamepad movement button keeps the analogue stick working alongside it.
- **RESET TO DEFAULTS** restores the original layout. The lobby and settings screens always print your **live** bindings.
- Remapped controls are shared with Story Mode, which has its own **Player N controls** screen with the same rules.

**Choosing a hand.** In **SOLO RUN**, the lobby's **P1 INPUT** button cycles the left keyboard side (WASD, Space, F, G, Shift, E), the right side (arrows, Period, Comma, Slash, Apostrophe, M) and any connected gamepad, so you can play right- or left-handed without remapping.

**One-handed ideas.**

- *Left hand:* the default left side already sits under one hand. Turn on **PRESS TO TOGGLE** attack so only movement needs holding.
- *Right hand on the keypad:* remap P1 to keypad keys, which no other player uses: `Kp 4`/`Kp 6` move, `Kp 8` up, `Kp 5` down, `Kp 0` jump, `Kp 1` attack, `Kp 2` special, `Kp 3` dodge, `Kp Enter` revive.
- *Controller only:* every menu, shop and remap screen works with a gamepad, including choosing buttons for each action.

Keyboard hardware may not report many keys pressed at once (*rollover*). If a combination fails, try other keys or a controller.

## Assists

| Assist | What it changes | What it does not change |
| --- | --- | --- |
| **Press-to-toggle attack** (per player) | One Attack press starts repeating basic attacks; the next press stops. The HUD shows **AUTO-ATTACK** while it is on. | Specials, dodge and revive still use a normal press. |
| **Game speed** 80% / 60% | Slows the whole simulation (enemies, projectiles, timers and you) so there is more time to read tells. Menus stay responsive. | Combat rules, damage and wave contents. Returns to 100% automatically when you leave the run. |
| **Damage taken** 75% / 50% / 25% | Every player takes less damage from enemies. | You can still be downed; there is no invulnerability setting. Enemies are not weakened. |

Runs with reduced damage or speed are marked **ASSISTED RUN** on the results screen and in your saved run records. Nothing is locked or hidden because of an assist.

## Seeing the game

- **High contrast** brightens secondary text to full ink, thickens every menu/HUD outline, lifts dim borders and makes backdrops behind menus nearly solid. Toggling it mid-run immediately redraws the HUD.
- **Player identity is never colour-only.** Each fighter carries a pixel **P1 / P2** label under its feet, and HUD panels are labelled by player.
- **Enemy tells use shape and position as well as colour:** charge lanes are drawn on the ground, flyer dive points are marked, heavies show guard brackets. See [Enemy mechanics](ENEMY_MECHANICS.md).
- Native Arena uses a 640×360 world at 3× scale for 1920×1080 and letterboxes other screens. **F11** toggles native fullscreen; a window can be started with `--windowed --resolution 1920x1080`. The browser fits complete world pixels to the available canvas; use its fullscreen toolbar.

## Hearing the game

- **Read menus aloud** speaks the focused menu item and its hint, screen titles, shop items with prices, wave starts/clears, a downed partner and notices. It uses your operating system's text-to-speech voice at the master volume.
- Native narration needs a system voice. On Linux install **speech-dispatcher** plus a voice such as **espeak-ng** (`sudo pacman -S speech-dispatcher espeak-ng`, `sudo apt install speech-dispatcher espeak-ng`, or `sudo dnf install speech-dispatcher espeak-ng`), then restart the game. If no voice is found the option stays off and says why. Voice availability in a browser depends on that browser and operating system; audible browser narration has not been verified.
- Important information is always shown as text as well as sound: wave numbers, countdowns, coin rewards, revive prompts, boss names and bars.
- The [intro video](VIDEOS.md#intro) has burned-in captions and a full transcript.

## Comfort

- **Reduced flash** halves effect brightness, removes extra sparks and stops invulnerability blinking.
- **Reduced shake** removes camera shake from hits and boss slams.
- **Pausing:** Escape / Enter / Start pauses at any time, and losing window focus pauses automatically. Nothing advances while paused; there is no wall-clock catch-up.
- A disconnected controller pauses the run until it is reconnected or another input is chosen.

## Story Mode

Story Mode shares your volume, reduced flash/shake and remapped controls, and has the same remap refusal rules plus a gamepad deadzone. Arena-only options (assists, high contrast, narration, toggle attack) do not apply inside Story yet.

## Known limitations

- Narration has been verified to report a missing voice correctly, but **audible speech has not been tested** on a machine with a voice installed.
- Buttons carry accessible names and descriptions for screen readers (Godot AccessKit), but the game has **not been tested with a screen reader** such as Orca, NVDA or VoiceOver. The built-in narration is the supported path.
- Text size is fixed by the 1920×1080 layout; there is no separate font-size slider.
- Physical controllers, keyboard rollover and assists have not been playtested with disabled players. Feedback is welcome through the repository's issue tracker.
