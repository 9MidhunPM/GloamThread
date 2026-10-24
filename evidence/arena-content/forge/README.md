# Local fighter forge

The forge is a separate Python authoring process. Built-in and accepted fighters remain playable without its optional dependencies, network or credentials. Agent 1 controls live requests and the initial shared experiment budget. Tests use synthetic drawings and mocked responses; they are not generated-art acceptance evidence.

```sh
python3 tools/fighter_forge.py status
python3 tools/fighter_forge.py analyse --job /absolute/job-directory/job.json
python3 tools/fighter_forge.py generate --job /absolute/job-directory/job.json
python3 tools/fighter_forge.py bake --job /absolute/job-directory/job.json
python3 -m unittest tools.tests.test_forge_provider -v
```

The optional authoring environment is described in `requirements-authoring.txt`. Live commands read the existing ignored project `.env` through `tools/ai_assets.py`; no key is copied to a job, Godot, bundle or log. `status` prints presence and model names only. The reviewed settings are `gpt-6-luna` structured vision and `gpt-image-1-mini`, low, one 1024-square PNG per edit. Other image settings fail explicitly. There are no automatic retries or model fallbacks. Each edit attaches a normalized snapshot of the player's original drawing.

An absolute `job.json` follows the approved specification. `analyse` writes `proposal.json` and `status.json` with `awaiting_approval`. The UI must store the corrected, approved proposal as the job's `proposal` field before `generate`. Simply receiving a proposal never authorizes generation. A drawing must be one PNG/JPEG, at most 20 MiB, 4096 pixels per side and 16 million decoded pixels. Description text is limited to 2,000 characters. The source is retained as a normalized PNG at most 1024 pixels per side with original and normalized hashes.

Generation requests a transparent 3×3 separated-parts board with the complete design in bottom-right cell 8, then an opaque theme board. The rig converter validates the required part cells, bakes its authored motion templates and produces the fixed bundle. Output is staged and admitted through the shared bundle validator before publication. The editable rig, part files, generated theme and source provenance remain beside `candidate/`. Optional `rig_edits.json` supports the documented masks and pivots. Local `bake` uses no paid settings or SDK, stages the edited result and replaces only this job's preview after complete validation. Publication failures roll back the previous preview; the accepted fighter library is never written by this worker.

`build/forge/budget.json` is the durable, cross-job initial experiment ledger. Before dispatch it reserves $0.05 for analysis and $0.10 for each of the two image edits, against both the job budget and the fixed $0.50 shared cap. These are deliberately conservative allocations, not charges or billing receipts. The UI's `estimated_usd` and `reserved_usd` report the job's cumulative allocated amount. Integer microdollars and a process lock protect reservations. Reservations remain after success, failure, timeout and cancellation; the tool never silently resets the experiment allowance. A failed or interrupted request is not retried by rerunning the command.

Each job is locked against duplicate processes. Creating `cancel` prevents later dispatch and conversion; an in-flight call may still be billed. Returned raw output and safe usage/request identity remain retained. `raw/*.attempt.json` freezes prompt, settings, source hash and reservation before dispatch. `provenance.json` records received raw hashes and the approved design. Verified cached successes can be reused without another request. Changed source, changed paid request settings/design, damaged cache files or unknown existing candidates fail visibly instead of replacing them or triggering a new bill.

The adapter follows the official [Luna model documentation](https://developers.openai.com/api/docs/models/gpt-6-luna), [Responses structured-output format](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses) and [image-edit API](https://developers.openai.com/api/reference/resources/images/methods/edit). Account access and real generated quality remain live-test gates. A passing manifest cannot establish drawing fidelity, recognizable motion, readable combat, controls, listening or human enjoyment.
