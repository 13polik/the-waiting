extends Node2D
## The animated loading screen. It starts on exactly the frame of the static
## launch image (assets/splash/splash.png, rendered by tools/render_splash.gd
## with the same layout), so the hand-over is seamless — then it comes alive:
## the creature breathes and blinks, the lantern glow pulses, a few motes of
## dust drift through the light. Meanwhile the main menu loads in the
## background; when it is ready (and at least [constant MIN_TIME] has passed)
## the screen fades to black and the menu fades in. A tap or key skips it.

const Creature := preload("res://scripts/character/creature_visual.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")
const MENU := "res://scenes/main_menu.tscn"
## The splash image's layout, in its own pixels (see tools/render_splash.gd).
const SPLASH := Vector2(2048, 1152)
const GROUND := 150.0
const SCALE := 3.2
const BG := Color(0.02, 0.02, 0.027)
const MIN_TIME := 2.6
const MAX_TIME := 8.0

var _t: float = 0.0
var _leaving: bool = false
var _glow: Node2D
var _creature: Node2D
var _title: Label
var _dust: CPUParticles2D
## Development: "--intro-shots=<dir>" saves a few frames (to check motion).
var _shots_dir: String = ""
var _shot_times: Array = [0.5, 1.5, 2.5]


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	# Automated tests go straight to the menu, as before.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--selftest"):
			get_tree().change_scene_to_file.call_deferred(MENU)
			return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--intro-shots="):
			_shots_dir = arg.get_slice("=", 1)
	ResourceLoader.load_threaded_request(MENU)
	UIManager.set_game_ui_visible(false)
	UIManager.fade_in(0.01)  # No black: continue straight from the launch image.
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build() -> void:
	_glow = _Glow.new()
	add_child(_glow)
	_creature = Creature.new()
	add_child(_creature)
	_dust = CPUParticles2D.new()
	_dust.material = LightTextures.additive()
	_dust.amount = 18
	_dust.lifetime = 6.0
	_dust.preprocess = 0.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_dust.direction = Vector2(0.3, -1)
	_dust.spread = 50.0
	_dust.gravity = Vector2(0, -3)
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 9.0
	_dust.scale_amount_min = 1.2
	_dust.scale_amount_max = 2.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0.8, 0.95, 0.9, 0), Color(0.8, 0.95, 0.9, 0.5), Color(0.8, 0.95, 0.9, 0.4), Color(0.8, 0.95, 0.9, 0)])
	_dust.color_ramp = fade
	add_child(_dust)
	_title = Label.new()
	_title.text = "THE WAITING"
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.add_theme_font_override("font", UiStyle.title_font())
	_title.add_theme_color_override("font_color", Color(0.78, 0.8, 0.78, 0.85))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)


## Same place and size as on the static image, scaled to fit the screen.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var k := minf(vp.x / SPLASH.x, vp.y / SPLASH.y)
	var center := vp * 0.5
	var ground := Vector2(center.x, center.y + GROUND * k)
	_creature.position = ground
	_creature.scale = Vector2.ONE * SCALE * k
	_glow.k = k
	_glow.bulb = ground + Vector2(26.0, -128.0) * SCALE * k
	_glow.ground = ground
	_glow.queue_redraw()
	_dust.position = _glow.bulb
	_dust.emission_sphere_radius = 160.0 * k
	_dust.scale = Vector2.ONE * k * 2.0
	_title.add_theme_font_size_override("font_size", int(round(64.0 * k)))
	_title.size = Vector2(vp.x, 120.0 * k)
	_title.position = Vector2(0, ground.y + 90.0 * k)


func _process(delta: float) -> void:
	if _glow == null:
		return
	_t += delta
	# The lantern breathes, slower than the creature.
	_glow.modulate.a = 0.85 + 0.15 * sin(_t * 1.6)
	_title.modulate.a = 0.85 + 0.15 * sin(_t * 0.9 + 1.0)
	if not _shots_dir.is_empty() and not _shot_times.is_empty() and _t >= _shot_times[0]:
		_shot_times.pop_front()
		get_viewport().get_texture().get_image().save_png(_shots_dir.path_join("intro_%.2f.png" % _t))
	if _leaving:
		return
	var status := ResourceLoader.load_threaded_get_status(MENU)
	var ready := status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_FAILED
	if (_t >= MIN_TIME and ready) or _t >= MAX_TIME:
		_leave()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _t < 0.4:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	await UIManager.fade_out(0.7)
	var scene: Resource = null
	if ResourceLoader.load_threaded_get_status(MENU) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		scene = ResourceLoader.load_threaded_get(MENU)
	if scene is PackedScene:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(MENU)


class _Glow extends Node2D:
	var bulb: Vector2
	var ground: Vector2
	var k: float = 1.0

	func _draw() -> void:
		for i in 40:
			draw_circle(bulb, (12.0 + i * 9.0) * k, Color(0.75, 0.9, 0.86, 0.012))
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(ground + Vector2(cos(a) * 300.0, sin(a) * 26.0) * k)
		draw_colored_polygon(pts, Color(0.6, 0.72, 0.7, 0.06))
		draw_line(ground + Vector2(-520, 2) * k, ground + Vector2(520, 2) * k, Color(0.25, 0.27, 0.27, 0.35), maxf(1.0, 2.0 * k), true)
