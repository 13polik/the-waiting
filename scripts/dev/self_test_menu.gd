extends Node
## End-to-end test of menus, languages, settings, pause, developer tools and
## save safety — driven through real mouse clicks on the real UI. Lives on the
## tree root so it survives scene changes.
##
##   -- --profile=menutest --reset-save --reset-settings --selftest-menu [--shots=<dir>]
##   -- --profile=menutest --selftest-menu=settings-check     (second launch)
##   -- --profile=migtest --selftest-menu=migration           (v0.1 save placed beforehand)
## Prints "MENUTEST PASS"/"MENUTEST FAIL" and exits 0/1.

const SaveStore := preload("res://scripts/core/save_store.gd")
const Loc := preload("res://scripts/core/loc.gd")
const DAY := 86400.0

var _fails: PackedStringArray = []
var _shots_dir: String = ""
## Set as the last line of each scenario: a script error part-way through
## ends the coroutine early, and must count as a failure.
var _reached_end: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.emulate_touch_from_mouse = false
	var mode := "full"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--selftest-menu="):
			mode = arg.get_slice("=", 1)
	await _wait_scene("MainMenu")
	await _wait(2.0)
	match mode:
		"settings-check": await _settings_check()
		"migration": await _migration()
		_: await _full()
	if not _reached_end:
		_fails.append("scenario stopped early (script error above)")
	print("MENUTEST PASS" if _fails.is_empty() else "MENUTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _full() -> void:
	var menu := get_tree().current_scene
	# 1. Fresh install: Polish by default, nothing to continue.
	_check(TranslationServer.get_locale().begins_with("pl"), "Polish is the default language")
	_check(menu.continue_button.disabled, "Continue disabled without a save")
	_check(not FileAccess.file_exists(SaveManager.save_file_path()), "menu does not create a save")
	_check(menu.new_button.atr(menu.new_button.text) == "Nowa gra", "menu shown in Polish")
	await _shot("m01_menu_pl")

	# 2. Settings from the menu: English, large text, half volume.
	await _click(_node(menu, "Settings"))
	var settings := await _wait_node("SettingsScreen")
	await _click(_node(settings, "Lang_en"))
	_check(TranslationServer.get_locale().begins_with("en"), "language switches to English at once")
	_check(menu.new_button.atr(menu.new_button.text) == "New Game", "menu text follows the language")
	await _click(_node(settings, "TextSize_2"))
	_check(int(SettingsManager.get_value("text_size")) == 2, "text size set to large")
	_check(menu.new_button.get_theme_font_size("font_size") == roundi(27 * 1.2), "text size applies at once (%d)" % menu.new_button.get_theme_font_size("font_size"))
	_node(settings, "Slider_master").value = 0.5
	_check(is_equal_approx(float(SettingsManager.get_value("master")), 0.5), "master volume set")
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.1, "master bus follows the slider")
	await _wait(0.5)
	await _shot("m02_settings_en")
	await _click(_node(settings, "Back"))
	await _wait(0.5)
	_check(not is_instance_valid(settings), "settings close")

	# 3. Credits open and close.
	await _click(_node(menu, "Credits"))
	var credits := await _wait_node("CreditsScreen")
	await _shot("m03_credits")
	await _click(_node(credits, "Back"))
	await _wait(0.4)

	# 4. New Game (no save yet: no question asked).
	await _click(menu.new_button)
	await _wait_scene("Main")
	await _wait(1.5)
	var game := get_tree().current_scene
	_check(SaveManager.session_active, "game session active")
	_check(SaveStore.read(SaveManager.save_file_path())["ok"], "new game saved at once")
	_check(TimeManager.day_index() == 0 and TimeManager.clock.debug_offset == 0.0, "timer starts at day 1")
	_check(UIManager._timer_label.text.begins_with("400 days") or UIManager._timer_label.text.begins_with("399 days"), "countdown in English (%s)" % UIManager._timer_label.text)

	# 5. The world is intact: walk and examine.
	var x0: float = game.player.global_position.x
	Input.action_press("move_right")
	await _wait(1.2)
	Input.action_release("move_right")
	await _wait(0.6)
	_check(game.player.global_position.x > x0 + 40.0, "creature walks")
	await _action("interact")
	await _wait(0.6)
	_check(UIManager.is_text_open(), "examine works")
	_check(UIManager._body.text == Loc.resolve(UIManager._lines[0]) and UIManager._body.text.begins_with("A hollow"), "examine text in English")
	await _shot("m04_examine_en")

	# 6. Pause while reading; switch to Polish from the pause menu.
	await _action("pause")
	var pause := await _wait_node("PauseMenu")
	_check(get_tree().paused, "pause stops the game")
	var e_before: float = TimeManager.clock.elapsed
	await _shot("m05_pause_en")
	await _click(_node(pause, "Settings"))
	settings = await _wait_node("SettingsScreen")
	await _click(_node(settings, "Lang_pl"))
	_check(UIManager._timer_label.text.contains(" dni "), "countdown re-renders in Polish (%s)" % UIManager._timer_label.text)
	_check(UIManager._body.text.begins_with("Zagłębienie"), "open examine text re-renders in Polish")
	await _click(_node(settings, "Back"))
	await _wait(0.4)
	await _wait(1.2)
	_check(TimeManager.clock.elapsed > e_before + 1.0, "real time keeps running while paused")

	# 7. Developer tools: offset is separate from real time.
	if OS.is_debug_build():
		await _click(_node(pause, "Dev"))
		await _wait(0.3)
		var dev: Control = game.dev_panel
		_check(dev.visible, "developer panel opens from pause")
		var real_before: float = TimeManager.clock.elapsed
		var anchor_before: float = TimeManager.clock.anchor
		await _click(_node(dev, "Skip_604800"))
		_check(TimeManager.day_index() == 7, "+7 days moves the simulated day (%d)" % TimeManager.day_index())
		_check(absf(TimeManager.clock.elapsed - real_before) < 2.0, "+7 days leaves real elapsed alone")
		_check(TimeManager.clock.anchor - anchor_before < 2.0, "+7 days leaves the anchor alone")
		_check(is_equal_approx(TimeManager.clock.debug_offset, 7 * DAY), "offset recorded separately")
		await _click(_node(dev, "Skip_3600"))
		await _click(_node(dev, "Skip_86400"))
		await _click(_node(dev, "Skip_2592000"))
		await _click(_node(dev, "Skip_8640000"))
		_check(TimeManager.day_index() == 138, "all skips add up (day %d)" % (TimeManager.day_index() + 1))
		await _wait(0.4)
		await _shot("m06_dev_pl")
		await _click(_node(dev, "ClearOffset"))
		_check(TimeManager.day_index() == 0, "clearing the offset returns to the real day")
		await _wait(0.4)
		await _click(_node(dev, "Skip_604800"))
		_check(TimeManager.day_index() == 7, "+7 days again after clearing (%d)" % TimeManager.day_index())

	# 8. Save from the pause menu.
	await _click(_node(pause, "Save"))
	var r := SaveStore.read(SaveManager.save_file_path())
	_check(r["ok"] and int(r["payload"]["version"]) == 3, "pause save writes the current save version")
	if r["ok"] and OS.is_debug_build():
		_check(is_equal_approx(float(r["payload"]["time"]["debug_offset"]), 7 * DAY), "offset saved apart from elapsed (%.0f, clock %.0f)" % [float(r["payload"]["time"]["debug_offset"]), TimeManager.clock.debug_offset])
	var saved_x: float = game.player.global_position.x

	# 9. Return to the menu: progress kept, Continue offered.
	await _click(_node(pause, "MainMenu"))
	await _wait_scene("MainMenu")
	await _wait(1.0)
	menu = get_tree().current_scene
	_check(not get_tree().paused, "menu is not paused")
	_check(not SaveManager.session_active, "session ended")
	_check(not menu.continue_button.disabled, "Continue enabled")
	var expect_day := TimeManager.day_index() + 1
	_check(menu.status_label.text == "Dzień %d z 400" % expect_day, "save status in Polish (%s)" % menu.status_label.text)
	await _shot("m07_menu_continue")

	# 10. Continue restores everything.
	await _click(menu.continue_button)
	await _wait_scene("Main")
	await _wait(1.0)
	game = get_tree().current_scene
	_check(absf(game.player.global_position.x - saved_x) < 2.0, "Continue restores the position")
	_check(WorldManager.examine_count("nest") >= 1, "Continue keeps world state")
	if OS.is_debug_build():
		_check(TimeManager.day_index() == 7, "Continue keeps the developer offset")

	# 11. New Game asks first; Cancel changes nothing.
	await _action("pause")
	pause = await _wait_node("PauseMenu")
	await _click(_node(pause, "MainMenu"))
	await _wait_scene("MainMenu")
	await _wait(1.0)
	menu = get_tree().current_scene
	var before_text := FileAccess.get_file_as_string(SaveManager.save_file_path())
	await _click(menu.new_button)
	var dlg := await _wait_node("ConfirmDialog")
	_check(dlg != null, "New Game asks for confirmation")
	await _shot("m08_confirm_pl")
	await _click(_node(dlg, "Cancel"))
	await _wait(0.5)
	_check(get_tree().current_scene.name == "MainMenu", "Cancel stays in the menu")
	_check(FileAccess.get_file_as_string(SaveManager.save_file_path()) == before_text, "Cancel leaves the save untouched")

	# 12. Confirm: a fresh wait, the old one archived.
	await _click(menu.new_button)
	dlg = await _wait_node("ConfirmDialog")
	await _click(_node(dlg, "Confirm"))
	await _wait_scene("Main")
	await _wait(1.0)
	_check(TimeManager.day_index() == 0 and TimeManager.clock.debug_offset == 0.0, "new game restarts the 400 days")
	_check(TimeManager.clock.elapsed < 30.0, "new clock started now")
	_check(WorldManager.examine_count("nest") == 0, "new game resets world state")
	_check(_archives() >= 1, "previous save archived, not destroyed")
	await _action("pause")
	pause = await _wait_node("PauseMenu")
	await _click(_node(pause, "MainMenu"))
	await _wait_scene("MainMenu")
	_reached_end = true


