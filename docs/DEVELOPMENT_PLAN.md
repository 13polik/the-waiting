# THE WAITING — Development Plan

## Vision in one paragraph

A small, hooded creature — **the Wick**, named for the pale lantern-bulb that
grows from its head on a long stalk — lives alone in a cave deep under an
unknown world. Before it stands a carved stone door with four hundred notches.
Something behind the door is breathing very slowly. In 400 real days it will
wake. Until then the Wick explores, examines, remembers, and slowly makes the
dark into a home. The game is about waiting as an activity, not as an idle
timer: the world changes slowly, rewards attention, and never nags.

## Engine & platform decisions

| Decision | Choice | Why |
|---|---|---|
| Engine | Godot 4.7 (GDScript) | Requested; installed locally. |
| Renderer | `gl_compatibility` on desktop **and** mobile | Widest iOS device support, cheapest 2D lighting path for older iPhones. |
| Base resolution | 1280×720, `canvas_items` stretch, `expand` aspect | Landscape; iPhone (19.5:9) shows more width, iPad (4:3) more height. The room is tall/wide enough for both. |
| Orientation | Sensor landscape | Either landscape direction on iOS. |
| Input | Touch first; mouse emulates touch; keyboard for development | One input path to test on desktop. |
| Assets | Procedurally *drawn* at load (inked polygons) and procedurally *synthesised* audio | Original, zero external dependencies, no placeholder sprites. Every system can later swap in hand-painted art/recorded audio without code changes elsewhere. |
| Save | JSON with SHA-256 checksum, atomic write, rolling backup | Offline-first, corruption-tolerant. |

iOS export requires macOS + Xcode. This project keeps an `iOS` preset in
`export_presets.cfg`; the actual build is done on a Mac (see checklist below).

## Architecture

```
scenes/main_menu.tscn            Entry scene: the main menu over the live cave
scenes/main.tscn                 The game session (main.gd)
scripts/main.gd                  Assembles room, creature, camera, input, pause, dev panel
scripts/autoload/                Global systems (registered in project.godot, in this order)
  save_manager.gd   SaveManager  Load/validate/autosave; lifecycle saves (close, iOS background)
  time_manager.gd   TimeManager  Wraps TimeClock; ticks, day changes, offline catch-up
  world_manager.gd  WorldManager World flags, examine counts, player state, interactable registry
  audio_manager.gd  AudioManager Buses, reverb, sound library, ambience + random events
  settings_manager.gd SettingsManager Language, volumes, window, text size (settings.cfg)
  ui_manager.gd     UIManager    Countdown, examine text, title card, hints, toasts, fades,
                                 scene transitions, pause glyph, safe area
scripts/core/                    Pure logic — unit-tested without the scene tree
  time_clock.gd                  400-day clock maths (anchor model, rollback handling)
  save_store.gd                  Checksummed atomic JSON files + best-candidate loading
  save_migrations.gd             Versioned, step-by-step save upgrades (v1 → v2)
  loc.gd                         Localisation helpers: plurals, countdown and duration text
  input_setup.gd                 Input actions registered in code
scripts/character/
  character_controller.gd        CharacterController — CharacterBody2D movement, lantern light
  creature_visual.gd             Procedural body, idle/walk animation, spring stalk, blinking
scripts/camera/camera_controller.gd  CameraController — smoothed follow, look-ahead, bounds
scripts/interaction/
  interactable.gd                Data + prompt glyph for an examinable thing
  interaction_system.gd          InteractionSystem — nearest-target detection, examine
scripts/input/world_input.gd     Tap-to-move, hold-to-walk, tap-object-to-examine
scripts/world/                   The home cave: geometry, painter, layers, props
scripts/audio/synth.gd           Original synthesised sounds (fallbacks for real recordings)
scripts/ui/                      Main menu, settings, credits, confirm, pause, dev panel,
                                 shared style (ui_style.gd) and button (waiting_button.gd)
scripts/world/baker.gd           Bakes static drawing into textures at load (performance)
scripts/world/room_base.gd       A cave chamber built from data: geometry, painting, baking,
                                 collision, exits. Rooms configure it:
scripts/world/cave_room.gd       Home (The Nest, the door, the crevice east)
scripts/world/rooms/             narrow_way.gd, echo_hall.gd, still_garden.gd
scripts/world/rooms.gd           The map: ids, names, how to build each room
scripts/world/exit.gd            Area2D way out; optional flag for hidden passages
scripts/data/items.gd            Collectibles; world_texts.gd: text of the new areas
scripts/ui/inventory_screen.gd   The satchel
scripts/data/home_texts.gd       Examine text as translation keys
localization/strings.csv         Every visible string, English and Polish
scripts/dev/self_test.gd         Gameplay / persistence / frame-rate self-tests
scripts/dev/self_test_menu.gd    Menu, language, settings, pause, dev tools, save-safety test
tests/run_unit_tests.gd          Headless unit tests for time and save logic
```

