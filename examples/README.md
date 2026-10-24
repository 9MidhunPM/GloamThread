# Contract illustrations

These JSON files are examples for the implementation agent. They are not shipped game content, complete schemas, scenes, collision geometry, usable sprite assets or a working save loader.

- [fixed_profiles.json](fixed_profiles.json): two fixed profile definitions; visual bundle IDs are symbolic and their actual assets must be authored.
- [theme_presets.json](theme_presets.json): two original visual directions and required logical tile slots; palette arrays match art-pipeline indices 1–15, with index 0 implicitly transparent. This is not a complete tileset.
- [world_graph.json](world_graph.json): eight-room progression illustration with challenge rewards. The checker assumes listed room challenges can be completed; it cannot prove jumping, combat or simultaneous player actions.
- [team_save.example.json](team_save.example.json): checkpoint-based team progress after the Spoolwarden; no arbitrary player coordinates or live enemy state.

`python3 tools/check_pack.py` validates these illustrations and their cross-references with Python's standard library. The actual game must add validators for complete asset files, room geometry and runtime data. Keep generated appearance, approved mechanics and required team progression separate.
