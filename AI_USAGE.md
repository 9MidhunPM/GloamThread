# AI usage record

Briefly document each meaningful coding-agent contribution here. Add a row after each meaningful task or milestone. Keep summaries concise; omit secrets, private data and full chat transcripts. Name the tool actually used; mark human review as pending until the user has reviewed the contribution.

This project maintains the record for **Devin Hack Kochi** as a repository convention. The event permits different AI tools and providers without major AI usage constraints. Historical tool names below describe actual assistance and remain unchanged.

## Build log

## Agent 1 — runtime and integration

| Date and time with timezone | Tool / model, if known | Task | Assistance and affected files | Human review / corrections | Validation and result |
| --- | --- | --- | --- | --- | --- |
| 2026-10-27T08:24:48+05:30 | OpenAI Codex | Stabilize fresh-import font metadata | Replaced stale standalone-texture import metadata with the fresh engine's embedded-font-page skip marker. Original PNG and glyph source unchanged. | Human review pending; exact fresh-clone import diff inspected. | Clean-source guard correctly rejected the changed import; canonical fix recorded before retrying fresh export. No content rebuild/API call. |
| 2026-10-27T08:19:49+05:30 | OpenAI Codex with browser QA and packaging review workers | Build and package browser deployment | Added Web preset/shell, original screenshot loading page, matching hashed templates, immutable assets, clean-source manifest and atomic export rollback, Docker/Compose/Nginx and secure worker-only key provisioning. Corrected loading/resume, screenshot aspect and Nginx regex during actual QA/review. | Human review pending; actual local Chromium screenshots inspected. | 10 package tests, actual ARM64 nginx -t and Compose validation pass; Chromium gameplay/Story/co-op/invite/ZIP flows exercised. Production/Firefox/live provider gates pending. |
| 2026-10-27T08:15:33+05:30 | OpenAI Codex with browser Forge and independent review workers | Add browser transfers and lifecycle | Implemented hosted adapter/invite UI, file pickers, strict bundle ZIPs, safe snapshot installation, mode focus/sizing and retained native kit selection. Review repaired uncertain submission state, rollback and cancellation after creator exit. | Human review pending; actual Chromium title/solo combat/pause/Home inspected. | Arena 23/23, native Forge 176/0, browser boundaries 31/0; no providers. Complete browser/deployment gates still pending. |
| 2026-10-27T08:13:49+05:30 | OpenAI Codex with hosted Forge implementation and review workers | Add hosted invited authoring | Built API/session/queue/worker, owner-projected status and artifacts, durable SQLite reservations, worker-only secret support; retained native accounting. Review corrected whole-master artifact admission and truthful configured-model reporting. | Human review pending; integrator reviewed boundaries and tests. | 30 hosted tests pass; 61 native provider/accounting/recovery tests passed. No live provider request or deployment claimed. |
| 2026-10-27T08:10:48+05:30 | OpenAI Codex with runtime baseline worker | Repair arena baseline before browser release | Guarded freed enemy references and corrected revival/pursuit fixtures for current wave flow. | Human review pending; integrator reviewed focused diff. | Godot 4.7.2 headless arena 23/23 scenarios pass; no provider calls. |
| 2026-10-27T00:25:15+05:30 | Devin CLI (Cognition) | Accessibility, documentation and video publishing | Added Arena accessibility settings/assists/narration/remapping, solo keyboard-side choice, accessibility test and tour, `--record` launchers and Story Movie Maker framing fix; rewrote README, added accessibility/videos guides and recording evidence; recorded four real-engine videos and published them with the owner's intro. Found and fixed during work: Callable bind order for adjust rows, compile-time autoload reference in the tour, Story capture cropping. | Human review pending; user authorised pushing and the release. | Accessibility scenario passes; arena/forge failures match clean `96ae418`; Python/validators/check_pack pass; route passes; recordings' reports and stills inspected. |
| 2026-10-25T08:27:56+05:30 | OpenAI Codex with Story driver/launcher and lifecycle review workers | Create full RPG/Story autoplay | Added sequential viewer/launcher, real-input secret and Gallery cleanup, readable Next dialogue, pause/speed/quit, isolated saves and exact evidence. Fixed review-found cancellation/report handling and observed pause/input/modal timing failures. | Human review pending; actual native captures inspected and automated/handler evidence distinguished. | Complete8-room headless/native routes pass with secret/all flags,0recoveries/errors; pause/resume/speed/cancel pass. No API/export/broad suite or human/hardware claim. |
| 2026-10-25T08:15:19+05:30 | OpenAI Codex with launcher/docs and read-only review workers | Create automated gameplay showcase | Added visible highlight/full-route launcher, labeled staging, spectator controls/reporting, route hooks and evidence; corrected report staging/skip outcomes and audio cleanup during review. | Human review pending; native captures inspected, staged encounters distinguished from ordinary-input routes. | Seven smoke chapters/32peak/six roles pass; native handler/render QA and ordinary co-op2 route pass; no API/export/full-suite or new full25 run. |
| 2026-10-25T08:07:35+05:30 | OpenAI Codex with enemy diagnosis/regression worker | Fix wave-one stall and speed up replenishment | Reproduced nearby cave catch-up policy gap; changed session spawn/pursuit/timers and HUD, added one focused regression and source evidence. | Human review pending; untimed owned shops preserved. | Focused scenario1pass/0fail; solo/co-op2-wave owned-input bots pass1198/2267ticks, no route/engine errors; no broad suite/export/API calls. |
| 2026-10-25T07:19:34+05:30 | OpenAI Codex with branch-audit/review worker | Merge branch histories and prepare final review | Integrated final gallery/guide histories, retained unique sideview prompts and archived incompatible overhead changes through an explicit current-tree merge; linked real screenshots and final source instructions. | Human review pending; current 2D modes preserved and private character art excluded. | Read-only ancestry/diff review only, all fetched refs integrated; no new test suite/build/model request. |
| 2026-10-25T07:16:10+05:30 | OpenAI Codex with art/conversion, staging and combat workers; built-in image_gen | Preserve the user-preferred full character and enforce attack identity | Added illustrated-master generation/import/poses and compatible kit rules; extracted the actual retained wizard for the local library. | Human review pending; private preview/atlas/game inspected, private art excluded from Git. | One built-in cutout edit; local conversion/acceptance/combat succeeds with unchanged user-API ledger and Frost in runtime; broad tests/builds skipped. |
| 2026-10-25T06:50:14+05:30 | OpenAI Codex with Agent 2 documentation worker | Integrate illustrated player guide | Added detailed controls/modes/forge/walkthrough instructions, 11 real images and provenance; linked guide and current source launch. | Human review pending. | Native Story entry/r00/return and creator page captured; no test suites, build or API calls. |
| 2026-10-25T06:47:19+05:30 | OpenAI Codex with generation-prompt worker | Make fighter name/weapon guide art and kit | Forwarded explicit name before analysis, bound identity to fresh image prompts, preserved held weapons and added editable name-led kit suggestions. | Human review pending. | Code/diff review only; tests/import/build/API calls skipped at user request, no new-output quality claim. |
| 2026-10-25T06:46:40+05:30 | OpenAI Codex with story runtime worker | Restore Story Mode alongside wave arena | Wired existing campaign entry and save-safe return actions with per-mode sizing; preserved saves. | Human review pending. | Read-only dependency/diff review; tests/import/build skipped at user request, no new full-playthrough claim. |
| 2026-10-25T06:38:49+05:30 | OpenAI Codex | Publish counterplay/creator integration | Exported exact merged Linux revision, retained completed offline/ZIP results, updated release records and launch guidance. | Human review pending; user requested no further optional tests, no model calls made. | Official 25-wave export passes offline in 50,487 ticks; normal boot and all 30 archive entries/payload hashes pass. |
| 2026-10-25T06:32:57+05:30 | OpenAI Codex with enemy, contact-origin and independent review workers | Add distinct enemy mechanics and counterplay | Implemented committed tells/recovery, directional guard counters and native/whole-run verification; fixed a review-found flyer target-lock defect. | Human review pending; native cues inspected and bots/controlled fixtures distinguished. | 21 arena/173 creator/187 Python checks pass; solo20/co-op25 ordinary-input routes and four actual native captures pass. No image/API requests. |
| 2026-10-25T06:30:55+05:30 | OpenAI Codex with independent crop review; Agent 2 Python integration | Fix reported Save/convert loop and acceptance handoff | Added visible-pixel preflight, click-safe crops, useful modal errors, uncapped status UI and actual creator-to-combat verification. | Human review pending; latest user-approved art reviewed privately and recovered locally, no new image requests. | Three layout/two handoff failures reproduced before fix; 173 creator checks and native offline conversion/acceptance/combat pass with unchanged accounting. |
| 2026-10-25T06:09:09+05:30 | OpenAI Codex; independent read-only evidence review | Integrate and package the scrolling world | Merged focused checkpoints, exported the official Linux builds, checked offline routes/archive inventory and updated release evidence. | Human review pending; private Wizard retained locally; no new model requests. | 25-wave official export passes offline; normal boot and native title inspected; all 30 archive entries/payload hashes verified. |
| 2026-10-25T06:00:11+05:30 | OpenAI Codex with map/art, camera and independent review workers; Agent 2 package QA | Implement expanding-world plan and integrate tested runtime | Authored map/scenery, camera/shops/loot, world-relative combat/navigation and export provenance; fixed issues found by real routes and native captures. | Human review pending; recorded bots, controlled fixtures and native metrics separately. | 19 arena/162 creator/186 Python checks, validators/import and solo 20/co-op 25 exploration routes pass. Native split captures/profile retained; private Wizard stays local, no new world-generation API calls. |
| 2026-10-25T05:13:53+05:30 | OpenAI Codex with budget worker; existing gpt-image-1-mini | Fix local authoring budget and resume the blocked drawing | Added configurable lifetime allowance, safe accounting/UI and explicit resume; isolated test drafts and locally corrected the retained returned layout. | Human review pending; private drawing/assets retained locally. |72focusedPython checks and162creator assertions pass; real pair succeeds within2USDcap; offline native correction/acceptance passes without more requests. Ledger0.55reserved, not billing. |
| 2026-10-25T04:57:53+05:30 | OpenAI Codex | Start approved expanding-world and budget implementation | Established map/presentation/budget interfaces and exclusive parallel lanes; refreshed active guidance. | Human review pending; user selected allowance, terrain, free breaks, split camera and world-only scenery. | Baseline12arena scenarios pass; new implementation/acceptance pending. |
| 2026-10-25T04:26:31+05:30 | OpenAI Codex | Package and publish the tested arena checkpoint | Merged main, exported/hashed Linux package, ran official offline route, inspected visible packaged title and recorded current submission/release evidence. | Human review pending; automated route and controlled fixtures are explicitly distinguished. | Official export25waves/34,142ticks without overrides/errors, offline normal boot, all28ZIP entries/hash checks and matching GitHub digest. No new API calls; physical/human gates remain unverified. |
| 2026-10-25T04:18:53+05:30 | OpenAI Codex with parallel content/actor/creator/provider workers; live `gpt-6-luna` and `gpt-image-1-mini` | Integrate reviewed generated starter, six special cues and local crop recovery | Added raw-layout UI/fresh drafts, fixed cross-language integer serialization and modal keyboard focus, retained native/offline evidence and refreshed current guidance. | Human review pending. Codex inspected actual generated poses and native captures; corrected provider layout locally without another request. | 12 arena scenarios, 154 creator assertions, 173 Python tests/import/validators pass; generated solo20 and network-isolated actual UI conversion/acceptance pass. Native crowd p95 11.779 ms is offscreen only; physical/human gates remain unverified. |
| 2026-10-25T03:39:54+05:30 | Codex with actor review | Optimize and verify dense wave combat/export | Reduced retained-canvas redraws, sweep allocations and HUD churn; added official arena QA export and retained current captures/source hashes. | Human/physical-device review pending; source and export runs use state-aware ordinary-input bots. |7actor scenarios plus30,000sweep cases;11arena/107forge/147Python checks; solo20/co-op25 and offline official export25 pass. Native offscreenp9513.253ms under32enemies/67projectiles. Image calls now return PNGs; rejected-layout correction remains separate. |
| 2026-10-25T03:10:36+05:30 | Codex with parallel Codex actors/creator/Agent2content and provider workers | Implement approved wave arena and local fighter forge | Built run/economy/UI, owned combat actors, creation/library and original generated-by-code content; integrated budgeted official SDK pipeline and review regressions. | Human review pending; fixed simultaneous shop edge loss, duplicate combat effects, terrain/reset and creator layout issues. |11arena scenarios,107forge assertions,146Python tests/import pass; actualLunaanalysisworks, mini image403blocked; no generatedart/nativefullgame/human completion claim. |
| 2026-10-25T02:47:21+05:30 | Codex | Start approved wave-fighter rebuild | Wrote current product/bundle/job contracts, parallel ownership and superseding documentation. | Human implementation review pending | Clean Git baseline and Godot4.7.2 confirmed; new game and live generation pending. |
| 2026-10-25T02:24:23+05:30 | Codex | Add bounded OpenAI image-authoring commands | Added optional official OpenAI SDK dependency setup, private.env loading/status, explicit model/quality plans, one/two-request generation, retained raw PNG/prompt/usage/hash provenance and local candidate preparation commands. Excluded local build and env data from both exports. | Pending human review | Eight mocked-provider/credential/decode/provenance tests pass; SDK2.54.0 installed in ignored.venv; key presence verified without its value. Real requests and converted quality are recorded separately after the shared prompt library lands. |
| 2026-10-25T02:20:42+05:30 | Codex | Restore the original side-view adventure | Restored verified34ccb96side-view simulation, rooms, art/audio, tests and authoring tools as a forward change. Preserved the complete overhead experiment on its branch. Created an ignored private blank.env and documented the newly authorized optional API authoring boundary. | Pending human review | Fresh restored import and20/20 engine scenarios pass, plus full asset/content validators and documentation/whitespace checks. No key is present and no live API generation is claimed. |
| 2026-10-25T02:18:24+05:30 | Codex | Preserve tested overhead experiment before returning to side view | Retained active overhead resource/App/save regressions and archived platform-only fixtures with explicit historical mapping; switched native QA observer to the new ordinary-input overhead route. | Pending human review | Full112Python tests, both validators, fresh import and40/40 active Godot scenarios pass. Native first-room split-screen rendered; full overhead native/export and human gates remain unverified. |
| 2026-10-25T02:13:07+05:30 | Codex | Reject malformed room epochs without script errors | Type-check the room content epoch before string comparison and retain overhead spawn/reference boundary checks. | Pending human review | Focused room-loading scenario now passes incompatible string, boolean, integer and null epochs plus dry-footprint checks; whitespace and pack checks pass. |
| 2026-10-25T02:06:20+05:30 | Codex | Teach overhead join controls | Replaced stale jump/default-key prose with per-slot current bindings and correct team dash availability | Pending human review | Actual-App controls scenario and editor import pass; corrected prior log table formatting |
| 2026-10-25T02:05:12+05:30 | Codex | Isolate overhead development identity | Set dedicated user data and derive package version from project configuration; corrected launch/evidence guide | Pending human review; preserved prior release and saves | Packaging compilation, documentation and whitespace checks pass; native overhead export pending |
| 2026-10-25T02:01:00+05:30 | Codex | Connect overhead story/session consumers | Integrated worldworker session/geometry/guidance and peer corrections; wired actual App intro completion and authored concise mission dialogue | Native/fresh-pair review pending; full route driver follows | Content validator and24new overhead engine scenarios PASS; fixture/actual UI boundary evidence distinguished from complete route |
| 2026-10-25T01:47:13+05:30 | Codex | Integrate overhead media admission | True-merged Agent2 original50asset packet; implemented strict directional/frame/timing/pivot/tile consumer and fixed metadata migration | Human art/music/gameplay review pending | Clean media import + actual boundary/negative scenarios PASS; whole new game still integrating |
| 2026-10-25T01:03:41+05:30 | Codex | Plan overhead migration and lane contracts | Converted latest user direction into explicit motor/art/terrain/save interfaces and playable milestones; coordinated Agent2 and actor review | User requested overhead perspective and200meaningful commits; implementation review pending | Docs links/whitespace pass; old side-view evidence kept separate |
| 2026-10-25T00:53:13+05:30 | Codex | Preserve tested milestone and start overhead direction | Packaged34ccb96with source/executable/archive identity; ran native no-network same-source release route and retained captures/raw timings/matrix; updated truthful release/submission/current scope | Pending fresh human/device/listening review; latest user requests overhead rewrite and200meaningful commits | 20engine/79Python tests and full validators pass; offline native route reaches ending; measured120medianFPS at1920x720. Evidence remains side-view-specific |
| 2026-10-25T00:31:03+05:30 | Codex | Repair missing-font startup reporting | Agent2 sandbox review found the font-dependent invisible failure UI; integrator moved validation before UI and added a diagnostic-only emergency screen plus regression | Pending human review; prior b96ad0e artifact superseded | Startup scenario PASS; all20 integrated scenarios PASS; no gameplay fallback or new content/backend scope |
| 2026-10-25T00:17:08+05:30 | Codex | Polish menus and prepare Linux candidate | Integrated Agent2 native layout evidence; added clean-commit exporter/packager, license/provenance inventory, launch guide and QA build metadata; improved notice contrast | Pending human review; no physical-controller/listening/fresh-pair claim | 19 integrated scenarios PASS; focused App checks PASS; packaging syntax/pack links/whitespace checked. Final package/offline proof follows the source checkpoint |
| 2026-10-25T00:02:04+05:30 | Codex | Complete player flows and campaign verification | Integrated separate menu worker; implemented app join/settings/remap/reconnect/dialogue/ending flows and HUD; delegated real physics route/movement/secret regressions | Pending human review; fixed coyote boundary, secret dedup, stale reward visuals and save-error masking | 18 scenarios PASS; actual-App full ordinary-input campaign reaches ending;600tick trace matches30/60/144; native room/boss/ending captures reviewed. Export/performance still in progress; no hardware/listening/fresh-pair claim |
| 2026-10-24T23:36:24+05:30 | Codex | Integrate production content and campaign core | Bounded workers implemented combat, runtime catalogs/presentation/audio and persistence verification; integrator owns shared session and true content merge | Pending human review; integration fixed simultaneous latch input loss, exact prop states, backup and save validation defects | Full import, full asset/content validators, 79 Python tests and 12 integrated Godot scenarios PASS; full route/UI/export/visible/hardware gates remain pending |
| 2026-10-24T22:50:16+05:30 | Codex | Refresh parallel handoff documentation | Corrected setup/decision/implementation/test/submission status and recorded the queued later content branch without claiming full gameplay | Pending | Pack/link checks, whitespace and remote refs verified; no new code or playtest claims |
| 2026-10-24T22:40:57+05:30 | Codex | Integrate first content packet | Merged Agent 2 diagnostic data/art, imported resources, added actual-content engine scenario, recorded jump/headroom metrics and initial native window capture | Pending — no human/device playthrough claimed | Diagnostic validators and 15 Python tests PASS; actual-content physics scenario/normal headless boot/import PASS. Static native capture observed; hidden-window visible input/motion remains unverified. Dash/full adventure not claimed |
| 2026-10-24T22:32:31+05:30 | Codex | Build the shared M0 session | Implemented boot/session/presentation/catalog with bounded player/camera/mover subagent work; added actual-physics session smoke fixture and safe missing-content startup | Pending — no human/device playthrough claimed | Clean editor import and session fixture smoke PASS; isolated motor/camera harness 19 checks PASS. Production content, rendering and actual input review follow Agent 2's first packet |
| 2026-10-24T22:23:11+05:30 | Codex | Start Agent 1 runtime verification | Built scenario runner and focused input/room cases with bounded subagent help; repaired bindings/remapping/reconnect/latching and room/spawn validation; recorded actual engine results and generated UID metadata | Pending — no physical device or human gameplay review claimed | 2 component scenarios PASS; wrapper filter PASS; empty filter correctly fails. Held-stick regression caught/fixed. Editor scan reports missing boot resource; complete-game import/launch and gameplay remain incomplete |
| 2026-10-24T22:10:33+05:30 | Codex | Prepare two-agent execution | Wrote runtime brief, coordinated the content brief, fixed shared interfaces/ownership and integration stages, linked current instructions and allocated independent logs; prepares separate feature branches/checkouts | Pending — user chose separate checkouts and requested immediate setup | Pack/link checks and whitespace validation before commit; branch/checkout/remote results verified after setup. No game completion or gameplay evidence claimed |

