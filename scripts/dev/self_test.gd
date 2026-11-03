extends Node
## End-to-end test of the real game, driven like a player would.
##
##   -- --profile=selftest --reset-save --selftest [--shots=<dir>]
##       walks with the keyboard, taps to move, taps an object, reads its
##       text to the end, saves and verifies the file; optional screenshots.
##   -- --profile=persist --selftest-persist=write   (first launch)
##   -- --profile=persist --selftest-persist=check   (second launch)
##       proves position, examine counts and time survive closing the game.
## Prints "SELFTEST PASS"/"SELFTEST FAIL" and exits 0/1.

const SaveStore := preload("res://scripts/core/save_store.gd")
const PERSIST_FILE := "user://selftest_persist_expect.json"
const WORLD_FILE := "user://selftest_world_expect.json"
const Loc := preload("res://scripts/core/loc.gd")

var main: Node
var _fails: PackedStringArray = []
var _shots_dir: String = ""


func _ready() -> void:
	# Real mouse clicks on the window must not disturb the scripted input.
	Input.emulate_touch_from_mouse = false
	var mode := "full"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--selftest-persist="):
			mode = arg.get_slice("=", 1)
		elif arg == "--selftest-fps":
			mode = "fps"
		elif arg == "--selftest-fps-areas":
			mode = "fps-areas"
		elif arg == "--selftest-world":
			mode = "world"
		elif arg == "--selftest-world=check":
			mode = "world-check"
		elif arg == "--selftest-lifecycle":
			mode = "lifecycle"
		elif arg == "--selftest-days":
			mode = "days"
		elif arg == "--selftest-mods":
			mode = "mods"
	match mode:
		"fps": _fps()
		"lifecycle": _lifecycle()
		"world": _world()
		"fps-areas": _fps_areas()
		"world-check": _world_check()
		"days": _days()
		"mods": _mods()
		"write": _persist_write()
		"check": _persist_check()
		_: _full()


func _full() -> void:
	var p = main.player
	await _wait(1.5)
	await _shot("01_start")

	# Keyboard walking.
	var x0: float = p.global_position.x
	Input.action_press("move_right")
	await _wait(1.6)
	Input.action_release("move_right")
	await _wait(0.8)
	_check(p.global_position.x > x0 + 60.0, "keyboard moves right (%.1f -> %.1f)" % [x0, p.global_position.x])
	_check(p.facing == 1, "faces right after walking right")
	_check(p.is_on_floor(), "stands on the floor")

	# Tap-to-move, through the real input pipeline.
	var target_x: float = p.global_position.x - 260.0
	await _touch_world(Vector2(target_x, p.global_position.y - 220.0))
	await _wait_until(func() -> bool: return absf(p.global_position.x - target_x) < 8.0 and absf(p.velocity.x) < 2.0, 8.0)
	_check(absf(p.global_position.x - target_x) < 8.0, "tap moves to point (%.1f vs %.1f)" % [p.global_position.x, target_x])
	_check(p.facing == -1, "faces left after walking left")

	# Hold-to-walk: press, keep the finger still, release.
	var hx: float = p.global_position.x
	var screen := _to_screen(Vector2(hx + 400.0, p.global_position.y))
	_send_touch(screen, true)
	await _wait(1.5)
	_send_touch(screen, false)
	await _wait(0.6)
	_check(p.global_position.x > hx + 50.0, "holding a touch walks toward it (%.1f -> %.1f)" % [hx, p.global_position.x])

	# Tap an object: walk over and examine it.
	var nest := _find("nest")
	var before := WorldManager.examine_count("nest")
	await _touch_world(nest.global_position + nest.hit_offset)
	await _wait_until(func() -> bool: return UIManager.is_text_open(), 10.0)
	_check(UIManager.is_text_open(), "tapping the nest opens its text")
	_check(WorldManager.examine_count("nest") == before + 1, "examine counted (%d -> %d)" % [before, WorldManager.examine_count("nest")])
	_check(absf(p.global_position.x - nest.global_position.x) <= nest.radius, "creature walked to the nest")
	await _wait(2.5)
	await _shot("02_examine")
	# Movement is locked while reading.
	var lx: float = p.global_position.x
	Input.action_press("move_right")
	await _wait(0.5)
	Input.action_release("move_right")
	_check(absf(p.global_position.x - lx) < 1.0, "cannot walk while reading")
	# Tap through to the end (first tap may only finish the typing).
	for i in 8:
		if not UIManager.is_text_open():
			break
		await _touch_screen(_window(Vector2(640, 360)))
		await _wait(0.35)
	_check(not UIManager.is_text_open(), "taps close the text")

	# Keyboard examine of whatever is nearest.
	await _wait(0.3)
	await _press_action("interact")
	await _wait(0.4)
	_check(UIManager.is_text_open(), "E examines the nearest thing")
	for i in 8:
		if not UIManager.is_text_open():
			break
		await _press_action("interact")
		await _wait(0.35)
	_check(not UIManager.is_text_open(), "E pages through and closes the text")

	# Every object answers.
	for it in WorldManager.interactables:
		var lines: Array = it.get_examine_lines(1)
		var again: Array = it.get_examine_lines(2)
		_check(not lines.is_empty() and not again.is_empty(), "%s has text" % it.object_id)

	# Save and verify the file on disk.
	_check(SaveManager.save_now("selftest"), "save succeeds")
	var r := SaveStore.read(SaveManager.save_file_path())
	_check(r["ok"], "save file valid")
	if r["ok"]:
		var data: Dictionary = r["payload"]
		_check(absf(float(data["player"]["x"]) - p.global_position.x) < 1.0, "position saved")
		_check(data.has("time") and float(data["time"]["elapsed"]) > 0.0, "time saved")
		_check(int(data["world"]["examined"].get("nest", 0)) >= 1, "examine count saved")

	# A tour of the cave for the screenshots.
	if not _shots_dir.is_empty():
		var stops := [["03_passage", 420.0], ["04_tally", 700.0], ["05_crack", 1500.0], ["06_pool", 1760.0], ["07_caps", 2200.0], ["08_door", 2760.0]]
		for s in stops:
			p.global_position = Vector2(s[1], main.room.floor_y(s[1]) - 1.0)
			p.velocity = Vector2.ZERO
			p.facing = 1
			main.camera.snap_to_target()
			await _wait(1.2)
			await _shot(s[0])
	_finish()


