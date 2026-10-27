# Browser release and operations

The browser version targets desktop Chromium and Firefox with WebAssembly and
WebGL 2. Keyboard and gamepad play share one computer. Arena solo/co-op and the
original two-player Story use the same game code as desktop. Mobile controls,
online multiplayer and account/cloud save synchronization are outside this
release. A page must load before gameplay can run without network access; this
release does not install a service worker for offline reloads.

## Build and serve

Use Godot 4.7.2 standard and Python 3 from a clean committed checkout:

```sh
python3 tools/fetch_web_templates.py
python3 tools/package_web.py
python3 -m http.server 8085 --directory build/web
```

Open `http://localhost:8085`. The template downloader extracts only the two Web
templates using HTTP byte ranges and checks their recorded SHA-256 hashes.
Packaging imports/exports a fresh payload, includes public original artwork and
licenses, writes `BUILD.json`, precompresses large files and publishes the whole
directory with rollback. It refuses changed source, unexpected files and an
unsupported engine. `--allow-dirty` is for local QA and explicitly labels the
manifest; production packaging requires committed source.

Play unlocks browser audio. Fullscreen is optional. The shell fits complete
integer world pixels in the available physical canvas and letterboxes spare
space; Story restores its own logical dimensions. Home pauses and retains the
running game. Refresh ends a run. Story checkpoints, settings, records and
accepted fighters persist through browser storage where available. A storage
warning explains when persistence is unavailable; clearing site data removes
these saves. Download fighter ZIP keeps a validated six-file backup.

## Hosted Forge

Anyone can play the built-in or saved fighters. Individual revocable invite
codes unlock explicit Analyse/Generate actions; no player account is required.
The [service guide](../server/README.md) covers endpoints, private jobs,
cancellation, operation recovery and operator commands.

Browser drawing/cutout uploads use a file picker. Finished bundles are validated,
previewed and accepted into that browser's library. Private drafts remain on the
server for recovery. Cached crop/mask/pivot corrections upload to the worker's
SDK-free conversion path and send no model request. A closed browser does not
silently retry a paid request; reopening can inspect its retained status.

There are no local dollar caps. Durable estimates and uncertain outcomes are
request history, not provider receipts. Revoking an invitation prevents new
stages but cannot guarantee avoiding billing for an already dispatched request.

## Docker and Dokploy

[The Compose configuration](../deploy/web/compose.yaml) builds Nginx, the API and
one worker. The Dockerfile downloads the matching official engine for amd64 or
arm64, exports the clean revision, and copies only public Web files into Nginx.
The API/worker image contains the conversion code and Python dependencies.

The API and worker share the named `gloamthread-web-forge-data` volume at `/data`.
Only the worker mounts the separate `gloamthread-web-forge-secrets` volume.
The existing authorized ignored `.env` can be transferred directly over SSH:

```sh
python3 tools/provision_forge_secret.py --host YOUR_SSH_ALIAS
docker compose -f deploy/web/compose.yaml up -d --build
```

The helper sends selected credentials through encrypted SSH stdin, keeps them
out of arguments/output and writes a worker-owned mode-600 file. No credential
is copied into the browser export, API image or Git history.

In Dokploy, select this repository and the committed release tag, set Compose
path `deploy/web/compose.yaml`, and route `gloamthread.midhunpm.in` to service
`web`, port `8080`, with HTTPS. Keep the Cloudflare origin pointed to the host.
The root health route checks Nginx; the API's internal `/healthz` checks SQLite.
Safe `/api/forge/configuration` reports worker readiness. Compressed versioned
engine/pack files use immutable caching; HTML and build metadata revalidate.

Issue/revoke invites from the API container's Dokploy terminal:

```sh
python -m server.cli invite --label "Creator name"
python -m server.cli list
python -m server.cli revoke --owner-id OWNER_ID
```

Keep the one-time invite output private. Persist the complete data volume across
releases. Never reset request accounting to recover a failed job. Roll back by
redeploying a previously tested immutable source tag while preserving both
volumes. A deployment or health response alone does not establish browser
gameplay, successful generation, audible sound or physical controller support.

## Private local backups

When no generation is queued or running, stop the API and worker, make a
consistent snapshot, then start those authoring services again. Static gameplay
can stay online:

```sh
docker compose -f deploy/web/compose.yaml stop api worker
docker compose -f deploy/web/compose.yaml --profile ops run --rm backup
docker compose -f deploy/web/compose.yaml start api worker
```

The backup command refuses active/queued work, uses SQLite's backup API, copies
private job artifacts without following symlinks, and publishes an atomic
archive plus file hashes in `gloamthread-web-forge-backups`. It keeps the seven
most recent completed archives and preserves live request history. Restore the
archive to the same `/data/forge` path while both authoring processes are
stopped. Backups share the deployment host; off-server backup storage and a
recurring schedule require separate operational configuration.

## Verification boundaries

Required source checks include the existing arena/Forge/Python suites and
validators, plus `tests/forge/browser_tests.gd` and the hosted API/package tests.
Actual Chromium testing has separately exercised title/lobby/solo combat,
pause/Home/Resume, Story new/save/return/reload and invite unlock plus fighter ZIP
download/import. Record later exported/deployed checks against their own source
SHA. Safari, physical controllers, audio listening and human enjoyment remain
unverified until separately recorded.
