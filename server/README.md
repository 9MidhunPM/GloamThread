# Hosted character Forge

This optional Python service handles invited creation jobs. The Godot browser
game, saved fighters and combat run independently of it. The production entry
points are `server.app:app` (ASGI) and `python -m server.worker` (one worker).

Install `requirements-web.txt`. Set `FORGE_DATA_ROOT=/data/forge` on both
processes and mount the same persistent volume at `/data`. Set
`FORGE_PUBLIC_ORIGIN=https://gloamthread.midhunpm.in` on the API. Only the worker
receives `OPENAI_API_KEY`, or mounts a private dotenv file selected by
`FORGE_SECRET_FILE=/run/forge-secrets/provider.env`. The API never needs that
file or credential. Supported models remain `gpt-6-luna` and
`gpt-image-1-mini` at low quality, with zero automatic retries.

Operator commands, run in a container with the persistent volume:

```sh
python -m server.cli invite --label "Creator name"
python -m server.cli list
python -m server.cli revoke --owner-id OWNER_ID
```

`invite` shows the code once. Deliver it privately; the database stores its
hash. Do not put invitation codes in URLs, public logs or the repository.
Revocation invalidates sessions and cancels queued/later work. An in-flight
provider request can still finish and be billed. There are no local dollar
limits; request estimates and uncertain outcomes are durable history, not
provider billing receipts.

The same-origin API uses a Secure, HttpOnly, SameSite=Strict cookie. Mutations
require the configured Origin; requests without Origin require
`X-Gloamthread-Request: 1`. It does not enable cross-origin CORS. Routes below
are under `/api/forge`:

| Route | Purpose |
| --- | --- |
| `POST /session` `{code}` / `DELETE /session` | Unlock / lock invited authoring |
| `GET /configuration` | Safe availability, model names and own estimates |
| `POST /jobs` | Bounded source PNG and metadata, optionally own parent job |
| `GET /jobs` | Own recent drafts, with safe metadata for browser recovery |
| `POST /jobs/{id}/operations` | Explicit Analyse/Generate/Bake with idempotency key |
| `GET /jobs/{id}` | Sanitized status; no filesystem paths or other users' totals |
| `GET /jobs/{id}/snapshot` | Allowlisted draft and validated candidate files |
| `POST /jobs/{id}/cancel` | Stop queued and subsequent stages |

Job and operation IDs are opaque. Clients cannot upload paths, rigs, executable
content, accounting records or provenance. Correction uploads admit only the
bounded crop recipe, rig edits, masks and fixed illustrated-master PNG. The
worker copies retained source artifacts for free correction jobs, and the
browser separately validates/previews/accepts the resulting six-file bundle.

SQLite owns invitations, sessions, job ownership, operations and hosted request
reservations. Request bodies are accepted durably before asynchronous execution.
One operation may be queued/running per invitation; one worker owns the volume
through an OS lock. A process restart preserves queued operations but marks
running operations uncertain, prevents their replay and keeps raw artwork and
request history. Native authoring continues to use its original JSON ledger.

Back up the complete named data volume, including SQLite/WAL and owner job
directories. Prefer stopping the worker/API during a volume snapshot or use a
SQLite-aware backup plus a consistent artifact snapshot. Never clear the ledger
or replace the volume to recover a failed request. Retained jobs are private;
this service does not synchronize accepted browser libraries or publish art.

Checks (mock providers and temporary data, no paid requests):

```sh
python -m unittest tools.tests.test_web_forge tools.tests.test_web_forge_api
```

HTTP tests require the optional web dependencies and otherwise report skipped.
The API health route is `/healthz`; worker readiness is exposed through safe
configuration metadata. Deployment does not prove a browser generation or
physical device playtest; record those separately when performed.
