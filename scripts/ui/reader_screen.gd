extends "res://scripts/ui/overlay_screen.gd"
## The faded pages from the Scribe's Alcove. The ink comes back one page per
## real day after they were found: day one shows page one, and so on.

const Notes := preload("res://scripts/data/notes.gd")
const Loc := preload("res://scripts/core/loc.gd")


func _build() -> void:
	panel_width = 700.0
	name = "ReaderScreen"
	add_title("READER_TITLE")
	var n := Notes.readable()
	for i in n:
		var head := UiStyle.label("", 14, UiStyle.DIM, false)
		head.text = Loc.t("READER_PAGE") % (i + 1)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(head)
		var page := add_paragraph(Notes.PAGES[i], true, 19)
		page.name = "Page_%d" % (i + 1)
	add_spacer(6)
	var more := add_paragraph("READER_ALL" if n >= Notes.PAGES.size() else "READER_MORE", true, 15)
	more.add_theme_color_override("font_color", UiStyle.FAINT)
	add_button("UI_BACK", close).name = "Back"