## Agent 2 — content and assets

| Date and time with timezone | Tool / model, if known | Task | Assistance and affected files | Human review / corrections | Validation and result |
| --- | --- | --- | --- | --- | --- |
| 2026-10-25T02:24:46+05:30 | Codex | Specify side-view image studies | Authored original material and 32-state Tavi prompts with registration, identity and layout constraints; coordinated provider/converter ownership with Agent 1 | Pending; no generated image accepted or human review claimed | JSON/job-contract, pack/link and whitespace PASS; provider generation and candidate quality not tested here |
| 2026-10-25T01:49:29+05:30 | Codex | Repair overhead authoring previews | Updated material/feet/crop/sort rendering, epoch/no-write guards, selected-room CLI and original font captions; protected historical evidence with a versioned default | Pending; independent review found no blocker; default-path clobber regression corrected | Full112Python/nineCLI cases, compilation/pack/whitespace PASS; labelled r00 snapshot study and hashes retained; no gameplay acceptance claim |
| 2026-10-25T01:29:53+05:30 | Codex | Add a dedicated overhead enemy warning | Authored stable hollow directional marker at actor-lane request; added original source/atlas, finite-effect admission and regression coverage | Pending; independent source/contact review found no blocker | Full50asset validation,103Python/two rebuilds,media import/pack/whitespace PASS; previous49media unchanged; runtime placement/encounter acceptance pending |
| 2026-10-25T01:18:03+05:30 | Codex | Build original overhead media and active music | Coordinated exact contracts with Agent 1; parallel workers authored directional heroes, radial actors/terrain/effects and original scores/synthesis/roll cue; integrated retained output/provenance and strict admission | Pending; source reviews corrected clip-name admission gaps; no external game content used | 100 Python tests/two rebuilds, full49asset validator and Godot media import PASS; original18SFX match baseline; static sheets inspected; actual overhead gameplay/listening/hardware/human acceptance not claimed |
| 2026-10-25T00:55:01+05:30 | Codex | Improve home composition and control clarity | Added original render-only title vignette, compact actions, real binding guides, owner badge and UI regression; coordinated runtime/animation/music boundaries with Agent 1 | Pending; native overlap and long-detail overflow corrected before delivery | Import/baseline20 and final21 engine scenarios PASS; native1×/2× fixture/input checks, pack/link/design scan/whitespace PASS; overhead/hardware/listening/human gates remain separate |
| 2026-10-25T00:28:37+05:30 | Codex | Prepare drawing-derived characters and textures | Coordinated source freeze with Agent 1; authored future brief/research and inspected fixed profile/theme/save boundaries with read-only subagents | Pending; corrected fixed-runtime readiness claims; missing-font startup case escalated to Agent 1 | Both full validators and 79 Python tests PASS; documentation/link/whitespace checks PASS; sandbox probes are diagnostic observations, not new feature acceptance |
| 2026-10-25T00:15:26+05:30 | Codex | Close peer-review UI harness gaps | Validated exact unique capture kinds, fresh paths/dimensions/nonblank distinct pixels and expected process lifetime | Pending; read-only peer review identified and verified the guard gaps | Full native helper and Python compilation PASS; captures unchanged; pack/link and whitespace PASS |
| 2026-10-25T00:13:18+05:30 | Codex | Strengthen native UI capture evidence | Added positive framebuffer/colour assertions so matching blank screenshots cannot satisfy input/scaling checks | Pending; physical settings screenshot visually inspected | Native QA helper, pack/link and whitespace checks PASS; fixture-only scope retained |
| 2026-10-25T00:06:44+05:30 | Codex | Finish UI native and layout QA | Added long-layout/mouse regression coverage, original-font preview scene and private-display capture/input helper; fixed overflow cue, critical text scale, footer wrapping and recoverable logger severity | Pending; native source review identified readability fixes; exact component API retained | Six scenarios PASS with 24 UI groups; actual 1x/2x window captures, owner/non-owner input, mouse payloads and two-line footer pass. No full-app, hardware, performance or human acceptance claimed |
| 2026-10-24T23:40:29+05:30 | Codex | Implement shared GameMenus UI | Built the owner-bound generic menu renderer, original-font layout and intent protocol; added real-engine input/pause scenarios and integration evidence on a UI-only branch | Pending; Agent 1 assigned the UI boundary; peer source review found no blocker | Baseline import/four scenarios/15 Python tests PASS; missing-component RED then five-scenario GREEN including 13 UI groups; pack/whitespace PASS. Native UI/window and full application checks remain pending |
| 2026-10-24T23:06:44+05:30 | Codex | Continue content QA autonomously | Reproduced accepted empty/cloned assets and silent PCM; added visibility, canonical mask and decoded composition gates with negative fixtures. Improved r02/r03/r06 approaches/clearance/recovery and expanded authoring views | Pending; original data references and generated assets preserved | 79 tests and both full validators PASS; temporary diagnostic validation, event/pack/whitespace PASS; native source-art views inspected. No runtime traversal/listening/human result claimed |
| 2026-10-24T23:00:02+05:30 | Codex | Correct Devin Hack Kochi documentation | Read the user-linked corrected template at its exact commit; corrected event/provider/logistics guidance across active docs, refreshed branch-specific status and added the event identity check | Pending; user explicitly requested the correction; historical Codex/Devin attribution preserved | New gate reproduced stale README failure then passed; pack/106 links, compilation and whitespace PASS. Runtime evidence read only; no new gameplay claims |
| 2026-10-24T22:46:23+05:30 | Codex | Reconcile measured motor evidence | Added full content SHA and Agent 1's exact measured jump/clearance command, configuration and limitations to the content handoff | Pending; no content/runtime implementation changed | Read committed runtime evidence; pack/whitespace PASS. Diagnostic movement measurements do not pass full-route or dash gates |
| 2026-10-24T22:43:33+05:30 | Codex | Author eight-room story data and integration evidence | Authored full room layouts/decor, canonical exits/progression/entities, data-only fixtures, content boundary tests and labelled source-art previews; documented concrete runtime traversal/presentation requests | Pending; review fixed rally feet inclusion, unsafe data crashes, missing causeway validation and overlarge draft stairs | Full content/assets PASS; 69 tests PASS; pack/whitespace PASS; native authoring inspection. No runtime traversal, animation, listening, controller, export or human gate claimed |
| 2026-10-24T22:40:32+05:30 | Codex | Complete original asset inventory | Authored production pixel/pose recipes, actor atlases, material/background/prop/effect/UI output and original synthesized cues/music with retained editable sources; strengthened negative validators and rebuild checks | Pending; review corrected inner-corner orientation; no human animation/listening review claimed | 47 full assets validate; 40 asset/audio/generator tests PASS; twice-generated hashes identical; native authoring sheets inspected. Engine playback, physical traversal, listening, gamepads and human acceptance remain pending |
| 2026-10-24T22:29:31+05:30 | Codex | Implement Drop A diagnostic tracer | Authored original pixel recipes/glyphs, generator, six-asset manifest, fixed content/r00, staged Python validators and tests; parallel agents assisted content and validation | Pending; user approved the content plan and Agent 1 integration | Diagnostic generation/asset/content checks PASS; 15 tests PASS; preflight/pack/whitespace PASS; courier PNGs inspected. Full validator rejects incomplete bundle. No engine/gameplay/audio/human acceptance claimed |
<!-- Agent 2 inserts its newest contribution row above this marker. -->

