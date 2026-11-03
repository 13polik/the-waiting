extends Node2D
## The pale bloom, planted in the glowing moss of the Still Garden (0.4). It
## grows with real days: a mound, a shoot (day 2), a bud (day 5), an open,
## glowing flower (day 10). Redrawn only when the day changes.
## Origin: floor contact.

const LightTextures := preload("res://scripts/world/light_textures.gd")
const FLAG_PLANTED_DAY := "bloom_planted_day"
const STAGE_DAYS := [0, 2, 5, 10]

var _light: PointLight2D
var _t: float = 0.0


func _ready() -> void:
	material = LightTextures.unshaded()
	_light = LightTextures.make_light(Color(0.85, 0.95, 0.9), 0.0, 1.4)
	_light.position = Vector2(0, -70)
	add_child(_light)
	TimeManager.day_changed.connect(_on_day_changed)
	WorldManager.flag_changed.connect(func(key: String, _v: Variant) -> void:
		if key == FLAG_PLANTED_DAY:
			_on_day_changed(0))
	_on_day_changed(0)


## -1 not planted; 0 seed; 1 shoot; 2 bud; 3 open.
static func stage() -> int:
	var planted: Variant = WorldManager.get_flag(FLAG_PLANTED_DAY)
	if planted == null:
		return -1
	var days := TimeManager.day_index() - int(planted)
	var s := 0
	for i in STAGE_DAYS.size():
		if days >= STAGE_DAYS[i]:
			s = i
	return s


func _on_day_changed(_d: int) -> void:
	visible = stage() >= 0
	set_process(stage() == 3)
	_light.energy = 0.6 if stage() == 3 else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	# Only the open flower breathes, and only through modulate.
	_t += delta
	var p := 0.8 + 0.2 * sin(_t * 0.8)
	modulate = Color(p, p, p, 1.0)
	_light.energy = 0.45 + 0.2 * p


func _draw() -> void:
	var s := stage()
	if s < 0:
		return
	var green := Color(0.55, 0.7, 0.6)
	var pale := Color(0.92, 0.94, 0.9)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 2), Vector2(-8, -5), Vector2(8, -5), Vector2(14, 2)]), Color(0.18, 0.22, 0.18))
	if s == 0:
		draw_circle(Vector2(0, -6), 2.4, pale)
		return
	var h: float = [0.0, 24.0, 46.0, 64.0][s]
	var stem := PackedVector2Array()
	for i in 7:
		var k := float(i) / 6.0
		stem.append(Vector2(sin(k * 2.2) * 4.0 * k, -5.0 - h * k))
	draw_polyline(stem, green, 2.0, true)
	var top := stem[stem.size() - 1]
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, 20), top + Vector2(-12, 12), top + Vector2(-2, 16)]), Color(green, 0.85))
	if s == 1:
		draw_circle(top, 2.0, green)
	elif s == 2:
		draw_colored_polygon(PackedVector2Array([top + Vector2(-5, 2), top + Vector2(0, -12), top + Vector2(5, 2)]), pale.darkened(0.15))
	else:
		draw_circle(top, 20.0, Color(pale, 0.06))
		for i in 6:
			var a := TAU * i / 6.0 - PI * 0.5
			var c := top + Vector2.from_angle(a) * 8.0
			var petal := PackedVector2Array()
			for k in 12:
				var b := TAU * k / 12.0
				petal.append(c + Vector2(cos(b) * 6.5, sin(b) * 3.8).rotated(a))
			draw_colored_polygon(petal, pale)
		draw_circle(top, 3.2, Color(0.82, 0.88, 0.62))
