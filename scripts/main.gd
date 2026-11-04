extends Node2D
## The game session: builds the current area, the creature, the camera and
## input, then hands the session to the autoload systems. While this scene
## exists, SaveManager.session_active is true (autosave and lifecycle saves).
##
## Areas (0.3): one room is loaded at a time. Walking into an exit fades out,
## swaps the room (the creature, camera, input and sound carry over), places
## the creature at the matching entry, records the visit, saves, fades in.
##
## Pause: Esc / P or the pause glyph. Satchel: I / Tab or the satchel glyph.
## Developer tools (debug builds only): F3 panel, F5 +1 day, F6 +1 hour,
## F8 save — or Pause → Developer tools.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const Rooms := preload("res://scripts/world/rooms.gd")
const Character := preload("res://scripts/character/character_controller.gd")
const CameraController := preload("res://scripts/camera/camera_controller.gd")
const WorldInput := preload("res://scripts/input/world_input.gd")
const ScreenEffects := preload("res://scripts/world/screen_effects.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const InventoryScreen := preload("res://scripts/ui/inventory_screen.gd")
const Loc := preload("res://scripts/core/loc.gd")
const MENU_SCENE := "res://scenes/main_menu.tscn"

signal room_changed(room_id: String)

var room: Node2D
var player: Character
var camera: CameraController
var world_input: WorldInput
var menus: CanvasLayer
var dev_panel: Control
## Offline time credited when this session began (shown once as a hint).
var offline_at_start: float = 0.0
var _pause: Node = null
var _satchel: Node = null
var _leaving: bool = false
var _travelling: bool = false
## Tampering was caught (0.5): go to the dungeon as soon as nothing is open.
var _jail_pending: bool = false


func _ready() -> void:
	InputSetup.register()

	var room_id := str(WorldManager.player_state.get("room", "home"))
	if not Rooms.exists(room_id):
		room_id = "home"
	# The clock was moved (caught now or before): the session begins in the cell.
	var forced_jail := TimeManager.is_jailed() and room_id != "dungeon"
	if forced_jail:
		room_id = "dungeon"
	room = Rooms.create(room_id)
	add_child(room)

	player = Character.new()
	player.room = room
	var spawn := WorldManager.resolve_spawn(room.room_id, Vector2(room.spawn_x, 0), room.walkable_range())
	var x: float = spawn["x"]
	if room.exit_at(Vector2(x, room.floor_y(x) - 40.0)) != null:
		x = room.spawn_x  # Never wake up standing in a doorway.
	if forced_jail:
		x = room.entry("cell")["x"]
		spawn["facing"] = 1
	player.position = Vector2(x, room.floor_y(x) - 1.0)
	player.facing = spawn["facing"]
	room.actor_layer.add_child(player)

	camera = CameraController.new()
	camera.target = player
	camera.bounds = room.bounds
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()
	room.set_camera(camera)

	world_input = WorldInput.new()
	world_input.player = player
	world_input.room = room
	add_child(world_input)

	add_child(ScreenEffects.new())

	menus = CanvasLayer.new()
	menus.layer = 20
	add_child(menus)
	if OS.is_debug_build():
		var dev_layer := CanvasLayer.new()
		dev_layer.layer = 25
		add_child(dev_layer)
		dev_panel = load("res://scripts/ui/dev_panel.gd").new()
		dev_panel.visible = false
		dev_layer.add_child(dev_panel)
		UIManager.register_blocker(dev_panel)

	UIManager.pause_requested.connect(open_pause)
	UIManager.inventory_requested.connect(open_satchel)
	room.exit_reached.connect(travel)
	TimeManager.tamper_detected.connect(_on_tamper)
	AudioManager.start_ambience()
	AudioManager.set_space(room.sound_space)
	WorldManager.enter_room(room.room_id)
	var new_game := SaveManager.is_new_game
	offline_at_start = TimeManager.offline_seconds_on_launch
	UIManager.on_session_start(new_game, offline_at_start)
	TimeManager.offline_seconds_on_launch = 0.0  # Greeted once per launch.
	SaveManager.session_active = true
	# Persist the start timestamp immediately on a fresh game.
	if SaveManager.save_now("session-start"):
		SaveManager.is_new_game = false
	if room.room_id != "home" and not new_game:
		UIManager.show_place(room.title_key, false)
	if not TimeManager.last_tamper.is_empty():
		_tell_tamper.call_deferred(2.6)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--selftest") and not arg.begins_with("--selftest-menu"):
			var test: Node = load("res://scripts/dev/self_test.gd").new()
			test.main = self
			add_child(test)
			break


func _exit_tree() -> void:
	SaveManager.session_active = false


func _process(_delta: float) -> void:
	if _jail_pending and not _travelling and not _leaving and not get_tree().paused and not UIManager.is_text_open():
		_jail_pending = false
		_imprison()


func _on_tamper(_skipped: float, _source: String) -> void:
	if room != null and room.room_id == "dungeon":
		_tell_tamper(0.3)  # Already here: the day starts again.
	else:
		_jail_pending = true


func _imprison() -> void:
	AudioManager.play("rumble", -3.0, 0.6)
	await travel("dungeon", "cell")
	_tell_tamper(0.8)


## The voice of the door: what happened, and what it cost.
func _tell_tamper(delay: float) -> void:
	var t: Dictionary = TimeManager.last_tamper
	TimeManager.last_tamper = {}
	if t.is_empty():
		return
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree() or _leaving:
		return
	var lines: Array = ["TAMPER_1"]
	if float(t.get("skipped", 0.0)) >= 60.0:
		lines.append(["TAMPER_2", Loc.duration(float(t["skipped"]))])
	lines.append("TAMPER_3")
	UIManager.show_text("TAMPER_TITLE", lines)


func is_travelling() -> bool:
	return _travelling


## Moves the creature to another area through [param to_entry].
func travel(to_room: String, to_entry: String) -> void:
	if _travelling or _leaving or not Rooms.exists(to_room):
		return
	_travelling = true
	player.input_locked = true
	player.stop()
	await UIManager.fade_out(0.45)

	var old := room
	old.actor_layer.remove_child(player)
	remove_child(old)
	old.queue_free()

	room = Rooms.create(to_room)
	add_child(room)
	move_child(room, 0)
	room.exit_reached.connect(travel)
	var e: Dictionary = room.entry(to_entry)
	var x: float = e["x"]
	player.position = Vector2(x, room.floor_y(x) - 1.0)
	player.velocity = Vector2.ZERO
	player.facing = int(e["facing"])
	player.room = room
	room.actor_layer.add_child(player)
	camera.set_bounds(room.bounds)
	camera.snap_to_target()
	room.set_camera(camera)
	world_input.room = room
	AudioManager.set_space(room.sound_space)
	var first_visit := WorldManager.enter_room(room.room_id)

	# Fade in once the new room's art is baked (two frames, under the black).
	var waited := 0.0
	while not room.is_ready_to_show and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	# Let physics see the creature at its new position before exits listen
	# again: two rooms can have exits at the same coordinates, and a stale
	# overlap would carry the creature straight on into a third.
	await get_tree().physics_frame
	await get_tree().physics_frame
	SaveManager.save_now("travel")
	UIManager.fade_in(0.7)
	UIManager.show_place(room.title_key, first_visit)
	player.input_locked = false
	_travelling = false
	room_changed.emit(room.room_id)


func open_pause() -> void:
	if _leaving or _travelling or (_pause != null and is_instance_valid(_pause)):
		return
	_pause = PauseMenu.new()
	_pause.game = self
	menus.add_child(_pause)


## The satchel: from the glyph or I / Tab (pauses), or from the pause menu.
func open_satchel() -> Node:
	if _leaving or _travelling or (_satchel != null and is_instance_valid(_satchel)):
		return null
	_satchel = InventoryScreen.new()
	menus.add_child(_satchel)
	return _satchel


## Called by the pause menu after a successful save.
func leave_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	SaveManager.session_active = false
	UIManager.transition_to(MENU_SCENE)


func toggle_dev_panel(force_show: bool = false) -> void:
	if dev_panel == null:
		return
	dev_panel.visible = true if force_show else not dev_panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_pause()
		return
	if event.is_action_pressed("inventory") and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_satchel()
		return
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_overlay"):
		toggle_dev_panel()
	elif event.is_action_pressed("debug_add_day"):
		TimeManager.debug_add_seconds(86400.0)
	elif event.is_action_pressed("debug_add_hour"):
		TimeManager.debug_add_seconds(3600.0)
	elif event.is_action_pressed("debug_save"):
		if SaveManager.save_now("debug"):
			UIManager.toast("HINT_SAVED")
