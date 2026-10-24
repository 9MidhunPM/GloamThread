# Arena content packet

Rebuild originals with `python3 -m tools.forge.content --build --validate`; validate retained output with `python3 -m tools.forge.content --validate`; exercise admission with `python3 -m unittest tools.tests.test_forge_content -v`. No network or credentials are used.

Runtime loads `content/arena/catalog.json` and `assets/arena/builtin/index.json`; each builtin directory follows the approved fixed-file/hash contract. Read `docs/WAVE_FIGHTER_SPEC.md` for schema,32frame order,544×272atlas and640×360background. General/kit cooldown upgrades have negative tick amounts; attack_speed/area values add to base multipliers; crit/lifesteal/thorns are fractions. Runtime must clamp all final stats.

`tools/forge/rigs.py` exposes `convert_generated(raw_parts, raw_theme, proposal, job_dir, provenance) -> candidate_dir` and `bake_job(job_json) -> candidate_dir`. Generated parts are a transparent1024×1024board,3×3slots row-major in `RIG_PARTS[rig_id]` order. Each nonempty part is alpha-cropped, fitted into its authored64×64body envelope, then animated by authored templates. A slot touching its edge is rejected. Theme board is opaque1024×1024: top1024×576background; bottom four256×448material panels.

The job folder receives `parts/<id>.png`, `rig.json`, `proposal.json`, theme_background.png, theme_materials.png and source_provenance.json. `rig.json` parts have id/file/pivot/anchor. All parts are64×64PNG. Optional `rig_edits.json` contains schema_version1 and parts:{id:{pivot:[x,y],mask_file:"masks/<id>.png"}}; masks are64×64grayscale or RGBA alpha. Only pivots/masks are edited; source files stay retained. Rebakes create candidate-bake-N siblings so earlier candidates survive.

Current shipped content is original locally authored artwork. Live generated outputs and human/native animation acceptance are separate gates, not implied by bundle validation.

Enemy consumer: `assets/arena/enemies/index.json` has assets keyed swarm/chaser/charger/shooter/flyer/heavy/warden/artillery/tempest/loom. Each record gives file, cell_size, origin,frames16,columns4,sha256. PNG is4×4cells without gutters, nearest sampling. Frames walk0–3,windup4–7,active8–11,recovery12–13,defeat14–15.

Generated parts-board slot8 (bottom-right) must hold a full transparent master design, retained as128square master.png beside rig.json. Rebake staging must copy theme_background.png,theme_materials.png and source_provenance.json as well as rig/parts/masks to preserve generated environment art and provenance.
