extends RefCounted
## The three books (0.7). Each has 300 pages, read twenty at a sitting, one
## sitting per book per real day — so a book takes fifteen days. Each sitting
## leaves a passage (what stays with you from those twenty pages).
## Pure data: progress lives in WorldManager flags (see BookProgress).

const PAGES := 300
const PER_SITTING := 20
const SITTINGS := PAGES / PER_SITTING  # 15

## id → title key, passage key prefix (…_1 … _15), where it is found.
const BOOKS := {
	"book_door": {"title": "ITEM_BOOK_DOOR_TITLE", "prefix": "BOOK_DOOR_"},
	"book_herbs": {"title": "ITEM_BOOK_HERBS_TITLE", "prefix": "BOOK_HERBS_"},
	"book_tales": {"title": "ITEM_BOOK_TALES_TITLE", "prefix": "BOOK_TALES_"},
}
const ORDER := ["book_door", "book_herbs", "book_tales"]


static func is_book(item_id: String) -> bool:
	return BOOKS.has(item_id)


static func passage_key(book_id: String, sitting: int) -> String:
	return "%s%d" % [BOOKS[book_id]["prefix"], sitting]


static func all_keys() -> Array:
	var keys: Array = []
	for id in ORDER:
		keys.append(BOOKS[id]["title"])
		for i in SITTINGS:
			keys.append(passage_key(id, i + 1))
	return keys
