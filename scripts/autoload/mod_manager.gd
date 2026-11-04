extends Node
## ModManager — data-only mods: new places, things and words, read from
## <user>/mods/<id>/mod.json. No code is ever loaded: mods cannot run scripts
## (App Store guideline 2.5.2, and simply safer). A broken mod is listed with
## its errors and stays off; it can never crash the game or touch the save.
##
## Text in a mod is written inline as {"en": "...", "pl": "..."} (or a plain
## string for every language); it is registered with TranslationServer under
## generated keys, so it follows the language setting like the game's own.
## Ids are namespaced: room "mod:<mod>:<room>", item "mod:<mod>:<item>".
## Format reference: docs/MODDING.md.

signal mods_changed

const FORMAT := 1
const MAX_FILE_BYTES := 512 * 1024
const MAX_ROOMS := 5
const MAX_ITEMS := 10
const MAX_OBJECTS := 30
## Base rooms with a spot where a mod's side passage can open, and where.
## 0.8: also the Scribe's Alcove and, after the ending, Beyond the Door.
const ANCHORS := {"narrow": 1450.0, "hall": 620.0, "garden": 1000.0, "alcove": 1620.0, "beyond": 620.0}
const OBJECT_KINDS := ["fossil", "marks", "trickle", "pillar", "moss", "veins", "pool", "shaft"]
const ART_KINDS := ["stone", "wing", "fragment", "bloom", "pages", "book_door", "book_herbs", "book_tales"]
## 0.8: books (read a set number of pages a day) and things the creature does
## while the player is away. Neither needs a room of its own.
const MAX_BOOKS := 3
const MAX_PASSAGES := 100
const MAX_AWAY := 20
const BOOK_ARTS := ["book_door", "book_herbs", "book_tales"]
## Base rooms where a mod's book (or an away activity) can be placed.
const BASE_ROOMS := ["home", "narrow", "hall", "garden", "alcove", "beyond"]
const EXAMPLE_SOURCE := "res://mods_examples"
const ID_PATTERN := "^[a-z0-9_]{1,32}$"

## Every mod found: {id, dir, name, description, author, version, ok, errors,
## enabled, rooms (full id → def), items (full id → def)}.
var mods: Array = []
var _translations: Array[Translation] = []
var _rooms: Dictionary = {}
var _items: Dictionary = {}
var _item_order: Array = []
var _anchor_rooms: Dictionary = {}
var _books: Dictionary = {}
## Items lying in base rooms: [{item, room, x}].
var _placements: Array = []
var _away: Array = []
var _id_regex := RegEx.create_from_string(ID_PATTERN)


func _ready() -> void:
	install_example()
	scan()


func mods_dir() -> String:
	return "user://mods" if SaveManager.profile == "save" else "user://mods_%s" % SaveManager.profile


# --- Queries used by the game ---------------------------------------------------

func room_def(room_id: String) -> Dictionary:
	return _rooms.get(room_id, {})


func room_ids() -> Array:
	return _rooms.keys()


