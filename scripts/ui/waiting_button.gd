extends Button
## A quiet text button: dim at rest; on hover or focus the text brightens and
## a thin line of lantern-light draws out beneath it, with a small mark beside.
## [member selected] keeps it lit (used for option groups). Tall enough for a
## thumb; works with mouse, touch, keyboard and gamepad focus.

const UiStyle := preload("res://scripts/ui/ui_style.gd")

var selected: bool = false:
	set(v):
		selected = v
		_update_colors()
		queue_redraw()

var _glow: float = 0.0


static func make(key: String, base_size: int = 26, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Button:
	var b: Button = load("res://scripts/ui/waiting_button.gd").new()
	b.text = key
	b.alignment = align
	UiStyle.remember_size(b, base_size)
	return b


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = 52
	add_theme_font_override("font", UiStyle.font())
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_update_colors()


func _update_colors() -> void:
	var rest := UiStyle.INK if selected else UiStyle.DIM
	add_theme_color_override("font_color", rest)
	add_theme_color_override("font_hover_color", UiStyle.INK)
	add_theme_color_override("font_focus_color", UiStyle.INK)
	add_theme_color_override("font_pressed_color", UiStyle.ACCENT)
	add_theme_color_override("font_hover_pressed_color", UiStyle.ACCENT)
	add_theme_color_override("font_disabled_color", Color(UiStyle.FAINT, 0.28))


func _process(delta: float) -> void:
	var lit := (is_hovered() or has_focus() or selected) and not disabled
	var before := _glow
	_glow = move_toward(_glow, 1.0 if lit else 0.0, delta * 5.0)
	if before != _glow:
		queue_redraw()


func _draw() -> void:
	if _glow <= 0.001:
		return
	var f := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var w := f.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var e := ease(_glow, -2.0)
	var y := size.y * 0.5 + fs * 0.62
	var x0 := 0.0
	match alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x0 = (size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x0 = size.x - w
	draw_line(Vector2(x0, y), Vector2(x0 + w * e, y), Color(UiStyle.ACCENT, 0.55 * e), 1.2, true)
	if alignment == HORIZONTAL_ALIGNMENT_LEFT:
		var m := Vector2(x0 - 16.0, size.y * 0.5)
		draw_circle(m, 2.4 * e, Color(UiStyle.ACCENT, 0.9 * e))
