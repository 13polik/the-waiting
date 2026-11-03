extends RefCounted
## Original sounds synthesised at runtime. They are fallbacks: AudioManager
## prefers a recorded res://audio/<name>.ogg when one exists.
## Every generator is deterministic (fixed seeds) so results can be cached.

const RATE := 22050

const GENERATORS := {
	"drone": "_drone",
	"drip": "_drip",
	"step": "_step",
	"step_wet": "_step_wet",
	"rumble": "_rumble",
	"knock": "_knock",
	"examine": "_examine",
	"chime": "_chime",
	"pickup": "_pickup",
}


static func has(sound: String) -> bool:
	return GENERATORS.has(sound)


static func generate(sound: String) -> AudioStreamWAV:
	match sound:
		"drone": return _drone()
		"drip": return _drip()
		"step": return _step()
		"step_wet": return _step_wet()
		"rumble": return _rumble()
		"knock": return _knock()
		"examine": return _examine()
		"chime": return _chime()
		"pickup": return _pickup()
	return null


## The cave's breath: a low two-tone hum that beats slowly, and soft moving
## air. Frequencies complete whole cycles in 8 s and the noise is crossfaded,
## so it loops without a seam.
static func _drone() -> AudioStreamWAV:
	var rate := 16000
	var length := 8.0
	var n := int(rate * length)
	var fade := rate / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Noise is generated longer than the loop so its tail can be crossfaded.
	var noise := PackedFloat32Array()
	noise.resize(n + fade)
	var brown := 0.0
	var lp := 0.0
	var air := 0.0
	for i in n + fade:
		brown = clampf(brown + rng.randf_range(-1.0, 1.0) * 0.03, -1.0, 1.0) * 0.997
		lp += (brown - lp) * 0.04
		air += (rng.randf_range(-1.0, 1.0) - air) * 0.08
		noise[i] = lp * 0.9 + air * 0.05
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / rate
		var swell := 0.5 - 0.5 * cos(TAU * t / length)
		var tone := sin(TAU * 55.0 * t) * 0.20
		tone += sin(TAU * 82.5 * t + 0.7) * 0.10 * swell
		tone += sin(TAU * 110.25 * t) * 0.035 * (1.0 - swell)
		var nz := noise[i]
		if i < fade:
			var k := float(i) / fade
			nz = noise[i] * k + noise[n + i] * (1.0 - k)
		out[i] = tone + nz * (0.6 + 0.4 * swell)
	return _to_stream(_normalize(out, 0.7), rate, true)


## A single drop into still water.
static func _drip() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var t := float(i) / RATE
		var f := 700.0 + 1500.0 * exp(-t * 22.0)
		phase += TAU * f / RATE
		var v := sin(phase) * exp(-t * 13.0)
		if t < 0.004:
			v += rng.randf_range(-1.0, 1.0) * 0.4 * (1.0 - t / 0.004)
		out[i] = v
	return _to_stream(_normalize(out, 0.8), RATE, false)


## A small soft foot on grit.
static func _step() -> AudioStreamWAV:
	var n := int(RATE * 0.11)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.18
		var env := minf(1.0, t / 0.004) * exp(-t * 45.0)
		out[i] = lp * env
	return _to_stream(_normalize(out, 0.7), RATE, false)


static func _step_wet() -> AudioStreamWAV:
	var n := int(RATE * 0.2)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		phase += TAU * (420.0 + 500.0 * exp(-t * 30.0)) / RATE
		out[i] = lp * exp(-t * 35.0) * 0.8 + sin(phase) * exp(-t * 25.0) * 0.4
	return _to_stream(_normalize(out, 0.7), RATE, false)


## Stone settling somewhere far away.
static func _rumble() -> AudioStreamWAV:
	var length := 3.2
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = clampf(brown + rng.randf_range(-1.0, 1.0) * 0.05, -1.0, 1.0) * 0.998
		lp += (brown - lp) * 0.012
		var env := pow(sin(PI * t / length), 2.0) * (0.7 + 0.3 * sin(t * 9.0))
		out[i] = lp * env
	return _to_stream(_normalize(out, 0.8), RATE, false)


## A deep, distant knock. Played in threes by AudioManager.
static func _knock() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (48.0 + 30.0 * exp(-t * 18.0)) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
		out[i] = sin(phase) * exp(-t * 7.0) + lp * exp(-t * 30.0) * 0.6
	return _to_stream(_normalize(out, 0.8), RATE, false)


## A quiet, breathy hum the creature makes when it looks closely at something.
static func _examine() -> AudioStreamWAV:
	var length := 1.5
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.35) * exp(-maxf(0.0, t - 0.35) * 2.6)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.05
		var vib := 1.0 + 0.004 * sin(TAU * 5.0 * t)
		var v := sin(TAU * 196.0 * vib * t) * 0.5 + sin(TAU * 293.66 * vib * t) * 0.25
		v += sin(TAU * 392.0 * t) * 0.06
		out[i] = (v + lp * 0.8) * env
	return _to_stream(_normalize(out, 0.6), RATE, false)


## A hanging stone, struck: inharmonic partials with a long, clean decay.
static func _chime() -> AudioStreamWAV:
	var length := 3.0
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[392.0, 1.0, 1.6], [1004.0, 0.45, 2.6], [1717.0, 0.22, 4.0], [2603.0, 0.1, 6.0]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * p[0] * t) * p[1] * exp(-t * p[2])
		out[i] = v * minf(1.0, t / 0.003)
	return _to_stream(_normalize(out, 0.7), RATE, false)


## Something small taken into the satchel: a soft rising breath of two notes.
static func _pickup() -> AudioStreamWAV:
	var length := 0.9
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 523.25 if t < 0.22 else 659.25
		var env := minf(1.0, fmod(t, 0.22) / 0.03) * exp(-maxf(0.0, t - 0.22) * 4.0) if t >= 0.22 else minf(1.0, t / 0.03) * 0.7
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.05
		out[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.12 + lp * 0.4) * env
	return _to_stream(_normalize(out, 0.5), RATE, false)


static func _normalize(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for s in samples:
		m = maxf(m, absf(s))
	var k := peak / m
	for i in samples.size():
		samples[i] *= k
	return samples


static func _to_stream(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
