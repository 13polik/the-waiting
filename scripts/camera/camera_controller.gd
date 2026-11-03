extends Camera2D
## CameraController — a calm side-view follow.
## Exponential smoothing (frame-rate independent), a look-ahead in the
## direction the creature faces that eases in slowly so turning never jerks
## the view, and clamping to the room so the edges never show. No shake.

var target
var bounds: Rect2 = Rect2(0, 0, 3200, 1100)
@export var follow_speed: float = 2.4
@export var lookahead: float = 90.0
## Puts the creature low in frame, leaving room above for the cave.
@export var vertical_offset: float = -150.0

var _look: float = 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	set_bounds(bounds)


## The room the camera may show (called again when the area changes).
func set_bounds(rect: Rect2) -> void:
	bounds = rect
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func snap_to_target() -> void:
	if target == null:
		return
	_look = target.facing * lookahead * 0.4
	position = _desired()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var moving := clampf(absf(target.velocity.x) / 95.0, 0.0, 1.0)
	_look = lerpf(_look, target.facing * lookahead * (0.4 + 0.6 * moving), 1.0 - exp(-1.1 * delta))
	position = position.lerp(_desired(), 1.0 - exp(-follow_speed * delta))


func _desired() -> Vector2:
	var p: Vector2 = target.global_position + Vector2(_look, vertical_offset)
	var half := get_viewport_rect().size * 0.5 / zoom
	if bounds.size.x > half.x * 2.0:
		p.x = clampf(p.x, bounds.position.x + half.x, bounds.end.x - half.x)
	else:
		p.x = bounds.get_center().x
	if bounds.size.y > half.y * 2.0:
		p.y = clampf(p.y, bounds.position.y + half.y, bounds.end.y - half.y)
	else:
		p.y = bounds.get_center().y
	return p
