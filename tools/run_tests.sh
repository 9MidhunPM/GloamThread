#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$script_dir/.." && pwd)"

exec godot --headless --fixed-fps 60 --path "$project_root" --script tests/run_tests.gd "$@"
