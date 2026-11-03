# THE WAITING

A slow, atmospheric exploration game about a small hooded creature — the
Wick — waiting four hundred real days beneath the world, beside the place it
calls The Nest. Godot 4.7, GDScript, iOS-first, landscape, touch-first.
Version 0.4: things that move on only with real days — an old passage dug
out one stone a day (seven days) into the Scribe's Alcove, twelve faded pages
that become readable one per day, and a bloom planted in the garden that grows
over ten days — and data-only mods with a Mods screen in the menu
([docs/MODDING.md](docs/MODDING.md)). On top of 0.3's five areas, items and
satchel, and 0.2's menu, Polish/English, settings and pause.

See [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) for the design,
architecture, time/save design, roadmap, asset replacement plan and iOS
export checklist.

## Run

Open the folder in Godot 4.7 and press Play, or:

```
godot --path .
```

The game opens on the main menu (Continue · New Game · Settings · Credits ·
Exit Game). Exit is shown on desktop only — iOS apps must not quit themselves.

| Action | Touch / mouse | Keyboard |
|---|---|---|
| Walk to a spot | tap | A / D, ← / → |
| Walk while held | touch and hold, or drag | hold A / D |
| Examine | tap the thing | E / Space / Enter near it |
| Continue text | tap anywhere | E / Space / Enter |
| Pause | the ‖ mark, top left | Esc / P |
| Satchel (items, places found) | the satchel mark, top left | I / Tab |
| Go to another area | walk into a tunnel, or tap it | walk into it |

Developer tools (debug builds only — absent from release exports): Pause →
Developer tools, or F3. Skips of +1 hour / 1 / 7 / 30 / 100 days are stored as
a separate offset and never change the real-time clock. F5 +1 day, F6 +1 hour,
F8 save.

## Languages

Polish is the default; English is the alternative (Settings → Language,
applies immediately). All text lives in
[localization/strings.csv](localization/strings.csv) (`keys,en,pl`), imported
by Godot as translations. Plurals use `_ONE / _FEW / _MANY` keys
(see `scripts/core/loc.gd`). "THE WAITING" and "The Nest" are never translated.

## Files on disk

`user://` is `%APPDATA%\TheWaiting` on Windows and the app's Documents folder
on iOS.

| File | What |
|---|---|
| `save.json` (+ `.bak`, `.tmp`) | the game (version 2, checksummed) |
| `save.json.v1.bak` | the original file, kept when a 0.1 save was migrated |
| `save.json.archive-<time>` | a previous game, kept when New Game was chosen |
| `settings.cfg` | language, volumes, window, text size |

`-- --profile=<name>` uses separate files (tests do this); `-- --reset-save`
and `-- --reset-settings` start that profile from scratch.

## Test

```
godot --headless --path . --script res://tests/run_unit_tests.gd -- --profile=unittest
godot --headless --path . -- --profile=selftest --reset-save --selftest
godot --headless --path . -- --profile=persist --reset-save --selftest-persist=write
godot --headless --path . -- --profile=persist --selftest-persist=check
godot --headless --path . -- --profile=menutest --reset-save --reset-settings --selftest-menu
godot --headless --path . -- --profile=menutest --selftest-menu=settings-check
```

0.4 content over simulated days: `-- --profile=daystest --reset-save --selftest-days`.
Mods (example install, broken mods, side passage, mod item, switching off):
`-- --profile=modtest --reset-save --selftest-mods`.

World (areas, exits, hidden passage, items, satchel, then a restart check):
`-- --profile=worldtest --reset-save --selftest-world`, then
`-- --profile=worldtest --selftest-world=check`. Frame times in every area:
`-- --profile=fpstest --reset-save --selftest-fps-areas` (windowed).

Migration: copy `tests/fixtures/save_v1.json` (a real 0.1 save) to
`user://migtest.json`, then run `-- --profile=migtest --selftest-menu=migration`.
Performance profile: `-- --profile=fpstest --reset-save --selftest-fps` (windowed;
add `--bake-scale=1.5` to compare). iOS lifecycle (background, suspend,
resume): `-- --profile=lifecycle --reset-save --selftest-lifecycle`.
See [docs/PERFORMANCE.md](docs/PERFORMANCE.md).
Add `"--shots=<folder>"` (windowed) to the self-tests to capture screenshots.
