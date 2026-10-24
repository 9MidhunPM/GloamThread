#!/usr/bin/env python3
"""Rebuild original Gloamthread assets; defaults to the complete Phase 1 bundle."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
from gen import art, font
from gen.common import write_json

GENERATOR_VERSION = "1.0.0"


def generate(root: Path, seed: int = 18427, stage: str = "full") -> dict:
    if stage not in ("diagnostic", "full"):
        raise ValueError(f"Unknown stage: {stage}")
    if stage == "diagnostic":
        assets, sfx, music = art.diagnostic(root) + font.generate(root), {}, {}
    else:
        from gen import actors, audio
        audio_assets, sfx, music = audio.generate(root, seed)
        assets = art.production(root, seed) + actors.generate(root) + font.generate(root) + audio_assets
    manifest = {"schema_version": 1, "content_version": "phase1-v1",
                "generator_version": GENERATOR_VERSION, "seed": seed, "stage": stage,
                "assets": sorted(assets, key=lambda item: item["id"]), "sfx": sfx, "music": music}
    write_json(root / "assets/manifest.json", manifest)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=18427)
    parser.add_argument("--stage", choices=("diagnostic", "full"), default="full")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    manifest = generate(root, args.seed, args.stage)
    print(f"GENERATED {args.stage}: {len(manifest['assets'])} original assets, seed {args.seed}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"FAIL generation: {exc}", file=sys.stderr)
        sys.exit(1)
