# Entire Story autoplay evidence

Godot4.7.2 /Compatibility /original Tavi+Neri campaign. No API calls. The production campaign route remains unchanged except an overridable description for accurate dialogue logging; the showcase adapter adds ordinary-input Gallery cleanup and a staircase detour for the secret.

```sh
./story_showcase.sh --smoke --report /tmp/gloamthread-story-showcase-smoke-final.json
godot --path . --display-driver wayland --script evidence/story-showcase/native_qa.gd -- --mode smoke --speed 4 --report /tmp/gloamthread-story-showcase-native-final.json
godot --headless --path . --fixed-fps 60 --script evidence/story-showcase/cancel_qa.gd -- --mode smoke --report /tmp/gloamthread-story-showcase-cancel.json
```

- `smoke.json`: completedtrue,12,305 unpaused route physics steps, all eight rooms, both bridges, charm, Spoolwarden, Threadstep, Loom and return-home ending. Valid temporary save; zero recoveries; final hearts4/3; zero failures/engine errors.
- `native.json`: same complete route on actual Wayland/Compatibility at4x,12,198 steps, same milestones/hearts, zero failures/engine errors. The fixture sends key events directly to the real overlay handler: pause and frozen route both true, then resume and4x. It forces actual viewport rendering for three PNG captures. These are960×420 logical viewport captures: the original960×360 split views plus a60px viewing banner. First qualifying frames can precede a HUD/banner refresh by one frame. One cosmetic missing xdg-toplevel-icon warning; no audio/cleanup warning. This is native rendering/control-handler evidence, not physical keyboard/gamepad, listening or performance proof.
- `cancel.json`: deliberate early exit at step101; completedfalse/interruptedtrue, no failures/errors, valid temporary save before cleanup. Partial viewing is not called completion.
- Launcher shell syntax, help from another directory and invalid-argument rejection pass. All reported source hashes match the retained code. No room/actor teleports, granted unlocks, invulnerability or debug damage/healing. Checkpoints and rewards use normal interactions; actual Next actions show every active authored dialogue line. Visible default mode allows reading time and holds the ending card; smoke advances text quickly.

Personal campaign/settings files are never used: each run creates a unique temporary directory, validates the real save, then removes it. The report stays at the requested path. Human play/enjoyment and physical devices remain unverified; this does not add regions beyond the existing eight-room campaign or produce another binary release.
