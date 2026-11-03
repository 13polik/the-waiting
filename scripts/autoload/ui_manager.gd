extends CanvasLayer
## UIManager — the few, quiet pieces of interface THE WAITING allows itself
## during play: the countdown, examine text, a title card, gentle hints and
## toasts, a small pause button, and the fade used for every scene change.
##
## Text is held as Loc entries and re-resolved when the language changes, so
## switching language mid-sentence re-renders the open text. Font sizes
## follow the Text size setting. Gameplay controls ignore the mouse; touches
## are interpreted by WorldInput, which asks [method blocks_point] first.

signal text_opened
signal text_closed
signal pause_requested
signal inventory_requested

const InputSetup := preload("res://scripts/core/input_setup.gd")
const Loc := preload("res://scripts/core/loc.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const CHARS_PER_SECOND := 40.0

var _root: Control
var _timer_label: Label
var _pause_button: Button
var _satchel_button: Button
var _place: Label
var _place_new: Label
var _place_tweens: Array[Tween] = []
var _place_key: String = ""
var _panel: PanelContainer
var _title: Label
var _body: Label
var _continue: Label
var _title_card: Label
var _hint: Label
var _toast: Label
var _fade_layer: CanvasLayer
var _fade: ColorRect

var _title_entry: Variant = ""
var _lines: Array = []
var _line_index: int = -1
var _typing: bool = false
var _type_tween: Tween
var _hint_tween: Tween
var _toast_tween: Tween
var _hint_entry: Variant = ""
var _opened_at: float = 0.0
var _t: float = 0.0
var _blockers: Array[Control] = []
var _transitioning: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register()
	_build()
	get_viewport().size_changed.connect(_layout)
	TimeManager.second_ticked.connect(_update_timer)
	SettingsManager.changed.connect(_on_settings_changed)
	_layout()
	_update_timer()
	set_game_ui_visible(false)


func _process(delta: float) -> void:
	_t += delta
	if _continue.visible:
		_continue.modulate.a = 0.35 + 0.35 * sin(_t * 3.0)


# --- Modes and scene changes --------------------------------------------------

## Countdown and pause button are shown only while playing.
func set_game_ui_visible(on: bool) -> void:
	_timer_label.visible = on
	_pause_button.visible = on
	_satchel_button.visible = on
	refresh_satchel_badge()
	if not on:
		clear_session_ui()


func clear_session_ui() -> void:
	if is_text_open():
		_lines = []
		_panel.visible = false
		text_closed.emit()
	_typing = false
	_title_card.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_place.modulate.a = 0.0
	_place_new.modulate.a = 0.0
	if _hint_tween:
		_hint_tween.kill()


## Fades to black, changes scene, and fades back in.
func transition_to(scene_path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	await fade_out(0.55)
	get_tree().paused = false
	clear_session_ui()
	get_tree().change_scene_to_file(scene_path)
	_transitioning = false


func fade_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished


func fade_in(duration: float) -> void:
	_fade.color.a = maxf(_fade.color.a, 0.999)
	create_tween().tween_property(_fade, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)


## Controls (dev panel, pause button) that a touch must not walk through.
func register_blocker(c: Control) -> void:
	if c not in _blockers:
		_blockers.append(c)


func blocks_point(viewport_pos: Vector2) -> bool:
	for c in _blockers:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(viewport_pos):
			return true
	return false


# --- Examine text -----------------------------------------------------------

func is_text_open() -> bool:
	return not _lines.is_empty()


## [param title] and each line are Loc entries (keys, or [key, args...]).
func show_text(title: Variant, lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_line_index = -1
	_title_entry = title
	_title.text = Loc.resolve(title).to_upper()
	_title.visible = not _title.text.is_empty()
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.35)
	_opened_at = _t
	text_opened.emit()
	_next_line()


## Finishes the current line, shows the next, or closes the text.
func advance() -> void:
	if not is_text_open() or _t - _opened_at < 0.2:
		return
	if _typing:
		if _type_tween:
			_type_tween.kill()
		_body.visible_ratio = 1.0
		_finish_typing()
	else:
		_next_line()


func _next_line() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_close_text()
		return
	_body.text = Loc.resolve(_lines[_line_index])
	_body.visible_ratio = 0.0
	_continue.visible = false
	_typing = true
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_body, "visible_ratio", 1.0, maxf(0.3, _body.text.length() / CHARS_PER_SECOND))
	_type_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	_typing = false
	_continue.visible = true


func _close_text() -> void:
	_lines = []
	_typing = false
	_continue.visible = false
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_hide_panel_if_closed)
	text_closed.emit()


