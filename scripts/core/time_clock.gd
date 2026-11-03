extends RefCounted
## Pure timekeeping logic for THE WAITING's 400-day countdown.
##
## The clock tracks [member elapsed] — trusted seconds of waiting — and an
## [member anchor]: its best estimate of the real wall-clock time that
## [member elapsed] is accurate up to.
##
## * While the game runs, time comes from the monotonic tick counter
##   ([method advance]), so changing the device clock mid-session does nothing.
## * While the game is closed or suspended, time comes from the wall clock
##   ([method catch_up]), but the anchor never moves backwards. Setting the
##   clock back cannot rewind progress, and an accidental reset loses nothing:
##   once the clock is correct again, the real gap is credited.
##
## A clock set *forward* while closed cannot be detected offline; see
## docs/DEVELOPMENT_PLAN.md. No engine calls here, so it is unit-testable.
##
## Developer time skips are kept apart in [member debug_offset]: they move
## the simulated day ([method simulated_seconds]) but never touch the real
## elapsed time or the anchor.

const SECONDS_PER_DAY := 86400.0
const DEFAULT_TOTAL_DAYS := 400
## A wall clock running further ahead of the anchor than this is treated as a
## suspension we were not told about, and the gap is credited.
const MAX_RUNNING_STEP := 2.0
## A wall clock further behind the anchor than this counts as a rollback.
const ROLLBACK_TOLERANCE := 5.0

var total_days: int = DEFAULT_TOTAL_DAYS
var start_unix: float = 0.0
var anchor: float = 0.0
var elapsed: float = 0.0
var rollback_events: int = 0
var clock_behind: bool = false
## Seconds added by developer tools. Saved separately from real time.
var debug_offset: float = 0.0


## Begins a brand-new wait at wall time [param now].
func start_new(now: float) -> void:
	start_unix = now
	anchor = now
	elapsed = 0.0
	debug_offset = 0.0
	rollback_events = 0
	clock_behind = false


## Credits wall-clock time that passed while the game was not running.
## Returns the seconds credited (0 if the clock is behind the anchor).
func catch_up(now: float) -> float:
	var delta := now - anchor
	if delta < 0.0:
		if delta < -ROLLBACK_TOLERANCE:
			_note_behind()
		return 0.0
	clock_behind = false
	elapsed += delta
	anchor = now
	return delta


## Advances by [param mono_delta] seconds of monotonic running time.
## [param now] is the current wall time, used only to detect suspensions and
## rollbacks. Returns the seconds credited.
func advance(mono_delta: float, now: float) -> float:
	var added := 0.0
	if mono_delta > 0.0 and mono_delta <= MAX_RUNNING_STEP:
		elapsed += mono_delta
		anchor += mono_delta
		added = mono_delta
	var gap := now - anchor
	if gap > MAX_RUNNING_STEP:
		added += catch_up(now)
	elif gap < -ROLLBACK_TOLERANCE:
		_note_behind()
	elif gap >= -1.0:
		# Within normal jitter: keep the anchor glued to the wall clock so tiny
		# drift between the two timers never accumulates.
		anchor = now
		clock_behind = false
	return added


## Development-only: skips simulated time. Real elapsed time is untouched.
func add_debug_seconds(seconds: float) -> void:
	debug_offset = maxf(0.0, debug_offset + seconds)


func clear_debug_offset() -> void:
	debug_offset = 0.0


## Real waiting time plus any developer offset: what the world responds to.
func simulated_seconds() -> float:
	return elapsed + debug_offset


func total_seconds() -> float:
	return float(total_days) * SECONDS_PER_DAY


func days_elapsed() -> float:
	return simulated_seconds() / SECONDS_PER_DAY


## Zero-based index of the current day (0 on the first day).
func day_index() -> int:
	return clampi(int(floor(simulated_seconds() / SECONDS_PER_DAY)), 0, total_days - 1)


func seconds_remaining() -> float:
	return maxf(0.0, total_seconds() - simulated_seconds())


func is_complete() -> bool:
	return simulated_seconds() >= total_seconds()


func to_dict() -> Dictionary:
	return {
		"total_days": total_days,
		"start_unix": start_unix,
		"anchor": anchor,
		"elapsed": elapsed,
		"debug_offset": debug_offset,
		"rollback_events": rollback_events,
	}


## Restores from a saved dictionary. Returns false (leaving the clock
## untouched) when the data is missing or implausible.
func from_dict(d: Dictionary) -> bool:
	var keys := ["total_days", "start_unix", "anchor", "elapsed"]
	for key in keys:
		var v: Variant = d.get(key)
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			return false
		if not is_finite(float(v)):
			return false
	var td := int(d["total_days"])
	var e := float(d["elapsed"])
	var a := float(d["anchor"])
	if td <= 0 or e < 0.0 or a <= 0.0:
		return false
	total_days = td
	start_unix = float(d["start_unix"])
	anchor = a
	elapsed = e
	rollback_events = maxi(0, int(d.get("rollback_events", 0)))
	var off: Variant = d.get("debug_offset", 0.0)
	debug_offset = maxf(0.0, float(off)) if (typeof(off) == TYPE_FLOAT or typeof(off) == TYPE_INT) and is_finite(float(off)) else 0.0
	clock_behind = false
	return true


func _note_behind() -> void:
	if not clock_behind:
		rollback_events += 1
		clock_behind = true
