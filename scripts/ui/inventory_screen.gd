extends "res://scripts/ui/overlay_screen.gd"
## The satchel: what the creature carries, and the places it has found.
## Touch (or focus) an item to read about it. Opened from the HUD it pauses
## the game; opened from the pause menu it leaves the pause as it was.

const Items := preload("res://scripts/data/items.gd")
const Rooms := preload("res://scripts/world/rooms.gd")
const ItemArt := preload("res://scripts/world/item_art.gd")
const Loc := preload("res://scripts/core/loc.gd")

var _owns_pause: bool = false
var _desc: Label
var _places: Label
var _cards: Array = []


func _build() -> void:
	panel_width = 700.0
	name = "InventoryScreen"
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	add_title("SATCHEL_TITLE")

	var held: Array[String] = []
	for id in Items.ORDER:
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
			card.name = "Item_" + id
			card.pressed.connect(_select.bind(card))
			card.focus_entered.connect(_select.bind(card))
			row.add_child(card)
			_cards.append(card)
		_desc = add_paragraph("", true, 18)
		_desc.name = "Description"
		_desc.custom_minimum_size.y = 64
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
	_desc.text = Items.ITEMS[card.item_id]["desc"]


func _refresh_places() -> void:
	var names: PackedStringArray = []
	for id in Rooms.ORDER:
		if WorldManager.discovered.has(id):
			names.append(Loc.t(Rooms.TITLES[id]))
	_places.text = (Loc.t("SATCHEL_PLACES") % [names.size(), Rooms.ORDER.size()]) + "\n" + "  ·  ".join(names)


func close() -> void:
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
		_label = UiStyleRef.label(ItemsRef.ITEMS[item_id]["title"], 16, UiStyleRef.INK)
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