Systems talk through autoload APIs and signals; no script owns the whole game.

## Time system design

`TimeClock` keeps two numbers: `elapsed` (trusted waiting seconds) and
`anchor` (its best estimate of the real wall-clock time `elapsed` is accurate
up to).

* **While running:** time comes from the monotonic tick counter, so changing
  the device clock mid-session has no effect. The anchor advances with it.
* **While closed / backgrounded:** on launch and on `APPLICATION_RESUMED` the
  clock credits `now - anchor` from the wall clock (UTC Unix time, so time-zone
  changes are irrelevant).
* **Clock set backwards by up to an hour:** the anchor never moves back. No
  time is credited until real time passes the anchor again, and a rollback
  event is recorded.
* **Clock set backwards by more than an hour (0.5): tampering.** This is what
  "set the date forward, play, set it back" leaves behind. The time credited
  ahead of the clock is taken back off `elapsed`, counting restarts from the
  clock as it is, and the creature is jailed (below).
* **Unannounced suspension** (device sleep without a notification): detected
  when the wall clock runs ahead of the anchor by more than 2 s, then credited.
* **Developer skips** (debug builds) go into a separate `debug_offset`. The
  world responds to `elapsed + debug_offset`; the real clock and anchor
  never move.
* **Trusted time (0.5):** when there is a network, `TimeManager` sends a HEAD
  request to `https://www.apple.com/` (fallback `https://www.google.com/`)
  a few seconds after launch, on every resume and every 20 minutes, and reads
  only the `Date` header. Nothing about the player is sent. `TimeClock.apply_network`
  checks that no more waiting was credited since the last check than really
  passed (first check: the anchor is not past the true time). More than an
  hour over is tampering. Offline the game works as before; a clock moved
  forward while closed and offline is caught at the next online check.
  The check only ever *removes* time. Automated tests pass `--selftest*`
  (or `--no-net-time`) and never touch the network; `tests/net_time_probe.gd`
  checks the real source by hand.
* **The dungeon:** when tampering is caught the skipped time is taken back,
  `jail_until = simulated + 86 400` is saved in the time section, and the
  session moves to the Dungeon (`rooms/dungeon.gd`, not one of the places to
  find). The bars are solid and the exit is shut until a day of waiting has
  passed (`TimeManager.jail_released`); a new offence restarts the day. After
  a punished forward jump, putting the device clock right again is forgiven
  (`pardon_back`). Debug builds: Developer tools → "Tamper" simulates it.
* **Known limitation:** a device clock that is genuinely more than an hour
  wrong in the future looks like tampering on the first online check.

1 game day = 86 400 real seconds; the wait is 400 days.

## Save system design

* File: `user://save.json` (iOS: app Documents; Windows: `%APPDATA%/TheWaiting`).
* Envelope `{format, sha256, payload}`; payload is a JSON string so the
  checksum is exact.
* Write: `save.json.tmp` → verify by reading back → `save.json` → `.bak`
  rotation. A crash at any point leaves at least one valid file.
* Load order: `save.json`, `.tmp`, `.bak`. If all fail but files exist, the bad
  file is renamed `save.json.corrupt-<unix>` and a new game starts.
* Saved: schema version, meta, time clock (with `debug_offset` apart from real
  time), world flags + examine counts, player room, position and facing.
* Versioning (0.2): saves carry `version`; `save_migrations.gd` upgrades older
  payloads step by step in memory. Before a migrated save is first
  overwritten, the original file is copied to `save.json.v1.bak`. A save
  from a newer game version is never modified (saving is blocked; Continue
  is disabled with an explanation).
* New Game asks for confirmation when a save exists and archives it as
  `save.json.archive-<unix>` — a previous wait is never destroyed.
* Saves are written only during a game session; the menu never writes.
  Returning to the menu saves first and stays in the game if that fails.
* Autosave every 20 s, after every examination, on window close, on focus loss
  and on iOS backgrounding (`NOTIFICATION_APPLICATION_PAUSED`).
* Restored positions are validated against the room's walkable range; the
  creature is always re-snapped onto the floor.

## Milestones