## Earlier contributions

| Date and time with timezone | Tool / model, if known | Task | Assistance and affected files | Human review / corrections | Validation and result |
| --- | --- | --- | --- | --- | --- |
| 2026-10-24T21:51:38+05:30 | Codex | Review and prepare GitHub publication | Read the handoff, docs and code with read-only subagent reviews; corrected only the two unpublished project commit identities; retained the organizer template and local backup; configured the authorized origin; corrected stale implementation/demo status and recorded the repository URL | Pending — user authorized publication and normal author identity; no human gameplay review claimed | Preflight and planning-pack checks PASS; Git integrity/whitespace checks PASS; replacement trees/messages/author dates verified; targeted scan of 52 original tracked blobs found no credential-pattern or private-filename matches. Engine/gameplay checks remain unverified; remote verification follows push |
| 2026-10-24T21:42:00+05:30 | Devin CLI (Claude) | Start M0 engine shell and write the handoff | Wrote `project.godot`, input contract scripts, `AudioDirector`, `RoomDefinition`, `CollisionBuilder`, `GrayboxSkin`, `Room`; wrote `HANDOFF.md` and `docs/PLAN_PHASE1.md`; updated `docs/STATUS.md`, `CHANGELOG.md` | Pending — user requested the handoff because the agent's budget ran low | `python3 tools/check_pack.py` PASS. No Godot parse/import/run performed on the new scripts (unverified) |
| 2026-10-24T21:25:00+05:30 | Devin CLI (Claude) | Read the full design pack, verify the environment and write the Phase 1 implementation plan; bootstrap the repository on the hackathon template | Wrote the milestone plan (M0–M7, decisions D1–D12, parallel work split). Merged `README.md`, extended `AGENTS.md`, filled `CHANGELOG.md`, `AI_USAGE.md`, `SUBMISSION.md`, `.gitignore`; removed the template remote. | Pending — user chose scope (full Phase 1), input mode (keyboard + keyboard), template adoption and parallel subagents through the plan questions | `python3 tools/preflight.py` exit 0; `python3 tools/check_pack.py` PASS; Godot 4.7.2 CLI flags and split-screen docs checked against official sources |

