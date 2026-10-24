#!/usr/bin/env python3
"""Optional local fighter authoring worker. Godot never receives credentials."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from forge.jobs import ROOT, ForgeError, budget_status, run_job
from forge.provider import public_settings, settings, total_budget_microusd


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status", help="Print safe key presence, model names and local budget accounting")
    for name in ("analyse", "generate", "bake"):
        command = sub.add_parser(name)
        command.add_argument("--job", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == "status":
            config = settings(ROOT)
            result = {**public_settings(config), "configuration_file": str(ROOT / ".env"),
                      "budget": budget_status(ROOT, total_cap=total_budget_microusd(config), required=200000)}
        else:
            result = run_job(args.command, args.job)
        print(json.dumps(result, ensure_ascii=True))
        return 0 if result.get("state") != "cancelled" else 2
    except ForgeError as error:
        print(json.dumps({"state": "failed", "message": str(error)}), file=sys.stderr)
        return 1
    except OSError:
        print(json.dumps({"state": "failed", "message": "Local authoring storage is unavailable."}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
