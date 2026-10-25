extends SceneTree
## Visible source-only tour: staged highlights or the existing25-wave input bot.

class Errors extends Logger:
	var messages: Array[String] = []
	func _log_error(_fn: String, file: String, line: int, code: String, reason: String, _notify: bool, type: int, _trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING:
			messages.append("%s:%d %s" % [file, line, reason if reason != "" else code])

class TourOverlay extends CanvasLayer:
	var owner_tree: SceneTree
	var caption: Label
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process_input(true)
		layer = 100
		var panel := ColorRect.new()
		panel.color = Color(0.025, 0.045, 0.065, 0.94)
		panel.position = Vector2(0, 920)
		panel.size = Vector2(1920, 160)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		caption = Label.new()
		caption.position = Vector2(40, 936)
		caption.size = Vector2(1840, 130)
		caption.add_theme_font_size_override("font_size", 23)
		caption.add_theme_color_override("font_color", Color("f2e2b9"))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)
	func _input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo:
			return
		match event.physical_keycode:
			KEY_SPACE: owner_tree.toggle_pause()
			KEY_1: owner_tree.set_speed(1)
			KEY_2: owner_tree.set_speed(2)
			KEY_4: owner_tree.set_speed(4)
			KEY_N: owner_tree.next_chapter()
			KEY_ESCAPE: owner_tree.stop_tour()
			_: return
		get_viewport().set_input_as_handled()

const CHAPTERS := [
	{"wave": 1, "title": "TWO FIGHTERS, ONE WORLD", "detail": "Melee + projectiles, coins, personal shops, exploration and split cameras."},
	{"wave": 5, "title": "BOSS I / WARDEN", "detail": "First boss encounter. Watch attack warnings, dodges and recovery."},
	{"wave": 10, "title": "BOSS II / ARTILLERY", "detail": "Ranged pressure, locked bursts, chargers and personal upgrades."},
	{"wave": 15, "title": "BOSS III / TEMPEST", "detail": "Flying dives, moving threats and the expanded third region."},
	{"wave": 20, "title": "BOSS IV / THE LOOM", "detail": "Final boss with heavy guards, projectile pressure and the full world."},
	{"wave": 25, "title": "ENDLESS / NEXT CYCLE", "detail": "The normal endless budget, scaled health and another boss."},
	{"wave": 25, "title": "CROWD STRESS / ALL SIX ENEMY ROLES", "detail": "STAGED64-foe budget, normal32-live cap. Bots dodge first, then unleash upgrades.", "crowd": true}
]

var options := {"mode": "highlights", "seed": 18427, "speed": 1, "report": "/tmp/gloamthread-showcase.json"}
var errors := Errors.new()
var overlay: TourOverlay
var driver: Node
var skip_requested := false
var quit_requested := false
var heading := ""
var description := ""
var results: Array[Dictionary] = []

func _initialize() -> void:
	OS.add_logger(errors)
	call_deferred("_run")

func _parse() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.size() % 2 != 0: return false
	for index in range(0, args.size(), 2):
		var key := args[index].trim_prefix("--")
		if not options.has(key): return false
		if key in ["seed", "speed"]:
			if not args[index + 1].is_valid_int(): return false
			options[key] = int(args[index + 1])
		else: options[key] = args[index + 1]
	return options.mode in ["highlights", "full", "smoke"] and options.speed in [1, 2, 4] and not str(options.report).is_empty()

func _run() -> void:
	if not _parse():
		printerr("Usage: ./showcase.sh [--full|--smoke] [--speed 1|2|4] [--seed INTEGER] [--report PATH]")
		quit(2)
		return
	if DisplayServer.get_name() == "headless" and options.mode != "smoke":
		printerr("Use --smoke for headless validation; the showcase needs a display.")
		quit(2)
		return
	root.size = Vector2i(1920, 1080)
	root.title = "Gloamthread / Gameplay Showcase"
	root.close_requested.connect(stop_tour)
	set_speed(options.speed)
	if DisplayServer.get_name() != "headless":
		overlay = TourOverlay.new()
		overlay.owner_tree = self
		root.add_child(overlay)
	var chapters: Array = [{}] if options.mode == "full" else CHAPTERS
	for index in chapters.size():
		if quit_requested: break
		skip_requested = false
		var chapter: Dictionary = chapters[index]
		heading = "FULL25-WAVE RUN / NORMAL INPUT BOT" if chapter.is_empty() else "%d/%d  %s" % [index + 1, chapters.size(), chapter.title]
		description = "Real progression, earned purchases, all four bosses, exploration and endless. N is disabled in full mode." if chapter.is_empty() else str(chapter.detail)
		driver = load("res://tools/arena_showcase_driver.gd").new()
		driver.chapter = chapter
		root.add_child(driver)
		var target := 25 if chapter.is_empty() else int(chapter.wave)
		var result: Dictionary = await driver.run(2, target, "", 0, options.seed)
		result.chapter = heading
		result.skipped = skip_requested
		result.peak_live_enemies = driver.peak_enemies
		result.seen_roles = driver.seen_roles.keys()
		results.append(result)
		if bool(result.success) and not quit_requested and not skip_requested:
			await _intermission(chapter)
		await _dispose_driver()
		paused = false
		if not bool(result.success) and not skip_requested and not quit_requested:
			printerr("SHOWCASE FAILED: ", JSON.stringify(result.errors))
			break
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	_write_report()
	if not errors.messages.is_empty():
		quit(1)
		return
	var failed := results.any(func(item: Dictionary) -> bool: return not bool(item.success) and not bool(item.skipped) and not quit_requested)
	quit(1 if failed else 0)

