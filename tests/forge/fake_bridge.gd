extends "res://scripts/forge/forge_bridge.gd"
## Records UI requests; never creates a process or contacts a provider.

var commands: Array[String] = []
var jobs: Array[String] = []
var configuration_report := {"ok": true, "key_present": true, "configuration_file": "fixture/.env", "budget": {"total_limit_usd": 2.0, "total_reserved_usd": 0.35, "total_remaining_usd": 1.65, "job_limit_usd": 0.50, "job_reserved_usd": 0.0, "job_remaining_usd": 0.50, "required_usd": 0.20}}


func _init() -> void:
	# Never expose deliberately malformed mock drafts in the user's real library.
	job_root = "/tmp/gloamthread-forge-ui-fixtures-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]


func configuration() -> Dictionary:
	return configuration_report.duplicate(true)


func start(command: String, path: String) -> Dictionary:
	if not trusted_job(path) or command not in COMMANDS:
		return {"ok": false, "error": "Invalid fixture request."}
	commands.append(command)
	jobs.append(path)
	pid = OS.get_process_id()
	write_json(path.get_base_dir().path_join("status.json"), {"state": "queued", "message": "Mock worker queued"})
	return {"ok": true, "error": "", "pid": pid}
