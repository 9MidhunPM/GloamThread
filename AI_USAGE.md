# AI usage record

Briefly document each meaningful coding-agent contribution here. Add a row after each meaningful task or milestone. Keep summaries concise; omit secrets, private data and full chat transcripts. Name the tool actually used; mark human review as pending until the user has reviewed the contribution.

## Build log

| Date and time with timezone | Tool / model, if known | Task | Assistance and affected files | Human review / corrections | Validation and result |
| --- | --- | --- | --- | --- | --- |
| 2026-10-24T21:51:38+05:30 | Codex | Review and prepare GitHub publication | Read the handoff, docs and code with read-only subagent reviews; corrected only the two unpublished project commit identities; retained the organizer template and local backup; configured the authorized origin; corrected stale implementation/demo status and recorded the repository URL | Pending — user authorized publication and normal author identity; no human gameplay review claimed | Preflight and planning-pack checks PASS; Git integrity/whitespace checks PASS; replacement trees/messages/author dates verified; targeted scan of 52 original tracked blobs found no credential-pattern or private-filename matches. Engine/gameplay checks remain unverified; remote verification follows push |
| 2026-10-24T21:42:00+05:30 | Devin CLI (Claude) | Start M0 engine shell and write the handoff | Wrote `project.godot`, input contract scripts, `AudioDirector`, `RoomDefinition`, `CollisionBuilder`, `GrayboxSkin`, `Room`; wrote `HANDOFF.md` and `docs/PLAN_PHASE1.md`; updated `docs/STATUS.md`, `CHANGELOG.md` | Pending — user requested the handoff because the agent's budget ran low | `python3 tools/check_pack.py` PASS. No Godot parse/import/run performed on the new scripts (unverified) |
| 2026-10-24T21:25:00+05:30 | Devin CLI (Claude) | Read the full design pack, verify the environment and write the Phase 1 implementation plan; bootstrap the repository on the hackathon template | Wrote the milestone plan (M0–M7, decisions D1–D12, parallel work split). Merged `README.md`, extended `AGENTS.md`, filled `CHANGELOG.md`, `AI_USAGE.md`, `SUBMISSION.md`, `.gitignore`; removed the template remote. | Pending — user chose scope (full Phase 1), input mode (keyboard + keyboard), template adoption and parallel subagents through the plan questions | `python3 tools/preflight.py` exit 0; `python3 tools/check_pack.py` PASS; Godot 4.7.2 CLI flags and split-screen docs checked against official sources |

## Template preparation

On 10 October 2026, Codex prepared the documentation template this repository started from, covering `README.md`, `RULES.md`, `AGENTS.md`, `CHANGELOG.md`, `AI_USAGE.md`, `SUBMISSION.md`, `.gitignore` and the pull request checklist. That preparation is separate from this project's implementation and the AI usage recorded above.
