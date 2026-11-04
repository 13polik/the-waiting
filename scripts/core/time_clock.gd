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
## Time tampering (0.5). Offline, a wall clock that has gone back more than
## [constant TAMPER_TOLERANCE] behind the anchor is taken as proof that it was
## moved (usually: set forward to skip days, then put back). Online, a trusted
## network time ([method apply_network]) also catches a clock set forward while
## the game was closed. Either way the skipped time is taken back off
## [member elapsed] and the creature is jailed for [constant JAIL_SECONDS] of
## waiting. Small differences (up to an hour) are never punished.
## No engine calls here, so it is unit-testable.
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
## Differences larger than this (seconds) count as tampering.
const TAMPER_TOLERANCE := 3600.0
## How long the creature stays in the dungeon: one day of waiting.
const JAIL_SECONDS := 86400.0
const MONTHS := {"Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6, "Jul": 7, "Aug": 8, "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12}

var total_days: int = DEFAULT_TOTAL_DAYS
var start_unix: float = 0.0
var anchor: float = 0.0
var elapsed: float = 0.0
var rollback_events: int = 0
var clock_behind: bool = false
## Seconds added by developer tools. Saved separately from real time.
var debug_offset: float = 0.0
## Times tampering was caught.
var tamper_events: int = 0
## Simulated seconds at which the dungeon opens (0: not jailed).
var jail_until: float = 0.0
## Last trusted network time, and [member elapsed] at that moment.
var net_unix: float = 0.0
var net_elapsed: float = 0.0
## After a punished forward clock, putting the clock back by up to this much
## is the player correcting it, not a new offence.
var pardon_back: float = 0.0
## Set when tampering is caught; read once with [method take_tamper].
var _pending: Dictionary = {}


## Begins a brand-new wait at wall time [param now].
func start_new(now: float) -> void:
	start_unix = now
	anchor = now
	elapsed = 0.0
	debug_offset = 0.0
	rollback_events = 0
	clock_behind = false
	tamper_events = 0
	jail_until = 0.0
	net_unix = 0.0
	net_elapsed = 0.0
	pardon_back = 0.0
	_pending = {}


## Credits wall-clock time that passed while the game was not running.
## Returns the seconds credited (0 if the clock is behind the anchor).
func catch_up(now: float) -> float:
	var delta := now - anchor
	if delta < 0.0:
		var behind := -delta
		if pardon_back > 0.0 and behind <= pardon_back + TAMPER_TOLERANCE:
			# The clock is being put right after a punished jump: no new offence.
			anchor = now
			pardon_back = 0.0
			clock_behind = false
			return 0.0
		if behind > TAMPER_TOLERANCE:
			# Gone back by hours or days: the time credited "ahead" was never
			# waited. Take it back, and start counting from the clock as it is.
			anchor = now
			clock_behind = false
			_punish(behind, "rollback")
			return 0.0
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
		catch_up(now)
	elif gap >= -1.0:
		# Within normal jitter: keep the anchor glued to the wall clock so tiny
		# drift between the two timers never accumulates.
		anchor = now
		clock_behind = false
	return added


## A trusted time from the network ([param net_now], unix seconds) checked
## against [param wall_now], the device clock at the same moment. Returns the
## seconds taken back (0 when everything adds up).
func apply_network(net_now: float, wall_now: float) -> float:
	var over := 0.0
	if net_unix > 0.0 and net_now >= net_unix:
		# Since the last check, no more waiting can have been credited than
		# really passed.
		over = (elapsed - net_elapsed) - (net_now - net_unix)
	else:
		# First check: the clock must not have been credited past the true time.
		over = anchor - net_now
	var skipped := 0.0
	if over > TAMPER_TOLERANCE:
		skipped = over
		_punish(over, "network")
	var ahead := wall_now - net_now
	if ahead > TAMPER_TOLERANCE:
		# The device clock is still ahead: putting it right later is fine.
		pardon_back = maxf(pardon_back, ahead)
	net_unix = net_now
	net_elapsed = elapsed
	return skipped


func is_jailed() -> bool:
	return jail_until > 0.0 and simulated_seconds() < jail_until


func jail_remaining() -> float:
	return maxf(0.0, jail_until - simulated_seconds()) if jail_until > 0.0 else 0.0


## The last offence caught ({"skipped": seconds, "source": ...}), once.
func take_tamper() -> Dictionary:
	var t := _pending
	_pending = {}
	return t


## Development-only: behave as if tampering had been caught (nothing taken).
func debug_tamper() -> void:
	_punish(0.0, "debug")


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
		"tamper_events": tamper_events,
		"jail_until": jail_until,
		"net_unix": net_unix,
		"net_elapsed": net_elapsed,
		"pardon_back": pardon_back,
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
	tamper_events = maxi(0, int(_num(d.get("tamper_events", 0))))
	jail_until = maxf(0.0, _num(d.get("jail_until", 0.0)))
	net_unix = maxf(0.0, _num(d.get("net_unix", 0.0)))
	net_elapsed = clampf(_num(d.get("net_elapsed", 0.0)), 0.0, elapsed)
	pardon_back = maxf(0.0, _num(d.get("pardon_back", 0.0)))
	_pending = {}
	return true


static func _num(v: Variant) -> float:
	if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v)):
		return float(v)
	return 0.0


func _punish(skipped: float, source: String) -> void:
	elapsed = maxf(0.0, elapsed - skipped)
	net_elapsed = minf(net_elapsed, elapsed)
	tamper_events += 1
	jail_until = simulated_seconds() + JAIL_SECONDS
	_pending = {"skipped": skipped, "source": source}


func _note_behind() -> void:
	if not clock_behind:
		rollback_events += 1
		clock_behind = true


## "Tue, 04 Nov 2026 10:00:00 GMT" → unix seconds (-1 if not understood).
static func parse_http_date(text: String) -> float:
	var parts := text.split(" ", false)
	if parts.size() < 5:
		return -1.0
	var hms := parts[4].split(":")
	if hms.size() != 3 or not MONTHS.has(parts[2]):
		return -1.0
	var year := parts[3].to_int()
	if year < 2024 or year > 2200:
		return -1.0
	var dt := {"year": year, "month": MONTHS[parts[2]], "day": parts[1].to_int(),
		"hour": hms[0].to_int(), "minute": hms[1].to_int(), "second": hms[2].to_int()}
	return float(Time.get_unix_time_from_datetime_dict(dt))