## Second launch after _full: settings and save must have survived.
func _settings_check() -> void:
	var menu := get_tree().current_scene
	_check(TranslationServer.get_locale().begins_with("pl"), "language persisted (pl)")
	_check(int(SettingsManager.get_value("text_size")) == 2, "text size persisted")
	_check(is_equal_approx(float(SettingsManager.get_value("master")), 0.5), "volume persisted")
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.1, "volume applied at launch")
	_check(menu.new_button.get_theme_font_size("font_size") == roundi(27 * 1.2), "text size applied at launch")
	_check(not menu.continue_button.disabled, "Continue available after restart")
	_check(menu.status_label.text == "Dzień 1 z 400", "status shows the new game's day (%s)" % menu.status_label.text)
	await _click(_node(menu, "Settings"))
	var settings := await _wait_node("SettingsScreen")
	await _click(_node(settings, "Reset"))
	_check(SettingsManager.get_value("language") == "pl" and int(SettingsManager.get_value("text_size")) == 1, "reset restores defaults")
	_check(is_equal_approx(float(SettingsManager.get_value("master")), 1.0), "reset restores volume")
	_reached_end = true


## A real v0.1 save is waiting in this profile.
func _migration() -> void:
	var menu := get_tree().current_scene
	var path := SaveManager.save_file_path()
	_check(SaveManager.loaded_from_version == 1, "v1 save detected")
	_check(not menu.continue_button.disabled, "v1 save can be continued")
	_check(FileAccess.file_exists(path + ".v1.bak"), "original v1 file kept")
	var raw := SaveStore.read(path)
	_check(raw["ok"] and int(raw["payload"]["version"]) == 1, "menu did not rewrite the v1 file")
	await _click(menu.continue_button)
	await _wait_scene("Main")
	await _wait(1.0)
	var game := get_tree().current_scene
	_check(absf(game.player.global_position.x - 1053.4) < 2.0, "v1 position restored (%.1f)" % game.player.global_position.x)
	_check(WorldManager.examine_count("nest") == 2, "v1 examine counts restored")
	_check(TimeManager.clock.elapsed > 17.0, "v1 elapsed time kept and still running")
	_check(TimeManager.clock.debug_offset == 0.0, "no offset invented")
	await _action("pause")
	var pause := await _wait_node("PauseMenu")
	await _click(_node(pause, "Save"))
	var after := SaveStore.read(path)
	_check(after["ok"] and int(after["payload"]["version"]) == 3, "saving upgrades the file to the current version")
	_check(after["ok"] and after["payload"]["world"]["discovered"].has("home"), "migrated save knows home was visited")
	var bak := SaveStore.read(path + ".v1.bak")
	_check(bak["ok"] and int(bak["payload"]["version"]) == 1, "v1 backup still intact")
	_reached_end = true


