extends "res://scripts/forge/forge_bridge.gd"
## Records UI requests; never creates a process or contacts a provider.

var commands: Array[String] = []
var jobs: Array[String] = []


func start(command: String, path: String) -> Dictionary:
	if not trusted_job(path) or command not in COMMANDS:
		return {"ok": false, "error": "Invalid fixture request."}
	commands.append(command)
	jobs.append(path)
	pid = OS.get_process_id()
	write_json(path.get_base_dir().path_join("status.json"), {"state": "queued", "message": "Mock worker queued"})
	return {"ok": true, "error": "", "pid": pid}
