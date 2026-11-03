extends "res://scripts/ui/overlay_screen.gd"
## Settings: language, three volumes, window mode (desktop only), text size,
## reset. Every change applies and is saved immediately through
## SettingsManager. Used from both the main menu and the pause menu.

var _lang_buttons: Dictionary = {}
var _size_buttons: Array = []
var _window_buttons: Dictionary = {}
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _notice: Label


func _build() -> void:
	panel_width = 760.0
	name = "SettingsScreen"
	add_title("SETTINGS_TITLE")

	var langs := _option_row("SET_LANGUAGE")
	for code in ["pl", "en"]:
		var b := add_button("LANG_" + code.to_upper(), SettingsManager.set_value.bind("language", code), HORIZONTAL_ALIGNMENT_CENTER, langs)
		b.name = "Lang_" + code
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lang_buttons[code] = b

	add_spacer(4)
	for key in ["master", "music", "sfx"]:
		_add_slider(key, "SET_" + key.to_upper())

	if SettingsManager.is_desktop():
		var win := _option_row("SET_DISPLAY")
		for full in [true, false]:
			var b := add_button("SET_FULLSCREEN" if full else "SET_WINDOWED", SettingsManager.set_value.bind("fullscreen", full), HORIZONTAL_ALIGNMENT_CENTER, win)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_window_buttons[full] = b

	var sizes := _option_row("SET_TEXT_SIZE")
	for i in 3:
		var b := add_button(["TEXT_SMALL", "TEXT_NORMAL", "TEXT_LARGE"][i], SettingsManager.set_value.bind("text_size", i), HORIZONTAL_ALIGNMENT_CENTER, sizes)
		b.name = "TextSize_%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_size_buttons.append(b)

	add_spacer(6)
	_notice = UiStyle.label("", 16, UiStyle.DIM)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.visible = false
	box.add_child(_notice)
	var actions := _row()
	var reset := add_button("SET_RESET", _on_reset, HORIZONTAL_ALIGNMENT_CENTER, actions)
	reset.name = "Reset"
	var back := add_button("UI_BACK", close, HORIZONTAL_ALIGNMENT_CENTER, actions)
	back.name = "Back"
	for b in [reset, back]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sync()


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	return row


## A labelled line of choices: the label on the left, buttons filling the rest.
func _option_row(label_key: String) -> HBoxContainer:
	var row := _row()
	var l := UiStyle.label(label_key, 19)
	l.custom_minimum_size.x = 200
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


func _add_slider(key: String, label_key: String) -> void:
	var row := _row()
	var l := UiStyle.label(label_key, 19)
	l.custom_minimum_size.x = 200
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var s := HSlider.new()
	s.name = "Slider_" + key
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_slider(s)
	s.value_changed.connect(_on_slider.bind(key))
	row.add_child(s)
	var v := UiStyle.label("", 17, UiStyle.DIM, false)
	v.custom_minimum_size.x = 56
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(v)
	_sliders[key] = s
	_values[key] = v


func _on_slider(value: float, key: String) -> void:
	_values[key].text = "%d%%" % roundi(value * 100.0)
	if not is_equal_approx(float(SettingsManager.get_value(key)), value):
		SettingsManager.set_value(key, value)
		if key != "music":
			AudioManager.play("step", -6.0, 1.4, AudioManager.BUS_SFX)


func _on_reset() -> void:
	SettingsManager.reset()
	_notice.text = "SET_RESET_DONE"
	_notice.visible = true


func _on_settings_changed(key: String) -> void:
	super(key)
	_sync()


func _sync() -> void:
	var lang: String = SettingsManager.get_value("language")
	for code in _lang_buttons:
		_lang_buttons[code].selected = code == lang
	for i in _size_buttons.size():
		_size_buttons[i].selected = i == int(SettingsManager.get_value("text_size"))
	for full in _window_buttons:
		_window_buttons[full].selected = full == bool(SettingsManager.get_value("fullscreen"))
	for key in _sliders:
		var v := float(SettingsManager.get_value(key))
		_sliders[key].set_value_no_signal(v)
		_values[key].text = "%d%%" % roundi(v * 100.0)