0. **0.7 (done)** — books (`data/books.gd`, `data/book_progress.gd`,
   `ui/book_screen.gd`): 300 pages, 20 per sitting, one sitting per book per
   day; found in the Narrow Way, the Still Garden and (left by the Lamplighter)
   on the shelf at home. Home makeover (`props/nest.gd`, `props/home_decor.gd`).
   The Lamplighter (`props/lamplighter.gd`, `data/lamplighter_visits.gd`):
   twelve meetings from day 1 to the end, one a day at most, placed by
   `RoomBase._add_visitor`; meeting 4 leaves a book, meeting 5 relights the
   scribe's lantern. Animated intro (`scenes/intro.tscn`) after the static
   launch image (`tools/render_splash.gd`).
0. **0.6 (done)** — the ending: after 400 days `TimeManager.wait_completed`
   opens the door at home; through it, Beyond the Door (`rooms/beyond_door.gd`);
   its daylight shows `EndingScreen` (epilogue, places, items, pages, bloom,
   honesty with time). "Stay" keeps the world open; the menu shows the wait as over.
0. **0.5 (done)** — time tampering detection (clock rollbacks offline,
   trusted network time online); skipped time is taken back and the creature
   spends a day in the Dungeon behind bars.
0. **0.4 (done)** — daily content: the old passage (one stone per real day,
   seven days) opens into the Scribe's Alcove; twelve pages, one more readable
   each day, in a reader in the satchel; the pale bloom planted in the garden
   moss grows over 0–10 days. Data-only mods (`ModManager`, `docs/MODDING.md`)
   with a Mods screen, Files-app access on iOS and a bundled example mod.
0. **0.3 (done)** — rooms built from data (`room_base.gd`); three new areas
   east of home, one behind a hidden passage; exits with fades; four items,
   satchel, using the smooth stone on the cairn; discovered places; save v3.
0. **0.2 (done)** — main menu over the live cave, Polish (default) and
   English, settings, pause menu, developer panel, save v2 with migration,
   static-art baking for performance.
1. **First playable (0.1, done)** — creature, home cave, camera, touch +
   keyboard movement, 8 examinable objects, real-time 400-day clock, autosave,
   original ambience. Tally wall and glowing caps already change with real days.
2. **Living home** — collectables, placing objects, a second and third cave,
   books (readable texts that take real time to read), the passage clearing
   slowly over real weeks.
3. **Art pass** — replace procedural layers with hand-painted textures (see
   asset plan), recorded ambience, a composed score of sparse cues.
4. **iOS hardening** — device testing on oldest supported iPhone, haptics,
   ProMotion pacing, local notifications (opt-in), iCloud backup review.
5. **The long middle** — content spread over 400 days, endings.

## Asset replacement plan

The current art is not placeholder sprites: it is drawn in code with an
ink-and-charcoal language (wobbling inked outlines, catch-lights, hatching) on
a cold palette with a single warm note (the nest). Each visual lives behind a
single node, so replacing it with painted art means swapping one node:

| Element | Now | Replace with |
|---|---|---|
| Back wall, masses, foreground | `PaintChunk` nodes drawn by `cave_room.gd` | Painted PNG strips (≈1024 px wide, ASTC compressed) per layer |
| Creature | `creature_visual.gd` (`_draw`) | Skeleton2D cut-out rig or frame animation; keep `get_bulb_position()` and the `footstep` signal |
| Props | `scripts/world/props/*.gd` | Sprite2D per prop, same origin (floor contact) |
| Sounds | `synth.gd` | Drop `res://audio/<name>.ogg` — `AudioManager` prefers files over synthesis automatically |
| UI font | System serif (Iowan Old Style / Georgia) | A licensed or commissioned serif bundled in `res://fonts/` |

## iOS export checklist (on a Mac)

1. Install Godot 4.7 export templates and Xcode.
2. Open the project, *Project → Export → iOS*; set Team ID and bundle id.
3. Provide app icons (1024 px) and launch screen colour (#050507).
4. Export the Xcode project, build to a device, test on the oldest target iPhone.
5. Verify: backgrounding saves; resuming catches time up; safe-area insets on
   notched devices; 60 fps with lights on.

## Testing

* `tests/run_unit_tests.gd` — clock maths, rollback, suspension, save
  round-trip, checksum tamper, corruption fallback.
* `-- --selftest` — launches the real game, walks with the keyboard, taps to
  move, taps an object, reads its text, saves, verifies the file, and captures
  screenshots.
* `-- --selftest-persist=write` then `=check` — two separate launches proving
  position and time survive closing the game.

## Performance

See [PERFORMANCE.md](PERFORMANCE.md): renderer decision (Compatibility on
iOS), measured Windows numbers, bottlenecks found, and the iOS settings and
on-device measurement plan.