## iOS lifecycle, simulated: backgrounding saves, a suspension is credited
## once on resume (not twice), and pausing drops the frame rate for battery.
## 0.3 world: exits, a tapped exit, the hidden passage, all four items, the
## satchel, placing the stone on the cairn, the way home, and saving.
func _world() -> void:
	var p = main.player
	await _wait(1.5)
	_check(main.room.room_id == "home", "a new game starts at home")
	_check(WorldManager.discovered.has("home"), "home is discovered")

	# Home → Narrow Way, walking through the crevice beside the door.
	_teleport(2880.0)
	await _walk_into("narrow", "move_right")
	_check(main.room.room_id == "narrow", "the crevice leads to the Narrow Way")
	_check(WorldManager.discovered.has("narrow"), "Narrow Way discovered")
	_check(absf(p.global_position.x - 255.0) < 30.0 and p.facing == 1, "arrives at the tunnel's west end facing in (%.0f)" % p.global_position.x)
	_check(UIManager.place_text() == Loc.t("ROOM_NARROW"), "the place name is shown")
	var r := SaveStore.read(SaveManager.save_file_path())
	_check(r["ok"] and r["payload"]["player"]["room"] == "narrow", "arrival is saved")
	await _shot("w01_narrow")

	# The smooth stone, by tapping it.
	var stone := _find("item_stone")
	_check(stone != null, "the smooth stone lies in the Narrow Way")
	if stone != null:
		_teleport(1120.0)
		await _wait(0.3)  # Let the camera settle before turning world into screen positions.
		await _touch_world(stone.global_position + stone.hit_offset)
		await _wait_until(func() -> bool: return UIManager.is_text_open(), 8.0)
		await _read_to_end()
	_check(WorldManager.has_item("stone"), "tapping the stone picks it up")
	_check(_find("item_stone") == null, "the stone is gone from the world")
	_check(UIManager._satchel_button.badge, "the satchel shows something new")

	# Narrow Way → Hall, by tapping the exit.
	_teleport(2120.0)
	await _wait(0.3)
	await _touch_world(Vector2(2262.0, main.room.floor_y(2250.0) - 60.0))
	await _wait_room("hall", 8.0)
	_check(main.room.room_id == "hall", "tapping the tunnel's end walks through it")
	_check(WorldManager.discovered.has("hall"), "Hall of Echoes discovered")
	await _wait(1.2)
	await _shot("w02_hall")

	_teleport(840.0)
	await _examine_id("chimes")
	_teleport(1700.0)
	await _wait(1.0)
	await _shot("w02b_hall_pillar")
	_check(WorldManager.examine_count("chimes") == 1, "the hanging stones can be rung")
	_teleport(1830.0)
	await _examine_id("item_fragment")
	_teleport(2090.0)
	await _examine_id("item_wing")
	_check(WorldManager.has_item("fragment") and WorldManager.has_item("wing"), "fragment and wing collected")

	# The hidden passage stays shut until the stones are pulled away.
	_teleport(2790.0)
	Input.action_press("move_right")
	await _wait(1.5)
	Input.action_release("move_right")
	_check(main.room.room_id == "hall", "the loose stones block the way at first")
	_teleport(2700.0)
	await _examine_id("loose")
	_check(WorldManager.get_flag("hall_passage_open", false), "pulling the stones opens the passage")
	await _walk_into("garden", "move_right")
	_check(main.room.room_id == "garden", "the hidden passage leads to the Still Garden")
	_check(WorldManager.discovered.has("garden"), "Still Garden discovered")
	await _wait(1.2)
	await _shot("w03_garden")

	_teleport(1200.0)
	await _examine_id("item_bloom")
	_check(WorldManager.has_item("bloom"), "pale bloom collected")
	_check(WorldManager.inventory.size() == 4, "four items carried (%d)" % WorldManager.inventory.size())

	# The satchel.
	await _press_action("inventory")
	var satchel := await _wait_node_named("InventoryScreen")
	_check(satchel != null and get_tree().paused, "the satchel opens and pauses")
	if satchel != null:
		_check(satchel.find_children("Item_*", "", true, false).size() == 4, "the satchel lists four items")
		var wing_card: Node = satchel.find_child("Item_wing", true, false)
		await _click(wing_card)
		var desc: Label = satchel.find_child("Description", true, false)
		_check(desc != null and desc.text == "ITEM_WING_DESC", "choosing an item shows its description")
		_check(String(satchel.find_child("Places", true, false).text).contains("4"), "the satchel counts places found")
		await _shot("w04_satchel")
		await _click(satchel.find_child("Back", true, false))
		await _wait(0.5)
	_check(not get_tree().paused, "closing the satchel resumes the game")
	_check(not UIManager._satchel_button.badge, "the new-item mark clears once seen")

	# All the way home.
	await _walk_into("hall", "move_left", 240.0)
	_check(main.room.room_id == "hall" and absf(p.global_position.x - 2755.0) < 70.0, "back in the hall at the passage (%.0f)" % p.global_position.x)
	await _walk_into("narrow", "move_left", 260.0)
	await _walk_into("home", "move_left", 200.0)
	_check(main.room.room_id == "home" and absf(p.global_position.x - 2925.0) < 70.0, "home again, beside the door (%.0f)" % p.global_position.x)
	await _shot("w05_home_again")

	# Tapping the floating marker itself (above the tally's own area) works.
	var tally := _find("tally")
	_teleport(900.0)
	await _wait(0.4)
	await _touch_world(tally.global_position + tally.prompt_offset + Vector2(18, -12))
	await _wait_until(func() -> bool: return UIManager.is_text_open(), 8.0)
	_check(UIManager.is_text_open() and UIManager._title.text == Loc.t("OBJ_TALLY_TITLE").to_upper(), "tapping just beside a floating marker examines its object")
	await _read_to_end()

	# The smooth stone completes the cairn.
	_teleport(1225.0)
	await _examine_id("cairn")
	_check(not WorldManager.has_item("stone"), "the stone is placed on the cairn")
	_check(WorldManager.get_flag("cairn_eighth_stone", false), "the cairn remembers it")
	_check(main.room.cairn.stones == 8, "the cairn now has eight stones")
	await _shot("w06_cairn")

	# End the session in the Narrow Way, to check the room is restored.
	_teleport(2880.0)
	await _walk_into("narrow", "move_right")
	_teleport(900.0)
	await _wait(0.3)
	_check(SaveManager.save_now("world-test"), "save succeeds")
	var saved := SaveStore.read(SaveManager.save_file_path())
	if saved["ok"]:
		var w: Dictionary = saved["payload"]["world"]
		_check(int(saved["payload"]["version"]) == 3, "save is version 3")
		_check(w["discovered"].size() == 4, "four places in the save")
		_check(w["collected"].size() == 4 and w["inventory"].size() == 3, "items in the save")
	var expect := {
		"room": main.room.room_id,
		"x": p.global_position.x,
		"inventory": WorldManager.inventory,
		"discovered": WorldManager.discovered.keys(),
		"collected": WorldManager.collected.keys(),
	}
	var f := FileAccess.open(WORLD_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()
	_finish()


## Second launch after _world: everything found must still be found.
func _world_check() -> void:
	var p = main.player
	await _wait(1.5)
	var expect: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLD_FILE))
	if typeof(expect) != TYPE_DICTIONARY:
		_check(false, "expectation file from the world run exists")
		_finish()
		return
	_check(main.room.room_id == expect["room"], "the game resumes in the saved area (%s)" % main.room.room_id)
	_check(absf(p.global_position.x - float(expect["x"])) < 2.0, "at the saved position")
	_check(Array(WorldManager.inventory) == Array(expect["inventory"]), "satchel restored %s" % str(WorldManager.inventory))
	for id in expect["discovered"]:
		_check(WorldManager.discovered.has(id), "%s still discovered" % id)
	for id in expect["collected"]:
		_check(WorldManager.is_collected(id), "%s still collected" % id)
	_check(_find("item_stone") == null, "a collected item does not come back")
	_check(WorldManager.get_flag("hall_passage_open", false) and WorldManager.get_flag("cairn_eighth_stone", false), "world changes kept")
	_check(not UIManager._satchel_button.badge, "items already seen stay seen")
	_teleport(2120.0)
	await _walk_into("hall", "move_right")
	_check(main.room.loose.opened, "the passage is still open")
	_teleport(2790.0)
	await _walk_into("garden", "move_right")
	_check(main.room.room_id == "garden" and _find("item_bloom") == null, "the garden is reachable and the bloom stays picked")
	_finish()


