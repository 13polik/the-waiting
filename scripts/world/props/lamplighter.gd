extends Node2D
## The Lamplighter (0.7): tall, thin, in a long grey coat, with soft feathery
## feelers rising from the hood and a lantern hung from a crooked pole. Twice
## the creature's height. It appears where scripts/data/lamplighter_visits.gd
## says, says its piece once, and is gone until the next meeting.
## The body is drawn once; the lantern sways and the body breathes by
## transform only. Origin: floor contact, between the feet.

const Painter := preload("res://scripts/world/painter.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")
const Visits := preload("res://scripts/data/lamplighter_visits.gd")
const FLAG_TALKS := "lamp_talks"
const FLAG_LAST_DAY := "lamp_last_day"
const FLAG_RELIT := "scribe_lamp_lit"
const COAT := Color(0.28, 0.28, 0.3)
const COAT_DARK := Color(0.15, 0.15, 0.17)
const FEELER := Color(0.7, 0.66, 0.58)
const POLE_TOP := Vector2(64, -300)

var _t: float = 0.0
var _body: Node2D
var _lantern: Node2D
var _light: PointLight2D


## Index of the meeting that can happen in [param room_id] now, or -1.
static func due_visit(room_id: String) -> int:
	var i := int(WorldManager.get_flag(FLAG_TALKS, 0))
	if i < 0 or i >= Visits.VISITS.size():
		return -1
	var v: Dictionary = Visits.VISITS[i]
	if v["room"] != room_id or TimeManager.day_index() < int(v["day"]):
		return -1
	if v.get("complete", false) and not TimeManager.is_complete():
		return -1
	if v.has("needs") and not WorldManager.get_flag(v["needs"], false):
		return -1
	var last: Variant = WorldManager.get_flag(FLAG_LAST_DAY)
	if last != null and int(last) == TimeManager.day_index():
		return -1
	return i


static func talks() -> int:
	return int(WorldManager.get_flag(FLAG_TALKS, 0))


## The meeting [param index] is over: remember it, and what it changed.
static func finish_visit(index: int) -> void:
	WorldManager.set_flag(FLAG_TALKS, index + 1)
	WorldManager.set_flag(FLAG_LAST_DAY, TimeManager.day_index())
	if index == Visits.BOOK_AFTER:
		WorldManager.set_flag("lamp_book_left", true)
	if index == Visits.RELIGHT_AFTER:
		WorldManager.set_flag(FLAG_RELIT, true)


func _ready() -> void:
	_body = Node2D.new()
	_body.draw.connect(_draw_body.bind(_body))
	add_child(_body)
	_lantern = Node2D.new()
	_lantern.position = POLE_TOP + Vector2(18, 0)
	_lantern.draw.connect(_draw_lantern.bind(_lantern))
	add_child(_lantern)
	_light = LightTextures.make_light(Color(1.0, 0.78, 0.5), 0.75, 1.6)
	_light.position = Vector2(0, 46)
	_lantern.add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_body.scale.y = 1.0 + 0.012 * sin(_t * 1.1)
	_lantern.rotation = 0.07 * sin(_t * 0.9)
	_light.energy = 0.7 + 0.08 * sin(_t * 3.1) + 0.04 * sin(_t * 7.3)


## Leaves slowly, fading into the dark.
func depart() -> void:
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(self, "modulate:a", 0.0, 2.2)
	tw.tween_callback(queue_free)


