extends CharacterBody2D
## CharacterController — moves the Wick and carries its lantern.
##
## Two ways to move, sharing one acceleration model:
##  * keyboard axis (development / hardware keyboards on iPad);
##  * a target x set by touch ([method move_to_x]), approached with an
##    easing arrival, optionally running a callback on arrival.
## Movement is deliberately unhurried. Input is ignored while text is open.

const CreatureVisual := preload("res://scripts/character/creature_visual.gd")
const InteractionSystem := preload("res://scripts/interaction/interaction_system.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")
const ARRIVE_DISTANCE := 4.0

@export var max_speed: float = 95.0
@export var acceleration: float = 240.0
@export var deceleration: float = 380.0
@export var gravity: float = 1400.0

var facing: int = 1
var input_locked: bool = false
## The room the creature is in (set by main.gd).
var room
var visual: CreatureVisual
var lantern: PointLight2D
var interaction: InteractionSystem
var motes: CPUParticles2D

var _has_target: bool = false
var _target_x: float = 0.0
var _on_arrive: Callable
var _t: float = 0.0


func _ready() -> void:
	floor_snap_length = 18.0
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true

	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14.0
	capsule.height = 64.0
	shape.shape = capsule
	shape.position = Vector2(0, -32)
	add_child(shape)

	visual = CreatureVisual.new()
	visual.facing = facing
	visual.max_speed = max_speed
	visual.footstep.connect(_on_footstep)
	add_child(visual)

	visual.scale = Vector2(1.15, 1.15)

	lantern = LightTextures.make_light(Color(0.76, 0.92, 0.88), 1.4, 4.4)
	lantern.shadow_enabled = true
	lantern.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	lantern.shadow_filter_smooth = 3.0
	lantern.shadow_color = Color(0, 0, 0, 0.75)
	lantern.shadow_item_cull_mask = 1
	add_child(lantern)

	# A few motes turning in the lantern's light. World-space, so they drift
	# behind as the creature walks on.
	motes = CPUParticles2D.new()
	motes.material = LightTextures.additive()
	motes.local_coords = false
	motes.amount = 14
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 130.0
	motes.position = Vector2(0, -110)
	motes.gravity = Vector2(0, -0.6)
	motes.initial_velocity_min = 1.0
	motes.initial_velocity_max = 5.0
	motes.spread = 180.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 1.8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(0.85, 0.95, 0.92, 0), Color(0.85, 0.95, 0.92, 0.28), Color(0.85, 0.95, 0.92, 0.28), Color(0.85, 0.95, 0.92, 0)])
	motes.color_ramp = fade
	add_child(motes)

	interaction = InteractionSystem.new()
	interaction.actor = self
	add_child(interaction)

	WorldManager.register_player(self)
	UIManager.text_closed.connect(set_examining.bind(false))


## Walks to world x. [param on_arrive] runs once there (e.g. to examine).
func move_to_x(x: float, on_arrive: Callable = Callable()) -> void:
	_has_target = true
	_target_x = x
	_on_arrive = on_arrive


func stop() -> void:
	_has_target = false
	_on_arrive = Callable()


func face_toward(x: float) -> void:
	if absf(x - global_position.x) > 2.0:
		facing = 1 if x > global_position.x else -1


func set_examining(on: bool) -> void:
	visual.set_examining(on)


func is_moving() -> bool:
	return absf(velocity.x) > 2.0 or _has_target


func _notification(what: int) -> void:
	# Leaving the game frees the creature; nothing may keep pointing at it.
	if what == NOTIFICATION_PREDELETE and WorldManager.player == self:
		WorldManager.player = null


func _physics_process(delta: float) -> void:
	var locked := input_locked or UIManager.is_text_open()
	var axis := 0.0 if locked else Input.get_axis("move_left", "move_right")
	var desired := 0.0
	if axis != 0.0:
		stop()
		desired = axis * max_speed
	elif _has_target and not locked:
		var dx := _target_x - global_position.x
		if absf(dx) <= ARRIVE_DISTANCE:
			_arrive()
		else:
			desired = signf(dx) * minf(max_speed, absf(dx) * 2.4 + 14.0)

	var speeding_up := absf(desired) > absf(velocity.x) and (velocity.x == 0.0 or signf(desired) == signf(velocity.x))
	velocity.x = move_toward(velocity.x, desired, (acceleration if speeding_up else deceleration) * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()

	if _has_target and is_on_wall() and absf(get_real_velocity().x) < 3.0 and absf(desired) > 20.0:
		stop()  # Walked into a wall; the target is unreachable.
	if absf(desired) > 1.0:
		facing = 1 if desired > 0.0 else -1
	visual.update_motion(velocity.x, facing, delta)


func _process(delta: float) -> void:
	_t += delta
	lantern.position = visual.position + visual.get_bulb_position() * visual.scale
	var flicker := 0.035 * sin(_t * 7.3) + 0.025 * sin(_t * 12.7 + 1.3)
	lantern.energy = 1.4 + flicker + (0.25 if UIManager.is_text_open() else 0.0)


func _arrive() -> void:
	_has_target = false
	var cb := _on_arrive
	_on_arrive = Callable()
	if cb.is_valid():
		cb.call()


func _on_footstep() -> void:
	var wet := WorldManager.is_wet(global_position.x)
	AudioManager.play_at("step_wet" if wet else "step", global_position, -20.0 if not wet else -15.0,
		randf_range(0.85, 1.15), AudioManager.BUS_CHARACTER)
	if wet and room != null and room.pool != null:
		room.pool.splash()