## Template preparation

This historical note describes the inherited template, not current event logistics or AI requirements. Current guidance is in [RULES.md](RULES.md).

On 10 October 2026, Codex prepared the documentation template this repository started from, covering `README.md`, `RULES.md`, `AGENTS.md`, `CHANGELOG.md`, `AI_USAGE.md`, `SUBMISSION.md`, `.gitignore` and the pull request checklist. That preparation is separate from this project's implementation and the AI usage recorded above.


## Overhead actor lane

<!-- overhead-actors -->

- 2026-10-25T02:08:28+05:30 | Codex | Independently exercised integrated actors against original profiles/assets and authored room geometry after merging core5162c34. Human review pending. Production-content actor scenario passes; corrected a test overconstraint for safe collision-margin settling, with no speculative runtime change.


- 2026-10-25T01:37:34+05:30 | Codex | Corrected the traversal fixture after the world worker identified its now-invalid partial boss reward. Human review pending. Focused scenario passes against the integrator progress contract.


- 2026-10-25T01:37:07+05:30 | Codex | Added the approved enemy-warning asset consumer and actual-physics animator checks. Human review pending. Fixture-based scenario passes; production art quality and native readability remain integration gates.


- 2026-10-25T01:35:23+05:30 | Codex | Investigated buffered same-facing animation restart with actual physics and a diagnostic texture atlas. Human review pending. Regression passes without a source fix; retained existing same-state guards and avoided speculative API changes.