func _draw_body(ci: Node2D) -> void:
	# Shadow.
	ci.draw_colored_polygon(Painter.ellipse(Vector2(6, 2), 44, 6, 20), Color(0, 0, 0, 0.35))
	# The pole: held in the right hand, crooked at the top.
	ci.draw_line(Vector2(46, 4), Vector2(58, -250), Color(0.12, 0.1, 0.09), 6.0, true)
	ci.draw_line(Vector2(46, 4), Vector2(58, -250), Color(0.42, 0.34, 0.26), 3.6, true)
	ci.draw_polyline(PackedVector2Array([Vector2(58, -250), Vector2(60, -290), POLE_TOP + Vector2(18, -4)]), Color(0.42, 0.34, 0.26), 3.6, true)
	# The long coat.
	var coat := PackedVector2Array([Vector2(-34, 0), Vector2(-30, -60), Vector2(-26, -130), Vector2(-28, -180),
		Vector2(-22, -210), Vector2(-4, -224), Vector2(18, -218), Vector2(28, -196), Vector2(26, -150),
		Vector2(30, -80), Vector2(36, 0)])
	Painter.gradient_polygon(ci, coat, -224, 0, COAT, COAT_DARK)
	# Ragged hem.
	var hem := PackedVector2Array()
	for i in 9:
		hem.append(Vector2(-34 + i * 8.75, -2 if i % 2 == 0 else 8))
	ci.draw_polyline(hem, Painter.INK, 1.6, true)
	# Folds.
	for x in [-14.0, 2.0, 18.0]:
		ci.draw_line(Vector2(x, -170), Vector2(x * 1.3, -6), Color(COAT_DARK, 0.8), 1.4, true)
	# The arm reaching to the pole.
	ci.draw_polyline(PackedVector2Array([Vector2(16, -170), Vector2(36, -140), Vector2(52, -150)]), COAT_DARK, 7.0, true)
	ci.draw_circle(Vector2(53, -150), 5.0, Color(0.55, 0.52, 0.48))
	ci.draw_polyline(Painter.closed(coat), Painter.INK, 2.0, true)
	# Hood and face.
	var hood := Painter.ellipse(Vector2(0, -240), 26, 30, 22)
	Painter.gradient_polygon(ci, hood, -270, -210, COAT.lightened(0.1), COAT_DARK)
	ci.draw_polyline(Painter.closed(hood), Painter.INK, 2.0, true)
	ci.draw_colored_polygon(Painter.ellipse(Vector2(6, -236), 15, 18, 18), Color(0.02, 0.02, 0.025))
	for e in [Vector2(1, -240), Vector2(12, -240)]:
		ci.draw_circle(e, 2.6, Color(0.95, 0.82, 0.55))
	# Feathery feelers, like a moth's.
	for side: float in [-1.0, 1.0]:
		var base := Vector2(side * 10.0, -266)
		var tip := base + Vector2(side * 34.0, -46)
		var mid := base + Vector2(side * 10.0, -34)
		ci.draw_polyline(PackedVector2Array([base, mid, tip]), FEELER, 1.6, true)
		for k in 7:
			var t := 0.25 + k * 0.1
			var p := base.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(tip, (t - 0.5) * 2.0)
			ci.draw_line(p, p + Vector2(side * 7.0, 3.0), Color(FEELER, 0.7), 1.0, true)
			ci.draw_line(p, p + Vector2(-side * 3.0, -6.0), Color(FEELER, 0.5), 1.0, true)


func _draw_lantern(ci: Node2D) -> void:
	ci.draw_line(Vector2.ZERO, Vector2(0, 26), Color(0.3, 0.26, 0.2), 1.6, true)
	var frame := PackedVector2Array([Vector2(-12, 26), Vector2(12, 26), Vector2(15, 50), Vector2(10, 66), Vector2(-10, 66), Vector2(-15, 50)])
	ci.draw_colored_polygon(frame, Color(1.0, 0.82, 0.5, 0.85))
	ci.draw_circle(Vector2(0, 48), 7.0, Color(1.0, 0.95, 0.75))
	ci.draw_polyline(Painter.closed(frame), Color(0.2, 0.16, 0.12), 2.0, true)
	ci.draw_line(Vector2(0, 26), Vector2(0, 66), Color(0.2, 0.16, 0.12, 0.8), 1.2, true)
	ci.draw_rect(Rect2(-13, 22, 26, 5), Color(0.25, 0.2, 0.15))
