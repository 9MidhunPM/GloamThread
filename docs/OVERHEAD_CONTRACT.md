# Overhead runtime and content contract

Active from the user's25October2026 request. This replaces side-view movement/terrain/animation assumptions. The preservedv0.1.0-demo tag and evidence remain side-view-only. Root integrates; workers use separate branches/checkouts and exclusive lanes.

## Simulation and ground plane

Keep Godot4.7.2 standard, Compatibility, typed GDScript,60Hz physics, one authoritative World2D, fixed split960x360 (480x360 each), nearest sampling/integer scaling, two fixed characters, original content and one audio mix. Both couriers stay in the same active room. Shared pause/map/dialogue/reconnect/recovery freezes gameplay; no wall-clock catch-up. No friendly fire/body blocking. No runtime model service, upload UI, network play or generic engine framework.

Hero physics uses CharacterBody2D floating motion. InputVector2 limits length to1 while preserving analogue magnitude. Base speed110px/s. No gravity, platform support, coyote, jumping or one-way/drop-through. Feet collider12x10, local rectangle(-6,-10,12,10), centre(0,-5). Clamp both axes by the footprint. Room.can_stand_at(feet) validates the entire footprint. Room.can_threadstep(from,to) validates the swept footprint against walls and requires a dry traversable landing. Actors never parse room JSON themselves.

Logical entity coordinates name a16px floor cell. `tile_center` remains tile*16+(8,8); `feet_position` is tile_center+(0,5), placing the collision centre at cell centre. Interactions use the same feet convention. Actor/occluding-prop sort origins are feet; they share one sortable entity parent, not independently sorted cousins. Pure visual shadows/hover offsets never move hurtboxes.

## Direction and actions

Facing enum DOWN=0,LEFT=1,RIGHT=2,UP=3 and a cardinal facing_vector. Dominant input axis chooses facing; ties prefer the prior facing if it still matches. Direction locks for windup through recovery, roll and dash. No mirroring of directional atlas banks. Keep animation_state semantic and derive animation_key=state_direction only in presentation.

Roll replaces Jump, retaining input bit16. Canonical saved action name becomes roll; legacy jump bindings map to roll. A compatibility JUMP alias may remain for menu/test transition, while ALL_ACTIONS contains the bit once. Menus confirm with Roll/Interact and cancel with Pause, owned snapshots only. Labels/prompts derive from current bindings, not hardcoded keys. Keyboard sources remain WASD/Space/F/G/E/Shift/Escape/Tab and arrows/Period/Comma/Slash/M/Apostrophe/Enter/Semicolon. Gamepads remain per-device-owned.

- Roll:12ticks,180px/s (36px),6invulnerable ticks,36tick cooldown. Water/walls still block it.
- Slash:6windup+6active+6recovery=18ticks. One hit per enemy per swing; independent couriers retain independent attacks. Six-tick input buffer for a queued attack. Facing locks across the swing.
- Special:22ticks, emissiontick8. Tavi Ember Arc is a directed close fan; Neri Spore Bolt is a swept two-axis projectile with nearest-hit/wall ordering and bounded lifetime. Specials retain distinct readable roles.
- Threadstep: team unlock,12ticks at300px/s=60px,45tick cooldown. It bypasses only the room's separate water body after validating the entire corridor and dry landing. Walls remain solid. Interrupted/invalid crossing restores recorded dry departure before ordinary movement resumes. Menus pause the ongoing move; room replacement/recovery clears its water exception.
- Damage: planar knockback, independent hurt rectangle from art,45tick immunity; revive gives2hearts/90tick immunity. Downed720ticks, hold-revive90ticks, interrupts/range checks, revive wins timeout at the chosen boundary; boss outcome commits before same-tick wipe.

## Required hero art

Keep32x48 frames, origin[16,43], padded atlas conventions. Four32-frame banks DOWN,LEFT,RIGHT,UP produce128frames (288x832 with current gutters). Nine states per direction, keys e.gslash_down, not platform rise/fall/land:

| State | Frames | Tick durations | Loop |
| --- | --- | --- | --- |
| idle |4|10,10,10,10|yes|
| run |6|5,5,5,5,5,5|yes|
| slash |5|3,3,3,3,6|no|
| special |5|4,4,3,4,7|no|
| roll |4|3,3,3,3|no|
| dash |2|6,6|no|
| hurt |2|5,7|no|
| downed |2|18,18|yes|
| revive |2|6,10|no|

