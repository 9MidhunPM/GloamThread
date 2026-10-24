# Side-view AI asset authoring

The user's25October2026 instruction restores the side-view game and authorizes optional OpenAI image generation for original sprites/textures. The active game remains local two-player co-op with the existing physics, eight-room story and fixed abilities. The overhead experiment is preserved on `feat/overhead-core`.

## Credentials and first experiment

Put your own key in the ignored repository `.env` as `OPENAI_API_KEY=...`. Never paste it into chat. `.env.example` documents supported settings. Godot never reads this key or calls OpenAI. The authoring CLI runs separately and keeps the game playable without an account/network. API responses and candidate output stay under ignored `build/ai-assets/`.

Default experiment: `gpt-image-1-mini`, low quality,1024x1024, one PNG per request, no automatic retries or model fallback. Two-image smoke = one original material board and one original Tavi animation sheet. No reference game art is uploaded. Use broad side-view pixel-adventure qualities only; all characters, motifs and art are original.

The official [model page](https://developers.openai.com/api/docs/models/gpt-image-1-mini) lists low square output at$0.005/image plus input. It is deprecated and scheduled for [1December2026 retirement](https://developers.openai.com/api/docs/deprecations). Model/quality are configurable, never silently upgraded; account access is checked by the actual request. Price is an estimate, not a billing guarantee. New models/settings require a fresh cost review.

Install with `python3 -m venv --system-site-packages .venv` and `.venv/bin/python -m pip install -r requirements-authoring.txt`. Run `tools/ai_assets.py status`, `plan --kind smoke`, then `generate --kind smoke` using that Python. Generation makes two billable requests; `--kind materials` or `--kind tavi` makes one. No automatic retries or replacement. `prepare build/ai-assets/RUN_ID` converts a completed retained run locally. Dry-run and mocked-provider checks establish local behavior only. Live generation cannot be claimed until a key is present and a real request succeeds; generated quality must be inspected before promotion.

## Candidate/runtime contract

A candidate directory has `manifest.json` plus fixed-ID PNG files. Manifest fields:

```json
{
  "schema_version": 1,
  "content_version": "phase1-v1",
  "base_manifest_sha256": "64 lowercase hex characters",
  "assets": [
    {"id": "terrain_ember_v1", "file": "terrain_ember_v1.png", "sha256": "64 lowercase hex characters"}
  ]
}
```

Only `terrain_ember_v1`, `terrain_moss_v1`, `fixed_tavi_v1` and `fixed_neri_v1` are permitted. Every file name is exactly`<id>.png`; no scripts, profile/stat changes, arbitrary paths or model-produced runtime manifests. Dimensions match the packaged atlas. Atlas gutters stay transparent. Tile alpha masks must equal the packaged original per pixel. Courier frames preserve32x48cells, all32animation slots and pivot[16,43]; conversion rejects empty/clipped/inconsistent sheet cells rather than inventing frames. Keep recognizable consistent silhouettes and visual attack timing; structural acceptance is not art acceptance.

Python retains raw PNGs, prompts, model/settings, provider usage/request identity when available, source/output hashes and conversion metadata. It converts only to a new candidate directory. A candidate never overwrites source art or installed assets. A generated sheet is not accepted just because it has a grid.

Godot preview is an explicit launch option: `godot --path . -- --ai-assets /absolute/candidate/manifest.json`. The complete overlay is validated before replacing any cached textures. Failure leaves the original bundle intact and displays an error; the ordinary game still launches. No save format, hurtbox, geometry or traversal changes. Shipping retains original assets until a reviewed candidate is explicitly promoted through the project's provenance/asset gates.
