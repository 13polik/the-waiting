extends PanelContainer
## Developer tools — created only in debug builds (OS.is_debug_build()), so a
## release export has no way to reach them.
##
## Time skips go through TimeManager.debug_add_seconds, which stores them as a
## separate offset: the real-time clock (elapsed + anchor) is never touched,
## and the panel shows both so the two can never be confused.
## Non-modal: the game keeps running behind it; works while paused too.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const WaitingButton := preload("res://scripts/ui/waiting_button.gd")
const Loc := preload("res://scripts/core/loc.gd")
const HOUR := 3600.0
const DAY := 86400.0
const SKIPS := [["DEV_ADD_HOUR", HOUR], ["DEV_ADD_DAY", DAY], ["DEV_ADD_7", 7 * DAY], ["DEV_ADD_30", 30 * DAY], ["DEV_ADD_100", 100 * DAY]]

var _readout: Label
var _refresh: float = 0.0


func _init() -> void:
	name = "DevPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var style := UiStyle.panel_style(0.9)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.border_color = Color(0.55, 0.85, 0.7, 0.25)
	style.border_width_left = 1
	style.border_width_right = 1
	add_theme_stylebox_override("panel", style)
	# A fixed column at the top right, clear of the centred pause menu.
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size.x = 420
	offset_left = -434
	offset_right = -14
	offset_top = 60

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := UiStyle.label("DEV_TITLE", 15, Color(0.6, 0.9, 0.75, 0.9))
	title.uppercase = true
	box.add_child(title)
	_readout = UiStyle.label("", 15, UiStyle.INK, false)
	box.add_child(_readout)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	box.add_child(grid)
	for s in SKIPS:
		var b := WaitingButton.make(s[0], 17, HORIZONTAL_ALIGNMENT_CENTER)
		b.name = "Skip_%d" % int(s[1])
		b.custom_minimum_size = Vector2(118, 44)
		b.pressed.connect(_skip.bind(float(s[1])))
		grid.add_child(b)
	var clear := WaitingButton.make("DEV_CLEAR", 17, HORIZONTAL_ALIGNMENT_CENTER)
	clear.name = "ClearOffset"
	clear.custom_minimum_size = Vector2(118, 44)
	clear.pressed.connect(TimeManager.debug_clear_offset)
	grid.add_child(clear)
	var tamper := WaitingButton.make("DEV_TAMPER", 17, HORIZONTAL_ALIGNMENT_CENTER)
	tamper.name = "Tamper"
	tamper.custom_minimum_size = Vector2(118, 44)
	tamper.pressed.connect(TimeManager.debug_tamper)
	grid.add_child(tamper)

	var note := UiStyle.label("DEV_NOTE", 13, UiStyle.FAINT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 370
	box.add_child(note)
	var keys := UiStyle.label("DEV_KEYS", 13, UiStyle.FAINT)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = 370
	box.add_child(keys)
	var close := WaitingButton.make("DEV_CLOSE", 17, HORIZONTAL_ALIGNMENT_RIGHT)
	close.pressed.connect(hide)
	box.add_child(close)

	SettingsManager.changed.connect(func(_k: String) -> void: UiStyle.rescale(self))
	_update()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_update()


func _skip(seconds: float) -> void:
	TimeManager.debug_add_seconds(seconds)
	_update()


func _update() -> void:
	var c := TimeManager.clock
	_readout.text = "\n".join([
		Loc.t("DEV_DAY") % (c.day_index() + 1),
		Loc.t("DEV_REAL") % Loc.span(c.elapsed),
		Loc.t("DEV_OFFSET") % Loc.span(c.debug_offset),
		Loc.t("DEV_TOTAL") % Loc.span(c.simulated_seconds()),
		Loc.t("DEV_REMAINING") % TimeManager.remaining_text(),
		Loc.t("DEV_STATS") % [c.rollback_events, Engine.get_frames_per_second()],
	])
