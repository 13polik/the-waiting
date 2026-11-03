extends Node2D
## The main menu. Behind it is the real home cave: the creature resting at its
## nest, the lantern breathing, the camera drifting slowly, the pool dripping.
## In front, a single column: the title, a line of poetry, and five quiet
## choices. Nothing here writes to the save; only New Game (after asking)
## and Continue lead into a game session.

const CaveRoom := preload("res://scripts/world/cave_room.gd")
const CreatureVisual := preload("res://scripts/character/creature_visual.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")
const ScreenEffects := preload("res://scripts/world/screen_effects.gd")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
const WaitingButton := preload("res://scripts/ui/waiting_button.gd")
const SettingsScreen := preload("res://scripts/ui/settings_screen.gd")
const CreditsScreen := preload("res://scripts/ui/credits_screen.gd")
const ConfirmDialog := preload("res://scripts/ui/confirm_dialog.gd")
const ModsScreen := preload("res://scripts/ui/mods_screen.gd")
const Loc := preload("res://scripts/core/loc.gd")
const GAME_SCENE := "res://scenes/main.tscn"

var room: CaveRoom
var camera: Camera2D
var ui: CanvasLayer
var column: VBoxContainer
var continue_button: Button
var new_button: Button
var status_label: Label
var _creature: Node2D
var _lantern: PointLight2D
var _t: float = 0.0
var _busy: bool = false


func _ready() -> void:
	# Old automated tests launch straight into the game.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--selftest") and not arg.begins_with("--selftest-menu"):
			get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
			return

	_build_background()
	_build_ui()
	UIManager.set_game_ui_visible(false)
	UIManager.fade_in(1.6)
	AudioManager.start_ambience()
	_refresh_status()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--selftest-menu") and not get_tree().root.has_node("MenuSelfTest"):
			var test: Node = load("res://scripts/dev/self_test_menu.gd").new()
			test.name = "MenuSelfTest"
			get_tree().root.add_child.call_deferred(test)
			break


func _process(delta: float) -> void:
	if camera == null:
		return
	_t += delta
	# A slow drift along the wall, about a minute each way.
	camera.position = Vector2(700.0 + sin(_t * 0.05) * 90.0, 650.0 + sin(_t * 0.031) * 10.0)
	_lantern.position = _creature.position + _creature.get_bulb_position() * _creature.scale
	_lantern.energy = 1.25 + 0.05 * sin(_t * 7.1) + 0.03 * sin(_t * 12.3)


