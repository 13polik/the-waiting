extends RefCounted
## Reading progress of the books, kept in WorldManager flags:
##   "<book>_sittings" — sittings read (0…15), "<book>_day" — day of the last one.

const Books := preload("res://scripts/data/books.gd")


static func sittings(book_id: String) -> int:
	return clampi(int(WorldManager.get_flag(book_id + "_sittings", 0)), 0, Books.SITTINGS)


static func pages_read(book_id: String) -> int:
	return sittings(book_id) * Books.PER_SITTING


static func finished(book_id: String) -> bool:
	return sittings(book_id) >= Books.SITTINGS


static func read_today(book_id: String) -> bool:
	var d: Variant = WorldManager.get_flag(book_id + "_day")
	return d != null and int(d) == TimeManager.day_index()


static func can_read(book_id: String) -> bool:
	return WorldManager.has_item(book_id) and not finished(book_id) and not read_today(book_id)


## Reads the next twenty pages. Returns false when it cannot today.
static func read_next(book_id: String) -> bool:
	if not can_read(book_id):
		return false
	WorldManager.set_flag(book_id + "_sittings", sittings(book_id) + 1)
	WorldManager.set_flag(book_id + "_day", TimeManager.day_index())
	return true


static func total_pages_read() -> int:
	var n := 0
	for id in Books.ORDER:
		n += pages_read(id)
	return n