- 2026-10-25T01:31:49+05:30 | Codex | Aligned damage/revival presentation with the accepted state transition and added focused damage regressions. Human review pending. Scenario passes; UID generated by own-clone import with known editor socket warnings.


- 2026-10-25T01:30:41+05:30 | Codex | Fixed overlong evasion caused by deduplicating rejected contacts. Human review pending. Focused real-physics boss contact regression passes and retains accepted-hit deduplication.


- 2026-10-25T01:28:41+05:30 | Codex | Added shared boss phase state and non-overwriting combat feedback. Human review pending. Focused boss scenario passes; pending integrated route and native feedback review remain disclosed.


- 2026-10-25T01:27:48+05:30 | Codex | Added boss phase-pattern acceptance and generated owned script UIDs. Human review pending. Actor clone passes 8/8 scenarios; import environment warnings and controlled boss damage fixtures are disclosed. No normal-route or rendered-quality claim.


- 2026-10-25T01:25:13+05:30 | Codex | Migrated enemy movement, ground hurtboxes and explicit room-water flight; added real FSM/physics assertions with controlled placements. Human review pending. Ordinary enemy scenario and six courier scenarios pass; boss-specific acceptance and rendered art remain pending.


- 2026-10-25T01:22:30+05:30 | Codex | Corrected post-roll coasting found while reviewing dash braking. Human review pending. Added and passed a neutral-input completion assertion in the real-physics roll scenario.


