extends Node2D
## Flat stones hanging on long cords. [method strike] swings them and rings
## them, one after another; the swing is a rotation tween (no redraw).
## Origin: the point on the floor beneath them.

const Painter := preload("res://scripts/world/painter.gd")

signal rung

## [x, y of the stone's top, radius]
const STONES := [[-46.0, -330.0, 15.0], [-8.0, -300.0, 18.0], [34.0, -345.0, 13.0]]
const CORD := 900.0

var _hangers: Array[Node2D] = []


func _ready() -> void:
	for i in STONES.size():
		var spec: Array = STONES[i]
		var h := Node2D.new()
		# Pivot at the top of the cord, far above; the stone hangs CORD below.
		h.position = Vector2(spec[0], spec[1] - CORD)
		h.draw.connect(_draw_hanger.bind(h, i))
		add_child(h)
		_hangers.append(h)


func strike() -> void:
	for i in _hangers.size():
		var h := _hangers[i]
		var tw := create_tween()
		tw.tween_interval(i * 0.55)
		tw.tween_callback(func() -> void:
			AudioManager.play_at("chime", global_position + Vector2(0, -300), -8.0, [1.0, 1.26, 0.84][i]))
		tw.tween_property(h, "rotation", 0.03 * (1.0 if i % 2 == 0 else -1.0), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(h, "rotation", -0.015, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(h, "rotation", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	rung.emit()


## Cord from far above, then the stone: drawn once, swung by rotation.
func _draw_hanger(h: Node2D, i: int) -> void:
	var spec: Array = STONES[i]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8100 + i
	h.draw_line(Vector2.ZERO, Vector2(0, CORD), Color(0.16, 0.14, 0.12), 1.6, true)
	var c := Vector2(0, CORD + float(spec[2]))
	Painter.stone(h, c, spec[2], rng, Color(0.30, 0.29, 0.28), 1.3, 1.7)
	h.draw_circle(Vector2(0, CORD), 2.0, Color(0.1, 0.09, 0.08))
