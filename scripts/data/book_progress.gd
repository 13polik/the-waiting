extends RefCounted
## Reading progress of the books, kept in WorldManager flags:
##   "<book>_sittings" — sittings read, "<book>_day" — day of the last one.
## Works for the game's books and for mod books alike (see books.gd).

const Books := preload("res://scripts/data/books.gd")


static func sittings(book_id: String) -> int:
	var total := int(Books.info(book_id).get("sittings", 0))
	return clampi(int(WorldManager.get_flag(book_id + "_sittings", 0)), 0, total)


static func pages_read(book_id: String) -> int:
	var b := Books.info(book_id)
	if b.is_empty():
		return 0
	return mini(sittings(book_id) * int(b["per_day"]), int(b["pages"]))


static func finished(book_id: String) -> bool:
	var b := Books.info(book_id)
	return not b.is_empty() and sittings(book_id) >= int(b["sittings"])


static func read_today(book_id: String) -> bool:
	var d: Variant = WorldManager.get_flag(book_id + "_day")
	return d != null and int(d) == TimeManager.day_index()


static func can_read(book_id: String) -> bool:
	return Books.is_book(book_id) and WorldManager.has_item(book_id) and not finished(book_id) and not read_today(book_id)


## Reads the next sitting's pages. Returns false when it cannot today.
static func read_next(book_id: String) -> bool:
	if not can_read(book_id):
		return false
	WorldManager.set_flag(book_id + "_sittings", sittings(book_id) + 1)
	WorldManager.set_flag(book_id + "_day", TimeManager.day_index())
	return true


static func total_pages_read() -> int:
	var n := 0
	for id in Books.all_ids():
		n += pages_read(id)
	return n


static func total_pages() -> int:
	var n := 0
	for id in Books.all_ids():
		n += int(Books.info(id).get("pages", 0))
	return n