- 2026-10-25T01:21:52+05:30 | Codex | Added explicitly authorized projectile water flight through the room-context body. Human review pending. Focused Spore scenario passes with water traversal and retained wall rejection.


- 2026-10-25T01:21:06+05:30 | Codex | Implemented room-owned Threadstep validation and per-courier water exceptions with exact-distance and interruption scenarios. Human review pending. Six isolated actor scenarios pass; no full campaign route claim.


- 2026-10-25T01:19:15+05:30 | Codex | Migrated Neri projectile movement and swept hit ordering with actual-physics scenarios. Human review pending. Five isolated actor scenarios pass; terrain/target fixtures do not establish full-route balance.


- 2026-10-25T01:17:53+05:30 | Codex | Implemented the directed Ember Arc and explicit special timing. Human review pending. Four isolated scenarios pass, including geometric fan and wall checks; authored effects have not been rendered here.


- 2026-10-25T01:17:03+05:30 | Codex | Implemented cardinal slash timing and bounded attack buffering, plus real motor/query scenarios. Human review pending. Three isolated actor scenarios pass; checks use stationary enemy fixtures and make no authored-art claim.


- 2026-10-25T01:15:39+05:30 | Codex | Added the overhead roll and actual-physics boundary tests. Human review pending. Isolated Godot 4.7.2 actor scenarios pass 2/2; original roll sound/rendered animation remain pending.


