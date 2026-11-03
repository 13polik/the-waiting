extends Node2D
## The Wick: a small hooded creature in a ragged, ash-brown shroud, with a
## long stalk curving from its crown to a pale lantern-bulb.
##
## Animation:
##  * idle — slow breathing, an occasional blink, the stalk swaying;
##  * walk — two thin legs stepping under the hem, a gentle bob and lean,
##    the hem trailing, the stalk lagging behind on a spring;
##  * examine — leans in and lowers the bulb toward what it is looking at;
##  * turning — the body narrows through profile instead of flipping.
##
## Performance: the body, face, eyes and bulb are drawn once and animated by
## transform only (breath, bob, lean, turn, blink). Only the parts whose shape
## changes are redrawn: the hem and the stalk every frame, the legs while they
## move. Rebuilding draw commands every frame was the largest per-frame CPU
## cost in the game (see docs/PERFORMANCE.md).
## Origin: between the feet, on the ground. Faces +x when [member facing] is 1.

signal footstep

const BODY := Color(0.36, 0.325, 0.30)
const BODY_LIT := Color(0.46, 0.43, 0.40)
const BODY_SHADE := Color(0.20, 0.18, 0.18)
const INK := Color(0.04, 0.035, 0.045, 0.95)
const RIM := Color(0.74, 0.86, 0.83, 0.6)
const FACE := Color(0.025, 0.025, 0.03)
const EYE := Color(0.84, 0.90, 0.94)
const BULB := Color(0.92, 1.0, 0.97)
const STALK := Color(0.40, 0.37, 0.34)

const STALK_BASE := Vector2(-3, -83)
const TIP_REST := Vector2(26, -128)
const TIP_EXAMINE := Vector2(50, -100)
const STRIDE := 22.0
const EYE_LINE := Vector2(10.0, -68.5)
## The shroud above the hem; the hem strip below it is drawn live.
const BODY_TOP := [
	Vector2(21, -17), Vector2(18, -34), Vector2(16, -50), Vector2(19, -62), Vector2(15, -76),
	Vector2(5, -85), Vector2(-7, -86), Vector2(-18, -77), Vector2(-25, -58), Vector2(-28, -38), Vector2(-28, -18)]

var facing: int = 1
var max_speed: float = 95.0

var _speed: float = 0.0
var _walk: float = 0.0
var _examine: float = 0.0
var _examine_target: float = 0.0
var _face_blend: float = 1.0
var _phase: float = 0.0
var _t: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 2.5
var _tip: Vector2 = TIP_REST
var _tip_vel: Vector2 = Vector2.ZERO
var _xform: Transform2D = Transform2D.IDENTITY
var _legs_at_rest: bool = false

var _shadow: Node2D
var _legs: Node2D
var _body: Node2D
var _hem: Node2D
var _eyes: Node2D
var _stalk: Node2D
var _bulb: Node2D


func _ready() -> void:
	_face_blend = float(facing)
	_shadow = _part(self, _draw_shadow)
	_shadow.scale = Vector2(1.0, 0.18)
	_legs = _part(self, _draw_legs)
	_body = _part(self, _draw_body)
	_hem = _part(_body, _draw_hem)
	_eyes = _part(_body, _draw_eyes)
	_eyes.position = EYE_LINE
	_stalk = _part(_body, _draw_stalk)
	_bulb = _part(_body, _draw_bulb)
	_apply()


## Called by the controller every physics step.
func update_motion(velocity_x: float, new_facing: int, delta: float) -> void:
	var speed := absf(velocity_x)
	var accel := (speed - _speed) / maxf(delta, 0.0001)
	_speed = speed
	facing = new_facing
	# Accelerating forward throws the stalk back; stopping throws it forward.
	_tip_vel.x -= accel * 0.012


func set_examining(on: bool) -> void:
	_examine_target = 1.0 if on else 0.0


## Bulb position in this node's own space (unscaled); the owner applies the
## node's position and scale to place the lantern light.
func get_bulb_position() -> Vector2:
	return _xform * _tip


