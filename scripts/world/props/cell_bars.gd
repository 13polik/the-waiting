extends Node2D
## The dungeon's gate: thick stone-iron bars from floor to ceiling. Closed
## while the creature serves its day; when the day is over they slide up into
## the rock ([method open]). Origin: floor contact at the middle of the gate.
## Drawn once (a few polylines); opening moves the node, it never redraws.

const Painter := preload("res://scripts/world/painter.gd")

const HEIGHT := 360.0
const WIDTH := 150.0
const BARS := 5

var is_open: bool = false
var _grid: Node2D


func _ready() -> void:
	_grid = _Grid.new()
	add_child(_grid)
	if is_open:
		_grid.position.y = -HEIGHT + 30.0


## Slides the bars up; [param animate] false snaps them.
func open(animate: bool = true) -> void:
	if is_open and _grid != null and _grid.position.y < -1.0:
		return
	is_open = true
	if _grid == null:
		return
	if not animate:
		_grid.position.y = -HEIGHT + 30.0
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_grid, "position:y", -HEIGHT + 30.0, 4.0)


class _Grid extends Node2D:
	func _draw() -> void:
		var h: float = 360.0
		var w: float = 150.0
		var ink := Color(0.02, 0.02, 0.025)
		var metal := Color(0.24, 0.23, 0.25)
		var shine := Color(0.42, 0.4, 0.44, 0.55)
		for i in 5:
			var x := -w * 0.5 + w * float(i) / 4.0
			draw_line(Vector2(x, 8), Vector2(x, -h), ink, 15.0, true)
			draw_line(Vector2(x, 8), Vector2(x, -h), metal, 11.0, true)
			draw_line(Vector2(x - 3, 0), Vector2(x - 3, -h), shine, 2.0, true)
			# A pointed foot on each bar.
			draw_colored_polygon(PackedVector2Array([Vector2(x - 7, 4), Vector2(x + 7, 4), Vector2(x, 22)]), metal)
		for y in [-100.0, -270.0]:
			draw_line(Vector2(-w * 0.5 - 14, y), Vector2(w * 0.5 + 14, y), ink, 17.0, true)
			draw_line(Vector2(-w * 0.5 - 14, y), Vector2(w * 0.5 + 14, y), metal, 12.0, true)