- 2026-10-25T01:12:16+05:30 | Codex | Implemented floating courier movement, cardinal facing, footprint and room-context API with a real-physics owned-input scenario. Human review pending. Isolated Godot 4.7.2 scenario passes; corrected an inferred-string parse error during verification. Original directional art and combat migration remain pending.




## Overhead world lane

<!-- overhead-world -->

### 2026-10-25 02:08:22 +0530 — Budget the campaign for real-time execution

- OpenAI Codex coordinated the route's 300-second wall-clock budget with the runner owner so the verified 99-second campaign can run without fixed-FPS acceleration. No gameplay or acceptance assertion changes; no new native-run claim.


### 2026-10-25 02:07:36 +0530 — Verify the production overhead route

- Tool: OpenAI Codex merged the published consumer/media branch and ran the authored ordinary-input campaign gate. Fixed only the driver's normalized-direction mask and asynchronous test audio retirement.
- Checks: campaign PASS at 5,941 physics ticks with all eight rooms/ending/save and no recovery; combined overhead PASS 25/25 with writable isolated user data; content validator PASS. Actual App menu/dialogue intents and gameplay inputs are exercised, with no fixture repositioning or progression overrides.
- Human review: pending. Native captures, export behavior, physical devices and listening remain independent integrator gates; side-view evidence is not reused as overhead proof.


### 2026-10-25 01:50:17 +0530 — Draft tick-indexed campaign acceptance driver

- Tool: OpenAI Codex authored the newly assigned ordinary-input overhead campaign gate using actual App intents, canonical room queries and physics-indexed commands. No forced flags, actor repositioning, private room loads or direct damage calls.
- Checks: real runner parsed the scenario; expected production catalog startup failure prevents route verification. This remains WIP until the independent consumer/art bundle lands. Generated UID retained; no fabricated route evidence.


### 2026-10-25 01:42:11 +0530 — Correct transient cooperative guidance

