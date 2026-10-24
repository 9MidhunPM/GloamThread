extends Scenario
## A malformed required-font bundle must fail before font-dependent UI exists.
const App := preload("res://scripts/app/app_controller.gd")

func run() -> void:
	var bundle := ContentCatalog.load_bundle()
	assert_true(bundle.errors.is_empty(), "valid baseline bundle loads")
	bundle.assets = AssetCatalog.load_from_path("res://assets/manifest.json")
	bundle.assets.entries.erase("font_v1")
	bundle._validate_required_assets()
	assert_true(not bundle.errors.is_empty(), "missing required original font invalidates the bundle")
	var app := App.new()
	app.catalog = bundle
	app.settings_store.path = "user://startup-test-%d/missing-settings.json" % Time.get_ticks_usec()
	AudioDirector.stop_music()
	add_child(app)
	await get_tree().process_frame
	assert_eq(app.screen, "error", "missing font opens an emergency error screen")
	var label := app.get_node_or_null("StartupErrorMessage") as Label
	var quit_button := app.get_node_or_null("StartupQuit") as Button
	assert_true(label != null and label.is_visible_in_tree(), "startup error remains readable without the original font")
	if label != null:
		assert_true(label.text.contains("complete build") and label.text.contains("UI/font"), "diagnostic explains the broken font bundle and reinstall remedy")
	assert_true(quit_button != null and quit_button.is_visible_in_tree(), "broken startup has a visible way to exit")
	assert_true(app.menus == null and app.session == null, "font-dependent menus and world never start with invalid content")
	assert_eq(AudioDirector.current_track(), &"", "invalid startup never starts campaign music")
	app.free()
	InputRouter.clear(0)
	InputRouter.clear(1)
