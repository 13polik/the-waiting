extends Node
## WorldInput — what a touch means.
##  * Tap a thing: walk to it and examine it.
##  * Tap elsewhere: walk there (a faint ring marks the spot).
##  * Touch and hold / drag: walk toward the finger for as long as it is down.
##  * Any tap while text is shown: continue the text.
## With emulate_touch_from_mouse on, the mouse drives exactly the same path.
## Keyboard "interact" examines the nearest thing or continues text.

const TAP_MAX_TIME := 0.28
const TAP_MAX_MOVE := 26.0

var player
var room

var _touch: int = -1
var _consumed: bool = false
var _press_pos: Vector2
var _last_pos: Vector2
var _press_time: float = 0.0
var _holding: bool = false
var _t: float = 0.0
var _marker: Node2D


func _ready() -> void:
	# Owned by the game scene, not the room: rooms are swapped (0.3).
	_marker = TapMarker.new()
	get_parent().add_child.call_deferred(_marker)


func _process(delta: float) -> void:
	_t += delta
	if _touch < 0 or _consumed:
		return
	if not _holding and _t - _press_time > TAP_MAX_TIME:
		_holding = true
	if _holding:
		# Recomputed every frame: as the camera follows, a still finger keeps
		# leading the creature onward, like holding a direction.
		player.move_to_x(_to_world(_last_pos).x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		if event.index == _touch and not _consumed:
			_last_pos = event.position
			if event.position.distance_to(_press_pos) > TAP_MAX_MOVE:
				_holding = true
	elif event.is_action_pressed("interact") and not event.is_echo():
		if UIManager.is_text_open():
			UIManager.advance()
		else:
			player.interaction.try_interact()
		get_viewport().set_input_as_handled()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch >= 0:
			return  # Ignore extra fingers.
		if UIManager.blocks_point(event.position):
			return  # On the pause button or developer panel.
		_touch = event.index
		_press_pos = event.position
		_last_pos = event.position
		_press_time = _t
		_holding = false
		_consumed = UIManager.is_text_open()
		if _consumed:
			UIManager.advance()
		get_viewport().set_input_as_handled()
		return
	if event.index != _touch:
		return
	_touch = -1
	if _consumed:
		_consumed = false
		return
	if not _holding:
		tap(event.position)
	get_viewport().set_input_as_handled()


## A single tap at a viewport position. Public so tests can drive it.
func tap(screen_pos: Vector2) -> void:
	var world := _to_world(screen_pos)
	var target: Node = WorldManager.find_interactable_at(world)
	if target != null:
		var stand: float = target.stand_x_from(player.global_position.x)
		var walk := clampf(stand, room.walkable_range().x, room.walkable_range().y)
		player.move_to_x(walk, func() -> void: player.interaction.examine(target))
		return
	var exit: Node = room.exit_at(world)
	if exit != null:
		player.move_to_x(exit.walk_x)  # Walking into it carries the creature through.
		return
	var x := clampf(world.x, room.walkable_range().x, room.walkable_range().y)
	player.move_to_x(x)
	_marker.show_at(Vector2(x, room.floor_y(x)))


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


## A faint ring on the floor where the player tapped. Fades in a second.
class TapMarker extends Node2D:
	var _life: float = 0.0

	func _ready() -> void:
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		z_index = 30

	func show_at(p: Vector2) -> void:
		position = p
		_life = 1.0
		queue_redraw()

	func _process(delta: float) -> void:
		if _life > 0.0:
			_life = maxf(0.0, _life - delta * 1.1)
			queue_redraw()

	func _draw() -> void:
		if _life <= 0.0:
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
		draw_arc(Vector2.ZERO, 10.0 + (1.0 - _life) * 18.0, 0.0, TAU, 32, Color(0.8, 0.9, 0.88, 0.45 * _life), 4.0, true)
