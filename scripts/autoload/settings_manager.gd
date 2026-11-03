extends Node
## SettingsManager — player preferences, kept apart from the game save in
## user://settings.cfg (ConfigFile), applied immediately when changed.
##
## Settings: language (pl default), master / music / sfx volume (0..1),
## fullscreen (desktop only), text size (0 small, 1 normal, 2 large).
## Profiles other than the default use settings_<profile>.cfg, so tests never
## touch the player's own preferences. `-- --reset-settings` starts from defaults.

signal changed(key: String)

const Loc := preload("res://scripts/core/loc.gd")
const SECTION := "settings"
const DEFAULTS := {
	"language": "pl",
	"master": 1.0,
	"music": 0.8,
	"sfx": 0.9,
	"fullscreen": false,
	"text_size": 1,
}
const TEXT_SCALES := [0.85, 1.0, 1.2]

var values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	values = DEFAULTS.duplicate()
	if not "--reset-settings" in OS.get_cmdline_user_args():
		_load()
	for key in values:
		_apply(key)


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = _sanitize(key, value)
	_apply(key)
	save()
	changed.emit(key)


func reset() -> void:
	values = DEFAULTS.duplicate()
	for key in values:
		_apply(key)
	save()
	changed.emit("all")


func text_scale() -> float:
	return TEXT_SCALES[int(values.get("text_size", 1))]


func is_desktop() -> bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web")


func settings_path() -> String:
	var profile: String = SaveManager.profile
	return "user://settings.cfg" if profile == "save" else "user://settings_%s.cfg" % profile


func save() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value(SECTION, key, values[key])
	var err := cfg.save(settings_path())
	if err != OK:
		push_warning("Settings could not be saved: %s" % error_string(err))


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path()) != OK:
		return  # Missing or unreadable: defaults stay.
	for key in DEFAULTS:
		if cfg.has_section_key(SECTION, key):
			values[key] = _sanitize(key, cfg.get_value(SECTION, key))


func _sanitize(key: String, value: Variant) -> Variant:
	match key:
		"language":
			return str(value) if str(value) in Loc.LANGUAGES else DEFAULTS[key]
		"master", "music", "sfx":
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				return clampf(float(value), 0.0, 1.0)
			return DEFAULTS[key]
		"fullscreen":
			return bool(value) if typeof(value) == TYPE_BOOL else DEFAULTS[key]
		"text_size":
			return clampi(int(value), 0, TEXT_SCALES.size() - 1) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else DEFAULTS[key]
	return value


func _apply(key: String) -> void:
	match key:
		"language":
			TranslationServer.set_locale(values["language"])
		"master", "music", "sfx":
			AudioManager.set_volume(key, values[key])
		"fullscreen":
			if is_desktop() and DisplayServer.get_name() != "headless":
				var want := DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
				var mode := DisplayServer.window_get_mode()
				var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
				if is_full != bool(values["fullscreen"]):
					DisplayServer.window_set_mode(want)
