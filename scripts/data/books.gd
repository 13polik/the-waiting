extends RefCounted
## Books (0.7; mod books 0.8). The game's three books have 300 pages, read
## twenty at a sitting; a mod book sets its own length and pages per day (for
## example 850 pages, fifty a day). One sitting per book per real day; each
## sitting leaves a passage (what stays with you from those pages).
## Progress lives in WorldManager flags (see book_progress.gd).

const PAGES := 300
const PER_SITTING := 20
const SITTINGS := PAGES / PER_SITTING  # 15

## id → title key, passage key prefix (…_1 … _15).
const BOOKS := {
	"book_door": {"title": "ITEM_BOOK_DOOR_TITLE", "prefix": "BOOK_DOOR_"},
	"book_herbs": {"title": "ITEM_BOOK_HERBS_TITLE", "prefix": "BOOK_HERBS_"},
	"book_tales": {"title": "ITEM_BOOK_TALES_TITLE", "prefix": "BOOK_TALES_"},
}
const ORDER := ["book_door", "book_herbs", "book_tales"]


static func is_book(item_id: String) -> bool:
	return BOOKS.has(item_id) or not _mod_book(item_id).is_empty()


## The game's books, then those of enabled mods.
static func all_ids() -> Array:
	var mm := _mods()
	return ORDER + (mm.book_ids() if mm != null else [])


## {title, pages, per_day, sittings, passages: [keys]}, or {} if not a book.
static func info(book_id: String) -> Dictionary:
	if BOOKS.has(book_id):
		var keys: Array = []
		for i in SITTINGS:
			keys.append(passage_key(book_id, i + 1))
		return {"title": BOOKS[book_id]["title"], "pages": PAGES, "per_day": PER_SITTING, "sittings": SITTINGS, "passages": keys}
	var d := _mod_book(book_id)
	if d.is_empty():
		return {}
	return {"title": d["title"], "pages": d["pages"], "per_day": d["per_day"], "sittings": (d["passages"] as Array).size(), "passages": d["passages"]}


static func passage_key(book_id: String, sitting: int) -> String:
	return "%s%d" % [BOOKS[book_id]["prefix"], sitting]


## Translation keys of the game's own books (for the completeness test).
static func all_keys() -> Array:
	var keys: Array = []
	for id in ORDER:
		keys.append(BOOKS[id]["title"])
		for i in SITTINGS:
			keys.append(passage_key(id, i + 1))
	return keys


static func _mod_book(book_id: String) -> Dictionary:
	var mm := _mods()
	return mm.book_def(book_id) if mm != null else {}


## The ModManager autoload, looked up at run time (unit tests run without it).
static func _mods() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("ModManager") if tree != null else null
