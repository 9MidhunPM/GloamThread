#!/usr/bin/env python3
"""Rebuild twice and record measured manifest/output hashes for the full bundle."""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from generate_assets import generate
from gen.common import digest, write_json


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=18427)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    manifest = generate(root, args.seed, "full")
    first = {item["path"]: digest(root / item["path"]) for item in manifest["assets"]}
    first_manifest = digest(root / "assets/manifest.json")
    manifest = generate(root, args.seed, "full")
    second = {item["path"]: digest(root / item["path"]) for item in manifest["assets"]}
    second_manifest = digest(root / "assets/manifest.json")
    identical = first == second and first_manifest == second_manifest
    result = {"stage": "full", "seed": args.seed, "asset_count": len(first),
              "first_manifest_sha256": first_manifest, "second_manifest_sha256": second_manifest,
              "identical": identical, "output_sha256": second}
    write_json(root / "evidence/content/rebuild.json", result)
    print(f"{'PASS' if identical else 'FAIL'} twice-generated {len(first)} output hashes and manifest, seed {args.seed}")
    return 0 if identical else 1


if __name__ == "__main__":
    sys.exit(main())