func _process(delta: float) -> void:
	_t += delta
	_face_blend = move_toward(_face_blend, float(facing), delta * 6.5)
	_examine = move_toward(_examine, _examine_target, delta * 2.2)
	var ratio := clampf(_speed / max_speed, 0.0, 1.0)
	_walk = move_toward(_walk, 1.0 if ratio > 0.04 else 0.0, delta * 5.0)

	var phase_before := _phase
	if ratio > 0.01:
		_phase += delta * _speed / STRIDE * PI
		if int(phase_before / PI) != int(_phase / PI):
			footstep.emit()
	else:
		# Settle the legs at the nearest rest pose.
		_phase = move_toward(_phase, round(_phase / PI) * PI, delta * 4.0)

	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.5, 7.0)
	_blink = maxf(0.0, _blink - delta)

	var target := TIP_REST.lerp(TIP_EXAMINE, _examine)
	target += Vector2(sin(_t * 0.9) * 2.0, sin(_t * 1.3 + 0.5) * 1.5)
	target += Vector2(0, absf(sin(_phase)) * 3.0 * _walk)
	var acc := (target - _tip) * 70.0 - _tip_vel * 8.5
	_tip_vel += acc * delta
	_tip += _tip_vel * delta

	_apply()
	_hem.queue_redraw()
	_stalk.queue_redraw()
	var resting := _walk <= 0.0 and _phase == phase_before
	if not (resting and _legs_at_rest):
		_legs.queue_redraw()
	_legs_at_rest = resting


## Pushes the pose into the parts' transforms (cheap: no redraw).
func _apply() -> void:
	var fb := _face_blend
	if absf(fb) < 0.18:
		fb = 0.18 * (1.0 if fb >= 0.0 else -1.0)
	var dir := 1.0 if fb > 0.0 else -1.0
	var ratio := clampf(_speed / max_speed, 0.0, 1.0)
	var breath := sin(_t * 1.25) * 0.018 * (1.0 - _walk * 0.6)
	var bob := absf(sin(_phase)) * 2.2 * _walk
	var lean := (0.05 * ratio + 0.09 * _examine) * dir
	_xform = Transform2D(lean, Vector2(fb, 1.0 + breath), 0.0, Vector2(0, -bob))
	_body.transform = _xform
	_legs.scale = Vector2(fb, 1.0)
	_eyes.scale = Vector2(1.0, 1.0 if _blink <= 0.0 else 0.15)
	_bulb.position = _tip


func _part(parent: Node, paint: Callable) -> Node2D:
	var n := Node2D.new()
	n.use_parent_material = true
	n.draw.connect(paint.bind(n))
	parent.add_child(n)
	return n


# --- Parts ---------------------------------------------------------------------

func _draw_shadow(ci: Node2D) -> void:
	ci.draw_circle(Vector2.ZERO, 28.0, Color(0, 0, 0, 0.35))


## Legs stay planted on the ground; only the body bobs.
func _draw_legs(ci: Node2D) -> void:
	var legs := PackedVector2Array()
	for i in 2:
		var ph := _phase + i * PI
		var hip := Vector2(5.0 if i == 0 else -7.0, -15.0)
		var foot := Vector2(hip.x + sin(ph) * 9.0 * _walk, -maxf(0.0, -cos(ph)) * 5.0 * _walk)
		var knee := (hip + foot) * 0.5 + Vector2(3.0, -1.5)
		legs.append_array([hip, knee, knee, foot, foot, foot + Vector2(4.5, 0.5)])
	ci.draw_multiline(legs, INK, 2.6)


