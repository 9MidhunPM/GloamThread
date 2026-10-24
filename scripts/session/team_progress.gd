class_name TeamProgress
extends RefCounted
## One team owns permanent outcomes. No actor/camera owns a second reward copy.

const CONTENT_VERSION := "phase1-v1"
const FLAG_GROUPS := {
	"threadstep": "team_unlocks",
	"bridge_spindle": "restored_pairs", "bridge_causeway": "restored_pairs",
	"boss_spoolwarden": "boss_flags", "lantern_charm": "secret_flags",
	"shortcut_bell": "world_flags", "loom_restored": "world_flags",
}
const SAVE_GROUPS := ["team_unlocks", "restored_pairs", "boss_flags", "secret_flags", "world_flags"]
const ROOM_IDS := ["r00", "r01", "r02", "r03", "r04", "r05", "r06", "r07"]

var flags: Dictionary = {}
var profile_ids: Array[String] = ["tavi_fixed", "neri_fixed"]
var checkpoint_id: String = "checkpoint_a"
var explored_rooms: Array[String] = []


func has_flag(flag: String) -> bool:
	return flags.get(flag, false) == true


func commit_flags(new_flags: Array[String]) -> bool:
	for flag in new_flags:
		if not FLAG_GROUPS.has(flag):
			push_error("Unknown permanent flag: %s" % flag)
			return false
	var changed := false
	for flag in new_flags:
		if not has_flag(flag):
			flags[flag] = true
			changed = true
	return changed


func set_checkpoint(value: String) -> bool:
	if value not in ["checkpoint_a", "checkpoint_b"]:
		return false
	checkpoint_id = value
	return true


func visit(room_id: String) -> void:
	if room_id not in explored_rooms:
		explored_rooms.append(room_id)


func to_save() -> Dictionary:
	var data := {"schema_version": 1, "content_version": CONTENT_VERSION,
		"profile_ids": profile_ids.duplicate(), "checkpoint_id": checkpoint_id,
		"explored_rooms": explored_rooms.duplicate()}
	for group: String in SAVE_GROUPS:
		var values: Array[String] = []
		for flag: String in FLAG_GROUPS:
			if FLAG_GROUPS[flag] == group and has_flag(flag):
				values.append(flag)
		values.sort()
		data[group] = values
	return data


func load_save(data: Dictionary) -> bool:
	var version: Variant = data.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != 1.0:
		return false
	if not data.get("content_version") is String or data.content_version != CONTENT_VERSION:
		return false
	var roster: Variant = data.get("profile_ids")
	if not roster is Array or roster.size() != 2:
		return false
	for value: Variant in roster:
		if not value is String or value not in ["tavi_fixed", "neri_fixed"]:
			return false
	if roster[0] == roster[1]:
		return false
	if not data.get("checkpoint_id") is String or data.checkpoint_id not in ["checkpoint_a", "checkpoint_b"]:
		return false
	var rooms: Variant = data.get("explored_rooms")
	if not rooms is Array:
		return false
	var visited: Dictionary = {}
	for value: Variant in rooms:
		if not value is String or value not in ROOM_IDS or visited.has(value):
			return false
		visited[value] = true
	var next_flags: Dictionary = {}
	for group: String in SAVE_GROUPS:
		var values: Variant = data.get(group)
		if not values is Array:
			return false
		for flag: Variant in values:
			if not flag is String or FLAG_GROUPS.get(flag) != group or next_flags.has(flag):
				return false
			next_flags[flag] = true
	if next_flags.has("threadstep") and not next_flags.has("boss_spoolwarden"):
		return false
	if next_flags.has("shortcut_bell") and not next_flags.has("boss_spoolwarden"):
		return false
	# Defeat, traversal and shortcut are one reward transaction. Accepting only
	# the defeat would remove the boss while leaving its required ability locked.
	if next_flags.has("boss_spoolwarden") and (not next_flags.has("threadstep") or not next_flags.has("shortcut_bell")):
		return false
	if next_flags.has("bridge_causeway") and not next_flags.has("threadstep"):
		return false
	if next_flags.has("loom_restored") and not next_flags.has("bridge_causeway"):
		return false
	flags = next_flags
	profile_ids.assign(roster)
	checkpoint_id = data["checkpoint_id"]
	explored_rooms.assign(rooms)
	return true
