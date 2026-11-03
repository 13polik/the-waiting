extends RefCounted
## Collectible items: translation keys for their name, description (shown in
## the satchel) and the lines read when they are found. ORDER is the order the
## satchel lists them in. Items from enabled mods follow (see ModManager);
## always look items up through [method get_def] / [method order].

const ORDER := ["stone", "wing", "fragment", "bloom", "pages"]

const ITEMS := {
	"stone": {"title": "ITEM_STONE_TITLE", "desc": "ITEM_STONE_DESC", "found": ["ITEM_STONE_FOUND_1", "ITEM_STONE_FOUND_2"]},
	"wing": {"title": "ITEM_WING_TITLE", "desc": "ITEM_WING_DESC", "found": ["ITEM_WING_FOUND_1", "ITEM_WING_FOUND_2"]},
	"fragment": {"title": "ITEM_FRAGMENT_TITLE", "desc": "ITEM_FRAGMENT_DESC", "found": ["ITEM_FRAGMENT_FOUND_1", "ITEM_FRAGMENT_FOUND_2"]},
	"bloom": {"title": "ITEM_BLOOM_TITLE", "desc": "ITEM_BLOOM_DESC", "found": ["ITEM_BLOOM_FOUND_1", "ITEM_BLOOM_FOUND_2"]},
	"pages": {"title": "ITEM_PAGES_TITLE", "desc": "ITEM_PAGES_DESC", "found": ["ITEM_PAGES_FOUND_1", "ITEM_PAGES_FOUND_2"]},
}


static func get_def(item_id: String) -> Dictionary:
	if ITEMS.has(item_id):
		return ITEMS[item_id]
	var mm := _mods()
	return mm.item_def(item_id) if mm != null else {}


## How the item is drawn (ItemArt): base items by id, mod items by "art".
static func art(item_id: String) -> String:
	return item_id if ITEMS.has(item_id) else str(get_def(item_id).get("art", "stone"))


## The game's items, then those of enabled mods.
static func order() -> Array:
	var mm := _mods()
	return ORDER + (mm.item_ids() if mm != null else [])


## The ModManager autoload, looked up at run time so this script also compiles
## where autoloads are not registered (unit tests run with -s).
static func _mods() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("ModManager") if tree != null else null
