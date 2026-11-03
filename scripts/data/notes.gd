extends RefCounted
## The faded pages found in the Scribe's Alcove: someone who waited here
## before. One more page becomes readable each real day after finding them.

const PAGES := [
	"NOTE_1", "NOTE_2", "NOTE_3", "NOTE_4", "NOTE_5", "NOTE_6",
	"NOTE_7", "NOTE_8", "NOTE_9", "NOTE_10", "NOTE_11", "NOTE_12",
]
const FLAG_FOUND_DAY := "pages_found_day"


## How many pages can be read today (0 until the pages are found).
static func readable() -> int:
	var found: Variant = WorldManager.get_flag(FLAG_FOUND_DAY)
	if found == null or not WorldManager.is_collected("pages"):
		return 0
	return clampi(TimeManager.day_index() - int(found) + 1, 1, PAGES.size())
