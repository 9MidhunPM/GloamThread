# Shared GameMenus integration

UI branch: `feat/phase1-ui`, based on runtime commit
`17e59e583253af82cc379ee22ef9e48714c7b054`. This is a separate UI vertical;
the full content branch remains preserved. Merge this branch into Agent 1's
current runtime with its full content/event corrections, not over those changes.

## Public component

`scripts/ui/game_menus.gd` provides `GameMenus extends CanvasLayer`:

```gdscript
signal action_requested(action: String, payload: Variant)
func set_font(font: Font) -> void
func show_menu(kind: String, title: String, body: String,
               rows: Array[Dictionary], owner_slot: int = 0) -> void
func hide_menu() -> void
```

The application must pass the original Font and an assigned owner slot before
showing keyboard/gamepad menus. The renderer accepts nonempty kind identifiers;
the application supplies title/join/pause/map/dialogue/settings/reconnect/ending
content and owns device, campaign, settings, pause and persistence decisions.
It does not automatically hide after emitting an intent.

Rows require unique nonempty string `id` and `label`; `detail` defaults to empty,
`enabled` to true and `adjustable` to false. Malformed rows/owners retain the
current menu and report an error. Display text uses ASCII plus the original
replacement glyph for unsupported characters, without a system-font fallback.

- JUMP or INTERACT: row ID, null payload; both pressed together emit once.
- PAUSE: `cancel`, null payload, with priority over confirmation.
- LEFT/RIGHT on an adjustable row: row ID and `{direction: -1|1}`.
- UP/DOWN: select enabled rows, skipping disabled entries. At list boundaries,
  navigation scrolls long content. Direction repeats immediately, after 18 ticks,
  then every six ticks. Opposite directions cancel; confirmation never repeats.

Only the owner's immutable snapshots navigate. Both player streams are flushed
on shared-menu entry, exit and owner/mode changes to prevent held gameplay input
leaking into a new mode. Same-kind updates preserve selected ID and scroll,
including an owner handoff; repeated snapshot reads do not duplicate actions.
The component processes while the tree is paused but never changes tree pause.

Native keyboard focus is disabled on controls. Mouse selection/clicks use the
same enabled/generation guards; old queued rows cannot activate a new screen.
Font scales are integral (24px title, 16px body/actions, 8px details/prompts),
inside a 960x360 overlay with 24px outer safe margins and a scrolling content area.

## Core checkpoint verification

Environment: Godot `4.7.2.stable.arch_linux.ed1daf0bf`, 60 Hz physics, Linux.

```sh
godot --headless --path . --editor --import --quit --log-file /tmp/gloamthread-ui-baseline-import.log
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-ui-red.log -- --filter ui_menus
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-ui-core-suite.log
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/check_pack.py
git diff --check
```

Baseline import passed; four existing scenarios and 15 Python tests passed.
The new scenario initially exited 1 for the missing component. The final core
suite passes all five scenarios, including 13 UI behavior groups. Negative row
fixtures intentionally emit GameMenus error messages; those expected diagnostics
are separate from scenario failures. The public signal/input tests cover both
owners, disabled/empty/malformed data, payloads, repetition, flushing, owner
handoff, paused operation and selection preservation. Pack/whitespace pass.

A direct `--script scripts/ui/game_menus.gd --check-only` invocation does not
initialize project autoload globals and reported `InputRouter` missing. The
normal project scenario runner loads the component successfully with autoloads;
that is the valid component compilation/execution check.

Native rendered layouts, long-layout/mouse cases and actual window input are
the next UI gate. Physical controllers, keyboard rollover and full application
flows are not established by synthetic component scenarios. Agent 1 retains
authoritative integrated imports, sidecars, application wiring and main release.
