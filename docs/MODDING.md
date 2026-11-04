# Modding THE WAITING (format 1)

Mods are **data only**: one `mod.json` per mod, no scripts, no code. That
keeps the game safe and keeps it within App Store rules (guideline 2.5.2).

A mod can add any mix of these:

| Section | What it adds | Limit |
|---|---|---|
| `rooms` | Small places behind a side passage in an existing area | 5 |
| `items` | Things to find (in the mod's rooms) | 10 |
| `books` | Books of any length, read a set number of pages a day, lying in any area | 3 |
| `away` | Things the creature is found doing when you come back after a while | 20 |

A mod does not have to add a place. `quiet_hours` adds only `away` activities,
and `long_almanac` adds only a book (and two activities).

## Where mods go

| Platform | Folder |
|---|---|
| iPhone / iPad | Files app → *On My iPhone* → *The Waiting* → `mods/` |
| Windows | `%APPDATA%\TheWaiting\mods\` (the Mods screen shows the path and has *Open folder*) |

Each mod is a folder whose name is the mod id, containing `mod.json`:
`mods/glimmer_grotto/mod.json`.

The game comes with seven example mods, all switched off. Each is copied to
the mods folder once; one you delete stays deleted.

| Mod | Kind |
|---|---|
| Lśniąca Grota / The Glimmer Grotto | room (Narrow Way) |
| Grzybowa Kotlina / The Mushroom Hollow | room (Hall of Echoes) |
| Zatopione Jezioro / The Sunken Lake | room (Still Garden) |
| Stare Archiwum / The Old Archive | room (Scribe's Alcove) |
| Cicha Kapliczka / The Quiet Shrine | room (Beyond the Door, after the ending) |
| Długi Almanach / The Long Almanac | book: 850 pages, 50 a day |
| Ciche Godziny / Quiet Hours | away activities only |

Switch mods on and off in **Menu → Mods**. Changes apply the next time you
enter the game. A mod never changes your save: things from a mod that is
switched off stay in the save, hidden, and come back when you switch it on.

## mod.json

```json
{
  "format": 1,
  "id": "my_mod",
  "name": { "en": "My Mod", "pl": "Mój mod" },
  "description": { "en": "…", "pl": "…" },
  "author": "you",
  "version": "1.0",
  "items": { … },
  "rooms": { … },
  "books": { … },
  "away": [ … ]
}
```

* **Ids** (`id`, item, room and book ids) use 1–32 characters from `a–z`,
  `0–9` and `_`. The `id` must match the folder name.
* **Texts** are either a plain string or `{"en": "…", "pl": "…"}`, at most
  600 characters. A missing language falls back to the other one.
* **Item art:** `stone`, `wing`, `fragment`, `bloom`, `pages`, `book_door`,
  `book_herbs`, `book_tales`.

### Rooms

| Key | Meaning |
|---|---|
| `title` | Place name (required) |
| `anchor` | `narrow`, `hall`, `garden`, `alcove` or `beyond`: the area whose side passage leads here. If two mods use the same anchor, the first one (alphabetically) wins. |
| `width` | 1200–4000 px |
| `floor`, `ceiling` | 2–40 `[x, y]` points; floor y 650–900, ceiling y 100–640 |
| `palette` | `light`, `stone`, `wash`: `[r, g, b]` from 0 to 1 |
| `objects` | List of `{kind, x, title?, text?, again?}`. Kinds: `fossil`, `marks`, `trickle`, `pillar`, `moss`, `veins`, `pool`, `shaft`. With a `title` the object can be examined: `text` is the first reading, `again` is shown on later visits. |
| `items` | List of `{item, x}`: where the mod's own items lie |

The room's west end leads back to its anchor area.

### Books

```json
"books": {
  "almanac": {
    "title": { "en": "The Long Almanac", "pl": "Długi Almanach" },
    "description": { … },
    "found": [ { … }, { … } ],
    "art": "book_tales",
    "pages": 850,
    "per_day": 50,
    "room": "hall",
    "x": 420,
    "passages": [ { … }, … ]
  }
}
```

| Key | Meaning |
|---|---|
| `pages` | 10–5000 |
| `per_day` | Pages read at one sitting; one sitting per real day |
| `passages` | Exactly one text per sitting: `ceil(pages / per_day)` of them (at most 100). 850 pages at 50 a day = 17 passages. |
| `room`, `x` | Where the book lies: `home`, `narrow`, `hall`, `garden`, `alcove`, `beyond`, or one of the mod's own rooms (`mod:<mod>:<room>`) |
| `art` | `book_door` (red), `book_herbs` (green) or `book_tales` (blue) |

A book is read from the satchel (*Read*), exactly like the game's own books.

### Away activities

When the game is opened after at least half an hour, the creature may be found
doing something. A short line says what, under "While you were away". It is
only something that happened: it never reads pages or moves anything along.

```json
"away": [
  { "text": { "en": "Humming to the hanging stones.", "pl": "Nucenie wiszącym kamieniom." }, "room": "home", "x": 900 },
  { "text": { "en": "A dream about the world above." } },
  { "text": { … }, "needs_item": "almanac" }
]
```

| Key | Meaning |
|---|---|
| `text` | What it was doing (required). In Polish, prefer phrasing without gendered verb forms. |
| `room` | Only when coming back in this area (`home`, `narrow`, `hall`, `garden`, `alcove`, `beyond`); leave it out for anywhere |
| `x` | Where the creature is found (with `room`) |
| `needs_item` | Only once this item is carried: one of the mod's own ids, or a game item id |

## When something is wrong

A broken mod is listed in red in the Mods screen with the reason (for example
"books.almanac.passages must list exactly 17 texts…"), and it cannot be
switched on. The rest of the game keeps working. Files over 512 KB are refused.
