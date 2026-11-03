extends Node
## AudioManager — buses, the sound library, ambience and rare distant events.
##
## Sounds are requested by name. A recorded res://audio/<name>.ogg (or .wav)
## always wins; otherwise the original synthesised version from Synth is used,
## cached to user://cache so it is only generated once per install.
##
## Buses: Music (music and the ambience under it), Ambience (low-passed, sends
## to Music), SFX (cave reverb with echo), Character (dry-ish).
## Volume groups for settings: "master", "music", "sfx" (SFX + Character).

const Synth := preload("res://scripts/audio/synth.gd")
const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"
const BUS_CHARACTER := "Character"
const CACHE_DIR := "user://cache"
const CACHE_VERSION := 1

var _streams: Dictionary = {}
var _players_2d: Array[AudioStreamPlayer2D] = []
var _players: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _event_timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup_buses()
	for i in 10:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 1800.0
		p.attenuation = 1.6
		add_child(p)
		_players_2d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS_AMBIENCE
	add_child(_ambience)
	_event_timer = Timer.new()
	_event_timer.one_shot = true
	_event_timer.timeout.connect(_on_event_timer)
	add_child(_event_timer)


## Linear 0..1 volume for a settings group.
func set_volume(group: String, linear: float) -> void:
	var buses: Array = {"master": ["Master"], "music": [BUS_MUSIC], "sfx": [BUS_SFX, BUS_CHARACTER]}.get(group, [])
	for bus_name: String in buses:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
			AudioServer.set_bus_mute(idx, linear <= 0.001)


## Starts the room tone with a slow fade-in. Generation is deferred one frame so
## the first picture appears before any synthesis work. Safe to call again.
func start_ambience() -> void:
	if _ambience.playing:
		return
	await get_tree().process_frame
	if _ambience.playing:
		return
	_ambience.stream = get_stream("drone")
	_ambience.volume_db = -60.0
	_ambience.play()
	create_tween().tween_property(_ambience, "volume_db", -9.0, 6.0)
	# Warm the cache for one-shots so the first footstep never hitches.
	for sound in ["step", "step_wet", "drip", "examine", "rumble", "knock", "chime", "pickup"]:
		get_stream(sound)
	if _event_timer.is_stopped():
		_schedule_event()


func get_stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var stream: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://audio/%s.%s" % [sound, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null and Synth.has(sound):
		stream = _load_or_generate(sound)
	_streams[sound] = stream
	return stream


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = BUS_SFX) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_at(sound: String, world_pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0, bus: String = BUS_SFX) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _free_player_2d()
	p.stream = stream
	p.global_position = world_pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


func _free_player_2d() -> AudioStreamPlayer2D:
	for p in _players_2d:
		if not p.playing:
			return p
	return _players_2d[0]


## Rare, distant happenings: stone settling, and — very rarely — knocking.
func _schedule_event() -> void:
	_event_timer.start(_rng.randf_range(45.0, 130.0))


func _on_event_timer() -> void:
	if _rng.randf() < 0.22:
		for i in 3:
			play("knock", -20.0 - i * 2.5, _rng.randf_range(0.92, 1.0))
			await get_tree().create_timer(0.72 + _rng.randf() * 0.1).timeout
	else:
		play("rumble", -17.0, _rng.randf_range(0.8, 1.1))
	_schedule_event()


func _load_or_generate(sound: String) -> AudioStream:
	var path := "%s/%s_v%d.res" % [CACHE_DIR, sound, CACHE_VERSION]
	if FileAccess.file_exists(path):
		var cached: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if cached is AudioStream:
			return cached
	var stream := Synth.generate(sound)
	if stream != null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
		ResourceSaver.save(stream, path)
	return stream


## How big the place sounds: reverb on effects and on the creature's own sounds.
const SPACES := {
	"home": {"room": 0.9, "wet": 0.42, "damp": 0.55, "near": 0.18},
	"tunnel": {"room": 0.55, "wet": 0.3, "damp": 0.75, "near": 0.26},
	"hall": {"room": 1.0, "wet": 0.6, "damp": 0.3, "near": 0.34},
	"garden": {"room": 0.7, "wet": 0.32, "damp": 0.7, "near": 0.16},
}


func set_space(space: String) -> void:
	var p: Dictionary = SPACES.get(space, SPACES["home"])
	var sfx := AudioServer.get_bus_index(BUS_SFX)
	if sfx >= 0 and AudioServer.get_bus_effect_count(sfx) > 0:
		var cave := AudioServer.get_bus_effect(sfx, 0) as AudioEffectReverb
		if cave != null:
			cave.room_size = p["room"]
			cave.wet = p["wet"]
			cave.damping = p["damp"]
	var ch := AudioServer.get_bus_index(BUS_CHARACTER)
	if ch >= 0 and AudioServer.get_bus_effect_count(ch) > 0:
		var near := AudioServer.get_bus_effect(ch, 0) as AudioEffectReverb
		if near != null:
			near.wet = p["near"]


func _setup_buses() -> void:
	_ensure_bus(BUS_MUSIC)
	var amb := _ensure_bus(BUS_AMBIENCE, BUS_MUSIC)
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2200.0
		AudioServer.add_bus_effect(amb, lp)

	var sfx := _ensure_bus(BUS_SFX)
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var cave := AudioEffectReverb.new()
		cave.room_size = 0.9
		cave.damping = 0.55
		cave.spread = 0.8
		cave.wet = 0.42
		cave.dry = 0.8
		cave.predelay_msec = 70.0
		cave.predelay_feedback = 0.3
		AudioServer.add_bus_effect(sfx, cave)

	var ch := _ensure_bus(BUS_CHARACTER)
	if AudioServer.get_bus_effect_count(ch) == 0:
		var near := AudioEffectReverb.new()
		near.room_size = 0.6
		near.damping = 0.7
		near.wet = 0.18
		near.dry = 0.95
		AudioServer.add_bus_effect(ch, near)


func _ensure_bus(bus_name: String, send: String = "Master") -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, send)
	return idx
