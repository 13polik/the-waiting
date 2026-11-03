extends Node2D
## A collectible lying in the world: the item itself, drawn once, and a slow
## glint above it (modulate only — no per-frame redraw). [method vanish] fades
## it out when it is picked up. Origin: where it rests.

const ItemArt := preload("res://scripts/world/item_art.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")

var item_id: String = ""
var _glint: Node2D
var _t: float = 0.0


func _ready() -> void:
	_glint = Node2D.new()
	_glint.material = LightTextures.additive()
	_glint.position = Vector2(4, -14)
	_glint.draw.connect(_draw_glint)
	add_child(_glint)
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	# A brief sparkle every few seconds: something here catches the light.
	var p := fmod(_t, 4.2)
	_glint.modulate.a = clampf(1.0 - absf(p - 0.6) / 0.6, 0.0, 1.0)
	_glint.rotation = _t * 0.6


func vanish() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)


func _draw() -> void:
	draw_colored_polygon(ItemArt.Painter.ellipse(Vector2(0, 2), 12, 2.5, 14), Color(0, 0, 0, 0.35))
	ItemArt.draw(self, item_id, Vector2(0, -6), 1.0)


func _draw_glint() -> void:
	var c := Color(0.9, 0.97, 0.95, 0.8)
	_glint.draw_line(Vector2(-5, 0), Vector2(5, 0), c, 1.2, true)
	_glint.draw_line(Vector2(0, -5), Vector2(0, 5), c, 1.2, true)
	_glint.draw_circle(Vector2.ZERO, 1.6, c)
