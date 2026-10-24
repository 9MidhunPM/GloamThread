# Expanding-world implementation contract

Approved 25 October 2026. Supersedes fixed-arena/camera and $0.50 lifetime experiment limits in the earlier wave contract. Keep local co-op, combat families, 20 waves, four bosses, optional endless, existing accepted bundles and honest evidence.

## Outcomes

- Total local authoring allowance $2, per-job maximum $0.50; retain existing $0.35 reservations and uncertain attempt. Show separate total/job remaining/required amounts; resume the valid blocked job without another analysis. No automatic paid retries, ledger resets or credential disclosure.
- Four 640px-wide chunks initially; append four after waves5/10/15, retaining terrain, discoveries and player positions. Height720. Endless reuses the16chunks. Seeded authored templates provide connected main ground, raised paths and shallow caves.
- Free intermissions: shops initially open, Explore closes an owned panel, E/M/Y reopens it; all active players Ready explicitly. Traversal continues during breaks/countdown, combat regeneration only in combat. Four3coin team caches and two20percent collector-heal plants per region, one landmark; loot is unique once per run. Attacks open caches.
- One authoritative World2D; merged640x360 or two320x360 views at3x. P1left/P2right. Split dx>480 or dy>192 for8ticks; merge dx<360 and dy<128 for45ticks. Downed body retains own view. Shops force split while open; no tether or player teleport.
- Rich original scenery inside the world; keep current fullscreen letterboxing. Four parallax layers,24distinct prop silhouettes,4landmark families, restrained ambient motion. Use retained generated materials and original editable sources; no resource packs.

## Shared interfaces (all world geometry is in world coordinates)

`ArenaMap` RefCounted, new scripts/arena/arena_map.gd:

- `configure(seed_value: int)` initializes4chunks. `expand_to(regions: int) -> Array[Dictionary]` appends up to4regions and returns only added chunk records.
- `bounds: Rect2`, `chunks: Array[Dictionary]`, `platforms: Array` (existing[x,y,width] interface), `anchors: Array[Vector2]`, `loot: Array[Dictionary]`, `landmarks: Array[Dictionary]`, `seed_value: int`.
- Each chunk: `id: int`, `region: int`, `origin: Vector2`, `solids: Array[Rect2]`, `platforms: Array`([x,y,width]), `anchors: Array[Vector2]`, decorative records, landmark data. Chunk geometry remains immutable after append. Initial safe main ground includes x270/370,y320.
- Loot records: `id: String`, `kind: cache|plant`, `position: Vector2`, `region: int`; stable IDs, no executable paths. Four caches +two plants per region, independent of view count.
- `safe_position(at: Vector2) -> Vector2` returns valid actor feet on reachable ground; `spawn_candidates(at: Vector2, radius: float = 720.0) -> Array[Vector2]`; `navigation_step(from: Vector2, to: Vector2) -> Dictionary` returns `{point:Vector2,jump:bool,drop:bool}`; `region_at(at:Vector2)->int`; `snapshot()->Dictionary` provides deterministic testable geometry/identity data.
- `ArenaChunk` Node2D new arena_chunk.gd: `setup(data:Dictionary, appearance:Dictionary)` draws shared world geometry/scenery using supplied solids/platforms; no gameplay triggers. Session constructs collisions from the same chunk records.

`ArenaPresentation` Control, new scripts/arena/arena_presentation.gd:

- `setup(world: ArenaRunSession)` creates persistent A/B views, only A parents session; B shares A.world_2d before cameras are added. Expose `viewport_a`, `viewport_b`, `camera_a`, `camera_b`, `split:bool`, `force_split:bool`.
- `visible_world_rects()->Array[Rect2]` returns unshaken active world rectangles. Fixed nearest sampling, rounded origins, disabled listeners, one audio mix. Freeing presentation frees session and both views.
- Session exposes `world_bounds()->Rect2`, `appearance_at(at:Vector2)->Dictionary`, `map: ArenaMap`, `shop_open:Array[bool]`, `shop_ready`, fighters/enemies and existing shake settings. Camera follows fighters including downed players; one view for solo.
- Presentation owns per-view parallax, compact exploration minimap, partner/revive/offscreenboss/finalenemy cues. It may use current map records and session collected/discovered dictionaries read-only. App retains shared HP/boss/wave HUD and owned shop overlays.

Session/actor boundary (integrator):

- `movement_allowed(slot:int)->bool` supports traversal combat/countdown/clear/intermission, except an open owned shop. `world_bounds`, `safe_position(at)`, `navigation_step(from,to)`, `visible_world_rects` replace fixed640px assumptions. Actor fixture will expose these too.
- Use phase `shop` for the free intermission to preserve existing transaction interface; shop_open controls per-player overlay/input independently. No physics-tree pause for personal shops. Real pause/device loss still pauses shared simulation.
- Spawns sample reachable anchors near living players, minimum96px clearance from all players,42tick telegraph, existing team-wide caps. Delay when no safe anchor exists. Separate deterministic RNG streams for map/spawn/loot/shop.
- Offscreen catch-up: ordinary enemy farther than960px from every living player and unseen in expanded active rects for180ticks; boss farther than1280px for300ticks. Warn42ordinary/90boss ticks before relocation to a safe nearby anchor, cancel if visible/dead, retain identity/HP/status/reward ownership. Reposition into recovery, never duplicate an enemy.

## Exclusive lanes

- Integrator: arena_app.gd, run_session.gd, actors/, loot gameplay, existing scenario/route tests, project entry/export, central docs and integration commits.
- Camera worker: arena_presentation.gd, arena_parallax.gd and focused presentation tests only. No App/session/actors edits.
- Agent2 map/art: arena_map.gd, arena_chunk.gd, tools/forge/world.py and scenery producer, content/arena/world.json, assets/arena/scenery/, original source files, focused map tests/validators. Existing catalog contract version bump coordinated with root; retain four arena descriptors for existing callers.
- Budget worker: tools/forge/jobs.py/provider.py, tools/ai_assets.py settings if needed, scripts/forge/, tests/forge/, budget Python tests and .env.example. Never print/change key or make API calls; root alone updates ignored.env limit and runs one live test. No broad content rebuilds or shared-doc edits.

## Evidence and delivery

Baseline12arena/154creator/173Python checks passed at previous release; establish current baseline before runtime edits. Focused tests cover deterministic multi-seed connectivity/clearance, immutable expansion/loot, movement/navigation, camera sharedWorld2D/split/merge/downed/pause, safe world-relative spawns/bosses, exact rewards and independent intermission shops. Final normal-input solo20/co-op25 must explore expanded chunks and split/merge. Inspect actual native scenery/camera captures, profile bounded split crowds separately, export and verify offline, document physical/human limits. Commit real milestones, preserve histories and private inputs, merge/push authorized origin, update package identity and launch configured source.
