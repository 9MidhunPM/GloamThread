# Fixed profile and theme boundary audit

Historical read-only evidence at the pinned source below. Future admission work is planned in the [drawing preparation brief](../../docs/DRAWING_PREPARATION.md).

Follow-up: Agent 1 reports adding an early catalog-error guard, an independent emergency diagnostic/Quit screen and a `startup_failure` scenario after this audit. Its final 20-scenario run and rebuild were pending at that handoff. This branch does not contain or independently verify that runtime fix; the observations below remain evidence for `b96ad0e` only.

Audited read-only at `/home/midhun/Coading/Gloamthread`, commit `b96ad0e86724db62a7d6f22ba26b01b75dcaee1c`, 2026-10-25 IST. Repository status was clean before and after. No repository edits, imports, commits, providers, uploads or new characters were introduced. All mutation probes ran in `/tmp/gloamthread-profile-audit-project` with a separate `XDG_DATA_HOME`.

## Result and scope

The complete fixed bundle passes the runtime load gate. Its health, ability, profile and theme identity checks protect the current Tavi/Neri campaign. Required traversal belongs to `TeamProgress`, and visual data does not redefine player collision or movement. There is no current external/generated-profile ingestion path to exploit.

One concrete broken-install startup defect was reproduced: the app cannot display its content-error screen when the original font resource is missing. The other findings below are runtime/offline-validation inconsistencies and future integration seams. The offline validators reject the malformed candidate bundles used in those probes, so they are not evidence that the frozen, validated Phase 1 package is broken or remotely exploitable. Agent 1 should decide whether the startup defect meets the current freeze exception; no immediate Phase 1 change is proposed for the future-only seams.

## Current loading path

1. `scripts/app/app_controller.gd:33` calls `ContentCatalog.load_bundle()` before a session exists.
2. `scripts/presentation/content_catalog.gd:27-53` loads the manifest, required assets, fixed profiles, themes, dialogue, all rooms and references. Resource resolution runs only when its accumulated validation errors are empty.
3. Profiles load from a fixed `res://content/profiles.json` path (`content_catalog.gd:127-150`). IDs are exactly `tavi_fixed`/`neri_fixed`; names, 5/4 hearts, specials, themes and visual IDs must equal their authored values. `RoomDefinition._is_integer` rejects non-finite/fractional values and booleans (`scripts/world/room_definition.gd:379-380`). Unknown ability IDs fail this boundary.
4. `scripts/session/game_session.gd:58-66` blocks a production session when catalog errors exist. At lines 151-165 it passes the selected validated dictionary into `PlayerController.configure`.
5. `scripts/actors/player_controller.gd:77-86` applies the trusted dictionary. Movement remains fixed code constants at lines 9-20. The physical rectangle is fixed in `scenes/actors/player.tscn:5-15`, separate from sprite/frame size.
6. `scripts/session/team_progress.gd:5-35` allowlists permanent outcomes. `_can_dash()` reads the shared `threadstep` flag (`player_controller.gd:264-265`), not a profile field. Save validation accepts both fixed roster orders, rejects duplicates/other IDs, and checks the boss/Threadstep/shortcut transaction (`team_progress.gd:70-107`).
7. Themes load at `content_catalog.gd:153-183`. Presentation consumers currently receive theme IDs and the asset catalog, not the validated theme dictionaries (`game_session.gd:198`; `scripts/presentation/split_presentation.gd:113-124`).

## Finding 1 — missing original font hides the startup diagnostic

**Current reproducible correctness defect; suggested P2, broken-install recovery only.** This is a blank error path, not an engine process crash. The correctly packaged bundle is unaffected.

At `scripts/app/app_controller.gd:40` and `:46`, the app calls `catalog.assets.font()` and uses the result before checking `catalog.errors` at lines 60-62. With the font absent, `GameMenus.set_font(null)` hides the menu, and `show_menu` later refuses the intended error screen because no original font was supplied (`scripts/ui/game_menus.gd:47-52`, `:57-61`). The null toast font override also emits an engine error. `_show_fatal` already provides an independent default-font Label at `app_controller.gd:530-534`, but this path is not called for missing content/font resources.

**Fresh-process reproduction:** in the isolated copy only, quarantine `assets/generated/font/weft_5x7.fnt`, its `.import` sidecar and the corresponding `.godot/imported/weft_5x7.fnt-*` files. Leave the production manifest unchanged. Instantiate the actual App controller in a fresh Godot process. Observed:

```text
AUDIT missing_font_resource_errors ["Original font could not load"]
AUDIT missing_font_resource_screen error
AUDIT missing_font_resource_menu_visible false
AUDIT missing_font_resource_direct_label_count 0
ERROR: Required object "rp_font" is null.
```

**Smallest regression:** App startup with an unresolved required font must show a visible nonempty fatal diagnostic independent of that font, create no session, and avoid null theme-font overrides. A second case with a malformed/missing manifest can share that path. Keep a valid-bundle startup case to protect the normal original-font presentation. A minimal fix would check/load the font once and route errors to the existing independent fatal display before constructing font-dependent controls; Agent 1 owns the implementation decision.

