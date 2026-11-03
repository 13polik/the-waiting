extends Node
## PowerManager — frame pacing for battery life. Nothing here changes how the
## game looks while it is being played.
##
##  * Playing / menu: 60 fps (also on 120 Hz ProMotion devices — the game's
##    slow motion gains nothing from 120, and the battery does).
##  * Pause menu open (scene frozen): 30 fps; only the menu itself animates.
##  * Mobile, app inactive but visible (Control Center, a call banner,
##    the app switcher): 10 fps until focus returns.
##  * Backgrounded (NOTIFICATION_APPLICATION_PAUSED): iOS suspends the app;
##    SaveManager saves and TimeManager catches up on resume.
## The real-time clock is independent of frame rate (TimeManager), so pacing
## never affects the 400-day countdown.

const ACTIVE_FPS := 60
const PAUSED_FPS := 30
const INACTIVE_FPS := 10

var _inactive: bool = false
var _current: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply()


func _process(_delta: float) -> void:
	_apply()


func target_fps() -> int:
	if _inactive:
		return INACTIVE_FPS
	if get_tree().paused:
		return PAUSED_FPS
	return ACTIVE_FPS


func _apply() -> void:
	var fps := target_fps()
	if fps != _current:
		_current = fps
		Engine.max_fps = fps


func _notification(what: int) -> void:
	if not OS.has_feature("mobile"):
		return  # On desktop, losing focus to another window should not throttle.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_inactive = true
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_inactive = false