- Tool: OpenAI Codex implemented the peer-reviewed per-slot target filter and ownership wording in Session/HUD, leaving QuestDirector pure. Added controlled anchor/Loom/downed guidance coverage and retained its generated UID.
- Checks: overhead_session PASS 3/3. Peer read-only review identified the stale claimed-end compass target; root owns the separate App dialogue-completion wiring. Human/native visual review remains pending.


### 2026-10-25 01:39:12 +0530 — Mid-Threadstep recovery diagnosis

- Tool: OpenAI Codex added the controlled transaction scenario, reproduced the stale-water-RID engine error, and fixed lifetime ordering in GameSession without modifying actor physics.
- Checks: overhead_session PASS 2/2 with no runtime errors. The regression failed before the ordering fix and passes afterward; generated scenario UID retained. Human review and integrated production playthrough remain pending.


### 2026-10-25 01:36:43 +0530 — Shared overhead session integration

- Tool: OpenAI Codex connected the exclusive GameSession/SplitPresentation/FollowCamera files to the merged actor/input APIs and authored an isolated session regression. Added completion-based Oru progress and per-slot guidance without changing actor/input sources.
- Checks: session fixture PASS; combined overhead 17/18 (one stale actor reward fixture reported for correction). Corrected the new test to use the complete boss/unlock/shortcut reward transaction. Null-catalog fixtures are not production-asset or playthrough evidence.
- Human review: pending; root retains App/catalog/art publication ownership.


### 2026-10-25 01:28:24 +0530 — Overhead validator and admission regressions

- Tool: OpenAI Codex implemented the world lane's overhead schema/route validation and 29 focused Python cases, aligned runtime bridge admission, and corrected opaque-ground draw ordering after source review.
- Checks: all 29 Python cases and both Godot overhead world scenarios pass. Temporary synthetic metadata isolates this lane from pending original-art/catalog work; production validation remains visibly failing until those bundles are integrated. Import-only sandbox socket errors are disclosed rather than treated as gameplay failure.
- Human review: pending. No external content or fabricated playthrough/rendering evidence; ordinary-input integrated acceptance remains the integrator's gate.


### 2026-10-25 01:21:27 +0530 — Overhead room authoring and route checks

- Tool: OpenAI Codex authored the seven remaining room JSON sources and a focused world-route scenario within the exclusive world lane. No outside maps/assets were used.
- Checks: overhead_world PASS 2/2; corrected the test fixture to instantiate only one collision room at a time, matching the production invariant. Three safe dash launch offsets pass on both axes.
- Human review: pending. This does not claim encounter balance, original-art visual quality or an integrated campaign playthrough.


### 2026-10-25 01:14:36 +0530 — Overhead world foundation

- Tool: OpenAI Codex; authored the owned parser/collision/room/theme lane, overhead r00/world gate and focused physical regression fixtures in feat/overhead-world.
- Checks: overhead_world_foundation PASS 1/1 on Godot 4.7.2; diff whitespace check. Corrected the initial exact three-tile teaching assumption after integrator chose forgiving two-tile mandatory gaps; three-tile case remains a boundary probe only.
- Human review: not yet performed. No rendered overhead quality, physical controller or listening claim; other rooms and integrated catalogs remain pending.




## Overhead input and persistence lane

<!-- overhead-input -->

### 2026-10-25T01:24:34+05:30 — Codex: pure quest and route guidance

Codex authored QuestDirector and fixture regressions in the exclusive input worktree. The module reads team/world/room state and returns objectives/targets without scene or campaign mutations. Human review is pending. Focused Godot guidance checks and import passed; rendered HUD/map integration remains with the integrator.


### 2026-10-25T01:18:32+05:30 — Codex: protect foreign backups

Codex identified and fixed silent replacement of incompatible backup data during ordinary rotation, with actual-file newer/corrupt backup regressions. Human review is pending. Both overhead save scenarios pass; storage hardware fault acceptance remains unverified.


### 2026-10-25T01:16:49+05:30 — Codex: explicit gamepad admission

Codex guarded negative device indices and verified owned Roll latching across synthetic reconnect/reassignment. Human review is pending. Three overhead input scenarios and editor import passed; physical hardware acceptance remains unverified.


### 2026-10-25T01:15:46+05:30 — Codex: atomic overhead progression and recovery

Codex hardened the live progress mutator against partial traversal rewards and wrote actual-file save/backup/fault/settings regressions. Human review is pending. Two focused save scenarios and editor import passed; physical storage power-loss testing was not performed.


### 2026-10-25T01:13:15+05:30 — Codex: bounded planar input

Codex implemented full-vector normalization at the snapshot boundary and added owned keyboard/synthetic gamepad regressions, including release and loss behavior. Human review is pending. All three focused input scenarios and editor import passed; hardware behavior remains unverified.


### 2026-10-25T01:11:22+05:30 — Codex: overhead campaign version boundary

Codex versioned team progress and campaign format handling, added met_oru, and verified actual file protection/replacement in the exclusive lane. Human review is pending. The focused schema scenario and editor import passed; separate application data-directory integration and gameplay remain with the integrator.


### 2026-10-25T01:10:20+05:30 — Codex: overhead Roll migration

Codex implemented the Roll action and legacy settings migration in the exclusive input lane, including canonical-name precedence and actual file/snapshot regression checks. Human review is pending. Godot4.7.2 import and the focused scenario passed; no physical-device or overhead-movement acceptance is claimed.
