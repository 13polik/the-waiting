extends RefCounted
## The interface's single source of look: palette, serif type, spacing, and
## text scaling. Every label/button made here remembers its base size (meta
## "base_size"), so [method rescale] can apply the Text size setting live.
##
## Static text is set as a translation key (Label/Button auto-translate and
## update by themselves when the language changes). Text built from data is
## resolved with Loc and refreshed on NOTIFICATION_TRANSLATION_CHANGED.

const INK := Color(0.86, 0.85, 0.81)
const DIM := Color(0.62, 0.64, 0.63, 0.78)
const FAINT := Color(0.62, 0.64, 0.63, 0.45)
const ACCENT := Color(0.80, 0.93, 0.89)
const PANEL_BG := Color(0.015, 0.016, 0.022, 0.86)
const GAP := 14
const SECTION_GAP := 26

static var _font: SystemFont
static var _title_font: FontVariation


static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Iowan Old Style", "Georgia", "Palatino", "Times New Roman", "serif"])
	return _font


## Wide letter spacing for the game's name and screen titles.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = font()
		_title_font.spacing_glyph = 9
	return _title_font


static func scale() -> float:
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("SettingsManager")
	return settings.text_scale() if settings != null else 1.0


static func label(text: String, base_size: int, color: Color = INK, translate: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS if translate else Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", font())
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("base_size", base_size)
	l.add_theme_font_size_override("font_size", roundi(base_size * scale()))
	return l


static func title(text: String, base_size: int) -> Label:
	var l := label(text, base_size, Color(0.84, 0.86, 0.84))
	l.add_theme_font_override("font", title_font())
	return l


static func remember_size(c: Control, base_size: int) -> void:
	c.set_meta("base_size", base_size)
	c.add_theme_font_size_override("font_size", roundi(base_size * scale()))


## Re-applies the Text size setting to everything under [param root].
static func rescale(root: Node) -> void:
	var k := scale()
	if root is Control and root.has_meta("base_size"):
		root.add_theme_font_size_override("font_size", roundi(int(root.get_meta("base_size")) * k))
	for child in root.get_children():
		rescale(child)


static func panel_style(alpha: float = 0.86) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL_BG, alpha)
	style.border_color = Color(0.7, 0.74, 0.72, 0.08)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 30
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	return style


## A soft round grabber for sliders, large enough for a thumb.
static func grabber_texture(highlight: bool) -> ImageTexture:
	var size := 30
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var core := clampf(9.5 - d, 0.0, 1.0)
			var halo := clampf((14.5 - d) / 5.0, 0.0, 1.0) * (0.35 if highlight else 0.18)
			var col := ACCENT if highlight else INK
			img.set_pixel(x, y, Color(col, maxf(core, halo)))
	return ImageTexture.create_from_image(img)


static func style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.10)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(ACCENT, 0.55)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", grabber_texture(false))
	s.add_theme_icon_override("grabber_highlight", grabber_texture(true))
	s.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	s.custom_minimum_size = Vector2(260, 44)
