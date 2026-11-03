extends RefCounted
## Localisation helpers on top of TranslationServer.
##
## All visible text lives in localization/strings.csv (keys, en, pl).
## Text that must be re-translated when the language changes is passed around
## as an *entry*: either a key ("OBJ_NEST_1") or an Array [key, arg, ...]
## whose translation is a format string ("%d marks."), or ["#BASE", n] for a
## plural (BASE_ONE / _FEW / _MANY chosen for n). [method resolve] turns an
## entry into display text in the current language.

const LANGUAGES := ["pl", "en"]


## Polish has three plural forms (1 dzień · 2 dni · 5 dni, 1 minutę ·
## 2 minuty · 5 minut); English two. Keys end in _ONE, _FEW or _MANY.
static func plural_key(base: String, n: int) -> String:
	if language() == "pl":
		if n == 1:
			return base + "_ONE"
		var m10 := n % 10
		var m100 := n % 100
		if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
			return base + "_FEW"
		return base + "_MANY"
	return base + ("_ONE" if n == 1 else "_MANY")


static func language() -> String:
	return TranslationServer.get_locale().substr(0, 2)


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func count(base: String, n: int) -> String:
	return t(plural_key(base, n)) % n


## Display text for an entry (see class description).
static func resolve(entry: Variant) -> String:
	if typeof(entry) == TYPE_ARRAY:
		var a: Array = entry
		if a.is_empty():
			return ""
		var key := str(a[0])
		if key.begins_with("#") and a.size() >= 2:
			return count(key.substr(1), int(a[1]))
		var fmt := t(key)
		if a.size() == 1:
			return fmt
		return fmt % a.slice(1)
	return t(str(entry))


## "399 dni  ·  23:59:12" — the countdown.
static func remaining(seconds: float) -> String:
	var s := int(ceil(maxf(0.0, seconds)))
	var days := s / 86400
	var rest := s % 86400
	return "%s  ·  %02d:%02d:%02d" % [count("UNIT_DAYS", days), rest / 3600, (rest % 3600) / 60, rest % 60]


## "3 godziny i 12 minut" — phrasing for absences.
static func duration(seconds: float) -> String:
	var s := int(seconds)
	var days := s / 86400
	var hours := (s % 86400) / 3600
	var minutes := (s % 3600) / 60
	var parts: PackedStringArray = []
	if days > 0:
		parts.append(count("UNIT_DAYS", days))
	if hours > 0:
		parts.append(count("UNIT_HOURS", hours))
	if minutes > 0 and days == 0:
		parts.append(count("UNIT_MINUTES", minutes))
	if parts.is_empty():
		return t("TIME_MOMENT")
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + t("LIST_AND") + parts[parts.size() - 1]


## "12 d  04:05:06" — a compact, language-neutral span for developer readouts.
static func span(seconds: float) -> String:
	var s := int(maxf(0.0, seconds))
	return "%d d  %02d:%02d:%02d" % [s / 86400, (s % 86400) / 3600, (s % 3600) / 60, s % 60]
