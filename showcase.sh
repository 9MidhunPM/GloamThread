#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: ./showcase.sh [--full | --smoke] [--seed INT] [--speed 1|2|4] [--report PATH]

Default: watch wave 1 / boss 5,10,15,20,25 highlights and a staged crowd finale.
Finale: 64-foe budget, normal 32-enemy live cap.
  --full         Watch the normal-input 25-wave route, without chapter jumps.
  --smoke        Run the highlights headlessly at fixed 60 Hz; exit with its result.
  --seed INT     Deterministic seed (default: 18427).
  --speed N      Initial simulation speed: 1, 2 or 4 (default: 1).
  --report PATH  JSON report (default: /tmp/gloamthread-showcase.json).
  --help         Show this help without launching Godot.

Native controls: Space pause/resume (including focus loss); 1/2/4 speed;
N next highlight chapter (disabled in --full); Escape quit.
Highlights use labeled chapter setup/preset upgrades; they are not a normal run.
Requires Godot 4.7.2 standard. Set GODOT_BIN to another executable if needed.
HELP
}

fail() {
    printf 'showcase: %s\n' "$1" >&2
    exit 2
}

mode=highlights
seed=18427
speed=1
report=
while (($#)); do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --full|--smoke)
            next_mode="${1#--}"
            [[ "$mode" == highlights || "$mode" == "$next_mode" ]] || fail '--full and --smoke cannot be combined.'
            mode="$next_mode"
            shift
            ;;
        --seed|--speed|--report)
            (($# >= 2)) && [[ -n "$2" ]] || fail "$1 needs a value. Use --help for options."
            case "$1" in
                --seed) seed="$2" ;;
                --speed) speed="$2" ;;
                --report) report="$2" ;;
            esac
            shift 2
            ;;
        *) fail "Unknown option: $1. Use --help for options." ;;
    esac
done
[[ "$seed" =~ ^-?[0-9]+$ ]] || fail '--seed must be an integer.'
[[ "$speed" =~ ^[124]$ ]] || fail '--speed must be 1, 2 or 4.'

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
engine="${GODOT_BIN:-godot}"
command -v "$engine" >/dev/null 2>&1 || fail "Godot executable not found: $engine. Install Godot 4.7.2 standard or set GODOT_BIN."
[[ -f "$repo_dir/tools/arena_showcase.gd" ]] || fail 'tools/arena_showcase.gd is missing; use the complete current source checkout.'

engine_args=(--path "$repo_dir")
if [[ "$mode" == smoke ]]; then
    engine_args+=(--headless --fixed-fps 60)
elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    engine_args+=(--display-driver wayland)
fi
script_args=(--mode "$mode" --seed "$seed" --speed "$speed")
if [[ -n "$report" ]]; then
    [[ "$report" == /* ]] || report="$PWD/$report"
    script_args+=(--report "$report")
fi
exec "$engine" "${engine_args[@]}" --script "$repo_dir/tools/arena_showcase.gd" -- "${script_args[@]}"
