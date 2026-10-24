# Gloamthread: Two Ends — Linux demo candidate

Two players share one physical world, seen through Ember and Moss. Restore the Lantern Loom and return home together. This is a complete eight-room playable candidate for fresh-pair testing; human balance and enjoyment are not yet accepted.

## Launch

Extract the whole archive, then:

```sh
chmod +x Gloamthread.x86_64
./Gloamthread.x86_64 --display-driver x11
```

Tested on Arch Linux / Hyprland with XWayland, Intel Core Ultra 7 255H and Intel integrated graphics, Compatibility/OpenGL. Godot, Python, accounts, keys and a network connection are not required by the packaged game. Other Linux distributions/hardware remain unverified. Native Wayland source QA was slower on the build laptop; X11/XWayland is the verified release baseline.

Choose **New journey**, confirm each player's distinct input source, then **Begin journey**. Use Up/Down to select, Jump or Interact to choose, and Pause to go back. Mouse selection is also available. Only the menu owner navigates a shared screen.

| Action | Keyboard left (P1) | Keyboard right (P2) | Gamepad defaults |
| --- | --- | --- | --- |
| Move | WASD | Arrows | Left stick / D-pad |
| Jump | Space | Period | A |
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

Continue loads the last safe checkpoint with permanent team progress. Campaign data and settings are separate in Godot's per-user application-data directory. A valid backup is offered explicitly if the active save is damaged. Save errors remain visible; title/quit offers retry or explicit discard of unsaved progress.

## Evidence and limits

Automated real-physics routes complete all eight rooms and the actual ending without actor warps or forced rewards. Software checks cover both specials, Cross-stitch, revive/wipe ordering, ownership, save faults and the cosmetic secret. These results do not establish physical controller handling, hardware rollover, audio listening or fresh-pair usability. The 15–20 minute first-clear target, balance and fun remain unverified. Please treat this as a playtesting candidate.

The exact source revision and executable hash are in `BUILD.json`. Original asset provenance is in `ASSET_PROVENANCE.json`; editable generators, maps, writing and audio sources are retained at [9MidhunPM/GloamThread](https://github.com/9MidhunPM/GloamThread). See `THIRD_PARTY_NOTICES.md` and the included engine licenses. No game-content packs or external runtime services are used.
