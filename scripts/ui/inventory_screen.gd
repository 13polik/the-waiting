extends "res://scripts/ui/overlay_screen.gd"
## The satchel: what the creature carries, and the places it has found.
## Touch (or focus) an item to read about it. Opened from the HUD it pauses
## the game; opened from the pause menu it leaves the pause as it was.

const Items := preload("res://scripts/data/items.gd")
const Rooms := preload("res://scripts/world/rooms.gd")
const ItemArt := preload("res://scripts/world/item_art.gd")
const Loc := preload("res://scripts/core/loc.gd")
const ReaderScreen := preload("res://scripts/ui/reader_screen.gd")
const Notes := preload("res://scripts/data/notes.gd")
const BookScreen := preload("res://scripts/ui/book_screen.gd")
const Books := preload("res://scripts/data/books.gd")

var _owns_pause: bool = false
var _desc: Label
var _places: Label
var _cards: Array = []
var _read: Button
var _sub: Node = null
var _selected: String = ""


func _build() -> void:
	panel_width = 700.0
	name = "InventoryScreen"
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	add_title("SATCHEL_TITLE")

	var held: Array[String] = []
	for id in Items.order():
		if WorldManager.has_item(id):
			held.append(id)
	if held.is_empty():
		add_paragraph("SATCHEL_EMPTY").add_theme_color_override("font_color", UiStyle.DIM)
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		for id in held:
			var card := ItemCard.new()
			card.item_id = id
			card.name = "Item_" + id.replace(":", "_")
			card.pressed.connect(_select.bind(card))
			card.focus_entered.connect(_select.bind(card))
			row.add_child(card)
			_cards.append(card)
		_desc = add_paragraph("", true, 18)
		_desc.name = "Description"
		_desc.custom_minimum_size.y = 64
		_read = add_button("SATCHEL_READ", _open_reader)
		_read.name = "Read"
		_select(_cards[0])

	add_spacer(6)
	_places = add_paragraph("", false, 15)
	_places.name = "Places"
	_places.add_theme_color_override("font_color", UiStyle.DIM)
	_refresh_places()
	add_button("UI_BACK", close).name = "Back"
	WorldManager.mark_items_seen()
	UIManager.refresh_satchel_badge()


func _select(card: Button) -> void:
	for c in _cards:
		c.selected = c == card
	_selected = card.item_id
	_desc.text = Items.get_def(card.item_id)["desc"]
	if _read != null:
		_read.visible = (card.item_id == "pages" and Notes.readable() > 0) or Books.is_book(card.item_id)
		_read.text = "SATCHEL_READ_BOOK" if Books.is_book(card.item_id) else "SATCHEL_READ"


func _open_reader() -> void:
	if _sub != null and is_instance_valid(_sub):
		return
	if Books.is_book(_selected):
		_sub = BookScreen.new()
		_sub.book_id = _selected
	else:
		_sub = ReaderScreen.new()
	get_parent().add_child(_sub)
	# Only one panel at a time: the satchel steps aside while reading.
	visible = false
	_sub.closed.connect(func() -> void:
		_sub = null
		visible = true)


func _unhandled_input(event: InputEvent) -> void:
	if _sub != null and is_instance_valid(_sub):
		return  # The reader on top handles Back itself.
	super(event)


func _refresh_places() -> void:
	var names: PackedStringArray = []
	var all := Rooms.all_ids()
	for id in all:
		if WorldManager.discovered.has(id):
			names.append(Loc.t(Rooms.title(id)))
	_places.text = (Loc.t("SATCHEL_PLACES") % [names.size(), all.size()]) + "\n" + "  ·  ".join(names)


func close() -> void:
	if _sub != null and is_instance_valid(_sub):
		return
	if _owns_pause and not _closing:
		get_tree().paused = false
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _places != null:
		_refresh_places()


## One item: its drawing above, its name below; lit when selected.
class ItemCard extends Button:
	const UiStyleRef := preload("res://scripts/ui/ui_style.gd")
	const Art := preload("res://scripts/world/item_art.gd")
	const ItemsRef := preload("res://scripts/data/items.gd")
	var item_id: String = ""
	var selected: bool = false:
		set(v):
			selected = v
			queue_redraw()
	var _label: Label

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(136, 132)
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_label = UiStyleRef.label(ItemsRef.get_def(item_id)["title"], 16, UiStyleRef.INK)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_label.offset_bottom = -4
		add_child(_label)

	func _draw() -> void:
		var r := Rect2(Vector2(6, 4), size - Vector2(12, 8))
		draw_rect(r, Color(1, 1, 1, 0.06 if selected else 0.025))
		if selected:
			draw_rect(r, Color(UiStyleRef.ACCENT, 0.4), false, 1.0)
		Art.draw(self, item_id, Vector2(size.x * 0.5, 48), 2.4)
