extends SceneTree
## Headless unit tests for time, saving, migration and localisation.
## Run: godot --headless --path . --script res://tests/run_unit_tests.gd -- --profile=unittest

const TimeClock := preload("res://scripts/core/time_clock.gd")
const SaveStore := preload("res://scripts/core/save_store.gd")
const SaveMigrations := preload("res://scripts/core/save_migrations.gd")
const Loc := preload("res://scripts/core/loc.gd")
const Texts := preload("res://scripts/data/home_texts.gd")
const WorldTexts := preload("res://scripts/data/world_texts.gd")
const Items := preload("res://scripts/data/items.gd")
const Rooms := preload("res://scripts/world/rooms.gd")
const T0 := 1_800_000_000.0
const DAY := 86400.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_test_clock_basics()
	_test_clock_offline()
	_test_clock_rollback()
	_test_clock_running_is_immune_to_clock_changes()
	_test_clock_suspension()
	_test_clock_serialisation()
	_test_debug_offset_is_separate()
	_test_migration()
	_test_translations_complete()
	_test_format()
	_test_save_roundtrip()
	_test_save_corruption()
	_test_save_backup_fallback()
	print("\n%d checks, %d failures" % [_checks, _failures])
	print("UNIT TESTS PASS" if _failures == 0 else "UNIT TESTS FAIL")
	quit(0 if _failures == 0 else 1)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("  FAIL: ", what)


func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func _test_clock_basics() -> void:
	print("clock basics")
	var c := TimeClock.new()
	c.start_new(T0)
	check(c.day_index() == 0, "day 0 at start")
	check(near(c.seconds_remaining(), 400 * DAY), "400 days remain")
	var t := T0
	for i in 600:  # ten minutes of 1 s frames
		t += 1.0
		c.advance(1.0, t)
	check(near(c.elapsed, 600.0), "running time accumulates (%.3f)" % c.elapsed)
	c.add_debug_seconds(DAY)
	check(c.day_index() == 1, "debug skip moves to day 1")
	c.add_debug_seconds(500 * DAY)
	check(c.is_complete() and c.seconds_remaining() == 0.0, "completes and clamps")
	check(c.day_index() == 399, "day index caps at last day")


func _test_clock_offline() -> void:
	print("clock offline catch-up")
	var c := TimeClock.new()
	c.start_new(T0)
	var credited := c.catch_up(T0 + 3 * 3600.0)
	check(near(credited, 3 * 3600.0), "three hours credited")
	check(near(c.elapsed, 3 * 3600.0), "elapsed matches")
	check(near(c.anchor, T0 + 3 * 3600.0), "anchor moved to now")


func _test_clock_rollback() -> void:
	print("clock rollback")
	var c := TimeClock.new()
	c.start_new(T0)
	c.catch_up(T0 + 1000.0)
	# Device clock set back a whole day, game relaunched.
	var credited := c.catch_up(T0 + 1000.0 - DAY)
	check(credited == 0.0, "no time credited when clock is behind")
	check(near(c.elapsed, 1000.0), "progress not rewound")
	check(c.rollback_events == 1, "rollback recorded")
	check(near(c.anchor, T0 + 1000.0), "anchor never moves back")
	# Clock corrected later: only the real gap since the anchor counts.
	credited = c.catch_up(T0 + 1100.0)
	check(near(credited, 100.0), "after correction, real gap credited (%.1f)" % credited)
	# Repeated launches while still behind do not inflate the counter.
	var c2 := TimeClock.new()
	c2.start_new(T0)
	c2.catch_up(T0 - 50.0)
	c2.catch_up(T0 - 40.0)
	check(c2.rollback_events == 1, "one event per rollback episode")
	# Jitter smaller than tolerance is not a rollback.
	var c3 := TimeClock.new()
	c3.start_new(T0)
	c3.catch_up(T0 - 1.0)
	check(c3.rollback_events == 0, "small jitter ignored")


func _test_clock_running_is_immune_to_clock_changes() -> void:
	print("clock mid-session changes")
	var c := TimeClock.new()
	c.start_new(T0)
	var wall := T0
	for i in 60:
		wall += 1.0
		c.advance(1.0, wall)
	# Player sets the clock back an hour while playing; play continues 60 s.
	wall -= 3600.0
	for i in 60:
		wall += 1.0
		c.advance(1.0, wall)
	check(near(c.elapsed, 120.0), "running time still counted after rollback (%.1f)" % c.elapsed)
	check(c.rollback_events == 1, "mid-session rollback recorded")


