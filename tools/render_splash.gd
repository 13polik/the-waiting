extends SceneTree
## Renders the launch screen image (the creature, its lantern, the title) from
## the game's own drawing code into assets/splash/splash.png.
## Run windowed (it needs a renderer):
##   godot --path . --script res://tools/render_splash.gd

const Creature := preload("res://scripts/character/creature_visual.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SIZE := Vector2i(2048, 1152)
const BG := Color(0.02, 0.02, 0.027)
const OUT := "res://assets/splash/splash.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(SIZE)
	vp.add_child(bg)

	var center := Vector2(SIZE) * 0.5
	var ground_y := center.y + 150.0
	var scale := 3.2

	# The lantern's glow, and a faint pool of light on the ground.
	var glow := _Glow.new()
	glow.bulb = Vector2(center.x + 26.0 * scale, ground_y - 128.0 * scale)
	glow.ground = Vector2(center.x, ground_y)
	vp.add_child(glow)

	var creature := Creature.new()
	creature.position = Vector2(center.x, ground_y)
	creature.scale = Vector2(scale, scale)
	vp.add_child(creature)

	var title := Label.new()
	title.text = "THE WAITING"
	title.add_theme_font_override("font", UiStyle.title_font())
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.78, 0.8, 0.78, 0.85))
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(SIZE.x, 90)
	title.position = Vector2(0, ground_y + 90.0)
	vp.add_child(title)

	for i in 30:
		await process_frame
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := img.save_png(OUT)
	print("splash saved: %s (%dx%d) err=%d" % [OUT, img.get_width(), img.get_height(), err])
	quit(0 if err == OK else 1)


class _Glow extends Node2D:
	var bulb: Vector2
	var ground: Vector2

	func _draw() -> void:
		for i in 40:
			var r := 12.0 + i * 9.0
			draw_circle(bulb, r, Color(0.75, 0.9, 0.86, 0.012))
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(ground + Vector2(cos(a) * 300.0, sin(a) * 26.0))
		draw_colored_polygon(pts, Color(0.6, 0.72, 0.7, 0.06))
		draw_line(ground + Vector2(-520, 2), ground + Vector2(520, 2), Color(0.25, 0.27, 0.27, 0.35), 2.0, true)
