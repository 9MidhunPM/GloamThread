#!/usr/bin/env python3
"""Validate this planning pack and its illustrations, not a playable game."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_json(name):
    data = json.loads((ROOT / "examples" / name).read_text(encoding="utf-8"))
    require(data.get("schema_version") == 1 and data.get("example_only") is True, f"{name}: example/version marker")
    return data


def reachable(graph, flags):
    seen = {graph["start_room"]}
    changed = True
    while changed:
        changed = False
        for edge in graph["connections"]:
            if set(edge["requires_all"]) <= flags and (edge["a"] in seen or edge["b"] in seen):
                before = len(seen)
                seen.update((edge["a"], edge["b"]))
                changed |= len(seen) != before
    return seen


def main():
    required = ["README.md", "MVP.md", "PRD.md", "AGENTS.md", "FIRST_AGENT_PROMPT.md"]
    required += ["RULES.md", "CHANGELOG.md", "AI_USAGE.md", "SUBMISSION.md", ".github/pull_request_template.md"]
    required += ["docs/" + name + ".md" for name in ["DECISIONS", "ARCHITECTURE", "IMPLEMENTATION_PLAN", "TASKS", "SETUP", "STORY_BIBLE", "ART_AUDIO_PIPELINE", "TEST_PLAN", "TRACK_ALIGNMENT", "GENERATION_ROADMAP", "STATUS", "VALIDATION", "AGENT_1_RUNTIME", "AGENT_2_CONTENT"]]
    for name in required:
        require((ROOT / name).is_file(), f"Missing document: {name}")
    link_count = 0
    for path in ROOT.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        for target in re.findall(r"!?\[[^\]]*\]\(([^)]+)\)", text):
            target = target.split("#", 1)[0]
            if not target or "://" in target or target.startswith("mailto:"):
                continue
            require((path.parent / target).resolve().is_file(), f"Broken relative link: {path.name} → {target}")
            link_count += 1
    print(f"PASS documents and {link_count} relative file links")

    profiles = read_json("fixed_profiles.json")
    themes = read_json("theme_presets.json")
    graph = read_json("world_graph.json")
    save = read_json("team_save.example.json")
    theme_ids = {theme["id"] for theme in themes["themes"]}
    require(theme_ids == {"ember", "moss"}, "Expected two themes")
    require(themes["tile_size"] == [16, 16] and themes["geometry_source"] == "canonical_room_data", "Canonical tile contract")
    for theme in themes["themes"]:
        require(all(re.fullmatch(r"#[0-9a-fA-F]{6}", c) for c in theme["palette"]), "Invalid palette colour")
        require(theme["visibility_bit"] in (2, 4), "Theme visibility mask")
    require(len({theme["visibility_bit"] for theme in themes["themes"]}) == 2, "Themes must use distinct masks")
    roster = profiles["profiles"]
    require(len(roster) == 2 and {p["id"] for p in roster} == {"tavi_fixed", "neri_fixed"}, "Fixed roster")
    for profile in roster:
        require(profile["theme_id"] in theme_ids, "Unknown profile theme")
        require(profile["special_id"] in {"ember_arc", "spore_bolt"}, "Unknown fixed special")
        require(type(profile["max_hearts"]) is int and 3 <= profile["max_hearts"] <= 6, "Heart bounds")
    print("PASS fixed character and theme example contracts")

    room_ids = {room["id"] for room in graph["rooms"]}
    require(len(graph["rooms"]) == 8 and room_ids == {f"r{i:02}" for i in range(8)}, "Exactly eight unique rooms")
    require(graph["start_room"] == "r00", "Start room")
    require(set(graph["checkpoints"].values()) == {"r00", "r04"}, "Two checkpoint rooms")
    all_rewards = {flag for room in graph["rooms"] for flag in room["challenge_rewards"]}
    pairs = set()
    for edge in graph["connections"]:
        require(edge["a"] in room_ids and edge["b"] in room_ids and edge["a"] != edge["b"], "Invalid room edge")
        pair = tuple(sorted((edge["a"], edge["b"])))
        require(pair not in pairs, "Duplicate undirected edge")
        pairs.add(pair)
        require(set(edge["requires_all"]) <= all_rewards, "Gate with no reward source")
    pre_dash = reachable(graph, {"bridge_spindle"})
    require("r05" in pre_dash and "r06" not in pre_dash and "r07" not in pre_dash, "Pre-dash progression")
    post_dash = reachable(graph, {"bridge_spindle", "threadstep", "shortcut_bell", "boss_spoolwarden"})
    require("r06" in post_dash and "r07" not in post_dash, "Causeway anchor gate")
    require(reachable(graph, all_rewards) == room_ids, "All rooms reachable after declared challenges")
    require(any({e["a"], e["b"]} == {"r07", "r00"} and "loom_restored" in e["requires_all"] for e in graph["connections"]), "Restoration return link")
    print("PASS abstract world graph: pre-dash, post-dash, anchor gate and restored return")

    require(set(save["profile_ids"]) == {p["id"] for p in roster}, "Save profile references")
    require(save["checkpoint_id"] in graph["checkpoints"], "Save checkpoint")
    require(set(save["explored_rooms"]) <= room_ids, "Save room references")
    for key in ("team_unlocks", "restored_pairs", "boss_flags", "world_flags"):
        require(set(save[key]) <= all_rewards, f"Save {key} references")
    require("threadstep" not in save["team_unlocks"] or "boss_spoolwarden" in save["boss_flags"], "Dash must follow boss in example save")
    print("PASS checkpoint-based save illustration")
    print("Planning-pack checks only. No Godot import, geometry, rendered art, gameplay or hardware tested.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"FAIL {exc}", file=sys.stderr)
        sys.exit(1)
