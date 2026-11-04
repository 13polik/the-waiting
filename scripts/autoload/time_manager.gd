extends Node
## TimeManager — runs the 400-day clock and tells the world when days pass.
## All the arithmetic lives in TimeClock; this node feeds it real timers and
## application lifecycle events.

signal day_changed(day_index: int)
signal second_ticked
## Time tampering caught (0.5): [param skipped] seconds were taken back and
## the creature is to be jailed.
signal tamper_detected(skipped: float, source: String)
## The jail day is over.
signal jail_released

## Trusted time: only the HTTP "Date" header of a HEAD request is read; nothing
## is sent but the request itself. Tried in order.
const TIME_URLS := ["https://www.apple.com/", "https://www.google.com/"]
## How often to re-check while the game runs (seconds).
const NET_INTERVAL := 1200.0
const NET_TIMEOUT := 8.0

const TimeClock := preload("res://scripts/core/time_clock.gd")
const Loc := preload("res://scripts/core/loc.gd")

var clock: TimeClock
## Seconds credited at launch for the time the game was closed.
var offline_seconds_on_launch: float = 0.0

var _last_ticks_usec: int = 0
var _last_day: int = -1
var _second_acc: float = 0.0
## The last offence not yet shown to the player ({} if none).
var last_tamper: Dictionary = {}
var _was_jailed: bool = false
var _http: HTTPRequest
var _url_index: int = 0
var _net_wait: float = 4.0
var _net_busy: bool = false
var _net_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_clock()
	SaveManager.before_save.connect(_on_before_save)
	SaveManager.data_reloaded.connect(_on_data_reloaded)
	for arg in OS.get_cmdline_user_args():
		# Automated tests never touch the network (they feed times directly).
		if arg.begins_with("--selftest") or arg == "--no-net-time":
			_net_enabled = false
	_http = HTTPRequest.new()
	_http.timeout = NET_TIMEOUT
	_http.use_threads = true
	_http.request_completed.connect(_on_net_response)
	add_child(_http)


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
	_was_jailed = clock.is_jailed()
	_check_tamper()


## New Game: the 400 days begin now.
func _on_data_reloaded() -> void:
	_load_clock()
	day_changed.emit(clock.day_index())
	second_ticked.emit()


func _process(delta: float) -> void:
	_tick()
	if _net_enabled and not _net_busy:
		_net_wait -= delta
		if _net_wait <= 0.0:
			_check_network()


func day_index() -> int:
	return clock.day_index()


func days_elapsed() -> float:
	return clock.days_elapsed()


func seconds_remaining() -> float:
	return clock.seconds_remaining()


func remaining_text() -> String:
	return Loc.remaining(clock.seconds_remaining())


func is_jailed() -> bool:
	return clock.is_jailed()


func jail_remaining() -> float:
	return clock.jail_remaining()


## A trusted network time (unix seconds) arrived; also used by tests.
func apply_network_time(net_now: float) -> void:
	_tick()
	clock.apply_network(net_now, _now())
	_check_tamper()


## Development builds only: act as if tampering had been caught.
func debug_tamper() -> void:
	clock.debug_tamper()
	_check_tamper()


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
	_check_tamper()
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
	var jailed := clock.is_jailed()
	if _was_jailed and not jailed:
		_was_jailed = false
		jail_released.emit()
	_was_jailed = jailed


func _check_tamper() -> void:
	var t := clock.take_tamper()
	if t.is_empty():
		return
	last_tamper = t
	_was_jailed = true
	push_warning("Time tampering caught (%s): %.0f s taken back." % [t["source"], t["skipped"]])
	_last_day = clock.day_index()
	day_changed.emit(_last_day)
	second_ticked.emit()
	tamper_detected.emit(float(t["skipped"]), str(t["source"]))
	if SaveManager.session_active:
		SaveManager.save_now("tamper")


# --- Trusted time ---------------------------------------------------------------

func _check_network() -> void:
	_net_busy = true
	if _http.request(TIME_URLS[_url_index], [], HTTPClient.METHOD_HEAD) != OK:
		_net_failed()


func _on_net_response(result: int, _code: int, headers: PackedStringArray, _body: PackedByteArray) -> void:
	var net := -1.0
	if result == HTTPRequest.RESULT_SUCCESS:
		for h in headers:
			if h.to_lower().begins_with("date:"):
				net = TimeClock.parse_http_date(h.substr(5).strip_edges())
				break
	if net <= 0.0:
		_net_failed()
		return
	_net_busy = false
	_url_index = 0
	_net_wait = NET_INTERVAL
	print_verbose("Trusted time: device clock %+.0f s from network." % (_now() - net))
	apply_network_time(net)


func _net_failed() -> void:
	_net_busy = false
	_url_index = (_url_index + 1) % TIME_URLS.size()
	# Offline: try again later; the game works the same without it.
	_net_wait = 15.0 if _url_index != 0 else 300.0


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
		_check_tamper()
		if _net_enabled and not _net_busy:
			_net_wait = 1.0


func _now() -> float:
	return Time.get_unix_time_from_system()