func item_def(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


func item_ids() -> Array:
	return _item_order


## A mod book: {title, pages, per_day, passages (keys)} or {}.
func book_def(item_id: String) -> Dictionary:
	return _books.get(item_id, {})


func book_ids() -> Array:
	return _books.keys()


## Mod items lying in [param room_id] (a base room): [{item, x}].
func placements_in(room_id: String) -> Array:
	var out: Array = []
	for p in _placements:
		if p["room"] == room_id:
			out.append(p)
	return out


## What the creature can be found doing on return: [{text, room, x, needs_item}].
func away_activities() -> Array:
	return _away


## The mod room whose side passage opens in [param base_room], or "".
func anchor_room(base_room: String) -> String:
	return _anchor_rooms.get(base_room, "")


# --- Managing mods --------------------------------------------------------------

func set_enabled(mod_id: String, on: bool) -> void:
	var enabled: Dictionary = (SettingsManager.get_value("mods_enabled") as Dictionary).duplicate()
	enabled[mod_id] = on
	SettingsManager.set_value("mods_enabled", enabled)
	scan()


func scan() -> void:
	mods.clear()
	var dir := mods_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var folders := DirAccess.get_directories_at(dir)
	folders.sort()
	var enabled: Dictionary = SettingsManager.get_value("mods_enabled")
	for folder in folders:
		var m := _read_mod(dir.path_join(folder), folder)
		m["enabled"] = bool(enabled.get(m["id"], false)) and m["ok"]
		mods.append(m)
	_rebuild()
	mods_changed.emit()


## First run: put the example mod (switched off) where players will find it.
func install_example() -> void:
	var done: Array = SettingsManager.get_value("mods_examples_installed").duplicate()
	if bool(SettingsManager.get_value("mods_example_installed")) and "glimmer_grotto" not in done:
		done.append("glimmer_grotto")  # Installed by 0.4, which kept only a flag.
	var dest_root := mods_dir()
	for folder in DirAccess.get_directories_at(EXAMPLE_SOURCE):
		var src := EXAMPLE_SOURCE.path_join(folder).path_join("mod.json")
		var dest_dir := dest_root.path_join(folder)
		if folder in done or not FileAccess.file_exists(src):
			continue
		done.append(folder)
		if DirAccess.dir_exists_absolute(dest_dir):
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
		var text := FileAccess.get_file_as_string(src)
		var f := FileAccess.open(dest_dir.path_join("mod.json"), FileAccess.WRITE)
		if f != null:
			f.store_string(text)
			f.close()
	SettingsManager.set_value("mods_examples_installed", done)
	SettingsManager.set_value("mods_example_installed", true)


# --- Reading and checking -------------------------------------------------------

func _read_mod(path: String, folder: String) -> Dictionary:
	var m := {"id": folder, "dir": path, "name": folder, "description": "", "author": "", "version": "",
		"ok": false, "errors": PackedStringArray(), "warnings": PackedStringArray(), "enabled": false,
		"rooms": {}, "items": {}, "texts": {}, "books": {}, "placements": [], "away": []}
	var errors: PackedStringArray = m["errors"]
	var file := path.path_join("mod.json")
	if not FileAccess.file_exists(file):
		errors.append("mod.json is missing")
		return m
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null or f.get_length() > MAX_FILE_BYTES:
		errors.append("mod.json cannot be read or is larger than 512 KB")
		return m
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		errors.append("mod.json is not valid JSON (line %d: %s)" % [maxi(json.get_error_line(), 1), json.get_error_message()])
		return m
	var d: Variant = json.data
	if typeof(d) != TYPE_DICTIONARY:
		errors.append("mod.json must contain an object")
		return m
	if int(d.get("format", 0)) != FORMAT:
		errors.append("\"format\" must be %d" % FORMAT)
	var id := str(d.get("id", ""))
	if _id_regex.search(id) == null:
		errors.append("\"id\" must be 1–32 characters a–z, 0–9 or _")
	elif id != folder:
		errors.append("\"id\" (%s) must match the folder name (%s)" % [id, folder])
	m["id"] = folder
	var texts: Dictionary = m["texts"]
	m["name"] = _text(d.get("name"), texts, "%s_NAME" % folder, errors, "name", true)
	m["description"] = _text(d.get("description", ""), texts, "%s_DESC" % folder, errors, "description", false)
	m["author"] = str(d.get("author", ""))
	m["version"] = str(d.get("version", ""))

	var items: Variant = d.get("items", {})
	if typeof(items) != TYPE_DICTIONARY or items.size() > MAX_ITEMS:
		errors.append("\"items\" must be an object with at most %d items" % MAX_ITEMS)
		items = {}
	for local in items:
		var it: Variant = items[local]
		var where := "items.%s" % local
		if _id_regex.search(str(local)) == null or typeof(it) != TYPE_DICTIONARY:
			errors.append("%s: bad id or not an object" % where)
			continue
		var art := str(it.get("art", ""))
		if art not in ART_KINDS:
			errors.append("%s.art must be one of %s" % [where, ", ".join(ART_KINDS)])
		var key := "%s_ITEM_%s" % [folder, str(local).to_upper()]
		m["items"]["mod:%s:%s" % [folder, local]] = {
			"title": _text(it.get("title"), texts, key + "_TITLE", errors, where + ".title", true),
			"desc": _text(it.get("description"), texts, key + "_DESC", errors, where + ".description", true),
			"found": _texts(it.get("found"), texts, key + "_FOUND", errors, where + ".found"),
			"art": art,
		}

	_read_books(folder, d.get("books", {}), m, texts, errors)
	_read_away(folder, d.get("away", []), m, texts, errors)

	var rooms: Variant = d.get("rooms", {})
	if typeof(rooms) != TYPE_DICTIONARY or rooms.size() > MAX_ROOMS:
		errors.append("\"rooms\" must be an object with at most %d rooms" % MAX_ROOMS)
		rooms = {}
	for local in rooms:
		var r := _read_room(folder, str(local), rooms[local], texts, m["items"], errors)
		if not r.is_empty():
			m["rooms"]["mod:%s:%s" % [folder, local]] = r
	if (m["rooms"] as Dictionary).is_empty() and (m["items"] as Dictionary).is_empty() and (m["away"] as Array).is_empty():
		errors.append("the mod adds nothing (no rooms, items, books or away activities)")
	m["ok"] = errors.is_empty()
	return m


## "books": {"<id>": {title, description, found, art, pages, per_day,
## passages: [one text per day of reading], room, x}}. A book is also an item.
func _read_books(folder: String, v: Variant, m: Dictionary, texts: Dictionary, errors: PackedStringArray) -> void:
	if v == null:
		return
	if typeof(v) != TYPE_DICTIONARY or v.size() > MAX_BOOKS:
		errors.append("\"books\" must be an object with at most %d books" % MAX_BOOKS)
		return
	for local in v:
		var b: Variant = v[local]
		var where := "books.%s" % local
		if _id_regex.search(str(local)) == null or typeof(b) != TYPE_DICTIONARY:
			errors.append("%s: bad id or not an object" % where)
			continue
		var full := "mod:%s:%s" % [folder, local]
		if m["items"].has(full):
			errors.append("%s: an item with this id already exists" % where)
			continue
		var key := "%s_BOOK_%s" % [folder, str(local).to_upper()]
		var art := str(b.get("art", "book_door"))
		if art not in BOOK_ARTS:
			errors.append("%s.art must be one of %s" % [where, ", ".join(BOOK_ARTS)])
		var pages := int(b.get("pages", 0)) if typeof(b.get("pages")) in [TYPE_INT, TYPE_FLOAT] else 0
		var per := int(b.get("per_day", 0)) if typeof(b.get("per_day")) in [TYPE_INT, TYPE_FLOAT] else 0
		if pages < 10 or pages > 5000:
			errors.append("%s.pages must be 10–5000" % where)
			continue
		if per < 1 or per > pages:
			errors.append("%s.per_day must be 1–%d" % [where, pages])
			continue
		var days := int(ceil(float(pages) / float(per)))
		var passages: Variant = b.get("passages")
		if typeof(passages) != TYPE_ARRAY or passages.size() != days or days > MAX_PASSAGES:
			errors.append("%s.passages must list exactly %d texts, one per day of reading (%d pages, %d a day; at most %d)" % [where, days, pages, per, MAX_PASSAGES])
			continue
		var keys: Array = []
		for i in passages.size():
			var k := _text(passages[i], texts, "%s_P%d" % [key, i + 1], errors, "%s.passages[%d]" % [where, i], true)
			keys.append(k)
		var room := str(b.get("room", "home"))
		if room not in BASE_ROOMS and not room.begins_with("mod:%s:" % folder):
			errors.append("%s.room must be one of %s (or one of this mod's rooms)" % [where, ", ".join(BASE_ROOMS)])
			continue
		var title := _text(b.get("title"), texts, key + "_TITLE", errors, where + ".title", true)
		m["items"][full] = {
			"title": title,
			"desc": _text(b.get("description"), texts, key + "_DESC", errors, where + ".description", true),
			"found": _texts(b.get("found"), texts, key + "_FOUND", errors, where + ".found"),
			"art": art,
		}
		m["books"][full] = {"title": title, "pages": pages, "per_day": per, "passages": keys}
		var x := float(b.get("x", 600.0)) if typeof(b.get("x")) in [TYPE_INT, TYPE_FLOAT] else 600.0
		(m["placements"] as Array).append({"item": full, "room": room, "x": x})


## "away": [{text, room?, x?, needs_item?}] — found doing this on return.
func _read_away(folder: String, v: Variant, m: Dictionary, texts: Dictionary, errors: PackedStringArray) -> void:
	if v == null:
		return
	if typeof(v) != TYPE_ARRAY or v.size() > MAX_AWAY:
		errors.append("\"away\" must be a list of at most %d activities" % MAX_AWAY)
		return
	for i in v.size():
		var a: Variant = v[i]
		var where := "away[%d]" % i
		if typeof(a) != TYPE_DICTIONARY:
			errors.append("%s must be an object" % where)
			continue
		var text := _text(a.get("text"), texts, "%s_AWAY_%d" % [folder, i + 1], errors, where + ".text", true)
		var room := str(a.get("room", ""))
		if not room.is_empty() and room not in BASE_ROOMS:
			errors.append("%s.room must be one of %s, or left out" % [where, ", ".join(BASE_ROOMS)])
			continue
		var need := str(a.get("needs_item", ""))
		if not need.is_empty() and not need.contains(":") and not need in ["stone", "wing", "fragment", "bloom", "pages", "book_door", "book_herbs", "book_tales"]:
			need = "mod:%s:%s" % [folder, need]
		var entry := {"text": text, "room": room, "needs_item": need}
		if typeof(a.get("x")) in [TYPE_INT, TYPE_FLOAT]:
			entry["x"] = float(a["x"])
		(m["away"] as Array).append(entry)


func _read_room(mod_id: String, local: String, r: Variant, texts: Dictionary, items: Dictionary, errors: PackedStringArray) -> Dictionary:
	var where := "rooms.%s" % local
	if _id_regex.search(local) == null or typeof(r) != TYPE_DICTIONARY:
		errors.append("%s: bad id or not an object" % where)
		return {}
	var key := "%s_ROOM_%s" % [mod_id, local.to_upper()]
	var out := {"mod": mod_id, "local": local}
	out["title"] = _text(r.get("title"), texts, key + "_TITLE", errors, where + ".title", true)
	var anchor := str(r.get("anchor", ""))
	if not ANCHORS.has(anchor):
		errors.append("%s.anchor must be one of %s" % [where, ", ".join(ANCHORS.keys())])
	out["anchor"] = anchor
	var width := float(r.get("width", 2000))
	if width < 1200 or width > 4000:
		errors.append("%s.width must be 1200–4000" % where)
	out["width"] = clampf(width, 1200, 4000)
	out["floor"] = _points(r.get("floor"), 650, 900, errors, where + ".floor")
	out["ceiling"] = _points(r.get("ceiling"), 100, 640, errors, where + ".ceiling")
	out["palette"] = {}
	var pal: Variant = r.get("palette", {})
	if typeof(pal) == TYPE_DICTIONARY:
		for c in ["light", "stone", "wash"]:
			if pal.has(c):
				var col := _color(pal[c])
				if col.a < 0.0:
					errors.append("%s.palette.%s must be [r, g, b] with values 0–1" % [where, c])
				else:
					out["palette"][c] = col
	var objects: Variant = r.get("objects", [])
	out["objects"] = []
	if typeof(objects) != TYPE_ARRAY or objects.size() > MAX_OBJECTS:
		errors.append("%s.objects must be a list of at most %d" % [where, MAX_OBJECTS])
		objects = []
	for i in objects.size():
		var o: Variant = objects[i]
		var ow := "%s.objects[%d]" % [where, i]
		if typeof(o) != TYPE_DICTIONARY:
			errors.append(ow + " must be an object")
			continue
		var kind := str(o.get("kind", ""))
		if kind not in OBJECT_KINDS:
			errors.append("%s.kind must be one of %s" % [ow, ", ".join(OBJECT_KINDS)])
			continue
		var x := float(o.get("x", -1))
		if x < 260 or x > width - 220:
			errors.append("%s.x must be between 260 and width − 220" % ow)
			continue
		var okey := "%s_O%d" % [key, i]
		var obj := {"kind": kind, "x": x, "examinable": o.has("title")}
		if obj["examinable"]:
			obj["title"] = _text(o.get("title"), texts, okey + "_TITLE", errors, ow + ".title", true)
			obj["first"] = _texts(o.get("text"), texts, okey + "_T", errors, ow + ".text")
			obj["repeat"] = _texts(o.get("again", []), texts, okey + "_A", errors, ow + ".again", false)
		out["objects"].append(obj)
	var picks: Variant = r.get("items", [])
	out["items"] = []
	if typeof(picks) == TYPE_ARRAY:
		for p in picks:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var full := "mod:%s:%s" % [mod_id, str(p.get("item", ""))]
			var px := float(p.get("x", -1))
			if not items.has(full):
				errors.append("%s.items: unknown item \"%s\"" % [where, p.get("item", "")])
			elif px < 260 or px > width - 220:
				errors.append("%s.items: x must be between 260 and width − 220" % where)
			else:
				out["items"].append({"item": full, "x": px})
	return out


## One piece of text → a translation key (registered later). Accepts
## {"en": "...", "pl": "..."} or a plain string.
func _text(v: Variant, texts: Dictionary, key: String, errors: PackedStringArray, where: String, required: bool) -> String:
	if v == null or (typeof(v) == TYPE_STRING and String(v).is_empty()):
		if required:
			errors.append("%s is missing" % where)
		return ""
	var by_lang := {}
	if typeof(v) == TYPE_STRING:
		by_lang = {"en": v}
	elif typeof(v) == TYPE_DICTIONARY:
		for lang in v:
			if typeof(v[lang]) == TYPE_STRING and String(v[lang]).length() <= 600:
				by_lang[str(lang)] = v[lang]
	if not by_lang.has("en") and not by_lang.has("pl"):
		errors.append("%s needs \"en\" or \"pl\" text (at most 600 characters)" % where)
		return ""
	var full := "MOD_" + key.to_upper()
	texts[full] = by_lang
	return full


func _texts(v: Variant, texts: Dictionary, key: String, errors: PackedStringArray, where: String, required: bool = true) -> Array:
	var out := []
	if v == null and not required:
		return out
	if typeof(v) != TYPE_ARRAY or v.size() > 8 or (required and v.is_empty()):
		errors.append("%s must be a list of 1–8 lines" % where)
		return out
	for i in v.size():
		var k := _text(v[i], texts, "%s%d" % [key, i], errors, "%s[%d]" % [where, i], true)
		if not k.is_empty():
			out.append(k)
	return out


func _points(v: Variant, lo: float, hi: float, errors: PackedStringArray, where: String) -> Array:
	var out := []
	if typeof(v) != TYPE_ARRAY or v.size() < 2 or v.size() > 40:
		errors.append("%s must be a list of 2–40 [x, y] points" % where)
		return out
	for p in v:
		if typeof(p) != TYPE_ARRAY or p.size() != 2 or not (typeof(p[0]) in [TYPE_INT, TYPE_FLOAT]) or not (typeof(p[1]) in [TYPE_INT, TYPE_FLOAT]):
			errors.append("%s: every point must be [x, y]" % where)
			return []
		if float(p[1]) < lo or float(p[1]) > hi:
			errors.append("%s: y values must be %d–%d" % [where, lo, hi])
			return []
		out.append(Vector2(float(p[0]), float(p[1])))
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return out


func _color(v: Variant) -> Color:
	if typeof(v) != TYPE_ARRAY or v.size() != 3:
		return Color(0, 0, 0, -1)
	for c in v:
		if not (typeof(c) in [TYPE_INT, TYPE_FLOAT]) or float(c) < 0.0 or float(c) > 1.0:
			return Color(0, 0, 0, -1)
	return Color(float(v[0]), float(v[1]), float(v[2]))


# --- Registration ---------------------------------------------------------------

func _rebuild() -> void:
	for t in _translations:
		TranslationServer.remove_translation(t)
	_translations.clear()
	_rooms.clear()
	_items.clear()
	_item_order.clear()
	_anchor_rooms.clear()
	_books.clear()
	_placements.clear()
	_away.clear()
	var by_locale := {}
	for m in mods:
		if not m["enabled"]:
			continue
		for key in m["texts"]:
			var by_lang: Dictionary = m["texts"][key]
			for lang in ["en", "pl"]:
				var text: String = by_lang.get(lang, by_lang.get("en", by_lang.get("pl", "")))
				if not by_locale.has(lang):
					var t := Translation.new()
					t.locale = lang
					by_locale[lang] = t
				by_locale[lang].add_message(key, text)
		for item_id in m["items"]:
			_items[item_id] = m["items"][item_id]
			_item_order.append(item_id)
		for book_id in m["books"]:
			_books[book_id] = m["books"][book_id]
		_placements.append_array(m["placements"])
		_away.append_array(m["away"])
		for room_id in m["rooms"]:
			var r: Dictionary = m["rooms"][room_id]
			_rooms[room_id] = r
			# One side passage per base room: the first mod (by folder name) wins.
			if not _anchor_rooms.has(r["anchor"]):
				_anchor_rooms[r["anchor"]] = room_id
			else:
				(m["warnings"] as PackedStringArray).append("%s: another mod already uses the side passage in %s" % [r["local"], r["anchor"]])
	for lang in by_locale:
		TranslationServer.add_translation(by_locale[lang])
		_translations.append(by_locale[lang])
