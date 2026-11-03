extends Node2D
## Something in the world the creature can examine.
##
## Draws its own quiet prompt glyph: a faint glimmer while never examined,
## and a soft ring when the creature is close enough. Text comes from
## [member first_lines] / [member repeat_lines], or from [member dynamic_lines]
## (a Callable(count: int) -> Array) for things that change. Lines and
## [member title] are Loc entries (translation keys), resolved when shown.
## [method ping] gives a brief ring of feedback when an examination begins.

const LightTextures := preload("res://scripts/world/light_textures.gd")

var object_id: String = ""
var title: String = ""
var first_lines: Array = []
var repeat_lines: Array = []
var dynamic_lines: Callable
## Optional: Callable(count: int) run after the text is chosen — for things
## that act (a chime that rings, an item that is picked up or placed).
var on_examined: Callable
## Horizontal distance at which the creature can examine it.
var radius: float = 110.0
## Tap target, centred on [member hit_offset] from the origin.
var hit_size: Vector2 = Vector2(170, 170)
var hit_offset: Vector2 = Vector2(0, -70)
## How far to the side of the object the creature stands to look at it.
var stand_distance: float = 70.0
var prompt_offset: Vector2 = Vector2(0, -150)

## 1 while the creature is in range; set by InteractionSystem.
var highlight: float = 0.0
var _shown: float = 0.0
var _ping: float = 0.0
var _t: float = 0.0
var _glyph: Node2D
var _pulse: Node2D
var _ping_ring: Node2D

const GLYPH := Color(0.82, 0.92, 0.9)


func _ready() -> void:
	material = LightTextures.unshaded()
	z_index = 40
	_build_glyph()
	WorldManager.register_interactable(self)
	tree_exiting.connect(WorldManager.unregister_interactable.bind(self))


func get_examine_lines(count: int) -> Array:
	if dynamic_lines.is_valid():
		return dynamic_lines.call(count)
	if count <= 1 or repeat_lines.is_empty():
		return first_lines
	return [repeat_lines[(count - 2) % repeat_lines.size()]]


func ping() -> void:
	_ping = 1.0


func contains_point(world_pos: Vector2) -> bool:
	return Rect2(global_position + hit_offset - hit_size * 0.5, hit_size).has_point(world_pos)


## Where to stand, on whichever side the creature approaches from.
func stand_x_from(from_x: float) -> float:
	var side := -1.0 if from_x < global_position.x else 1.0
	return global_position.x + side * stand_distance


func _process(delta: float) -> void:
	_t += delta
	var target := highlight
	if target == 0.0 and WorldManager.examine_count(object_id) == 0:
		target = 0.28
	_shown = move_toward(_shown, target, delta * 1.6)
	_ping = maxf(0.0, _ping - delta * 1.4)
	# Everything below changes transforms and modulate only: the glyph is
	# drawn once, so animating it costs no draw-command rebuilds.
	_glyph.visible = _shown > 0.001
	if _glyph.visible:
		_glyph.position = prompt_offset + Vector2(0, sin(_t * 1.4) * 3.0)
		_glyph.modulate.a = _shown
		_pulse.scale = Vector2.ONE * (1.0 + 0.15 * sin(_t * 2.0))
	_ping_ring.visible = _ping > 0.0
	if _ping_ring.visible:
		_ping_ring.position = prompt_offset
		_ping_ring.scale = Vector2.ONE * lerpf(0.19, 1.0, 1.0 - _ping)
		_ping_ring.modulate.a = _ping * _ping


func _build_glyph() -> void:
	_glyph = _drawn_child(func(ci: Node2D) -> void:
		ci.draw_circle(Vector2.ZERO, 14.0, Color(GLYPH, 0.05))
		ci.draw_circle(Vector2.ZERO, 2.2, Color(GLYPH, 0.85)))
	add_child(_glyph)
	_pulse = _drawn_child(func(ci: Node2D) -> void:
		ci.draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 28, Color(GLYPH, 0.35), 1.2, true))
	_glyph.add_child(_pulse)
	_ping_ring = _drawn_child(func(ci: Node2D) -> void:
		ci.draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 48, Color(GLYPH, 0.5), 1.8, true))
	add_child(_ping_ring)
	_glyph.visible = false
	_ping_ring.visible = false


func _drawn_child(paint: Callable) -> Node2D:
	var n := Node2D.new()
	n.use_parent_material = true
	n.draw.connect(paint.bind(n))
	return n
