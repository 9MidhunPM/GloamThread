# Local fighter forge

The forge is a separate Python authoring process. Built-in and accepted fighters remain playable without its optional dependencies, network or credentials. Generation has no local dollar cap. Tests use synthetic drawings and mocked responses; they are not generated-art acceptance evidence.

```sh
python3 tools/fighter_forge.py status
python3 tools/fighter_forge.py analyse --job /absolute/job-directory/job.json
python3 tools/fighter_forge.py generate --job /absolute/job-directory/job.json
python3 tools/fighter_forge.py bake --job /absolute/job-directory/job.json
python3 -m unittest tools.tests.test_forge_provider -v
```

The optional authoring environment is described in `requirements-authoring.txt`. Live commands read the existing ignored project `.env` through `tools/ai_assets.py`; no key is copied to a job, Godot, bundle or log. `status` prints safe key presence, model names and request accounting. The configured models are `gpt-6-luna` structured vision and `gpt-image-1-mini`, low, one 1024-square PNG per edit. Other image settings fail explicitly. There are no automatic retries or model fallbacks. Each edit attaches a normalized snapshot of the player's original drawing.

An absolute `job.json` follows the approved specification. `analyse` writes `proposal.json` and `status.json` with `awaiting_approval`. The UI must store the corrected, approved proposal as the job's `proposal` field before `generate`. Simply receiving a proposal never authorizes generation. A drawing must be one PNG/JPEG, at most 20 MiB, 4096 pixels per side and 16 million decoded pixels. Description text is limited to 2,000 characters. The source is retained as a normalized PNG at most 1024 pixels per side with original and normalized hashes.

Generation requests a transparent 3×3 separated-parts board with the complete design in bottom-right cell 8, then an opaque theme board. The rig converter validates the required part cells, bakes its authored motion templates and produces the fixed bundle. Output is staged and admitted through the shared bundle validator before publication. The editable rig, part files, generated theme and source provenance remain beside `candidate/`. Optional `rig_edits.json` supports the documented masks and pivots. Local `bake` uses no paid settings or SDK, stages the edited result and replaces only this job's preview after complete validation. Publication failures roll back the previous preview; the accepted fighter library is never written by this worker.

`build/forge/budget.json` retains durable request history and conservative estimates. The user's 25 October instruction removed all shared and per-character dollar caps. Legacy `FORGE_TOTAL_BUDGET_USD`, job `budget_usd` and stored cap values no longer block generation. Existing request records and uncertain outcomes stay intact; new writes mark the cap as `null`. Estimates remain $0.05 per analysis and $0.10 per image request for historical compatibility, not as charges, billing receipts or admission thresholds. Status reports `budget.limits_enabled: false` and `null` for all limit/remaining fields, with numeric accounting totals.

Before generation, preflight verifies both cache entries and rejects a previously attempted request without a valid received cache. Valid cached images need no new request. The process locks and durable per-request records prevent duplicate calls, and failures/timeouts never silently retry. These safeguards do not impose a monetary cutoff. Generate remains a deliberate user action; local correction and rebaking use no model.

Each job is locked against duplicate processes. Creating `cancel` prevents later dispatch and conversion; an in-flight call may still be billed. Returned raw output and safe usage/request identity remain retained. `raw/*.attempt.json` freezes prompt, settings, source hash and reservation before dispatch. `provenance.json` records received raw hashes and the approved design. Verified cached successes can be reused without another request. Changed source, changed paid request settings/design, damaged cache files or unknown existing candidates fail visibly instead of replacing them or triggering a new bill.

If image requests succeed but their board layout fails conversion, retain that job. A reviewed `source_layout.json` beside `job.json` can select bounded part/master/background/material crops and an alpha cutoff, bound to the exact raw-image hashes. The local converter owns that schema; the worker rejects unsafe, oversized or invalid JSON and copies the exact correction bytes into its isolated stage.

Running `bake --job /absolute/job-directory/job.json` without an existing rig now verifies the retained source, frozen approved proposal, both received image records, cache identities and PNG hashes, then converts staged copies locally. It loads no paid settings or SDK and makes no provider request or new reservation. A failed conversion or publication preserves the old preview and provenance. Specific project conversion rejections reach the creator instead of a generic failure.

Once a rig exists, normal mask/pivot rebaking continues to use its converted parts. A changed, added or removed source-layout document requires a new local correction job; it never silently reuses old part pixels. That new job must retain byte-identical source/raw/provenance records and the same approved proposal, with its source path updated to the copied original drawing. Keep previous editable art and previews in their original job. The UI can then bootstrap the corrected local job with `bake`, without resetting or charging the shared ledger.

The adapter follows the official [Luna model documentation](https://developers.openai.com/api/docs/models/gpt-6-luna), [Responses structured-output format](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses) and [image-edit API](https://developers.openai.com/api/reference/resources/images/methods/edit). Account access and real generated quality remain live-test gates. A passing manifest cannot establish drawing fidelity, recognizable motion, readable combat, controls, listening or human enjoyment.
