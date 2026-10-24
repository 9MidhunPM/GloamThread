# Gloamthread: Two Ends — overhead development build

Two players share one physical world, seen through Ember and Moss. Restore the Lantern Loom and return home together. This branch is the original overhead redesign, version 0.2.0-dev. Its full ordinary-input route, native export and human play acceptance are still being verified. The published v0.1.0-demo is the separately preserved side-view game.

## Launch

Extract the whole archive, then:

```sh
chmod +x Gloamthread.x86_64
./Gloamthread.x86_64 --display-driver wayland
```

The preserved side-view release was tested on Arch Linux / Hyprland with native Wayland and XWayland, Intel Core Ultra 7 255H and Intel integrated graphics, Compatibility/OpenGL. New overhead native evidence is recorded separately. Godot, Python, accounts, keys and a network connection are not required by the packaged game. Other Linux distributions/hardware remain unverified. The official release template is the play baseline; editor/source-build timings differ. On an X11 desktop use `--display-driver x11`.

Choose **New journey**, confirm each player's distinct input source, then **Begin journey**. Use Up/Down to select, Roll or Interact to choose, and Pause to go back. Mouse selection is also available. Only the menu owner navigates a shared screen.

| Action | Keyboard left (P1) | Keyboard right (P2) | Gamepad defaults |
| --- | --- | --- | --- |
| Move | WASD | Arrows | Left stick / D-pad |
| Roll | Space | Period | A |
| Slash | F | Comma | X |
| Special | G | Slash | B |
| Interact / hold revive | E | M | Y |
| Threadstep after unlock | Shift | Apostrophe | RB / right trigger |
| Pause | Escape | Enter | Start |
| Map | Tab | Semicolon | Select |

Keyboard sharing depends on physical key rollover. Gamepad configuration/reconnect is implemented and tested synthetically; physical controllers remain unverified. Settings provides remapping, gamepad deadzone, volume and reduced effects. The HUD uses current bindings.

## Journey

Meet Oru, then find the two anchors at Spindle Steps. Each courier takes a different end; there is no tight timing window. Both living players must rally by an exit, then one presses Interact. Fight through Glasswing Gallery and rest at Warden's Landing before the Spoolwarden. Its defeat gives both players Threadstep and opens the shortcut to the Atrium. Return to the remembered upper path, cross Severed Causeway, restore its pair and the Loom, then rally at the home exit for the ending.

At zero hearts a courier has 12 simulation seconds before recovery. Their partner holds Interact nearby for 1.5 seconds to revive. Damage interrupts the rescuer. Both down or timeout returns the team to the checkpoint; permanent restorations survive. Pause also offers deliberate checkpoint recovery.

Continue loads the last safe checkpoint with permanent team progress. Overhead campaign data and settings are separate files under Godot's per-user `Gloamthread-overhead` directory. This preserves the v0.1 side-view saves/settings in their original directory. A valid backup is offered explicitly if the active save is damaged. Save errors remain visible; title/quit offers retry or explicit discard of unsaved progress.

## Evidence and limits

Current overhead checks cover directional actors, validated art/content, shared simulation, introduction, paired anchors, dash corridors, recovery, input and save boundaries. A separate ordinary-input eight-room route is in progress; the completed side-view route is historical evidence only. These results do not establish physical controller handling, hardware rollover, audio listening or fresh-pair usability. The 15–20 minute first-clear target, balance and fun remain unverified. Please treat this as a playtesting candidate.

The exact source revision and executable hash are in `BUILD.json`. Original asset provenance is in `ASSET_PROVENANCE.json`; editable generators, maps, writing and audio sources are retained at [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread). See `THIRD_PARTY_NOTICES.md` and the included engine licenses. No game-content packs or external runtime services are used.
