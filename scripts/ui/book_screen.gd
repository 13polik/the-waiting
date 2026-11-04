extends "res://scripts/ui/overlay_screen.gd"
## Reading one of the three books (0.7). Three hundred pages, twenty at a
## sitting, one sitting a day: what stays from each sitting is listed under
## its page range. "Read on" reads the next twenty pages when it may.

const Books := preload("res://scripts/data/books.gd")
const BookProgress := preload("res://scripts/data/book_progress.gd")
const Loc := preload("res://scripts/core/loc.gd")

var book_id: String = "book_door"
var _list: VBoxContainer
var _status: Label
var _read: Button


func _build() -> void:
	panel_width = 720.0
	name = "BookScreen"
	add_title(Books.BOOKS[book_id]["title"])
	_status = add_paragraph("", false, 15)
	_status.name = "Status"
	_status.add_theme_color_override("font_color", UiStyle.DIM)
	_list = VBoxContainer.new()
	_list.name = "Passages"
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	add_spacer(6)
	_read = add_button("BOOK_READ_ON", _read_on)
	_read.name = "ReadOn"
	add_button("UI_BACK", close).name = "Back"
	_fill()


func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var n := BookProgress.sittings(book_id)
	if n == 0:
		var first := UiStyle.label("BOOK_UNOPENED", 17, UiStyle.DIM)
		first.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		first.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(first)
	for i in n:
		var head := UiStyle.label("", 14, UiStyle.FAINT, false)
		head.text = Loc.t("BOOK_PAGES") % [i * Books.PER_SITTING + 1, (i + 1) * Books.PER_SITTING]
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(head)
		var p := UiStyle.label(Books.passage_key(book_id, i + 1), 18, UiStyle.INK)
		p.name = "Passage_%d" % (i + 1)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.custom_minimum_size.x = panel_width - 80
		_list.add_child(p)
	var pages := BookProgress.pages_read(book_id)
	if BookProgress.finished(book_id):
		_status.text = Loc.t("BOOK_FINISHED") % Books.PAGES
	elif BookProgress.read_today(book_id):
		_status.text = (Loc.t("BOOK_PROGRESS") % [pages, Books.PAGES]) + "\n" + Loc.t("BOOK_TOMORROW")
	else:
		_status.text = Loc.t("BOOK_PROGRESS") % [pages, Books.PAGES]
	_read.visible = BookProgress.can_read(book_id)
	UiStyle.rescale(_list)
	await get_tree().process_frame
	if is_instance_valid(box):
		_fit(box.get_parent())
		var scroll := box.get_parent() as ScrollContainer
		if scroll != null:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _read_on() -> void:
	if BookProgress.read_next(book_id):
		AudioManager.play("examine", -16.0, 0.8, AudioManager.BUS_CHARACTER)
		SaveManager.save_now("book")
	_fill()
