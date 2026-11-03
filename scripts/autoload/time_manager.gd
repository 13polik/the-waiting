extends Node
## TimeManager — runs the 400-day clock and tells the world when days pass.
## All the arithmetic lives in TimeClock; this node feeds it real timers and
## application lifecycle events.

signal day_changed(day_index: int)
signal second_ticked

const TimeClock := preload("res://scripts/core/time_clock.gd")
const Loc := preload("res://scripts/core/loc.gd")

var clock: TimeClock
## Seconds credited at launch for the time the game was closed.
var offline_seconds_on_launch: float = 0.0

var _last_ticks_usec: int = 0
var _last_day: int = -1
var _second_acc: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_clock()
	SaveManager.before_save.connect(_on_before_save)
	SaveManager.data_reloaded.connect(_on_data_reloaded)


func _load_clock() -> void:
	clock = TimeClock.new()
	offline_seconds_on_launch = 0.0
	var section := SaveManager.get_section("time")
	if not section.is_empty() and clock.from_dict(section):
		offline_seconds_on_launch = clock.catch_up(_now())
	else:
		if not section.is_empty():
			push_warning("Time data was invalid; the wait begins again.")
		clock.start_new(_now())
	_last_ticks_usec = Time.get_ticks_usec()
	_last_day = clock.day_index()


## New Game: the 400 days begin now.
func _on_data_reloaded() -> void:
	_load_clock()
	day_changed.emit(clock.day_index())
	second_ticked.emit()


func _process(_delta: float) -> void:
	_tick()


func day_index() -> int:
	return clock.day_index()


func days_elapsed() -> float:
	return clock.days_elapsed()


func seconds_remaining() -> float:
	return clock.seconds_remaining()


func remaining_text() -> String:
	return Loc.remaining(clock.seconds_remaining())


## Development builds only (DevPanel / main.gd): skip simulated time.
## Stored as a separate offset; real elapsed time is never changed.
func debug_add_seconds(seconds: float) -> void:
	clock.add_debug_seconds(seconds)
	_check_day()
	second_ticked.emit()


func debug_clear_offset() -> void:
	clock.clear_debug_offset()
	_check_day()
	second_ticked.emit()


func _tick() -> void:
	var t := Time.get_ticks_usec()
	var mono := float(t - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = t
	clock.advance(mono, _now())
	_second_acc += mono
	if _second_acc >= 1.0:
		_second_acc = fmod(_second_acc, 1.0)
		second_ticked.emit()
	_check_day()


func _check_day() -> void:
	var d := clock.day_index()
	if d != _last_day:
		_last_day = d
		day_changed.emit(d)


func _on_before_save() -> void:
	_tick()
	SaveManager.set_section("time", clock.to_dict())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and clock != null:
		# Returning from the iOS background: credit the gap by wall clock, and
		# restart the monotonic baseline so it is not counted twice.
		clock.catch_up(_now())
		_last_ticks_usec = Time.get_ticks_usec()
		_check_day()


func _now() -> float:
	return Time.get_unix_time_from_system()
