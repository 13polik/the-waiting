extends "res://scripts/ui/overlay_screen.gd"
## Pause: Resume, Settings, Save Game, (developer tools in debug builds),
## Return to Main Menu. Pauses the scene tree while open — the 400-day clock
## is real time and keeps running, which the menu says plainly.
## Returning to the menu saves first and stays put if the save fails.

const SettingsScreen := preload("res://scripts/ui/settings_screen.gd")

## Set by main.gd.
var game: Node
var _feedback: Label
var _sub: Node = null


func _build() -> void:
	panel_width = 520.0
	name = "PauseMenu"
	get_tree().paused = true
	add_title("PAUSE_TITLE")
	add_button("PAUSE_RESUME", close).name = "Resume"
	add_button("PAUSE_SATCHEL", _open_satchel).name = "Satchel"
	add_button("MENU_SETTINGS", _open_settings).name = "Settings"
	add_button("PAUSE_SAVE", _on_save).name = "Save"
	if OS.is_debug_build():
		add_button("PAUSE_DEV", _on_dev).name = "Dev"
	add_button("PAUSE_MAIN_MENU", _on_main_menu).name = "MainMenu"
	_feedback = UiStyle.label("", 16, UiStyle.ACCENT)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_feedback)
	var note := add_paragraph("PAUSE_NOTE", true, 15)
	note.add_theme_color_override("font_color", UiStyle.FAINT)


func close() -> void:
	if _sub != null and is_instance_valid(_sub):
		return
	get_tree().paused = false
	super()


func _unhandled_input(event: InputEvent) -> void:
	if _sub != null and is_instance_valid(_sub):
		return  # The settings screen on top handles Back itself.
	super(event)


func _open_satchel() -> void:
	if _sub != null and is_instance_valid(_sub) or game == null:
		return
	_sub = game.open_satchel()
	if _sub != null:
		_sub.closed.connect(_on_sub_closed)


func _open_settings() -> void:
	if _sub != null and is_instance_valid(_sub):
		return
	_sub = SettingsScreen.new()
	get_parent().add_child(_sub)
	_sub.closed.connect(_on_sub_closed)


func _on_sub_closed() -> void:
	_sub = null
	_focus_first()


func _on_save() -> void:
	var ok := SaveManager.save_now("pause-menu")
	_feedback.text = "PAUSE_SAVED" if ok else "PAUSE_SAVE_FAILED"


func _on_dev() -> void:
	if game != null:
		game.toggle_dev_panel(true)


func _on_main_menu() -> void:
	if not SaveManager.save_now("return-to-menu"):
		_feedback.text = "PAUSE_SAVE_FAILED"
		return
	set_process_unhandled_input(false)
	if game != null:
		game.leave_to_menu()