func _hide_panel_if_closed() -> void:
	if not is_text_open():
		_panel.visible = false


# --- Session moments ----------------------------------------------------------

## Called once the room is built. Fades in and greets new or returning players.
func on_session_start(new_game: bool, offline_seconds: float) -> void:
	set_game_ui_visible(true)
	fade_in(2.2)
	if new_game:
		_show_title_card()
		await get_tree().create_timer(7.5).timeout
		if _timer_label.visible:
			show_hint("HINT_TOUCH" if DisplayServer.is_touchscreen_available() else "HINT_DESKTOP", 7.0)
	elif offline_seconds > 120.0:
		await get_tree().create_timer(2.5).timeout
		if _timer_label.visible:
			# The duration is kept as seconds so it re-phrases on a language change.
			show_hint(["HINT_AWAY", offline_seconds], 6.5)


## [param entry]: a Loc entry. ["HINT_AWAY", seconds] is phrased as a duration.
func show_hint(entry: Variant, duration: float = 5.0) -> void:
	_hint_entry = entry
	_hint.text = _resolve_hint(entry)
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 0.8, 1.2)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.8)


## The name of the area, low in the upper third, for a few seconds; on a
## first visit it is introduced as a new place.
func show_place(title_key: String, is_new: bool) -> void:
	_place_key = title_key
	_place.text = Loc.t(title_key)
	_place_new.visible = is_new
	for tw in _place_tweens:
		tw.kill()
	_place_tweens.clear()
	for l: Label in [_place, _place_new]:
		l.modulate.a = 0.0
		var tw := create_tween()
		_place_tweens.append(tw)
		tw.tween_interval(0.4)
		tw.tween_property(l, "modulate:a", 0.85, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(2.6 if is_new else 1.6)
		tw.tween_property(l, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)


func hide_place() -> void:
	for tw in _place_tweens:
		tw.kill()
	_place_tweens.clear()
	_place.modulate.a = 0.0
	_place_new.modulate.a = 0.0


func refresh_satchel_badge() -> void:
	if _satchel_button != null:
		_satchel_button.badge = not WorldManager.unseen_items.is_empty()


func place_text() -> String:
	return _place.text


## A brief confirmation near the bottom of the screen ("Saved.").
func toast(entry: Variant) -> void:
	_toast.text = Loc.resolve(entry)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.85, 0.25)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


func _resolve_hint(entry: Variant) -> String:
	if typeof(entry) == TYPE_ARRAY and entry.size() == 2 and entry[0] == "HINT_AWAY":
		return Loc.t("HINT_AWAY") % Loc.duration(float(entry[1]))
	return Loc.resolve(entry)


func _show_title_card() -> void:
	_title_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_title_card, "modulate:a", 0.9, 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.4)
	tw.tween_property(_title_card, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_SINE)


func _update_timer() -> void:
	_timer_label.text = TimeManager.remaining_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _body != null:
		_update_timer()
		if is_text_open():
			_title.text = Loc.resolve(_title_entry).to_upper()
			if _line_index >= 0 and _line_index < _lines.size():
				_body.text = Loc.resolve(_lines[_line_index])
		if not str(_hint_entry).is_empty():
			_hint.text = _resolve_hint(_hint_entry)
		if not _place_key.is_empty():
			_place.text = Loc.t(_place_key)


func _on_settings_changed(_key: String) -> void:
	UiStyle.rescale(_root)
	_layout()


