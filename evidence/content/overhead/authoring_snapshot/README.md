# Overhead authoring studies — no gameplay evidence

25 October 2026. `tools/gen/preview.py` now composes overhead material/pose studies from manifested PNGs and matching room data. It fixes the old utility's side-view tile names, bottom-only crop and feet offset. Materials use the new floor/wall/water/hazard/bridge slots; feet are tile×16+(8,13), the crop clamps both axes, and foreground props/actors share a feet sort. Captions use only the manifested original bitmap font.

```sh
python3 tools/gen/preview.py --room r00 --output /tmp/gloamthread-preview-studies
python3 tools/gen/preview.py
python3 -m unittest discover -s tools/tests -p 'test_preview.py'
python3 -m unittest discover -s tools/tests -p 'test_*.py'
```

`--room r00` supports the one-room milestone. Without selection, every listed world room must use `overhead-v1`. The default output is **evidence/content/overhead/authoring**, keeping the old side-view authoring images intact. All requested data/PNG decoding and composition completes before writing. Wrong epochs, missing early/late assets and invalid room selection produce actionable failures without replacing existing studies. This is not a transactional guarantee against a disk failure during image writes.

This retained example and its hashes live in the separate **authoring_snapshot** directory. The default command never writes here, so later studies cannot silently replace the PNG while leaving its input hashes stale.

**112 Python tests PASS** (46.090 seconds), including nine public-CLI cases for materials, feet, sorting, both-axis cropping, repeated output, version guards, missing data, selected-room behavior and historical-evidence preservation. The latter regression first failed when the old default replaced a sentinel; the versioned output directory fixes it. Python compilation, independent review, pack/link and whitespace pass.

The actual Agent 2 checkout still has the older room/world epoch, so its selected-room command correctly exits 1 before output. Separately, a read-only snapshot of Agent 1's new r00/world and the current PNG pack successfully generated [this r00 study](r00_themes.png). [Input/output hashes](inputs.json) identify the working-tree snapshot and tool exactly; the noted Git head is context, not a claim that every input was committed there.

The retained PNG is explicitly labelled **AUTHORING ONLY / NO PHYSICS**. It shows basic material slots and idle poses, not the engine's complete tile-edge selection, camera, UI, movement, collision, interactions, combat, sound or performance. It cannot substitute for an ordinary-control overhead playthrough or native captures.
