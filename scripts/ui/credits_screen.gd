extends "res://scripts/ui/overlay_screen.gd"
## Credits.


func _build() -> void:
	name = "CreditsScreen"
	add_title("CREDITS_TITLE")
	var game := UiStyle.title("THE WAITING", 22)
	game.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(game)
	add_spacer(6)
	for key in ["CREDITS_1", "CREDITS_2", "CREDITS_3"]:
		add_paragraph(key)
	add_spacer(8)
	var thanks := add_paragraph("CREDITS_4")
	thanks.add_theme_color_override("font_color", UiStyle.ACCENT)
	var version := UiStyle.label("v" + str(ProjectSettings.get_setting("application/config/version")), 14, UiStyle.FAINT, false)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)
	add_spacer(4)
	add_button("UI_BACK", close).name = "Back"
