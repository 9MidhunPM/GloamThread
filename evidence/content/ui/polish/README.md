# Menu polish — retained rendered evidence

25 October 2026. Source base `34ccb96`, branch `feat/phase1-polish`; the completed milestone commit follows these checks. These captures use the original fixed art before its overhead replacement. No overhead gameplay claim is made by this UI fixture.

The home screen now pairs a compact action list with a project-authored Ember/Moss loom vignette and animated courier art. It retains the supplied title/body/actions. All four normal application choices fit even with a long unavailable-save diagnostic; the diagnostic has a two-line summary and a full mouse tooltip. Operational menus keep full width, identify their input owner and preserve the original input/flush/action interface. Home keycaps follow each player's real bindings, including remapping. The vignette creates no gameplay actor, World2D, collision, sound or reward state.

Commands run:

```sh
godot --headless --path . --editor --import --quit
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd --log-file /tmp/gloamthread-polish-baseline.log
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd -- --filter ui_
godot --headless --fixed-fps 60 --path . --script tests/run_tests.gd
python3 tests/ui/native_menu_check.py --xvfb /tmp/gloamthread-ui-x11/runtime/usr/bin/Xvfb --xdotool /tmp/gloamthread-ui-x11/runtime/usr/bin/xdotool --library-path /tmp/gloamthread-ui-x11/runtime/usr/lib --output /tmp/gloamthread-polish-ui-captures
node /home/midhun/.agents/skills/impeccable/scripts/detect.mjs --json scripts/ui/game_menus.gd scripts/ui/title_vignette.gd
python3 tools/check_pack.py
git diff --check
```

Baseline: import and 20 existing engine scenarios PASS. Final: **21 scenarios PASS**, including three UI scenarios. The added case checks home-list/illustration separation, all four actions visible with long save detail, both default attack labels, remapped attack label refresh, full-width restoration and actual owner badge. Initial fixture compilation/type mistakes were corrected before the successful run. A native inspection caught an old container minimum width overlapping the illustration; rebuilding and shrinking the content before resizing the scroll area fixes it. The long-detail regression then caught a one-pixel bottom overflow, fixed by reserving the available title-only height.

The complete native helper passes on a private Xvfb display with Godot 4.7.2 Compatibility, Mesa llvmpipe and Dummy audio. Nine distinct nonblank fixture states render; settings window/framebuffer match, partner input is ignored, owned keyboard/mouse actions match, cancel/title/quit exits 0, settings scale exactly at 2×, and long prompts wrap into two footer lines. See [results](captures/results.json) and [title](captures/1x/title.png). All selected captures are actual engine/window output; no screenshot was painted or composited. Menu animation is decorative and is not a gameplay timing test.

The mechanical design detector returned `[]`; it has limited applicability to GDScript and is not visual-quality proof. Pack/link and whitespace checks pass. Physical controllers, keyboard rollover, audio listening, actual-app overhead flow and human acceptance remain separate. Agent 1 owns runtime integration and candidate packaging; later overhead art needs a fresh native review.

Peer review caught a misleading initial vignette caption that offered "Choose" to both players. Those captions now explicitly say "IN GAME" and preview attack bindings only; the owner footer alone provides menu confirmation. A regression assertion and final native rerun cover that distinction.
