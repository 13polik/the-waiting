extends Node2D
## A smoothed patch of wall scratched with one mark per real day waited,
## in groups of five. Redraws when TimeManager reports a new day.
## Origin: centre of the panel.

const Painter := preload("res://scripts/world/painter.gd")
const Baker := preload("res://scripts/world/baker.gd")
const SCRATCH := Color(0.72, 0.70, 0.64, 0.92)
const GROUPS_PER_ROW := 10
const GROUP_W := 22.0
const ROW_H := 16.0

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false


func _ready() -> void:
	TimeManager.day_changed.connect(func(_d: int) -> void: Baker.rebake(self))


func mark_count() -> int:
	return clampi(TimeManager.day_index() + 1, 1, 400)


func bake_rect() -> Rect2:
	return Rect2(-150, -100, 300, 200)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	# A face of stone rubbed smooth: soft-edged, no outline, so it sits in the wall.
	for k in 4:
		var panel := Painter.blob(Vector2(-4, -6), 128 - k * 12, rng, 14, 0.06, 0.58)
		draw_colored_polygon(panel, Color(0.25, 0.24, 0.235, 0.22 + k * 0.08))

	var dark := PackedVector2Array()
	var light := PackedVector2Array()
	var origin := Vector2(-GROUPS_PER_ROW * GROUP_W * 0.5 + 4, -58)
	var n := mark_count()
	for i in n:
		var group := i / 5
		var in_group := i % 5
		var row := group / GROUPS_PER_ROW
		var col := group % GROUPS_PER_ROW
		var gx := origin.x + col * GROUP_W
		var gy := origin.y + row * ROW_H
		var mr := RandomNumberGenerator.new()
		mr.seed = 9000 + i
		var a: Vector2
		var b: Vector2
		if in_group < 4:
			var x := gx + in_group * 4.0 + mr.randf_range(-0.6, 0.6)
			a = Vector2(x + mr.randf_range(-1.0, 1.0), gy + mr.randf_range(-1.0, 1.0))
			b = Vector2(x + mr.randf_range(-1.2, 1.2), gy + 12.0 + mr.randf_range(-1.0, 1.0))
		else:
			a = Vector2(gx - 2.0, gy + 10.0)
			b = Vector2(gx + 15.0, gy + 2.0)
		dark.append(a)
		dark.append(b)
		light.append(a + Vector2(0.8, 0.9))
		light.append(b + Vector2(0.8, 0.9))
	draw_multiline(light, Color(0.06, 0.05, 0.05, 0.7), 1.8)
	draw_multiline(dark, SCRATCH, 2.0)
