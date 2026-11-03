extends "res://scripts/ui/overlay_screen.gd"
## Mods: every mod found in the mods folder, with its author, description and
## state; broken ones explain why. Switching a mod on or off takes effect the
## next time the game is entered, and never touches the save.

const Loc := preload("res://scripts/core/loc.gd")

var _list: VBoxContainer


func _build() -> void:
	panel_width = 760.0
	name = "ModsScreen"
	add_title("MODS_TITLE")
	var note := add_paragraph("MODS_NOTE", true, 16)
	note.add_theme_color_override("font_color", UiStyle.DIM)
	var where := add_paragraph("", false, 15)
	where.name = "Where"
	where.add_theme_color_override("font_color", UiStyle.FAINT)
	if SettingsManager.is_desktop():
		where.text = Loc.t("MODS_FOLDER_DESKTOP") % ProjectSettings.globalize_path(ModManager.mods_dir())
	else:
		where.text = Loc.t("MODS_FOLDER_IOS")
	add_spacer(4)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 14)
	box.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	if SettingsManager.is_desktop():
		var open := add_button("MODS_OPEN_FOLDER", _open_folder, HORIZONTAL_ALIGNMENT_CENTER, row)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reload := add_button("MODS_RELOAD", ModManager.scan, HORIZONTAL_ALIGNMENT_CENTER, row)
	reload.name = "Reload"
	reload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := add_button("UI_BACK", close, HORIZONTAL_ALIGNMENT_CENTER, row)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ModManager.mods_changed.connect(_fill)
	_fill()


func _fill() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for c in _list.get_children():
		_list.remove_child(c)  # So the new rows keep their names.
		c.queue_free()
	if ModManager.mods.is_empty():
		var none := UiStyle.label("MODS_NONE", 18, UiStyle.DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(none)
	for m in ModManager.mods:
		_list.add_child(_mod_row(m))
	UiStyle.rescale(_list)
	await get_tree().process_frame
	if is_instance_valid(box):
		_fit(box.get_parent())


func _mod_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Mod_" + str(m["id"])
	row.add_theme_constant_override("separation", 16)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := UiStyle.label(m["name"] if not str(m["name"]).is_empty() else m["id"], 21, UiStyle.INK)
	text.add_child(title)
	var meta := UiStyle.label("", 14, UiStyle.FAINT, false)
	meta.text = Loc.t("MODS_BY") % [m["author"] if not str(m["author"]).is_empty() else "—", m["version"] if not str(m["version"]).is_empty() else "—"]
	text.add_child(meta)
	if not str(m["description"]).is_empty():
		var desc := UiStyle.label(m["description"], 16, UiStyle.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
	var problems: PackedStringArray = m["errors"] if not m["ok"] else m["warnings"]
	if not problems.is_empty():
		var p := UiStyle.label("", 14, Color(0.95, 0.65, 0.55) if not m["ok"] else UiStyle.DIM, false)
		var shown := problems.slice(0, 3)
		p.text = (Loc.t("MODS_BROKEN") % "; ".join(shown)) if not m["ok"] else "; ".join(shown)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(p)
	var toggle := WaitingButton.make("MODS_ENABLED" if m["enabled"] else "MODS_DISABLED", 19, HORIZONTAL_ALIGNMENT_CENTER)
	toggle.name = "Toggle"
	toggle.custom_minimum_size = Vector2(140, 52)
	toggle.selected = m["enabled"]
	toggle.disabled = not m["ok"]
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.pressed.connect(ModManager.set_enabled.bind(m["id"], not m["enabled"]))
	row.add_child(toggle)
	return row


func _open_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path(ModManager.mods_dir()))


func _exit_tree() -> void:
	if ModManager.mods_changed.is_connected(_fill):
		ModManager.mods_changed.disconnect(_fill)
