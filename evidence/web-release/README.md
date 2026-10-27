# Browser release evidence — 2026-10-27

Public game: **[gloamthread.midhunpm.in](https://gloamthread.midhunpm.in)**. Deployed implementation: [`1dac45b3816ca5174e5cf123100bd7f690f246b4`](https://github.com/9MidhunPM/GloamThread/commit/1dac45b3816ca5174e5cf123100bd7f690f246b4), immutable tag `web-v0.5.0-r9`. Godot game code is identical to the fully tested `4f456aa` checkpoint; later changes preserve CDN bytes and add manual recovery for stalled browser startup. Later documentation commits do not change that deployed payload. The site's `/BUILD.json` records the actual source, engine and payload hashes. Build/deployment instructions: [Web release guide](../../docs/WEB_RELEASE.md).

## Source checks

Godot **4.7.2 standard Compatibility**, native Arch Linux engine revision `ed1daf0bf`; the server export uses the matching official revision. Physics is fixed at 60 Hz. Python 3 source checks:

```sh
python3 tools/check_pack.py
python3 -m unittest discover -s tools/tests -p 'test_*.py'
python3 -m tools.forge.content --validate
python3 -m tools.forge.retained --validate
python3 -m tools.forge.world --validate
python3 -m tools.forge.scenery --validate
godot --headless --path . --editor --import --quit
godot --headless --fixed-fps 60 --path . --script tests/arena/run_tests.gd
godot --headless --fixed-fps 60 --path . --script tests/forge/run_tests.gd
godot --headless --fixed-fps 60 --path . --script tests/forge/browser_tests.gd
```

Results: **239 Python tests OK; arena 23/23; native Forge 178/178; browser boundary 50/50**. Editor import and all four validators pass. Python includes 31 hosted/core/HTTP, 11 backup and 10 packaging tests, with temporary stores/mock providers. Final browser assertions include snapshot replacement/rollback, changed/unchanged download cleanup with retained failure recovery, terminal refresh, prices, strict ZIP admission and cancellation transport after creator disposal. No deterministic content rebuild was run.

Ordinary-input final-source routes run with separate temporary data (runtime matches `4f456aa`; working changes during these runs were documentation only):

```sh
XDG_DATA_HOME=/tmp/gloam-r7-solo-data godot --headless --fixed-fps 60 --path . --script tools/arena_playthrough.gd -- --players 1 --waves 20 --fighter 0 --seed 18427 --output /tmp/gloam-r7-solo20.json
XDG_DATA_HOME=/tmp/gloam-r7-duo-data godot --headless --fixed-fps 60 --path . --script tools/arena_playthrough.gd -- --players 2 --waves 25 --fighter 0 --seed 18427 --output /tmp/gloam-r7-duo25.json
./story_showcase.sh --smoke --report /tmp/gloam-r7-story.json
```

Results: solo 20 succeeds in **24,994 ticks**; co-op 25 succeeds in **34,196 ticks**, with no route/engine errors. Story completes all eight rooms in **12,305 ticks**, all ending/secret flags, zero failures/errors/recoveries. Reports: [solo](source-solo20.json), [co-op](source-duo25.json), [Story](source-story.json). These headless bots use owned inputs and actual menus, with no actor placement, health/currency grants or wave/room skips. All 25 recorded source-file hash checks still match the current checkout. They are automated source evidence, separate from rendered browser checks.

## Actual browser checks

Public builds were exercised through actual browser canvas mouse/keyboard input using Playwright. Chromium used SwiftShader at 1366×768; Firefox used an isolated Xvfb display and Mesa software rendering after its headless environment rejected WebGL 2. This establishes those software-rendered browser routes, not physical GPU performance. Temporary browser contexts keep test saves separate; the private creation test used its own ignored persistent profile.

The final release smoke covers title, Solo Run, combat, pause, toolbar Home/Resume, Story title entry and return to Arena. Earlier public Chromium builds in the same milestone additionally exercise camera split/merge, ordinary wave-one clear, independent shop purchases, P1 Ready waiting for P2, then wave two, invite unlock and fighter ZIP download/import. Local Chromium also verifies Story save/return/reload/Continue. No page/console errors were captured on these gameplay routes. Chromium 153 and Firefox 155 final r9 reports include the exact clean BUILD and user agent: [Chromium](chromium.json), [Firefox](firefox.json). The [deployed BUILD snapshot](BUILD.json) and [public integrity report](public-integrity.json) verify all nine delivered file sizes/hashes and absence of the two known private values.

Controlled Chromium IndexedDB denial at 1280×720/DPR 1.25 still boots combat/pause, displays a storage warning and fits the canvas within the viewport. Fullscreen enters/exits through visible toolbar controls and Settings reflects actual fullscreen state. A 390×844 viewport shows the desktop-controls message. No mobile touch gameplay is claimed. A longer-lived software-rendered QA context encountered a transient rollout 502 and stalled startup; this led to a 30-second no-progress message and manual Retry action. Actual local Chromium tests aborting the engine script and holding the real pack request verify useful recovery controls, no automatic reload/duplicate pack request, and exactly one reload when Retry is clicked. Normal loading remains clean. [Controlled loader results](loader.json).

## Live invited creation

One original drawing was submitted through the public browser UI: Analyse, review its upright/Frost proposal, then Generate. Exactly **three paid reservations completed as received** (one analysis and two image requests); the durable total is **$0.25 in recorded estimates**, not a verified provider invoice. The generated theme board required a scenery crop despite passing conversion. The existing cached crop editor produced a corrected candidate through an explicit SDK-free conversion, adding **zero paid requests**. Original artwork/provenance, the first candidate and corrected draft remain retained privately.

The corrected preview was inspected, accepted into the browser library and selected in the solo lobby. Its character rendered in actual arena combat, and its validated six-file ZIP downloaded successfully. A later reload retained the fighter. Reopening a completed draft settled without a false worker error or new operation. Failed attempts, corrected UI bugs and intermediate deployment tags remain in honest Git/deployment history; no automatic paid retry was used.

## Deployment and recovery

Dokploy runs Nginx, the private API and one worker on the ARM64 host. The Web image exports the pinned Git tree instead of Dokploy's routing-mutated working Compose file. Public immutable assets use the source prefix; metadata/HTML revalidate. An end-to-end hash check caught Cloudflare adding an analytics script and rewriting license email addresses in r7 HTML. Origin `no-transform` directives now preserve the exported bytes, following [Cloudflare response transformation guidance](https://developers.cloudflare.com/rules/configuration-rules/response-body-inspection/) and [Web Analytics behavior](https://developers.cloudflare.com/web-analytics/faq/). Nginx configuration and Compose checks pass. The API's dedicated Docker alias avoids other projects' generic `api` names and dynamically refreshes addresses after restarts. No global DNS/Cloudflare setting was changed.

The provider credential is provisioned over SSH stdin into a worker-only volume. Exact-value scans found neither the provider key nor personal invitation in tracked files or the public payload. API/browser exports do not mount or receive the secret volume; sessions use Secure/HttpOnly/SameSite=Strict cookies. Private raw art, invitations and browser saves are excluded from Git/public export.

At idle, an actual production backup stopped only API/worker; static gameplay stayed running. Both services restarted afterward. The archive contained 52 entries, with all 51 payload hashes verified; SQLite integrity was `ok`. An isolated anonymous Docker volume restored it at the same `/data/forge` path with backups read-only and network disabled. Both completed candidates validated, including source/provenance and all three received reservations; correction's own reserved amount remained zero. No production restore or new provider request occurred. The exact configured key and credential-pattern exclusion checks passed on the archive.

Archive SHA-256: `ce266225f90fa0394e43b1ce2dc55f4d56bddb9a40c6ba3d3715fbd270d41889`. Backups keep up to seven completed local archives; the first snapshot is present. Off-server storage and a recurring schedule are not configured.

## Remaining limits

Desktop browsers are the supported scope. Safari, mobile touch controls, physical gamepads/hotplug and keyboard rollover, audible sound/narration, screen readers, human balance/enjoyment and physical frame-rate performance have not been certified. A complete 20-wave browser run has not been performed; the full-wave routes above are headless native source checks. A page needs its initial network download; offline reloads, accounts, online multiplayer and cloud save sync are outside this release. Clearing site data removes browser saves, so keep downloaded fighter ZIPs.