## Finding 2 — accepted theme references differ from what the renderer consumes

**Future seam / runtime validator alignment; not a frozen-package blocker.**

`content_catalog.gd:170-180` resolves each declared terrain/background ID by kind/dimensions, without requiring the fixed IDs/order. `ThemePresenter` then ignores those validated references and constructs IDs with `terrain_%s_v1` and `background_%s_%s_v1` (`scripts/presentation/theme_presenter.gd:9`, `:22`, `:42`, `:105-110`).

**Probe:** rename only `terrain_ember_v1` and `background_ember_far_v1` entries to aliases and update Ember's corresponding theme references. The catalog returned `errors=[]`; the canonical terrain key was absent. Calling `ThemePresenter.build_background(..., "ember")` produced `Required image is missing: background_ember_far_v1` and a null far-layer texture. Terrain's direct dictionary indexing would likewise reference a key the preflight gate did not require; that branch was not deliberately crashed.

The Python validator already requires the exact fixed terrain ID and ordered far/middle/near IDs (`tools/validate_content.py:202-209`). For Phase 1 parity, reject these aliases before the world exists. For a later bundle interface, consume validated theme references rather than reconstructing filenames/IDs. Do not broaden the fixed allowlist merely to make this probe pass.

**Smallest regressions:** alias/remove a canonical terrain ID while updating the theme reference; alias one background ID; swap or duplicate declared background layers. Require an explicit runtime error before session startup under the current fixed contract. A future theme implementation should instead prove that a validated mapping controls the actual rendered resource.

## Finding 3 — runtime accepts invalid courier presentation geometry

**Future seam / runtime validator alignment; offline asset validation prevents this in the shipped pack.**

`AssetCatalog._validate_atlas` checks positive cell dimensions, nonnegative origin, frame bounds and clip indices (`scripts/presentation/asset_catalog.gd:100-126`). It does not enforce the fixed courier's 32×48 cell, `(16,43)` origin, 32 frames, consistent frame size, or frame overlap. `ContentCatalog._validate_required_assets` checks required clips but not those geometry contracts (`content_catalog.gd:83-98`). The animator applies the supplied origin directly (`scripts/presentation/sprite_animator.gd:23-25`).

**Probe:** change only Tavi's manifest origin to `[999999,999999]`, cell size to `[1,1]` and its first frame to `[0,0,1,1]`. Full runtime catalog loading returned `errors=[]`; configuring its animator produced offset `(-999999,-999999)` and a 1×1 texture frame. Collision remained independent, which avoids physics mutation but allows an invisible/unreadable player.

The Python pack validator fixes those courier dimensions/count/pivot (`tools/validate_assets.py:474-475`) and checks frame contract elsewhere in the same module. This is not a reason to implement generation now.

**Smallest regression:** independently mutate a courier origin, cell size and one frame size, with a valid PNG and otherwise valid clips. Each must fail the runtime fixed-bundle gate. Future bundle validation must bound origin/frame geometry against the chosen courier contract before an animator is configured.

## Finding 4 — unknown profile fields and theme cue policy are accepted at runtime

**Low-impact contract mismatch; no execution or gameplay mutation demonstrated.**

`docs/ARCHITECTURE.md:143` says unknown required fields/IDs are rejected and only designated optional metadata is allowed. `ContentCatalog._load_profiles` validates known fields then retains the entire dictionary (`content_catalog.gd:143-145`), without an exact field allowlist. The Python validator requires the exact profile field set (`tools/validate_content.py:167-171`). Runtime theme loading does not validate the palette or `critical_cues`, while Python enforces 15 RGB colors and `common_shapes_and_contrast` (`tools/validate_content.py:198-201`).

**Probe:** add profile fields `script`, `team_unlocks`, `move_speed` and set a theme palette to a string plus `critical_cues="hide all hazards"`. Runtime catalog errors remained empty, and the unknown profile fields were retained. These fields are not executed or applied by the existing consumers: they do not grant flight, change movement or remove Threadstep.

**Smallest regressions:** one unexpected profile field and one malformed palette/cue-policy value; require rejection matching the offline validator. For future bundles, use a dedicated explicit metadata field if extensibility is needed, rather than retaining arbitrary proposal keys beside gameplay fields.

## Guardrails that currently work, and limits not to mislabel

