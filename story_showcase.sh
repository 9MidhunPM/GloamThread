#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: ./story_showcase.sh [--smoke] [--speed 1|2|4] [--report PATH]

Default: watch the complete eight-room Tavi/Neri Story campaign from a new game.
  --smoke        Run the sequential route headlessly at fixed 60 Hz.
  --speed N      Initial simulation speed: 1, 2 or 4 (default: 1).
  --report PATH  JSON report (default: /tmp/gloamthread-story-showcase.json).
  --help         Show this help without launching Godot.

Native controls: Space pause/resume; 1/2/4 speed; Escape quit. No chapter skip.
Uses temporary campaign saves; your personal Story save stays intact.
Requires Godot 4.7.2 standard. Set GODOT_BIN to another executable if needed.
HELP
}

fail() {
    printf 'story showcase: %s\n' "$1" >&2
    exit 2
}

mode=full
speed=1
report=/tmp/gloamthread-story-showcase.json
while (($#)); do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --smoke) mode=smoke; shift ;;
        --speed|--report)
            (($# >= 2)) && [[ -n "$2" && "$2" != --* ]] || fail "$1 needs a value. Use --help for options."
            case "$1" in
                --speed) speed="$2" ;;
                --report) report="$2" ;;
            esac
            shift 2
            ;;
        *) fail "Unknown option: $1. Use --help for options." ;;
    esac
done
[[ "$speed" =~ ^[124]$ ]] || fail '--speed must be 1, 2 or 4.'

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
engine="${GODOT_BIN:-godot}"
command -v "$engine" >/dev/null 2>&1 || fail "Godot executable not found: $engine. Install Godot 4.7.2 standard or set GODOT_BIN."
[[ -f "$repo_dir/tools/story_showcase.gd" ]] || fail 'tools/story_showcase.gd is missing; use the complete current source checkout.'
[[ "$report" == /* ]] || report="$PWD/$report"
engine_args=(--path "$repo_dir")
if [[ "$mode" == smoke ]]; then
    engine_args+=(--headless --fixed-fps 60)
elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    engine_args+=(--display-driver wayland)
fi
exec "$engine" "${engine_args[@]}" --script "$repo_dir/tools/story_showcase.gd" -- --mode "$mode" --speed "$speed" --report "$report"
