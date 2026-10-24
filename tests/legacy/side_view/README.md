# Preserved side-view checks

These files describe the retired side-view motor, diagnostic geometry and story route. They are retained for inspection; they are not overhead acceptance tests. `.gdignore` prevents Godot from importing the archived scripts, and the active runner discovers only files directly in `tests/scenarios/`.

Run the preserved checks from the `v0.1.0-demo` source tag in a separate checkout. Their original resource paths and assumptions belong to that version; these archived copies are not intended to execute against overhead actors or rooms. The tag retains the original assets, engine project and verified evidence.

| Archived scenario | Retired assumption | Active overhead coverage |
| --- | --- | --- |
| `campaign_route.gd` | Platform jumps, side-view waypoints and 72px dash | `overhead_campaign_route.gd` and overhead world routes |
| `combat_controls.gd` | Gravity, platform floor and drop-through | Overhead actor motor, roll, slash, damage and Threadstep |
| `combat_enemies.gd` | Enemies and charge paths on a platform floor | Overhead actor enemies and damage |
| `combat_ordinary_boss.gd` | Side-view arena and horizontal slash bot | Overhead actor boss and campaign route |
| `content_session.gd` | Side-view spawns and jump measurements | Overhead session foundation, catalog contract and world routes |
| `movement_boundaries.gd` | Jump buffer, coyote time and one-way platforms | Overhead actor motor/roll/Threadstep |
| `session_transactions.gd` | Controlled platform coordinates and added bridge-floor colliders | Overhead session transactions, guidance and world foundation |
| `smoke_session.gd` | M0 diagnostic mover and side-view room fixture | Overhead session foundation |

The old `m0_room.json` and three side-view contract JSON examples accompany these historical scenarios. Generic input, application/reconnect, persistence, corruption, resource, secret and UI checks remain active and are adapted to the overhead contract. Active failures must be investigated, not archived because they fail.
