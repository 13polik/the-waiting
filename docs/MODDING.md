# Modding THE WAITING (format 1)

Mods are **data only**: one `mod.json` per mod, no scripts, no code. That
keeps the game safe and keeps it within App Store rules (guideline 2.5.2).
A mod can add up to 5 small rooms, 10 items, and 30 objects. Each room hangs
off a side passage in one of the existing areas.

## Where mods go

| Platform | Folder |
|---|---|
| iPhone / iPad | Files app → *On My iPhone* → *The Waiting* → `mods/` |
| Windows | `%APPDATA%\TheWaiting\mods\` (the Mods screen shows the path and has *Open folder*) |

Each mod is a folder whose name is the mod id, containing `mod.json`:
`mods/glimmer_grotto/mod.json`. On first launch the game installs the example
mod **Lśniąca Grota / The Glimmer Grotto**, switched off.

Switch mods on and off in **Menu → Mods**. Changes apply the next time you
enter the game. A mod never changes your save: items from a mod that is
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
  "items": { "<item_id>": { "art": "stone", "title": {…}, "description": {…}, "found": [{…}, {…}] } },
  "rooms": { "<room_id>": { … } }
}
```

* **Ids** (`id`, item ids, room ids) use 1–32 characters from `a–z`, `0–9`
  and `_`. The `id` must match the folder name.
* **Texts** are either a plain string or `{"en": "…", "pl": "…"}`. A missing
  language falls back to the other one.
* **Item art:** `stone`, `wing`, `fragment`, `bloom`, `pages`.

### Rooms

| Key | Meaning |
|---|---|
| `title` | Place name (required) |
| `anchor` | `narrow`, `hall` or `garden`: the area whose side passage leads here. If two mods use the same anchor, the first one (alphabetically) wins. |
| `width` | 1200–4000 px |
| `floor`, `ceiling` | 2–40 `[x, y]` points; floor y 650–900, ceiling y 100–640 |
| `palette` | `light`, `stone`, `wash`: `[r, g, b]` from 0 to 1 |
| `objects` | List of `{kind, x, title?, text?, again?}`. Kinds: `fossil`, `marks`, `trickle`, `pillar`, `moss`, `veins`, `pool`, `shaft`. With a `title` the object can be examined: `text` is the first reading, `again` is shown on later visits. |
| `items` | List of `{item, x}`: where the mod's own items lie |

The room's west end leads back to its anchor area. See
`mods_examples/glimmer_grotto/mod.json` for a complete example.

## When something is wrong

A broken mod is listed in red in the Mods screen with the reason (for example
"rooms.r.anchor must be one of narrow, hall, garden"), and it cannot be
switched on. The rest of the game keeps working. Files over 512 KB are refused.
