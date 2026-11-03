extends Node
## SaveManager — owns the save file and decides when to write it.
##
## Other systems keep their own state and copy it into [member data] when
## [signal before_save] fires; they read their section back in their _ready
## and again whenever [signal data_reloaded] fires (New Game).
##
## Safety rules:
##  * Saves are written only during a game session ([member session_active]);
##    sitting in the main menu never creates or changes a save.
##  * Old saves are migrated in memory (SaveMigrations); the original file is
##    first copied to "<save>.v<N>.bak".
##  * A save from a newer game version is never touched: saving is blocked
##    until the player explicitly starts a New Game, which archives it.
##  * New Game archives the previous save as "<save>.archive-<unix>".
##
## Command-line options (after `--`):
##   --profile=<name>   use user://<name>.json (tests use their own profile)
##   --reset-save       delete the profile's files before loading

signal before_save
signal saved(ok: bool)
signal data_reloaded

const SaveStore := preload("res://scripts/core/save_store.gd")
const SaveMigrations := preload("res://scripts/core/save_migrations.gd")
const SCHEMA_VERSION := SaveMigrations.CURRENT
const AUTOSAVE_INTERVAL := 20.0

var profile: String = "save"
var data: Dictionary = {}
## True until the first save of a fresh game (drives the title card).
var is_new_game: bool = false
var load_source: String = ""
## Version the loaded file had before migration (0 for a new game).
var loaded_from_version: int = 0
## Human-readable problems found while loading (empty when all was well).
var load_errors: PackedStringArray = []
## A save exists but was written by a newer version of the game.
var blocked_newer_save: bool = false
var saving_enabled: bool = true
## Set by the game scene while it is running.
var session_active: bool = false

var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--profile="):
			profile = arg.get_slice("=", 1).validate_filename()
	if "--reset-save" in args:
		SaveStore.remove_all(save_file_path())
	_load()

	_timer = Timer.new()
	_timer.wait_time = AUTOSAVE_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(_on_autosave)
	add_child(_timer)


func save_file_path() -> String:
	return "user://%s.json" % profile


## True when there is a game the player can continue.
func has_continuable_save() -> bool:
	return not is_new_game and not blocked_newer_save and not load_source.is_empty()


## Section of the save owned by one system; empty if absent or malformed.
func get_section(section: String) -> Dictionary:
	var v: Variant = data.get(section)
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}


func set_section(section: String, value: Dictionary) -> void:
	data[section] = value


func save_now(reason: String = "") -> bool:
	if not saving_enabled:
		push_warning("Save skipped (%s): saving is disabled." % reason)
		return false
	before_save.emit()
	data["version"] = SCHEMA_VERSION
	data["saved_at_unix"] = Time.get_unix_time_from_system()
	var err := SaveStore.write(save_file_path(), data)
	if err != OK:
		push_warning("Save failed (%s): %s" % [reason, error_string(err)])
	else:
		load_source = save_file_path()
	saved.emit(err == OK)
	return err == OK


## Starts a fresh 400-day wait. Any existing save file is archived first, so
## a previous adventure is never destroyed. Systems reload via data_reloaded.
func start_new_game() -> void:
	var path := save_file_path()
	if FileAccess.file_exists(path):
		var archive := "%s.archive-%d" % [path, int(Time.get_unix_time_from_system())]
		var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(archive))
		if err != OK:
			push_warning("Could not archive the previous save: %s" % error_string(err))
	var now := Time.get_unix_time_from_system()
	data = {"version": SCHEMA_VERSION, "created_unix": now, "meta": {"created_unix": now}}
	is_new_game = true
	blocked_newer_save = false
	saving_enabled = true
	load_errors = PackedStringArray()
	loaded_from_version = 0
	data_reloaded.emit()


## Development helper: wipes the profile and starts over on next launch.
func delete_save() -> void:
	SaveStore.remove_all(save_file_path())


func _load() -> void:
	var path := save_file_path()
	var result := SaveStore.load_best(path)
	load_errors = result["errors"]
	if result["ok"]:
		var migrated := SaveMigrations.migrate(result["payload"])
		if migrated["ok"]:
			data = migrated["payload"]
			load_source = result["source"]
			loaded_from_version = migrated["from"]
			is_new_game = false
			if loaded_from_version < SCHEMA_VERSION:
				_keep_original(load_source, loaded_from_version)
			if not load_errors.is_empty():
				push_warning("Recovered save from %s after: %s" % [load_source.get_file(), ", ".join(load_errors)])
			return
		load_errors.append(str(migrated["error"]))
		if int(migrated["from"]) > SCHEMA_VERSION:
			# Written by a newer game: leave every file exactly as it is.
			push_warning("Save is from a newer version; it will not be modified.")
			blocked_newer_save = true
			saving_enabled = false
			_start_blank()
			return
	if result["any_exists"]:
		push_warning("No usable save (%s); starting fresh." % ", ".join(load_errors))
		SaveStore.quarantine(path)
	_start_blank()


func _start_blank() -> void:
	var now := Time.get_unix_time_from_system()
	data = {"version": SCHEMA_VERSION, "created_unix": now, "meta": {"created_unix": now}}
	is_new_game = true
	load_source = ""


## Before a migrated save is ever overwritten, keep the original file.
func _keep_original(source: String, version: int) -> void:
	var keep := "%s.v%d.bak" % [save_file_path(), version]
	if FileAccess.file_exists(keep):
		return
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(keep))
	if err == OK:
		print("Save migrated from v%d; original kept as %s" % [version, keep.get_file()])
	else:
		push_warning("Could not keep a copy of the v%d save: %s" % [version, error_string(err)])


func _on_autosave() -> void:
	if session_active:
		save_now("autosave")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if is_inside_tree() and session_active:
				save_now("lifecycle")