- **Finite/bounded fixed stats and special allowlist:** mutated heart values `true`, `0`, `999`, `5.5`, `"5"`, `null`, `[]`, `{}` all produced `Invalid fixed profile fields: tavi_fixed`. Fixed special/profile/theme IDs are exact checks. No arbitrary ability execution exists.
- **Direct actor configuration is not an ingestion validator:** `PlayerController.configure` coerces and clamps hearts and stores any special string (`player_controller.gd:78-82`). A direct internal call with `"999"` and `"unapproved"` yielded 6 hearts and that special string. Unknown attack kinds would take the non-slash/non-spore cleave branch (`player_controller.gd:286-320`). Production calls are protected by ContentCatalog. Keep this method internal/trusted or put a validated profile value in front of it before adding a future ingest route; do not expose it directly to model output.
- **Shared unlock separation:** a direct configure call preserved an existing team Threadstep flag. Fixed profile fields cannot remove it. The stored `required_team_unlocks_are_separate` boolean documents the contract; actual authority is the independent TeamProgress reference.
- **Executable/arbitrary output paths:** runtime records require lexical `assets/generated/...` containment, prohibit traversal, empty segments, backslashes, colon/URL schemes and control characters, and enforce PNG/FNT/WAV extensions per kind (`asset_catalog.gd:65-71`, `:138-147`). Profile visual values are IDs, not loader paths. Runtime dynamic script paths are authored constants, not profile fields. I found no active path from profile JSON to script execution.
- **Runtime path/hash validation is not the full build validator:** lexical runtime checks do not resolve filesystem symlinks or validate source hashes/provenance. The offline validator resolves real paths, enforces bundle containment, verifies hashes and validates BMFont's exact manifested neighboring page (`tools/validate_assets.py:117-138`, `:163-175`, `:383-386`). `asset_catalog.gd:3` explicitly assigns hash verification to offline tools. Before accepting local user bundles, validation must happen before import/load, including dependency paths; this is future work, not proof of a current remote attack surface.
- **Missing visual fallback is not currently implemented or claimed as a Phase 1 gate:** ContentCatalog correctly rejects unresolved required assets and GameSession refuses startup. `docs/GENERATION_ROADMAP.md:3` labels the document future-only; B0's fallback acceptance is at line 29, and future fallback/cache behavior is at lines 110-118. A missing custom profile cannot currently be selected. Do not count existing fixed-mode startup rejection as successful future fallback evidence.
- **Fixed-only IDs are intentional:** the current save loader rejects new/duplicate builds (`team_progress.gd:70-77`), the HUD derives Tavi/Neri names from ID (`split_presentation.gd:162`), and theme visibility uses the two fixed themes (`split_presentation.gd:115-116`). These are B0 compatibility changes after the fixed-game gate, not Phase 1 correctness defects. The roadmap's “same contract” means an intended seam, not that arbitrary approved future profiles already work.

## Evidence and proposed follow-up

Engine: `4.7.2.stable.arch_linux.ed1daf0bf`. Commands run only against the isolated copy:

```sh
XDG_DATA_HOME=/tmp/gloamthread-profile-audit-user timeout 20s godot --headless --fixed-fps 60 --path /tmp/gloamthread-profile-audit-project --script profile_audit_probe.gd
XDG_DATA_HOME=/tmp/gloamthread-profile-audit-user timeout 20s godot --headless --fixed-fps 60 --path /tmp/gloamthread-profile-audit-project --script missing_font_probe.gd
```

Both final probes exited 0 and printed the observations above. These are diagnostic probes, not passing acceptance tests. The initial scratch probe referenced PlayerController at script-compile time before autoload identifiers were available; it was corrected to load dynamically after initialization, and the complete final probe ran. No render-quality, controller-hardware, generated-character or two-person-playtest claim is made.

Recommended next sequence: send the reproduced font error path to Agent 1 for freeze triage; record the other seams in the future B0 plan; keep provider/backend work and new character content out of this phase. Add shared data-only negative fixtures for future runtime/offline parity when that work is authorized. Preserve the current fixed campaign and shared progression throughout.

## Preparation-branch baseline checks

The coordinating Agent 2 checkout is on `feat/drawing-preparation`, branched from the same `b96ad0e` source. Before documentation changes, these commands passed:

```sh
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 tools/validate_assets.py
python3 tools/validate_content.py
python3 tools/check_pack.py
git diff --check
```

The Python suite ran 79 tests in 8.124 seconds with `OK`; both full validators passed. The pack checker confirms Devin Hack Kochi identity, references and examples. No generated character, importer, provider, drawing corpus or recognition/playability result was created by this preparation work.

## Independent theme-slot and integrity probes

A second read-only review used a headless object-state probe on the same source. Replacing the two terrain `tile_ids` arrays and `required_tile_slots` with the same 48 unknown names produced no theme errors but zero used terrain cells. This is not a rendered screenshot: the probe queried the resulting `TileMapLayer`. The fixed authored names remain correct and the offline validators reject the mutation. Future admission must compare against the canonical slot set/order, rather than checking only agreement between candidate arrays.

Removing `sha256` and `sources` from the Tavi manifest record also passed the runtime resource/required-profile gates. This is intentional separation for the fixed export: offline tools verify original output/source hashes, while Godot loads imported resource remaps. A future local bundle installer needs a complete integrity gate before import; hashing imported engine resources against source PNG/WAV hashes would be incorrect.

Exact independent probe command (exit 0; Godot `4.7.2.stable.arch_linux.ed1daf0bf`):

```sh
godot --headless --path . --audio-driver Dummy --script /tmp/gloamthread-content-boundary-probe.gd --log-file /tmp/gloamthread-content-boundary-probe.log
```

Scratch fixtures were `/tmp/gloamthread-audit-{origin,frames,provenance,terrain}.json`; no tracked source was changed. This provides diagnostic observations, not generated-theme, visual-quality or new gameplay acceptance. A future implementation should convert the small payloads described here into retained negative fixtures when admission is built.
