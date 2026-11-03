extends Control
## Base for full-screen overlays (settings, credits, confirmations, pause):
## dims what is behind, centres a quiet panel, fades and drifts in, closes on
## Back / Esc, and keeps working while the game is paused.
## Subclasses override [method _build] to fill [member box].

signal closed

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const WaitingButton := preload("res://scripts/ui/waiting_button.gd")

var box: VBoxContainer
var panel: PanelContainer
## Width of the panel in base pixels.
var panel_width: float = 640.0
var closable: bool = true
var _closing: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_style_scrollbar(scroll.get_v_scroll_bar())
	panel.add_child(scroll)

	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", UiStyle.GAP)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_build()
	_fit(scroll)
	get_viewport().size_changed.connect(_fit.bind(scroll))
	SettingsManager.changed.connect(_on_settings_changed)

	UIManager.hide_place()  # A place name would show through the panel.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
	await get_tree().process_frame
	_focus_first()


## Fill [member box].
func _build() -> void:
	pass


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_finish_close)


func _finish_close() -> void:
	closed.emit()
	queue_free()


func add_title(key: String) -> Label:
	var t := UiStyle.title(key, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	add_spacer(6)
	return t


func add_section(key: String) -> Label:
	add_spacer(8)
	var l := UiStyle.label(key, 15, UiStyle.DIM)
	l.uppercase = true
	box.add_child(l)
	return l


func add_spacer(h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(s)


func add_button(key: String, callback: Callable, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, parent: Node = null) -> Button:
	var b := WaitingButton.make(key, 24, align)
	b.pressed.connect(callback)
	(parent if parent != null else box).add_child(b)
	return b


func add_paragraph(text: String, translate: bool = true, size: int = 19) -> Label:
	var l := UiStyle.label(text, size, UiStyle.INK, translate)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = panel_width - 80
	box.add_child(l)
	return l


func _fit(scroll: ScrollContainer) -> void:
	var vp := get_viewport_rect().size
	var w := minf(panel_width, vp.x - 48.0)
	scroll.custom_minimum_size = Vector2(w - 80.0, 0)
	box.custom_minimum_size.x = w - 80.0
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, vp.y - 120.0)


## A hairline that only shows when there is more to see.
func _style_scrollbar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.04)
	track.content_margin_left = 2
	track.content_margin_right = 2
	var thumb := StyleBoxFlat.new()
	thumb.bg_color = Color(UiStyle.ACCENT, 0.3)
	thumb.content_margin_left = 2
	thumb.content_margin_right = 2
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, thumb)


func _on_settings_changed(_key: String) -> void:
	UiStyle.rescale(self)


func _focus_first() -> void:
	for c in _all_children(self):
		if c is Button and not c.disabled and c.visible:
			c.grab_focus()
			return


func _all_children(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_children(c))
	return out


func _unhandled_input(event: InputEvent) -> void:
	if closable and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
