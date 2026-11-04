extends "res://scripts/ui/overlay_screen.gd"
## The end of the wait (0.6): an epilogue, then what this wait was made of —
## places found, things carried, pages read, the bloom, honesty with time.
## "Stay" returns to the world (everything stays open); "Main menu" leaves.

const Loc := preload("res://scripts/core/loc.gd")
const Rooms := preload("res://scripts/world/rooms.gd")
const Items := preload("res://scripts/data/items.gd")
const Notes := preload("res://scripts/data/notes.gd")
const BloomSprout := preload("res://scripts/world/props/bloom_sprout.gd")
const Books := preload("res://scripts/data/books.gd")
const BookProgress := preload("res://scripts/data/book_progress.gd")
const Visits := preload("res://scripts/data/lamplighter_visits.gd")

## The game scene (for leaving to the menu).
var game: Node
var _owns_pause: bool = false


func _build() -> void:
	panel_width = 760.0
	name = "EndingScreen"
	closable = false
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	add_title("ENDING_TITLE")
	for key in ["ENDING_1", "ENDING_2", "ENDING_3"]:
		add_paragraph(key, true, 19)
	add_spacer(8)
	var stats := add_paragraph("", false, 16)
	stats.name = "Stats"
	stats.add_theme_color_override("font_color", UiStyle.DIM)
	stats.text = "\n".join(summary())
	add_spacer(6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var stay := add_button("ENDING_STAY", _stay, HORIZONTAL_ALIGNMENT_CENTER, row)
	stay.name = "Stay"
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var menu := add_button("ENDING_MENU", _to_menu, HORIZONTAL_ALIGNMENT_CENTER, row)
	menu.name = "Menu"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## One line per thing this wait was made of.
static func summary() -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append(Loc.t("ENDING_DAYS") % Loc.count("UNIT_DAYS", TimeManager.clock.total_days))
	var all := Rooms.all_ids()
	var found := 0
	for id in all:
		if WorldManager.discovered.has(id):
			found += 1
	lines.append(Loc.t("ENDING_PLACES") % [found, all.size()])
	var carried := 0
	var total_items := Items.order()
	for id in total_items:
		if WorldManager.is_collected(id):
			carried += 1
	lines.append(Loc.t("ENDING_ITEMS") % [carried, total_items.size()])
	lines.append(Loc.t("ENDING_PAGES") % [Notes.readable(), Notes.PAGES.size()])
	lines.append(Loc.t("ENDING_BOOKS") % [BookProgress.total_pages_read(), Books.PAGES * Books.ORDER.size()])
	lines.append(Loc.t("ENDING_LAMP") % [mini(int(WorldManager.get_flag("lamp_talks", 0)), Visits.VISITS.size()), Visits.VISITS.size()])
	var stage := BloomSprout.stage()
	lines.append(Loc.t("ENDING_BLOOM_GROWN" if stage >= 3 else ("ENDING_BLOOM_GROWING" if stage >= 0 else "ENDING_BLOOM_NONE")))
	var tampers := TimeManager.clock.tamper_events
	lines.append(Loc.t("ENDING_HONEST") if tampers == 0 else Loc.t("ENDING_TAMPERED") % tampers)
	return lines


func _stay() -> void:
	if _owns_pause:
		get_tree().paused = false
	close()


func _to_menu() -> void:
	SaveManager.save_now("ending")
	get_tree().paused = false
	if game != null and is_instance_valid(game):
		game.leave_to_menu()
	close()