## Frame times while walking in every area, and texture memory before and
## after a full round trip (rooms are freed when left: it must not grow).
func _fps_areas() -> void:
	await _wait(3.0)
	print("renderer: %s / %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()])
	var mem0 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	WorldManager.set_flag("hall_passage_open", true)
	for id in ["home", "narrow", "hall", "garden", "home"]:
		if main.room.room_id != id:
			main.travel(id, "")
			await _wait_room(id, 10.0)
			await _wait(1.5)
		_teleport(main.room.spawn_x)
		await _wait(0.3)
		Input.action_press("move_right")
		await _profile(id, 4.0)
		Input.action_release("move_right")
		print("    textures %.1f MB, nodes %d" % [Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	await _wait(1.0)
	var mem1 := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	print("texture memory at home: before %.1f MB, after the round trip %.1f MB" % [mem0, mem1])
	_check(mem1 < mem0 + 8.0, "no texture memory left behind by visited rooms")
	_finish()


func _teleport(x: float) -> void:
	var p = main.player
	p.stop()
	p.velocity = Vector2.ZERO
	p.global_position = Vector2(x, main.room.floor_y(x) - 1.0)
	main.camera.snap_to_target()
	main.camera.force_update_scroll()


## Holds a direction until the area changes (or times out), then lets go.
func _walk_into(room_id: String, action: String, from_x: float = -1.0) -> void:
	if from_x >= 0.0:
		_teleport(from_x)
	Input.action_press(action)
	await _wait_room(room_id, 10.0)
	Input.action_release(action)
	await _wait(0.4)


func _wait_room(room_id: String, timeout: float) -> void:
	await _wait_until(func() -> bool: return main.room.room_id == room_id and not main.is_travelling(), timeout)
	await _wait(0.2)


func _examine_id(id: String) -> void:
	var target := _find(id)
	if target == null:
		_check(false, "%s is present" % id)
		return
	main.player.interaction.examine(target)
	await _wait(0.3)
	await _read_to_end()


func _read_to_end() -> void:
	for i in 10:
		if not UIManager.is_text_open():
			break
		await _press_action("interact")
		await _wait(0.3)


func _wait_node_named(node_name: String) -> Node:
	var t := 0.0
	while t < 3.0:
		var n := get_tree().root.find_child(node_name, true, false)
		if n != null:
			await _wait(0.4)
			return n
		await get_tree().process_frame
		t += get_process_delta_time()
	return null


## A real left click at a control's centre.
func _click(c: Variant) -> void:
	if c == null or not is_instance_valid(c):
		_check(false, "control to click exists")
		return
	var pos: Vector2 = _window((c as Control).get_global_rect().get_center())
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await _wait(0.2)


func _lifecycle() -> void:
	await _wait(2.0)
	var saved_before := float(SaveStore.read(SaveManager.save_file_path())["payload"].get("saved_at_unix", 0.0))
	await _wait(1.1)
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	var r := SaveStore.read(SaveManager.save_file_path())
	_check(r["ok"] and float(r["payload"]["saved_at_unix"]) > saved_before, "backgrounding saves the game")
	var e0: float = TimeManager.clock.elapsed
	var w0 := Time.get_unix_time_from_system()
	OS.delay_msec(3000)  # The app is suspended: no frames, no processing.
	var gap := Time.get_unix_time_from_system() - w0
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
	for i in 5:
		await get_tree().process_frame
	var gained: float = TimeManager.clock.elapsed - e0
	print("suspended %.2f s, clock gained %.2f s" % [gap, gained])
	_check(gained >= gap - 0.2, "suspension credited on resume")
	_check(gained < gap + 1.0, "suspension not counted twice")
	main.open_pause()
	await _wait(0.3)
	_check(Engine.max_fps == 30, "pause menu lowers the frame rate (%d)" % Engine.max_fps)
	get_tree().paused = false
	await _wait(0.2)
	_check(Engine.max_fps == 60, "frame rate restored after pause (%d)" % Engine.max_fps)
	_finish()


## Performance profile (windowed runs): frame-time distribution, draw calls,
## script time and memory, across walking, reading and the pause menu.
## Report-only, since numbers depend on the machine; fails only on hitches.
func _fps() -> void:
	await _wait(3.0)
	if "--fps-diagnose" in OS.get_cmdline_user_args():
		await _fps_diagnose()
		_finish()
		return
	print("renderer: %s / %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()])
	print("adapter: %s" % RenderingServer.get_video_adapter_name())
	Input.action_press("move_right")
	await _profile("walking right", 6.0)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _profile("walking left", 4.0)
	Input.action_release("move_left")
	await _press_action("interact")
	await _profile("reading", 3.0)
	for i in 6:
		if UIManager.is_text_open():
			await _press_action("interact")
			await _wait(0.3)
	main.open_pause()
	await _profile("pause menu open", 3.0)
	print("memory: static %.1f MB, video %.1f MB, textures %.1f MB (baked chunks %.1f MB), objects %d, nodes %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		main.room.baked_texture_bytes / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	_finish()


var _deltas: PackedFloat32Array = []


func _profile(label: String, seconds: float) -> void:
	_deltas.clear()
	var draws := 0.0
	var script_ms := 0.0
	var frames := 0
	var last := Time.get_ticks_usec()
	var end := last + int(seconds * 1_000_000)
	while Time.get_ticks_usec() < end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		_deltas.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		script_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		frames += 1
	var sorted := _deltas.duplicate()
	sorted.sort()
	var total := 0.0
	for d in sorted:
		total += d
	var p := func(q: float) -> float: return sorted[clampi(int(q * (sorted.size() - 1)), 0, sorted.size() - 1)]
	var hitches := 0
	for d in sorted:
		if d > 25.0:
			hitches += 1
	print("  %-16s %5.1f fps | frame ms p50 %5.1f  p99 %5.1f  max %6.1f | >25ms %3d | draws %3.0f | process %5.2f ms" % [
		label, 1000.0 * sorted.size() / total, p.call(0.5), p.call(0.99), sorted[sorted.size() - 1], hitches,
		draws / frames, script_ms / frames])
	_check(sorted[sorted.size() - 1] < 250.0, "%s: no frame over 250 ms" % label)


func _fps_diagnose() -> void:
	Input.action_press("move_right")
	await _profile("baseline", 3.0)
	main.player.lantern.shadow_enabled = false
	await _profile("lantern shadow off", 3.0)
	main.player.lantern.shadow_enabled = true
	main.player.visual.set_process(false)
	await _profile("creature frozen", 3.0)
	main.player.visual.set_process(true)
	for it in WorldManager.interactables:
		it.visible = false
	await _profile("glyphs hidden", 3.0)
	for it in WorldManager.interactables:
		it.visible = true
	Input.action_release("move_right")
	await _profile("standing still", 3.0)
	main.camera.set_physics_process(false)
	await _profile("standing, camera frozen", 3.0)


func _measure(label: String) -> void:
	await _wait(2.5)
	print("  %-34s %5.1f fps  draws %4d  process %5.2f ms  physics %5.2f ms" % [label, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _persist_write() -> void:
	var p = main.player
	await _wait(0.5)
	p.global_position = Vector2(1500.0, main.room.floor_y(1500.0) - 1.0)
	p.facing = -1
	await _wait(0.3)
	WorldManager.examine(_find("cairn"))
	await _wait(0.2)
	SaveManager.save_now("persist-write")
	var expect := {
		"x": p.global_position.x,
		"cairn": WorldManager.examine_count("cairn"),
		"elapsed": TimeManager.clock.elapsed,
		"unix": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(PERSIST_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()
	print("persist write: x=%.1f elapsed=%.2f" % [expect["x"], expect["elapsed"]])
	_finish()


func _persist_check() -> void:
	var p = main.player
	await _wait(0.5)
	var expect: Variant = JSON.parse_string(FileAccess.get_file_as_string(PERSIST_FILE))
	if typeof(expect) != TYPE_DICTIONARY:
		_check(false, "expectation file from the write run exists")
		_finish()
		return
	var gap := Time.get_unix_time_from_system() - float(expect["unix"])
	print("persist check: real gap %.2f s, elapsed %.2f (was %.2f), x=%.1f" % [gap, TimeManager.clock.elapsed, expect["elapsed"], p.global_position.x])
	_check(not SaveManager.is_new_game, "save was found")
	_check(absf(p.global_position.x - float(expect["x"])) < 1.5, "position restored")
	_check(p.facing == -1, "facing restored")
	_check(WorldManager.examine_count("cairn") == int(expect["cairn"]), "examine count restored")
	_check(TimeManager.clock.elapsed >= float(expect["elapsed"]) + gap - 1.5, "time kept running while closed")
	_check(TimeManager.clock.elapsed < float(expect["elapsed"]) + gap + 3.0, "no extra time invented")
	_check(main.offline_at_start > 0.0, "offline time credited at launch")
	_finish()


# --- helpers --------------------------------------------------------------------

func _find(id: String) -> Node:
	for it in WorldManager.interactables:
		if it.object_id == id:
			return it
	return null


## World -> window coordinates (what Input.parse_input_event expects; the
## root viewport then applies its stretch transform, like a real touch).
func _to_screen(world: Vector2) -> Vector2:
	return _window(get_viewport().get_canvas_transform() * world)


func _window(viewport_pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * viewport_pos


func _send_touch(screen: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = screen
	ev.pressed = pressed
	Input.parse_input_event(ev)


## A real input event, as a key press would produce.
func _press_action(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(0.05)


func _touch_screen(screen: Vector2) -> void:
	_send_touch(screen, true)
	await _wait(0.06)
	_send_touch(screen, false)


func _touch_world(world: Vector2) -> void:
	await _touch_screen(_to_screen(world))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	img.save_png(_shots_dir.path_join(shot_name + ".png"))


func _check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("SELFTEST PASS" if _fails.is_empty() else "SELFTEST FAIL: " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)


const DAY_SECONDS := 86400.0
const Notes := preload("res://scripts/data/notes.gd")
const BloomSprout := preload("res://scripts/world/props/bloom_sprout.gd")
const ItemsReg := preload("res://scripts/data/items.gd")


## 0.4: things that only move on with real days — the old passage (one stone a
## day), the Scribe's Alcove behind it, the pages (one more readable each day)
## and the bloom planted in the garden moss.
func _days() -> void:
	var p = main.player
	await _wait(1.5)
	_check(main.room.room_id == "home", "a new game starts at home")
	_teleport(400.0)
	await _examine_id("passage")
	_check(int(WorldManager.get_flag("passage_stones", 0)) == 1, "the first stone comes away")
	await _examine_id("passage")
	_check(int(WorldManager.get_flag("passage_stones", 0)) == 1, "only one stone a day")
	_teleport(400.0)
	Input.action_press("move_left")
	await _wait(1.2)
	Input.action_release("move_left")
	_check(main.room.room_id == "home", "the passage is still blocked")
	for i in 6:
		TimeManager.debug_add_seconds(DAY_SECONDS)
		_teleport(400.0)
		await _examine_id("passage")
	_check(int(WorldManager.get_flag("passage_stones", 0)) == 7, "seven stones over seven days (%d)" % int(WorldManager.get_flag("passage_stones", 0)))
	_check(WorldManager.get_flag("passage_open", false), "the passage is open")
	await _wait(0.8)
	await _shot("d01_passage_open")
	await _walk_into("alcove", "move_left", 400.0)
	_check(main.room.room_id == "alcove", "the passage leads to the Scribe's Alcove")
	_check(WorldManager.discovered.has("alcove"), "the Alcove is discovered")
	await _wait(1.2)
	await _shot("d02_alcove")
	for id in ["lamp", "desk", "sevens"]:
		var o := _find(id)
		if o != null:
			_teleport(o.global_position.x)
		await _examine_id(id)
		_check(WorldManager.examine_count(id) == 1, "%s can be examined" % id)
	_teleport(1080.0)
	await _examine_id("item_pages")
	_check(WorldManager.has_item("pages"), "the pages are taken")
	_check(Notes.readable() == 1, "one page readable on the day they are found")
	TimeManager.debug_add_seconds(DAY_SECONDS * 2.0)
	_check(Notes.readable() == 3, "two days later, three pages (%d)" % Notes.readable())

	await _press_action("inventory")
	var satchel := await _wait_node_named("InventoryScreen")
	if satchel != null:
		await _click(satchel.find_child("Item_pages", true, false))
		var read: Button = satchel.find_child("Read", true, false)
		_check(read != null and read.visible, "the satchel offers to read the pages")
		await _click(read)
		var reader := await _wait_node_named("ReaderScreen")
		_check(reader != null, "the reader opens")
		if reader != null:
			_check(reader.find_children("Page_*", "", true, false).size() == 3, "the reader shows three pages")
			await _shot("d03_reader")
			await _press_action("ui_cancel")
			await _wait(0.6)
			_check(not is_instance_valid(reader) or not reader.is_inside_tree(), "Back closes the reader first")
			_check(is_instance_valid(satchel) and satchel.is_inside_tree(), "the satchel is still open under it")
		if is_instance_valid(satchel):
			await _click(satchel.find_child("Back", true, false))
			await _wait(0.5)
	_check(not get_tree().paused, "the game resumes")
	TimeManager.debug_add_seconds(DAY_SECONDS * 30.0)
	_check(Notes.readable() == 12, "never more than twelve pages")

	# Back home through the passage, then plant the bloom in the garden moss.
	await _walk_into("home", "move_right", 1700.0)
	_check(main.room.room_id == "home" and absf(p.global_position.x - 420.0) < 80.0, "home again, by the passage (%.0f)" % p.global_position.x)
	WorldManager.collect("bloom")
	main.travel("garden", "")
	await _wait_room("garden", 10.0)
	await _wait(1.0)
	_check(BloomSprout.stage() == -1, "nothing planted yet")
	_teleport(700.0)
	await _examine_id("moss")
	_check(not WorldManager.has_item("bloom") and BloomSprout.stage() == 0, "the bloom is planted")
	for st in [[2, 1], [3, 2], [5, 3]]:
		TimeManager.debug_add_seconds(DAY_SECONDS * float(st[0]))
		await _wait(0.3)
		_check(BloomSprout.stage() == st[1], "sprout stage %d" % st[1])
	_teleport(745.0)
	await _wait(0.6)
	await _shot("d04_bloom_open")
	_teleport(700.0)
	await _examine_id("moss")
	_check(SaveManager.save_now("days-test"), "save succeeds")
	var saved := SaveStore.read(SaveManager.save_file_path())
	_check(saved["ok"] and saved["payload"]["world"]["flags"].has("bloom_planted_day"), "the planting is saved")
	_finish()


## 0.4 mods: the bundled example installs (switched off), a broken mod is
## reported, switching the example on adds a side passage, a room and an item;
## switching it off again leaves the game and the save working.
func _mods() -> void:
	await _wait(1.5)
	var dir := ModManager.mods_dir()
	_check(FileAccess.file_exists(dir.path_join("glimmer_grotto/mod.json")), "the example mod is installed")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir.path_join("broken_one")))
	var f := FileAccess.open(dir.path_join("broken_one/mod.json"), FileAccess.WRITE)
	f.store_string("{\"format\": 1, \"id\": \"broken_one\", \"name\": \"x\", \"rooms\": {\"r\": {\"anchor\": \"nowhere\"}}}")
	f.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir.path_join("not_json")))
	f = FileAccess.open(dir.path_join("not_json/mod.json"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	ModManager.scan()
	var by_id := {}
	for m in ModManager.mods:
		by_id[m["id"]] = m
	_check(by_id.has("glimmer_grotto") and by_id["glimmer_grotto"]["ok"], "the example mod is valid %s" % str(by_id.get("glimmer_grotto", {}).get("errors", "")))
	_check(by_id.has("glimmer_grotto") and not by_id["glimmer_grotto"]["enabled"], "the example mod starts switched off")
	_check(by_id.has("broken_one") and not by_id["broken_one"]["ok"], "a mod with a bad anchor is refused")
	_check(by_id.has("not_json") and not by_id["not_json"]["ok"], "a mod that is not JSON is refused")
	print("    broken_one: ", by_id.get("broken_one", {}).get("errors", []))
	print("    not_json: ", by_id.get("not_json", {}).get("errors", []))
	_check(ModManager.room_ids().is_empty(), "nothing loads while switched off")

	ModManager.set_enabled("glimmer_grotto", true)
	_check(ModManager.room_ids() == ["mod:glimmer_grotto:grotto"], "the grotto is registered %s" % str(ModManager.room_ids()))
	_check(ModManager.anchor_room("narrow") == "mod:glimmer_grotto:grotto", "it hangs off the Narrow Way")
	_check(TranslationServer.translate(ModManager.room_def("mod:glimmer_grotto:grotto").get("title", "")) == "Lśniąca Grota", "its texts are translated")
	main.travel("narrow", "")
	await _wait_room("narrow", 10.0)
	await _wait(1.0)
	var side := _find("side:mod:glimmer_grotto:grotto")
	_check(side != null, "the side passage is in the Narrow Way")
	_teleport(1450.0)
	await _wait(0.6)
	await _shot("m01_side_passage")
	if side != null:
		main.player.interaction.examine(side)
		await _wait(0.3)
		await _read_to_end()
	await _wait_room("mod:glimmer_grotto:grotto", 10.0)
	_check(main.room.room_id == "mod:glimmer_grotto:grotto", "the side passage leads into the grotto")
	await _wait(1.2)
	await _shot("m02_grotto")
	_teleport(600.0)
	await _examine_id("mod:glimmer_grotto:grotto:o0")
	_check(WorldManager.examine_count("mod:glimmer_grotto:grotto:o0") == 1, "a mod object can be examined")
	_teleport(760.0)
	await _examine_id("item_mod:glimmer_grotto:glass_pebble")
	_check(WorldManager.has_item("mod:glimmer_grotto:glass_pebble"), "the mod's item is taken")
	await _press_action("inventory")
	var satchel := await _wait_node_named("InventoryScreen")
	_check(satchel != null and satchel.find_child("Item_mod_glimmer_grotto_glass_pebble", true, false) != null, "the satchel shows the mod's item")
	_check(satchel != null and String(satchel.find_child("Places", true, false).text).contains("Lśniąca Grota"), "the grotto counts as a place")
	await _shot("m03_satchel")
	if satchel != null:
		await _click(satchel.find_child("Back", true, false))
		await _wait(0.5)
	await _walk_into("narrow", "move_left", 400.0)
	_check(main.room.room_id == "narrow", "the grotto leads back to the Narrow Way")

	ModManager.set_enabled("glimmer_grotto", false)
	_check(ModManager.room_ids().is_empty() and ItemsReg.order().size() == ItemsReg.ORDER.size(), "switched off, the mod is gone")
	main.travel("home", "")
	await _wait_room("home", 10.0)
	await _press_action("inventory")
	satchel = await _wait_node_named("InventoryScreen")
	_check(satchel != null, "the satchel still opens with the mod off")
	if satchel != null:
		await _click(satchel.find_child("Back", true, false))
		await _wait(0.5)
	_check(SaveManager.save_now("mods-test"), "the save still works")
	var saved := SaveStore.read(SaveManager.save_file_path())
	_check(saved["ok"] and Array(saved["payload"]["world"]["inventory"]).has("mod:glimmer_grotto:glass_pebble"), "the mod's item is kept in the save for later")
	_finish()
