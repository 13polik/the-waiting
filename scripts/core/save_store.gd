extends RefCounted
## Crash-safe, checksummed JSON files.
##
## A file holds {"format", "sha256", "payload"} where payload is the JSON text
## of the save, so the checksum covers exactly what will be parsed.
## Writes go to "<path>.tmp", are verified by reading back, and only then
## replace "<path>" — the previous file is kept as "<path>.bak".

const FORMAT := 1


static func write(path: String, payload: Dictionary) -> Error:
	var body := JSON.stringify(payload)
	var envelope := {"format": FORMAT, "sha256": body.sha256_text(), "payload": body}
	var tmp_path := path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(envelope))
	f.flush()
	f.close()

	var check := read(tmp_path)
	if not check["ok"]:
		return ERR_FILE_CORRUPT

	var bak_path := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(_abs(bak_path))
		var err := DirAccess.rename_absolute(_abs(path), _abs(bak_path))
		if err != OK:
			return err
	return DirAccess.rename_absolute(_abs(tmp_path), _abs(path))


## Returns {"ok": bool, "payload": Dictionary, "error": String}.
static func read(path: String) -> Dictionary:
	var result := {"ok": false, "payload": {}, "error": ""}
	if not FileAccess.file_exists(path):
		result["error"] = "missing"
		return result
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		result["error"] = "empty file"
		return result
	var envelope: Variant = _parse(text)
	if typeof(envelope) != TYPE_DICTIONARY:
		result["error"] = "not valid JSON"
		return result
	var body: Variant = envelope.get("payload")
	if typeof(body) != TYPE_STRING:
		result["error"] = "no payload"
		return result
	if str(envelope.get("sha256", "")) != String(body).sha256_text():
		result["error"] = "checksum mismatch"
		return result
	var payload: Variant = _parse(body)
	if typeof(payload) != TYPE_DICTIONARY:
		result["error"] = "payload is not an object"
		return result
	result["ok"] = true
	result["payload"] = payload
	return result


## Tries "<path>", "<path>.tmp" then "<path>.bak".
## Returns {"ok", "payload", "source", "errors": PackedStringArray, "any_exists"}.
static func load_best(path: String) -> Dictionary:
	var errors: PackedStringArray = []
	var any_exists := false
	for candidate in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			any_exists = true
		var r := read(candidate)
		if r["ok"]:
			return {"ok": true, "payload": r["payload"], "source": candidate, "errors": errors, "any_exists": true}
		if r["error"] != "missing":
			errors.append("%s: %s" % [candidate.get_file(), r["error"]])
	return {"ok": false, "payload": {}, "source": "", "errors": errors, "any_exists": any_exists}


## Moves a damaged file aside so it can be inspected instead of overwritten.
static func quarantine(path: String) -> void:
	if FileAccess.file_exists(path):
		var stamp := int(Time.get_unix_time_from_system())
		DirAccess.rename_absolute(_abs(path), _abs("%s.corrupt-%d" % [path, stamp]))


static func remove_all(path: String) -> void:
	for p in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(_abs(p))


## Parses without printing engine errors: corrupt files are expected here.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)