# --- Construction ------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_timer_label = UiStyle.label("", 19, Color(0.76, 0.79, 0.80, 0.42), false)
	_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.offset_top = 6
	_root.add_child(_timer_label)

	_pause_button = PauseGlyph.new()
	_pause_button.name = "PauseButton"
	_pause_button.position = Vector2(10, 4)
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_root.add_child(_pause_button)
	register_blocker(_pause_button)

	_satchel_button = SatchelGlyph.new()
	_satchel_button.name = "SatchelButton"
	_satchel_button.position = Vector2(74, 4)
	_satchel_button.pressed.connect(func() -> void: inventory_requested.emit())
	_root.add_child(_satchel_button)
	register_blocker(_satchel_button)
	WorldManager.item_added.connect(func(_id: String) -> void: refresh_satchel_badge())

	_place = UiStyle.title("", 30)
	_place.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_place.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place.offset_top = 150
	_place.modulate.a = 0.0
	_root.add_child(_place)
	_place_new = UiStyle.label("PLACE_NEW", 15, UiStyle.ACCENT)
	_place_new.uppercase = true
	_place_new.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_place_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_new.offset_top = 128
	_place_new.modulate.a = 0.0
	_root.add_child(_place_new)

	_hint = UiStyle.label("", 18, Color(0.80, 0.82, 0.80), false)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.offset_top = 44
	_hint.offset_left = 80
	_hint.offset_right = -80
	_hint.modulate.a = 0.0
	_root.add_child(_hint)

	# The game's name is never translated.
	_title_card = UiStyle.title("THE WAITING", 46)
	_title_card.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title_card.set_anchors_preset(Control.PRESET_CENTER)
	_title_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_card.offset_top = -160
	_title_card.offset_bottom = -100
	_title_card.modulate.a = 0.0
	_root.add_child(_title_card)

	_panel = PanelContainer.new()
	var style := UiStyle.panel_style(0.78)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	style.shadow_size = 26
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	_root.add_child(_panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_title = UiStyle.label("", 14, UiStyle.DIM, false)
	box.add_child(_title)
	_body = UiStyle.label("", 23, UiStyle.INK, false)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.y = 62
	box.add_child(_body)
	_continue = UiStyle.label("◦", 18, UiStyle.DIM, false)
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue.visible = false
	box.add_child(_continue)

	_toast = UiStyle.label("", 17, UiStyle.ACCENT, false)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_bottom = -24
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	# Fades sit above every menu.
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)


## Keeps text clear of notches and rounded corners on iPhone/iPad.
func _layout() -> void:
	var insets := Vector4.ZERO  # left, top, right, bottom
	var vp := get_viewport().get_visible_rect().size
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var sx := vp.x / win.x
			var sy := vp.y / win.y
			insets = Vector4(safe.position.x * sx, safe.position.y * sy,
				(win.x - safe.end.x) * sx, (win.y - safe.end.y) * sy)
	_root.offset_left = insets.x
	_root.offset_top = insets.y
	_root.offset_right = -insets.z
	_root.offset_bottom = -insets.w
	var width := minf(880.0 * UiStyle.scale(), (vp.x - insets.x - insets.z) * 0.8)
	_panel.custom_minimum_size.x = width
	_panel.offset_left = -width * 0.5
	_panel.offset_right = width * 0.5
	_panel.offset_bottom = -28


## A small drawn satchel; a dot of lantern light when something new is in it.
class SatchelGlyph extends Button:
	var badge: bool = false:
		set(v):
			badge = v
			queue_redraw()
	var _glow: float = 0.0

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(64, 64)
		size = Vector2(64, 64)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		var before := _glow
		_glow = move_toward(_glow, 1.0 if is_hovered() else 0.0, delta * 4.0)
		if before != _glow:
			queue_redraw()

	func _draw() -> void:
		var c := Color(0.8, 0.86, 0.84, 0.32 + 0.4 * _glow)
		var m := size * 0.5
		var bag := PackedVector2Array([m + Vector2(-9, -3), m + Vector2(9, -3), m + Vector2(7, 9), m + Vector2(-7, 9), m + Vector2(-9, -3)])
		draw_polyline(bag, c, 1.6, true)
		draw_arc(m + Vector2(0, -3), 5.0, PI, TAU, 10, c, 1.6, true)
		if badge:
			draw_circle(m + Vector2(10, -10), 3.0, Color(0.8, 0.93, 0.89, 0.95))


## Two thin bars, barely there until touched. A generous 64 px target.
class PauseGlyph extends Button:
	var _glow: float = 0.0

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(64, 64)
		size = Vector2(64, 64)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		var before := _glow
		_glow = move_toward(_glow, 1.0 if is_hovered() else 0.0, delta * 4.0)
		if before != _glow:
			queue_redraw()

	func _draw() -> void:
		var c := Color(0.8, 0.86, 0.84, 0.32 + 0.4 * _glow)
		var m := size * 0.5
		draw_line(m + Vector2(-5, -9), m + Vector2(-5, 9), c, 2.0, true)
		draw_line(m + Vector2(5, -9), m + Vector2(5, 9), c, 2.0, true)