func _process(_delta: float) -> bool:
	if overlay != null and is_instance_valid(overlay):
		var status := ""
		if is_instance_valid(driver) and is_instance_valid(driver.session):
			status = "  |  WAVE%02d  /  %d LIVE  /  PEAK%d" % [driver.session.wave, driver.session.living_enemies(), driver.peak_enemies]
		var mode := "NORMAL INPUT / EARNED PROGRESSION" if options.mode == "full" else "STAGED HIGHLIGHTS / PRESET UPGRADES / REAL COMBAT"
		overlay.caption.text = "%s%s\n%s\n%s   |   SPACE pause/resume   1/2/4 speed (%dx)   N next chapter   ESC quit%s" % [heading, status, description, mode, options.speed, "   /   PAUSED" if paused else ""]
	return false

func _intermission(chapter: Dictionary) -> void:
	if chapter.is_empty() or options.mode == "smoke": return
	var world: Node = driver.session
	if world.phase == "clear":
		world._open_shop()
		for tick in 150:
			if skip_requested or quit_requested: return
			await driver._step()
		for slot in world.fighters.size():
			for offer: Dictionary in world.shop_offers[slot].duplicate(true):
				world.try_purchase(slot, offer.id)
			world.set_shop_open(slot, false)
		if int(chapter.wave) == 1:
			description = "Bought real upgrades with kill rewards. Bots now walk apart: watch the shared camera split."
			for tick in 420:
				if skip_requested or quit_requested: return
				for fighter: Node in world.fighters:
					var goal := Vector2(560 if fighter.slot_index == 0 else 1600, 320)
					root.get_node("InputRouter").set_test_input(fighter.slot_index, driver._travel(fighter, goal))
				await driver._step()
	else:
		for tick in 90:
			if skip_requested or quit_requested: return
			await driver._step()

func toggle_pause() -> void:
	if paused:
		if is_instance_valid(driver) and is_instance_valid(driver.app) and driver.app.screen == "pause": driver.app._resume()
		paused = false
	else:
		paused = true

func set_speed(value: int) -> void:
	options.speed = value
	Engine.time_scale = float(value)
	# Keep60Hz simulated steps at higher viewing speeds.
	Engine.physics_ticks_per_second = 60 * value

func next_chapter() -> void:
	if options.mode == "full": return
	skip_requested = true
	if is_instance_valid(driver): driver.cancelled = true
	paused = false

func stop_tour() -> void:
	quit_requested = true
	if is_instance_valid(driver): driver.cancelled = true
	paused = false

func _dispose_driver() -> void:
	var temporary: Array[String] = []
	if is_instance_valid(driver.app):
		temporary = [driver.app.settings_store.path, driver.app.records.path]
	driver.free()
	driver = null
	var router := root.get_node("InputRouter")
	router.clear_test_input()
	for slot in 2: router.clear(slot)
	for path: String in temporary:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	await _retire_audio()

func _retire_audio() -> void:
	var audio := root.get_node("AudioDirector")
	var playbacks: Array[WeakRef] = []
	for player: Node in audio.get_children():
		if player is AudioStreamPlayer and player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	audio.stop_music()
	audio.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline and playbacks.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		await process_frame

func _write_report() -> void:
	var report := {"mode": options.mode, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "seed": options.seed, "chapters": results, "errors": errors.messages, "quit_early": quit_requested, "human_playtest": false, "staged_highlights": options.mode != "full"}
	report.completed = not quit_requested and results.size() == (1 if options.mode == "full" else CHAPTERS.size()) and results.all(func(item: Dictionary) -> bool: return bool(item.success) and not bool(item.skipped))
	report.source_hashes = {}
	for path: String in ["tools/arena_showcase.gd", "tools/arena_showcase_driver.gd", "tests/arena/route_driver.gd"]:
		report.source_hashes[path] = FileAccess.get_sha256("res://" + path)
	var file := FileAccess.open(options.report, FileAccess.WRITE)
	if file == null:
		printerr("Could not write showcase report: ", options.report)
		errors.messages.append("Could not write report.")
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("SHOWCASE_RESULT ", JSON.stringify({"chapters": results.size(), "errors": errors.messages, "report": options.report, "quit_early": quit_requested}))