func _build_background() -> void:
	room = CaveRoom.new()
	add_child(room)
	# The cave's glimmers invite examining; in the menu they would only distract.
	for it in WorldManager.interactables:
		it.visible = false
		it.set_process(false)

	_creature = CreatureVisual.new()
	_creature.facing = -1
	_creature.scale = Vector2(1.15, 1.15)
	_creature.position = Vector2(1010, room.floor_y(1010) - 1.0)
	room.actor_layer.add_child(_creature)
	_lantern = LightTextures.make_light(Color(0.76, 0.92, 0.88), 1.25, 4.4)
	_lantern.shadow_enabled = true
	_lantern.shadow_item_cull_mask = 1
	room.actor_layer.add_child(_lantern)

	var dust := CPUParticles2D.new()
	dust.material = LightTextures.additive()
	dust.amount = 28
	dust.lifetime = 16.0
	dust.preprocess = 16.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(520, 260)
	dust.position = Vector2(900, 560)
	dust.gravity = Vector2(1.0, 1.2)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(0.8, 0.86, 0.9, 0), Color(0.8, 0.86, 0.9, 0.22), Color(0.8, 0.86, 0.9, 0.22), Color(0.8, 0.86, 0.9, 0)])
	dust.color_ramp = fade
	room.add_child(dust)

	camera = Camera2D.new()
	camera.position = Vector2(700, 650)
	add_child(camera)
	camera.make_current()
	room.set_camera(camera)
	add_child(ScreenEffects.new())


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var root := Control.new()
	root.name = "MenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Darkness pooled on the left, where the words sit.
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.86), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.62
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	column = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 2)
	column.anchor_left = 0.0
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.offset_left = 110
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(column)

	var title := UiStyle.title("THE WAITING", 58)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(title)
	var tagline := UiStyle.label("MENU_TAGLINE", 19, UiStyle.DIM)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 38
	column.add_child(gap)

	continue_button = _menu_button("MENU_CONTINUE", _on_continue)
	continue_button.name = "Continue"
	status_label = UiStyle.label("", 15, UiStyle.FAINT, false)
	status_label.name = "Status"
	column.add_child(status_label)
	new_button = _menu_button("MENU_NEW_GAME", _on_new_game)
	new_button.name = "NewGame"
	_menu_button("MENU_SETTINGS", _open.bind(SettingsScreen)).name = "Settings"
	_menu_button("MENU_MODS", _open.bind(ModsScreen)).name = "Mods"
	_menu_button("MENU_CREDITS", _open.bind(CreditsScreen)).name = "Credits"
	# iOS apps must not quit themselves; the button exists on desktop only.
	if SettingsManager.is_desktop():
		_menu_button("MENU_EXIT", _on_exit).name = "Exit"

	var version := UiStyle.label("v" + str(ProjectSettings.get_setting("application/config/version")), 13, UiStyle.FAINT, false)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -24
	version.offset_bottom = -16
	root.add_child(version)

	SettingsManager.changed.connect(func(_k: String) -> void: UiStyle.rescale(ui))

	# The column rises out of the dark, one line after another.
	var delay := 0.5
	for c in column.get_children():
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(c, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		delay += 0.12
	await get_tree().create_timer(0.6).timeout
	(continue_button if not continue_button.disabled else new_button).grab_focus()


func _menu_button(key: String, cb: Callable) -> Button:
	var b := WaitingButton.make(key, 27)
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(320, 54)
	column.add_child(b)
	return b


func _refresh_status() -> void:
	var can := SaveManager.has_continuable_save()
	continue_button.disabled = not can
	continue_button.focus_mode = Control.FOCUS_ALL if can else Control.FOCUS_NONE
	if can:
		status_label.text = Loc.t("MENU_SAVE_STATUS") % (TimeManager.day_index() + 1)
	elif SaveManager.blocked_newer_save:
		status_label.text = Loc.t("MENU_SAVE_TOO_NEW")
	else:
		status_label.text = ""
	status_label.visible = not status_label.text.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and status_label != null:
		_refresh_status()


func _open(screen_script: Script) -> Node:
	if _busy or ui.get_child_count() > 1:
		return null
	var s: Control = screen_script.new()
	ui.add_child(s)
	s.closed.connect(_on_overlay_closed)
	return s


func _on_overlay_closed() -> void:
	await get_tree().process_frame
	(continue_button if not continue_button.disabled else new_button).grab_focus()


func _on_continue() -> void:
	if _busy or not SaveManager.has_continuable_save():
		return
	_busy = true
	UIManager.transition_to(GAME_SCENE)


func _on_new_game() -> void:
	if _busy:
		return
	var existing := SaveManager.has_continuable_save() or SaveManager.blocked_newer_save
	if not existing:
		_begin_new_game()
		return
	var dlg: Node = _open(ConfirmDialog)
	if dlg == null:
		return
	dlg.title_key = "CONFIRM_NEW_TITLE"
	dlg.body = ["CONFIRM_NEW_BODY", TimeManager.day_index() + 1]
	dlg.confirmed.connect(_begin_new_game)


func _begin_new_game() -> void:
	if _busy:
		return
	_busy = true
	SaveManager.start_new_game()
	UIManager.transition_to(GAME_SCENE)


func _on_exit() -> void:
	_busy = true
	await UIManager.fade_out(0.6)
	get_tree().quit()