# --- helpers --------------------------------------------------------------------

func _archives() -> int:
	var n := 0
	var prefix := SaveManager.save_file_path().get_file() + ".archive-"
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with(prefix):
			n += 1
	return n


func _node(root: Node, node_name: String) -> Node:
	var n := root.find_child(node_name, true, false)
	if n == null:
		_check(false, "found %s" % node_name)
	return n


func _wait_node(node_name: String, timeout: float = 4.0) -> Node:
	var t := 0.0
	while t < timeout:
		var n := get_tree().root.find_child(node_name, true, false)
		if n != null:
			await _wait(0.45)  # Let it fade in and lay out.
			return n
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(false, "%s appeared" % node_name)
	return null


func _wait_scene(scene_name: String, timeout: float = 15.0) -> void:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and s.is_node_ready():
			await _wait(0.3)
			return
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(false, "scene %s loaded" % scene_name)


## A real left click at the centre of a control, through the input pipeline.
func _click(c: Variant) -> void:
	if c == null or not is_instance_valid(c):
		return
	var control: Control = c
	# Scroll it into view first, as a player on a small screen would.
	var up := control.get_parent()
	while up != null:
		if up is ScrollContainer:
			up.ensure_control_visible(control)
			await get_tree().process_frame
			await get_tree().process_frame
			break
		up = up.get_parent()
	var p: Vector2 = get_tree().root.get_final_transform() * control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = p
	Input.parse_input_event(move)
	await get_tree().process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = p
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await _wait(0.15)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(0.06)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(shot_name + ".png"))


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fails.append(what)
