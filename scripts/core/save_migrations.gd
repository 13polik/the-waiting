extends RefCounted
## Step-by-step upgrades of save payloads, oldest first. Pure data, no file
## access, so every step is unit-tested.
##
## History
##   v1 (0.1)  time, world, player
##   v2 (0.2)  time.debug_offset kept apart from real time; "meta" section
##   v3 (0.3)  world.inventory, world.collected, world.discovered (areas).
##             Bumped (not just added) so that 0.2 refuses a 0.3 save rather
##             than load it and drop the satchel on its next write.
##
## To add v4: write _v3_to_v4, add it to [method migrate], bump CURRENT.

const CURRENT := 3


## Returns {"ok": bool, "payload": Dictionary, "from": int, "error": String}.
## Never modifies [param payload] itself.
static func migrate(payload: Dictionary) -> Dictionary:
	var from := int(payload.get("version", 0))
	if from < 1:
		return {"ok": false, "payload": {}, "from": from, "error": "missing version"}
	if from > CURRENT:
		return {"ok": false, "payload": {}, "from": from, "error": "newer than this game (v%d)" % from}
	var p: Dictionary = payload.duplicate(true)
	if int(p["version"]) == 1:
		p = _v1_to_v2(p)
	if int(p["version"]) == 2:
		p = _v2_to_v3(p)
	return {"ok": true, "payload": p, "from": from, "error": ""}


static func _v1_to_v2(p: Dictionary) -> Dictionary:
	var time: Variant = p.get("time")
	if typeof(time) == TYPE_DICTIONARY and not time.has("debug_offset"):
		# v1 mixed developer skips into "elapsed"; they cannot be told apart
		# now, so all of it is treated as real time.
		time["debug_offset"] = 0.0
	p["meta"] = {
		"created_unix": p.get("created_unix", p.get("saved_at_unix", 0.0)),
		"migrated_from": 1,
	}
	p["version"] = 2
	return p


static func _v2_to_v3(p: Dictionary) -> Dictionary:
	var world: Dictionary = p.get("world", {}) if typeof(p.get("world")) == TYPE_DICTIONARY else {}
	if not world.has("inventory"):
		world["inventory"] = []
	if not world.has("collected"):
		world["collected"] = {}
	if not world.has("discovered"):
		# Anyone with a save has stood in the home cave.
		world["discovered"] = {"home": float(p.get("saved_at_unix", p.get("created_unix", 0.0)))}
	p["world"] = world
	var player: Variant = p.get("player")
	if typeof(player) == TYPE_DICTIONARY and not player.has("room"):
		player["room"] = "home"
	if typeof(p.get("meta")) == TYPE_DICTIONARY and not p["meta"].has("migrated_from"):
		p["meta"]["migrated_from"] = 2
	p["version"] = 3
	return p