func _test_clock_suspension() -> void:
	print("clock suspension without notification")
	var c := TimeClock.new()
	c.start_new(T0)
	# Monotonic timer reports a tiny step, but the wall clock jumped 30 min
	# (device slept and the tick counter paused).
	c.advance(0.016, T0 + 1800.0)
	check(near(c.elapsed, 1800.0, 0.05), "suspension credited from wall clock (%.2f)" % c.elapsed)
	# Huge monotonic hitch with a matching wall gap is not double counted.
	var c2 := TimeClock.new()
	c2.start_new(T0)
	c2.advance(600.0, T0 + 600.0)
	check(near(c2.elapsed, 600.0), "long hitch counted once (%.1f)" % c2.elapsed)


func _test_clock_serialisation() -> void:
	print("clock serialisation")
	var c := TimeClock.new()
	c.start_new(T0)
	c.catch_up(T0 + 12345.5)
	var d := JSON.parse_string(JSON.stringify(c.to_dict())) as Dictionary
	var r := TimeClock.new()
	check(r.from_dict(d), "round-trips through JSON")
	check(near(r.elapsed, c.elapsed) and near(r.anchor, c.anchor), "values preserved")
	check(not TimeClock.new().from_dict({}), "rejects empty")
	check(not TimeClock.new().from_dict({"total_days": 400, "start_unix": T0, "anchor": T0, "elapsed": -5}), "rejects negative elapsed")
	check(not TimeClock.new().from_dict({"total_days": "x", "start_unix": T0, "anchor": T0, "elapsed": 1}), "rejects wrong types")


func _test_debug_offset_is_separate() -> void:
	print("developer offset")
	var c := TimeClock.new()
	c.start_new(T0)
	c.catch_up(T0 + 100.0)
	c.add_debug_seconds(7 * DAY)
	check(near(c.elapsed, 100.0), "real elapsed untouched by skip")
	check(near(c.anchor, T0 + 100.0), "anchor untouched by skip")
	check(c.day_index() == 7, "simulated day moves (%d)" % c.day_index())
	var r := TimeClock.new()
	r.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	check(near(r.debug_offset, 7 * DAY) and near(r.elapsed, 100.0), "offset saved separately")
	c.clear_debug_offset()
	check(c.day_index() == 0 and near(c.elapsed, 100.0), "clearing restores real day")
	var legacy := {"total_days": 400, "start_unix": T0, "anchor": T0, "elapsed": 5.0}
	var l := TimeClock.new()
	check(l.from_dict(legacy) and l.debug_offset == 0.0, "v1 time data loads with no offset")


func _test_migration() -> void:
	print("save migration")
	var r := SaveStore.read("res://tests/fixtures/save_v1.json")
	check(r["ok"], "real v0.1 save fixture reads (%s)" % r["error"])
	if not r["ok"]:
		return
	var original: Dictionary = r["payload"]
	var before := JSON.stringify(original)
	var m := SaveMigrations.migrate(original)
	check(m["ok"] and m["from"] == 1, "v1 migrates")
	var p: Dictionary = m["payload"]
	check(int(p["version"]) == SaveMigrations.CURRENT, "now current version")
	check(near(float(p["player"]["x"]), float(original["player"]["x"])), "position preserved")
	check(int(p["world"]["examined"]["nest"]) == 2, "examine counts preserved")
	check(near(float(p["time"]["elapsed"]), float(original["time"]["elapsed"])), "elapsed preserved")
	check(float(p["time"]["debug_offset"]) == 0.0, "offset added as zero")
	check(int(p["meta"]["migrated_from"]) == 1, "migration recorded")
	check(JSON.stringify(original) == before, "input payload not mutated")
	var c := TimeClock.new()
	check(c.from_dict(p["time"]), "migrated time loads into the clock")
	var again := SaveMigrations.migrate(p)
	check(again["ok"] and JSON.stringify(again["payload"]) == JSON.stringify(p), "current version passes through unchanged")
	check(int(p["world"]["discovered"].size()) == 1 and p["world"]["discovered"].has("home"), "v1 save: home counted as discovered")
	check(p["world"]["inventory"] == [] and p["world"]["collected"] == {}, "v1 save: empty satchel added")
	var v2 := {"version": 2, "saved_at_unix": T0, "player": {"x": 900.0}, "world": {"flags": {"a": true}, "examined": {}}, "time": {}}
	var m3 := SaveMigrations.migrate(v2)
	check(m3["ok"] and int(m3["payload"]["version"]) == 3, "v2 migrates to v3")
	check(m3["payload"]["world"]["flags"]["a"] == true, "v2 flags kept")
	check(m3["payload"]["player"]["room"] == "home", "v2 player placed at home")
	check(not SaveMigrations.migrate({"version": SaveMigrations.CURRENT + 1})["ok"], "newer version refused")
	check(not SaveMigrations.migrate({})["ok"], "missing version refused")


