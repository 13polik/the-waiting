extends Area2D
## A way out of a room: walking into it (or tapping it) carries the creature
## to another area. Event-driven — the physics engine reports the overlap, so
## an exit costs nothing per frame except a fade of its small floor mark.
## An exit with a "flag" stays shut until WorldManager has that flag set
## (a hidden passage), then [method refresh] opens it.

signal reached(to_room: String, to_entry: String)

const LightTextures := preload("res://scripts/world/light_textures.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const MARK := Color(0.82, 0.92, 0.9)

## {"id", "x0", "x1", "to_room", "to_entry", "flag"?}
var spec: Dictionary = {}
var floor_at: float = 800.0
## Where a tap sends the creature: inside the exit, within reach.
var walk_x: float = 0.0
var _open: bool = false
var _mark: Node2D
var _near: float = 0.0


func _ready() -> void:
	name = "Exit_" + str(spec.get("id", ""))
	var x0: float = spec["x0"]
	var x1: float = spec["x1"]
	position = Vector2((x0 + x1) * 0.5, floor_at)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, 220)
	shape.shape = rect
	shape.position = Vector2(0, -110)
	add_child(shape)
	monitorable = false
	body_entered.connect(_on_body_entered)

	_mark = Node2D.new()
	_mark.material = LightTextures.unshaded()
	_mark.z_index = 40
	_mark.position = Vector2(walk_x - position.x, -26)
	_mark.draw.connect(_draw_mark)
	_mark.modulate.a = 0.0
	_mark.scale = Vector2.ONE * UiStyle.glyph_scale()
	add_child(_mark)
	refresh()


func is_open() -> bool:
	return _open


func refresh() -> void:
	var flag := str(spec.get("flag", ""))
	_open = flag.is_empty() or bool(WorldManager.get_flag(flag, false))
	set_deferred("monitoring", _open)
	_mark.visible = _open


func contains_point(world_pos: Vector2) -> bool:
	var x0: float = spec["x0"]
	var x1: float = spec["x1"]
	return world_pos.x >= x0 - 40.0 and world_pos.x <= x1 + 40.0 and world_pos.y > floor_at - 320.0 and world_pos.y < floor_at + 60.0


func _process(delta: float) -> void:
	if not _open:
		return
	var p: Variant = WorldManager.player
	var target := 0.0
	if is_instance_valid(p) and p.is_inside_tree():
		target = clampf(1.0 - absf(p.global_position.x - global_position.x) / 420.0, 0.0, 1.0)
	_near = move_toward(_near, target, delta * 1.5)
	_mark.modulate.a = _near * 0.85


func _on_body_entered(body: Node) -> void:
	if not _open or body != WorldManager.player:
		return
	# Trust the creature's real position, not a stale physics overlap.
	var x: float = body.global_position.x
	if x < float(spec["x0"]) - 20.0 or x > float(spec["x1"]) + 20.0:
		return
	reached.emit(str(spec["to_room"]), str(spec["to_entry"]))


## Three faint dots leading into the dark: the way on.
func _draw_mark() -> void:
	var dir := 1.0 if str(spec.get("side", "right")) == "right" else -1.0
	for i in 3:
		_mark.draw_circle(Vector2(dir * i * 14.0, 0), 7.0 - i * 1.2, Color(MARK, 0.12))
		_mark.draw_circle(Vector2(dir * i * 14.0, 0), 3.0 - i * 0.5, Color(MARK, 1.0 - i * 0.25))
