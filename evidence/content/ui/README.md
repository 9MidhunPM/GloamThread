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

Rows require unique nonempty string `id` and nonempty string `label`; `detail` defaults to empty,
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
Font scales are integral (24px title, 16px body/actions/details, 8px prompts),
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

## Completed component layout and native-window QA

The cumulative follow-up adds `ui_layout.gd`: 11 additional behavior groups,
including original-font use, all-control focus isolation, nine fixture kinds,
long wrapping/scrolling, unsupported-glyph replacement, invalid owner/font
handling, callback screen changes, stale mouse/deferred callbacks and snapshot
deduplication. Both UI scenarios pass; the complete branch runner passes six
scenarios (four existing plus two UI), covering 24 UI behavior groups.

Recoverable validation now emits warnings while retaining `last_error` and the
existing menu, so Agent 1's stricter runtime-error logger can catch actual script
crashes without confusing malformed-row fixtures with crashes. The earlier core
checkpoint used intentional error diagnostics before this integration correction.

Native 960x360 review found and corrected an invisible scroll thumb and overly
small value/binding text. All details now use 16px, the scrollbar has an explicit
8px width and content inset, and long footer prompts wrap into two lines. Mouse
hover requires actual motion; rebuilding beneath a stationary pointer does not
steal keyboard selection. Navigation scrolls through a selected row's long text
before moving onward. The API and application ownership are unchanged.

The Agent Workspace connector was unavailable in this session. Rendered QA used
a new private Xvfb X11 display, Godot Compatibility and Mesa llvmpipe software
rendering, with Dummy audio. Xvfb 21.1.25-2 and xdotool 4.20260303.1-1 were
unpacked from official Arch tool packages into `/tmp`; no system packages or
game-content packs were installed. No host display/focus was controlled.

Reproduce with installed QA tools:

```sh
godot --path . res://scenes/ui/menu_preview.tscn -- --menu settings
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd -- --filter ui_
python3 tests/ui/native_menu_check.py
```

Exact invocation used here with the private tool binaries:

```sh
python3 tests/ui/native_menu_check.py --xvfb /tmp/gloamthread-ui-x11/runtime/usr/bin/Xvfb --xdotool /tmp/gloamthread-ui-x11/runtime/usr/bin/xdotool --library-path /tmp/gloamthread-ui-x11/runtime/usr/lib
```

The helper requires Godot, Xvfb, xdotool, ImageMagick `import` and Pillow. It
starts its own display, checks window PID ownership, captures actual framebuffer
and window pixels, sends X11 input, and closes its processes in `finally`.
It initially failed to find the debug-suffixed window title; prefix matching
plus the PID check corrected that harness issue before the successful run.

Results are in [captures/results.json](captures/results.json):

- All eight assigned menu kinds and a controls/remapping subpanel rendered with
  the original font at 960x360; native captures are under `captures/1x/`.
- The physical 1x window matches Godot's framebuffer pixel for pixel and contains
  eight colours. The helper asserts framebuffer equality and visible colour
  variation before input/scaling checks, preventing blank-window false positives.
- Non-owner P2 Down/period/M/Return left the rendered pixels unchanged and emitted
  no action. P1 D/S/A then mouse adjustment emitted exactly music +1, effects -1,
  effects +1. Native cancel -> title -> quit then exited with code 0.
- The 1920x720 window matches the 1x layout exactly after nearest downsampling;
  each physical 2x2 pixel block is identical. No filtered or uneven scaling.
- Synthetic long prompt labels render in exactly two footer lines, captured in
  `captures/long_prompts.png`. Those stress labels are not real key names.
- Native logs contain no unexpected engine/script errors. The software X11
  driver reports unsupported V-Sync; no performance claim is inferred from it.
- The helper and the earlier manual display/apps were all stopped after QA.

These are actual renders and automated window inputs in an isolated **UI
fixture**. Its values/actions stay in memory; it does not prove application save,
join, pause, map, dialogue or campaign semantics. Physical gamepads, real keyboard
rollover and human acceptance remain separate. Agent 1 retains authoritative
integrated imports, sidecars, application wiring and main release.
