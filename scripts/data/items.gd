extends RefCounted
## Collectible items: translation keys for their name, description (shown in
## the satchel) and the lines read when they are found. ORDER is the order the
## satchel lists them in.

const ORDER := ["stone", "wing", "fragment", "bloom"]

const ITEMS := {
	"stone": {"title": "ITEM_STONE_TITLE", "desc": "ITEM_STONE_DESC", "found": ["ITEM_STONE_FOUND_1", "ITEM_STONE_FOUND_2"]},
	"wing": {"title": "ITEM_WING_TITLE", "desc": "ITEM_WING_DESC", "found": ["ITEM_WING_FOUND_1", "ITEM_WING_FOUND_2"]},
	"fragment": {"title": "ITEM_FRAGMENT_TITLE", "desc": "ITEM_FRAGMENT_DESC", "found": ["ITEM_FRAGMENT_FOUND_1", "ITEM_FRAGMENT_FOUND_2"]},
	"bloom": {"title": "ITEM_BLOOM_TITLE", "desc": "ITEM_BLOOM_DESC", "found": ["ITEM_BLOOM_FOUND_1", "ITEM_BLOOM_FOUND_2"]},
}