## Drawn once: everything on the shroud above the hem.
func _draw_body(ci: Node2D) -> void:
	var top := PackedVector2Array(BODY_TOP)
	# Closed a little below the hem line so the live hem strip overlaps it.
	var fill := top.duplicate()
	fill.append(Vector2(-27, -13))
	fill.append(Vector2(21, -13))
	ci.draw_colored_polygon(fill, BODY_SHADE)
	# The side toward the lantern is lit.
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(19, -18), Vector2(16, -36), Vector2(14, -50), Vector2(17, -62), Vector2(13, -75), Vector2(4, -83),
		Vector2(-6, -84), Vector2(-14, -76), Vector2(-15, -58), Vector2(-10, -38), Vector2(-4, -20)]), BODY)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(12, -74), Vector2(4, -81), Vector2(-6, -82), Vector2(-10, -74), Vector2(-2, -66), Vector2(9, -63)]), BODY_LIT)
	# Charcoal hatching down the shadowed back, and folds in the shroud.
	var strokes := PackedVector2Array()
	for k in 7:
		var y := -70.0 + k * 8.0
		strokes.append(Vector2(-24.0 + k * 0.4, y))
		strokes.append(Vector2(-17.0 + k * 0.4, y + 6.0))
	ci.draw_multiline(strokes, Color(0.05, 0.045, 0.05, 0.4), 1.0)
	ci.draw_multiline(PackedVector2Array([Vector2(4, -60), Vector2(2, -40), Vector2(2, -40), Vector2(5, -20),
		Vector2(-12, -56), Vector2(-14, -34), Vector2(-14, -34), Vector2(-12, -16)]), Color(INK, 0.4), 1.2)
	# The hood opening.
	var face := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		face.append(Vector2(10.5, -67.0) + Vector2(cos(a) * 6.5, sin(a) * 9.5).rotated(0.25))
	ci.draw_colored_polygon(face, FACE)
	ci.draw_polyline(top, INK, 2.0, true)
	# Rim light down the front and along the crown, from the bulb above.
	ci.draw_polyline(PackedVector2Array([Vector2(19, -24), Vector2(16, -40), Vector2(15, -52), Vector2(18, -62)]), Color(RIM, 0.3), 1.2, true)
	ci.draw_polyline(PackedVector2Array([Vector2(-14, -78), Vector2(-6, -85), Vector2(5, -84), Vector2(14, -76)]), RIM, 1.4, true)


## Drawn live: the ragged hem sways and trails behind when walking.
func _draw_hem(ci: Node2D) -> void:
	var ratio := clampf(_speed / max_speed, 0.0, 1.0)
	var sway := sin(_t * 1.7) * 1.2
	var trail := -ratio * 4.0
	var edge := PackedVector2Array([Vector2(-28, -18)])
	for k in 9:
		var f := float(k) / 8.0
		var hx := lerpf(-28.0, 22.0, f) + trail * (1.0 - f) + sway * sin(_t * 2.1 + k)
		var hy := -10.0 - (5.0 if k % 2 == 1 else 0.0) + sin(_t * 2.6 + k * 1.3) * 0.8
		edge.append(Vector2(hx, hy))
	edge.append(Vector2(21, -17))
	var strip := edge.duplicate()
	strip.append(Vector2(21, -19))
	strip.append(Vector2(-28, -20))
	ci.draw_colored_polygon(strip, BODY_SHADE)
	ci.draw_polyline(edge, INK, 2.0, true)


## Drawn once; blinking squashes this node vertically.
func _draw_eyes(ci: Node2D) -> void:
	for e in [Vector2(12.5, -69.0), Vector2(7.5, -68.0)]:
		var eye := PackedVector2Array()
		for k in 6:
			var a := TAU * k / 6.0
			eye.append(e - EYE_LINE + Vector2(cos(a), sin(a)) * 1.7)
		ci.draw_colored_polygon(eye, EYE)


## Drawn live: the stalk bends with its spring.
func _draw_stalk(ci: Node2D) -> void:
	var ctrl := STALK_BASE + Vector2(-6, -34)
	var stalk := PackedVector2Array()
	for k in 11:
		var f := float(k) / 10.0
		stalk.append(STALK_BASE.lerp(ctrl, f).lerp(ctrl.lerp(_tip, f), f))
	ci.draw_polyline(stalk, INK, 4.2, true)
	ci.draw_polyline(stalk, STALK, 2.2, true)
	# Thicker where it grows from the crown.
	ci.draw_line(stalk[0], stalk[3], STALK, 3.0, true)


## Drawn once; moved to the stalk's tip each frame.
func _draw_bulb(ci: Node2D) -> void:
	ci.draw_circle(Vector2.ZERO, 14.0, Color(BULB, 0.08))
	ci.draw_circle(Vector2.ZERO, 7.5, Color(BULB, 0.3))
	ci.draw_circle(Vector2.ZERO, 4.6, BULB)
	ci.draw_arc(Vector2.ZERO, 4.9, 0.0, TAU, 18, Color(INK, 0.55), 1.1, true)