func _test_translations_complete() -> void:
	print("translations")
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	check(f != null, "strings.csv readable")
	if f == null:
		return
	var header := f.get_csv_line()
	check(header.size() == 3 and header[1] == "en" and header[2] == "pl", "columns keys,en,pl")
	var keys := {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		keys[row[0]] = true
		check(not row[1].is_empty() and not row[2].is_empty(), "%s translated in both" % row[0])
	for table in [Texts.OBJECTS, WorldTexts.OBJECTS]:
		for id in table:
			var o: Dictionary = table[id]
			for k in [o["title"]] + o["first"] + o["repeat"]:
				check(keys.has(k), "object key %s exists" % k)
	for id in Items.ORDER:
		var it: Dictionary = Items.ITEMS[id]
		for k in [it["title"], it["desc"]] + it["found"]:
			check(keys.has(k), "item key %s exists" % k)
	for id in Rooms.ORDER:
		check(keys.has(Rooms.TITLES[id]), "room title %s exists" % id)
		check(Rooms.exists(id), "room %s is buildable" % id)
	for k in ["SATCHEL_TITLE", "SATCHEL_EMPTY", "SATCHEL_PLACES", "TOAST_FOUND", "PLACE_NEW", "PAUSE_SATCHEL", "OBJ_CAIRN_PLACE_1", "OBJ_CAIRN_EIGHT_R1"]:
		check(keys.has(k), "ui key %s exists" % k)
	for base in ["UNIT_DAYS", "UNIT_HOURS", "UNIT_MINUTES", "OBJ_TALLY_COUNT", "OBJ_TALLY_R1"]:
		for form in ["_ONE", "_FEW", "_MANY"]:
			check(keys.has(base + form), "plural %s%s exists" % [base, form])
	for i in 12:
		check(keys.has("NOTE_%d" % (i + 1)), "page NOTE_%d exists" % (i + 1))
	for k in ["OBJ_PASSAGE_DIG", "OBJ_PASSAGE_COUNT", "OBJ_PASSAGE_TOMORROW", "OBJ_PASSAGE_OPENED", "OBJ_PASSAGE_OPEN_R",
			"OBJ_PLANT_1", "OBJ_PLANT_2", "OBJ_SPROUT_STAGE0", "OBJ_SPROUT_STAGE1", "OBJ_SPROUT_STAGE2", "OBJ_SPROUT_STAGE3",
			"READER_TITLE", "READER_PAGE", "READER_MORE", "READER_ALL", "SATCHEL_READ",
			"MENU_MODS", "MODS_TITLE", "MODS_NONE", "MODS_NOTE", "MODS_FOLDER_DESKTOP", "MODS_FOLDER_IOS",
			"MODS_OPEN_FOLDER", "MODS_RELOAD", "MODS_ENABLED", "MODS_DISABLED", "MODS_BROKEN", "MODS_BY"]:
		check(keys.has(k), "0.4 key %s exists" % k)
	var ex: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://mods_examples/glimmer_grotto/mod.json"))
	check(typeof(ex) == TYPE_DICTIONARY and ex.get("id") == "glimmer_grotto", "the example mod is valid JSON")
	check(TranslationServer.translate("OBJ_NEST_TITLE") == "The Nest", "The Nest is not translated")


func _test_format() -> void:
	print("formatting (pl / en)")
	_ensure_translations()
	TranslationServer.set_locale("pl")
	check(Loc.count("UNIT_DAYS", 1) == "1 dzień", "pl 1 dzień")
	check(Loc.count("UNIT_DAYS", 2) == "2 dni" and Loc.count("UNIT_DAYS", 5) == "5 dni", "pl dni")
	check(Loc.count("UNIT_MINUTES", 3) == "3 minuty", "pl 3 minuty")
	check(Loc.count("UNIT_MINUTES", 12) == "12 minut", "pl 12 minut (teen)")
	check(Loc.count("UNIT_MINUTES", 22) == "22 minuty", "pl 22 minuty")
	check(Loc.count("UNIT_MINUTES", 25) == "25 minut", "pl 25 minut")
	check(Loc.remaining(400 * DAY) == "400 dni  ·  00:00:00", "pl countdown (%s)" % Loc.remaining(400 * DAY))
	check(Loc.duration(3 * 3600 + 12 * 60) == "3 godziny i 12 minut", "pl duration (%s)" % Loc.duration(3 * 3600 + 12 * 60))
	check(Loc.resolve(["#OBJ_TALLY_R1", 4]).begins_with("4 rysy"), "pl plural entry")
	TranslationServer.set_locale("en")
	check(Loc.remaining(DAY + 3661) == "1 day  ·  01:01:01", "en countdown")
	check(Loc.duration(3 * 3600 + 12 * 60) == "3 hours and 12 minutes", "en duration")
	check(Loc.duration(2 * DAY + 3600) == "2 days and 1 hour", "en duration days")
	check(Loc.duration(20) == "a moment", "en moment")
	check(Loc.resolve(["OBJ_TALLY_R2", 9]).begins_with("9. You"), "en format entry")


func _ensure_translations() -> void:
	if TranslationServer.translate("MENU_CONTINUE") != "MENU_CONTINUE":
		return
	for code in ["en", "pl"]:
		var t: Translation = load("res://localization/strings.%s.translation" % code)
		if t != null:
			TranslationServer.add_translation(t)


func _test_save_roundtrip() -> void:
	print("save round-trip")
	var path := "user://unittest_roundtrip.json"
	SaveStore.remove_all(path)
	var payload := {"version": 1, "player": {"x": 1234.5, "facing": -1}, "world": {"examined": {"nest": 2}}}
	check(SaveStore.write(path, payload) == OK, "write ok")
	var r := SaveStore.read(path)
	check(r["ok"], "read ok")
	check(near(float(r["payload"]["player"]["x"]), 1234.5), "value preserved")
	check(not FileAccess.file_exists(path + ".tmp"), "temp file cleaned up")
	SaveStore.write(path, payload)
	check(FileAccess.file_exists(path + ".bak"), "backup kept on second write")
	SaveStore.remove_all(path)


func _test_save_corruption() -> void:
	print("save corruption")
	var path := "user://unittest_corrupt.json"
	SaveStore.remove_all(path)
	_write_raw(path, "{\"format\":1,\"sha256\":\"ab")  # truncated
	check(not SaveStore.read(path)["ok"], "truncated file rejected")
	_write_raw(path, "")
	check(not SaveStore.read(path)["ok"], "empty file rejected")
	SaveStore.write(path, {"version": 1, "x": 1})
	var text := FileAccess.get_file_as_string(path).replace("\\\"x\\\":1", "\\\"x\\\":9")
	_write_raw(path, text)
	var r := SaveStore.read(path)
	check(not r["ok"] and r["error"] == "checksum mismatch", "tampered payload rejected (%s)" % r["error"])
	var best := SaveStore.load_best("user://unittest_nothing_here.json")
	check(not best["ok"] and not best["any_exists"], "missing save reported as new game")
	SaveStore.remove_all(path)


func _test_save_backup_fallback() -> void:
	print("save backup fallback")
	var path := "user://unittest_fallback.json"
	SaveStore.remove_all(path)
	SaveStore.write(path, {"version": 1, "gen": 1})
	SaveStore.write(path, {"version": 1, "gen": 2})
	_write_raw(path, "garbage")
	var best := SaveStore.load_best(path)
	check(best["ok"] and int(best["payload"]["gen"]) == 1, "falls back to backup")
	check(best["source"].ends_with(".bak"), "source is backup")
	check(best["errors"].size() == 1, "corruption of main file reported")
	SaveStore.remove_all(path)


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
