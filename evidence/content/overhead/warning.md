# Dedicated enemy warning — original art follow-up

25 October 2026. Follow-up to `e85fc2f`, requested by Agent 1's actor lane. Generator 2.1.0, content `overhead-v1`, seed 18427.

Added `effect_enemy_warning_v1`: six 32×32 cells, origin `[16,16]`, padded 216×36 atlas, `play` ticks `[6,6,6,6,6,6]`, nonlooping. The hollow coral/ivory arrow points +X and preserves a steady outline from the first frame. A small travelling stitch supplies progression without a flash or disappearing tell. Transparent interior retains the underlying ground. Quarter-turns preserve the pixel grid.

The runtime must position/rotate the marker for the actual attack and hold its final pose until windup ends. The arrow communicates direction; it is not an exact danger-area mask. It has no gameplay collision or audio of its own. [Native-size contact sheet](contact_sheets/enemy_warning_1x.png) shows authored frames on three material colours plus cardinal rotations, not running-game evidence.

Validation:

```sh
python3 tools/generate_assets.py --seed 18427
python3 tools/validate_assets.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
godot --headless --path . --editor --import --quit
python3 tools/check_pack.py
git diff --check
```

All 50 assets validate; **103 Python tests PASS** in 42.010 seconds, including two complete reproducible rebuilds. Seven focused art cases cover marker bounds/heading/rotation/steady visibility and existing contracts. All 49 previous media file hashes match `e85fc2f` exactly. Provenance metadata updates to retain the changed recipes/code. Headless import, pack/link and whitespace pass.

A new regression first demonstrated that looping transient `play` clips could pass validation. The validator now requires effects to finish, and the regression passes. An actor may explicitly hold a warning's last frame; this does not require an endlessly looping effect. Actual boss/ordinary-enemy placement, timing, reduced-effect readability and encounter fairness remain Agent 1's integration/native acceptance work.
