# Gloamthread wave fighter — implementation contract

Approved by Midhun P M on 25 October 2026. This document supersedes the campaign and overhead product requirements wherever they conflict. Keep the earlier implementations and evidence in history; they do not establish acceptance of this game.

## Product

Godot 4.7.2 standard, Compatibility, typed GDScript, Python authoring. Solo or two local players, fixed shared side-view arena, 640×360 pixel world at 3× for fullscreen 1920×1080. UI uses a 1920×1080 canvas. One simulation and one audio mix. Nearest sampling, integer scaling and letterboxing. Active roster is fixed before the run; owned keyboard zones/gamepads, no friendly fire/body blocking.

20 waves, four five-wave stages, bosses at 5/10/15/20; optional endless with a boss every five waves. Target 10–15 minutes with quick untimed shopping. Wave completion requires empty spawn queue and no living enemies. Resolve accepted damage/rewards before wave clear, then team wipe on the same tick. Clear wins a simultaneous final kill/wipe. Downed co-op players can be revived by holding interact for 90 ticks nearby, or return on wave completion. Solo death/team wipe ends the run. No downed timeout. All run wallets/upgrades reset; only creations, settings and scores persist.

Manual move/jump/dodge, held basic attack and manual special. Six ability families: ember (cleave/flame/burn), frost (bolt/freeze/shatter), storm (fast strike/chain/charge), stone (heavy/slam/armour), nature (thorn/root/regen), shadow (slash/pierce/marks). Six enemy roles: swarm, chaser, charger, shooter, flyer, heavy. Four bosses with distinct patterns. Start 6–8 concurrent enemies and grow to 24 solo/32 duo; bounded projectiles/effects, telegraphs, separation and close-attack reservations. Endless keeps concurrency caps.

Personal last-hit rewards, once per death; DOT/chain/projectiles retain source slot. Cosmetic coin trails do not decide ownership. Everyone gets a wave-clear bonus. Separate concurrent shop panels: four offers (two kit/two general), healing, one free reroll/wave, ready toggle. Advance when all active slots ready. Atomic purchase checks phase, ownership, offer, funds and rank cap. 12 general upgrades, three branches per family, up to three ranks. Wave bonus covers at least the cheapest first-rank offer.

## Shared content boundary

Agent 2 produces `content/arena/catalog.json`, schema_version 1, content_version `arena-v1`. Required keys:

- `kits`: dictionary keyed ember/frost/storm/stone/nature/shadow; each has name, description, color (#RRGGBB), basic_name, special_name, passive_name. Runtime owns mechanics and numeric bounds.
- `upgrades`: array of records {id, name, description, kit (family or `any`), stat, amount, price, max_rank}. Allowlisted stats: damage, attack_speed, special_cooldown, max_health, move_speed, crit, magnet, dodge_cooldown, lifesteal, thorns, projectile_count, area, burn, freeze, chain, stagger, regen, pierce. General 12 / kit branches 18. Runtime clamps final stats.
- `waves`: exactly 20 records {number, count, interval_ticks, enemies (role array), boss (empty or warden/artillery/tempest/loom), elite_every}. Runtime scales co-op count and health, owns live cap. Suggested normal-wave count 8→45, intervals 45→16 ticks, boss supports 4→12; these are tuning values, not measured balance.
- `arenas`: four {id, name, platforms: [[x,y,width], ...]} using logical pixels, floor y=320, walls x=16/624, platforms at y=288/256, reachable in 48px jumps. All layouts must work with ground/flying enemies.

## Character and theme bundles

Draw in-game or import PNG/JPEG, optional description. Analyse into a strict proposal, allow corrections to name/body/kit/theme, generate a master design and separated transparent parts, preview with mask/pivot correction, bake deterministic authored animation, accept into local library. Supported rig_id: upright, quadruped, floating. Appearance never grants flight or changes mechanics/colliders.

Each bundle directory contains `manifest.json`, `character.png`, `portrait.png`, `background.png`, `materials.png`, `provenance.json`:

```
schema_version: 1
kind: "fighter-character"
id: safe lowercase slug (1..64 chars)
name: display string (1..40 chars)
rig_id: upright | quadruped | floating
kit_id: ember | frost | storm | stone | nature | shadow
theme: {name: string, palette: [4..8 #RRGGBB strings], motif: string}
files: {"character.png": sha256, "portrait.png": sha256,
        "background.png": sha256, "materials.png": sha256,
        "provenance.json": sha256}
```

Filenames are fixed, hashes verified, no provider file paths/code. Character atlas 544×272: 8×4 slots, 64×64 each with 2px gutters, frame rect (column×68+2,row×68+2,64,64), origin (32,56). 32 slots retain existing state order: idle0–3/run4–9/rise10–11/fall12–13/land14–15/slash16–19/special20–23/hurt24–25/dash26–27/downed28–29/revive30–31. Portrait128×128, background640×360, materials256×256. Actual foreground terrain uses canonical masks; background/palette/materials are render-only. Alternate P1/P2 theme on stages 1/2/3/4; solo uses own theme with stage variations.

Agent 2 ships two original built-ins at `assets/arena/builtin/<id>/manifest.json` and index `assets/arena/builtin/index.json` = {schema_version:1,bundles:[relative directory names]}. Accepted user creations live below user://fighters/. Failed imports preserve accepted bundles. Built-ins and generated creations cross the same loader.

Implemented extension: the index also admits optional `default_players`, at most two safe bundle IDs. The reviewed retained-generation `kiln-fox-ai` is the third built-in and default P1; Thistlepaw is default P2. Original starter ordering remains stable. Its real raw images, sanitized receipts, explicit crop recipe and editable rig rebuild offline through `tools.forge.retained`.

## Local authoring worker

Agent 2 owns `tools/fighter_forge.py`. Commands:

- `status`: safe JSON, key_present and configured models only.
- `analyse --job PATH`: read job JSON; output proposal/status under that job directory.
- `generate --job PATH`: consume approved proposal; output candidate bundle under job/candidate/.
- `bake --job PATH`: bake edited parts/rig into candidate without a paid request.

Cached-layout recovery adds `source_layout.json`: version 1, exact raw-board SHA-256 hashes, bounded integer part/master/background/material crops and opacity cutoff. The in-game editor copies verified source/raw/provenance into a fresh correction draft, preserving previous previews and masks. If no rig exists, `bake` converts these cached boards locally before normal admission; it does not load the SDK, reserve money or send a request.

Job schema_version1: optional preferred_name (1–40 characters, preserved exactly), source_image (absolute trusted local file), description, proposal (optional), legacy budget_usd (accepted but ignored). Job directory chosen by Godot, shell-free process launch. `status.json` atomically reports {state:queued|analysing|awaiting_approval|generating|converting|complete|failed|cancelled, message:string, candidate_path:string optional, proposal:object optional, estimated_usd:number, reserved_usd:number}. Cancellation marker `cancel` prevents subsequent calls, never claims an in-flight bill was avoided. `proposal.json`: {name,rig_id,kit_id,theme:{name,palette,motif},features:[string]}. Retain source/prompts/settings/request identity/usage/hash provenance; bound image/text sizes. Use existing optional official SDK/.env loader, Luna structured vision and mini low square PNG. No retries/model fallback. The initial $0.50 experiment and later $2 total/$0.50 character caps were removed by the user. Record conservative request estimates and retain uncertain attempts without enforcing local dollar limits. Only Agent 1 authorizes/runs live requests; Agent 2 uses mocks/local fixtures.

## Integration and completion

Runtime root owns scripts/arena/ except actors/, tests/arena/, scenes/arena/, project entry point, central docs and packaging. Actor worker owns scripts/arena/actors/ only. Creator worker owns scripts/forge/ and tests/forge/ only. Agent 2 owns tools/fighter_forge.py, tools/forge/, tools/tests/test_forge*.py, assets/arena/, content/arena/ and evidence/arena-content/ plus separate named logs. Communicate interface changes before editing outside ownership. Only root merges and pushes main.

Milestones: one-arena foundation → five waves/boss/shops → creation-to-combat →20 waves/six builds/three rigs/endless → native QA/balance/package. Test owned simultaneous inputs, exact rewards and shop transactions, pauses/reconnect, all rigs/kits, rejected bundles, reset semantics, full ordinary-input routes, generation errors/budget/cancellation, native1080p capped crowds. Human device/listening/fun acceptance is recorded only when actually observed.

Latest identity rule: explicit fighter name/weapon intent outranks ambiguous sketch interpretation; description is also bound into new image requests. Swordsman/knight defaults to Stone melee, dagger/ninja to Shadow, brawler to Storm and archer/gunner to Frost; a manual ability selection overrides suggestions. Existing cached drafts retain their original request identity and are not silently regenerated.