Gameplay owns attack windows; animation tables mirror them without executing behaviour. Distinct original Tavi/Neri silhouettes and readable cardinal attacks, never copied characters/maps/melodies/UI. Spoolmite/Wickwing retain their square frame sizes/counts/pivots with overhead radial bodies and existing semantic clips. Boss remains64x64,origin[32,59],32radial overhead frames/current clip names. Directed weapons/telegraphs are separate; effect art faces+X and rotates quarter turns. Boss slow-resist feedback must not conceal the partner-strike opening.

## Room and terrain data

Content/manifest version **overhead-v1**, JSON schema_version1 unless a field's schema is explicitly changed. Preserve room IDsr00-r07 and the restoration story/graph, with new overhead layouts. `#`=wall,`.`=walkable floor,`~`=water/rift,`^`=walkable damaging hazard,`=`=authored dry bridge. Spawns/entrances require two distinct safe complete footprints; no platform-support fallback. Exit rallies include both living couriers, then commit one deferred transition. Author permissive traversal, clear landmarks and a readable goal, not side-view stairs.

Wall and water collision are separate bodies. Canonical geometry exists once. Named unrepaired bridge spans block water; a paired restoration removes/disables its named blocker and adds both render skins once. Do not add a solid floor collider. Replaying permanent progress rebuilds the same traversability. Immutable walls never become passable through dash or a visual/theme change.

Forty-eight fully opaque16x16 terrain slots, identical rectangular alpha masks in both themes. Edge/corner materials are painted inside the full ground tile; no legacy one-way masks. Slot order:

1. floor_path_1,floor_path_2,floor_grass_1,floor_grass_2
2. wall_fill_1..4
3. wall_edge_north,east,south,west
4. wall_corner_outer_ne,se,sw,nw
5. wall_corner_inner_ne,se,sw,nw
6. water_fill_1..4
7. water_edge_north,east,south,west
8. water_corner_ne,se,sw,nw
9. bridge_plank_1,bridge_plank_2,bridge_rail_north,bridge_rail_south
10. seam_rune_1..4
11. background_earth_1,background_earth_2,background_roots_1,background_roots_2
12. hazard_glass_1,hazard_glass_2,hazard_thread_1,hazard_thread_2

Each numbered line supplies four slots, in order0..47. Props/actors/effects remain transparent with declared pivots. Floors, walls and water must read as different materials in both themes. Foreground props share feet sorting; render-only theme roots contain no collision/AI/triggers. Static detail must not conceal danger or the route.

## Progress, saves and guidance

Keep team-owned Threadstep, two bridges, boss outcome/shortcut, one cosmetic secret, two checkpoints, Loom restoration and ending. Add met_oru as an explicit shared introduction outcome. Derive a concise current objective and local destination from room/progress; per-player prompts require that living player's actual proximity. A downed/far courier never receives another actor's local action. Mark locked dash until unlocked. Map shows the branch/connections and current room, with a useful next destination.

Overhead campaign save schema_version2/content_versionoverhead-v1; use a separate Godot user-data directory for the new game so the preserved side-view build/settings remain playable. Keep atomic verification/backup/rejected-copy handling and explicit recovery. No silent acceptance of incompatible side-view coordinates. Fixed profiles use a declared courier_overhead_v1 collider boundary; drawings/generated profiles remain a separate future admission task, never an automatic traversal override.

## Ownership

- Root/integrator: project/boot, shared session, catalogs/profile/progression contracts, views/HUD, quests, main integration and exports.
- Actor worker: player/enemies/combat/effects runtime and dedicated actor scenarios in its own checkout.
- Room worker: room/world data, RoomDefinition/CollisionBuilder/Room/ThemePresenter, content validator and dedicated world scenarios in its own checkout.
- UX/persistence worker: CommandSnapshot/Bindings/InputRouter, settings/campaign repository/TeamProgress, dedicated input/save scenarios in its own checkout. App/session integration remains root.
- Agent2 separate checkout: original art/audio sources/generators, manifest, asset/audio validation, GameMenus/home presentation and component UI tests. Optionalset_assets(AssetCatalog) is the only agreed new menu injection; root wires it. Optionalboss_final music mapping enables phase intensity.

No concurrent edits to another lane. Workers commit only their owned paths plus their exclusive CHANGELOG/AI_USAGE section, inspect staged scope, use true timestamps and push only the authorized repo. Root alone merges main. Raise a contract conflict before editing a shared interface.
