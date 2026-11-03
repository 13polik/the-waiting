extends Node2D
## A cave chamber, built from data. Subclasses set the shape and look in
## [method _configure], add their props in [method _add_props], and list
## their lights in [method _light_specs]; everything else is shared:
## geometry, the hand-inked painting, baking, collision, exits.
##
## Layers, back to front:
##   back wall (parallax 0.93) → rock masses and stalagmites → props →
##   actors → foreground silhouettes (parallax 1.14).
## Painted layers are baked into textures once (see _bake, Baker).

const Painter := preload("res://scripts/world/painter.gd")
const PaintChunk := preload("res://scripts/world/paint_chunk.gd")
const DepthLayer := preload("res://scripts/world/parallax_layer.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")
const Interactable := preload("res://scripts/interaction/interactable.gd")
const Baker := preload("res://scripts/world/baker.gd")
const Exit := preload("res://scripts/world/exit.gd")
const ItemProp := preload("res://scripts/world/props/item_prop.gd")
const Items := preload("res://scripts/data/items.gd")
const Loc := preload("res://scripts/core/loc.gd")

## Fires when the creature walks into an open exit.
signal exit_reached(to_room: String, to_entry: String)
signal baked

const CHUNK_W := 640.0
const CELL_W := 160.0
const SAMPLE_STEP := 8.0
## Light-mask bit for rock that is lit but never shadowed by its own occluder.
const MASK_NO_SHADOW := 2

# --- Configuration (set in _configure) ----------------------------------------
var room_id: String = ""
var title_key: String = ""
var bounds: Rect2 = Rect2(0, 0, 3200, 1100)
var left_limit: float = 330.0
var right_limit: float = 3005.0
var spawn_x: float = 1000.0
var floor_keys: Array[Vector2] = []
var ceil_keys: Array[Vector2] = []
var noise_seed: int = 4001
var floor_noise: float = 6.0
var ceil_noise: float = 22.0
## Narrow slots straight up through the ceiling (x positions).
var ceiling_slots: Array[float] = []
## [x, half_width]: no random stalactites here.
var spike_clear: Array = []
## [x, width, length]: specific stalactites.
var hero_spikes: Array = []
## [x, width, height]: stalagmites with shadow occluders.
var stalagmites: Array = []
## [centre_x, top_y, half_width]: dark rock humps in the foreground.
var fg_humps: Array = []
## [x, length, width]: dark stalactites in the foreground.
var fg_spikes: Array = []
var modulate_color: Color = Color(0.30, 0.31, 0.37)
var stone: Color = Color(0.20, 0.192, 0.20)
var wash_top: Color = Color(0.10, 0.10, 0.12)
var wash_bottom: Color = Color(0.17, 0.16, 0.165)
var strata: Color = Color(0.19, 0.18, 0.19, 0.5)
var mass_top: Color = Color(0.15, 0.142, 0.14)
var mass_deep: Color = Color(0.035, 0.033, 0.04)
var lip: Color = Color(0.38, 0.36, 0.33, 0.55)
var wall_ink: Color = Color(0.03, 0.028, 0.036, 0.5)
var silhouette: Color = Color(0.012, 0.012, 0.016)
## Reverb preset for AudioManager.set_space.
var sound_space: String = "home"
## entry id → {"x": float, "facing": int}
var entries: Dictionary = {}
## Each: {"id", "x0", "x1", "to_room", "to_entry", "flag" (optional: opens when set)}
var exit_specs: Array = []

# --- Built ----------------------------------------------------------------------
var actor_layer: Node2D
var props_layer: Node2D
var pool: Node2D = null
var exits: Array = []
var is_ready_to_show: bool = false
## Texture memory used by baked chunks.
var baked_texture_bytes: int = 0
var paint_min_x: float = -400.0
var paint_max_x: float = 3600.0

var _floor: PackedFloat32Array = []
var _ceil: PackedFloat32Array = []
var _noise := FastNoiseLite.new()
var _parallax: Array = []
var _bake_queue: Array = []
var _props_to_bake: Array = []


## Subclasses: set the configuration variables above.
func _configure() -> void:
	pass


## Subclasses: add props and interactables to [param parent].
func _add_props(_parent: Node) -> void:
	pass


## Subclasses: [[position, color, energy, scale], ...].
func _light_specs() -> Array:
	return []


func _ready() -> void:
	_configure()
	paint_min_x = bounds.position.x - 400.0
	paint_max_x = bounds.end.x + 400.0
	WorldManager.clear_room()
	WorldManager.current_room = room_id
	_noise.seed = noise_seed
	_noise.frequency = 1.0 / 220.0
	_sample_geometry()

	var dark := CanvasModulate.new()
	dark.color = modulate_color
	add_child(dark)

	var back := _add_parallax(0.93)
	_add_chunks(back, _paint_back_wall)
	_add_chunks(back, _paint_haze)

	var masses := Node2D.new()
	add_child(masses)
	# Floor and roof are lit but take no shadows: shadows fall on the back wall.
	_add_chunks(masses, _paint_masses, MASK_NO_SHADOW)
	for side in [-1.0, 1.0]:
		var wall := PaintChunk.new()
		wall.painter = _paint_side_wall.bind(side)
		wall.light_mask = MASK_NO_SHADOW
		if side < 0:
			wall.region = Rect2(paint_min_x, 0, left_limit + 70.0 - paint_min_x, bounds.size.y)
		else:
			wall.region = Rect2(right_limit - 105.0, 0, paint_max_x - right_limit + 105.0, bounds.size.y)
		masses.add_child(wall)
		_bake_queue.append(wall)
	_add_stalagmites(masses)

	props_layer = Node2D.new()
	props_layer.name = "Props"
	add_child(props_layer)
	_add_props(props_layer)
	_add_exits(props_layer)

	actor_layer = Node2D.new()
	actor_layer.name = "Actors"
	add_child(actor_layer)

	var front := _add_parallax(1.14)
	_add_chunks(front, _paint_foreground, 1, LightTextures.unshaded())

	_add_collision()
	for s in _light_specs():
		var l := LightTextures.make_light(s[1], s[2], s[3])
		l.position = s[0]
		add_child(l)
	if Baker.enabled():
		_bake.call_deferred()
	else:
		is_ready_to_show = true


func set_camera(camera: Camera2D) -> void:
	for layer in _parallax:
		layer.camera = camera


func walkable_range() -> Vector2:
	return Vector2(left_limit + 16.0, right_limit - 16.0)


func floor_y(x: float) -> float:
	return _sample(_floor, x)


func ceil_y(x: float) -> float:
	return _sample(_ceil, x)


## Where the creature appears when arriving through [param entry_id].
func entry(entry_id: String) -> Dictionary:
	if entries.has(entry_id):
		return entries[entry_id]
	return {"x": spawn_x, "facing": 1}


## The open exit whose tap area contains [param world_pos], if any.
func exit_at(world_pos: Vector2) -> Node:
	for e in exits:
		if e.is_open() and e.contains_point(world_pos):
			return e
	return null


## Re-checks exits that open with a world flag (e.g. a hidden passage).
func refresh_exits() -> void:
	for e in exits:
		e.refresh()


func queue_bake(prop: Node2D) -> void:
	_props_to_bake.append(prop)


# --- Geometry -----------------------------------------------------------------

func _sample_geometry() -> void:
	var n := int((paint_max_x - paint_min_x) / SAMPLE_STEP) + 1
	_floor.resize(n)
	_ceil.resize(n)
	for i in n:
		var x := paint_min_x + i * SAMPLE_STEP
		_floor[i] = _keys_at(floor_keys, x) + _noise.get_noise_1d(x) * floor_noise
		var c := _keys_at(ceil_keys, x) + _noise.get_noise_1d(x + 900.0) * ceil_noise
		for slot_x in ceiling_slots:
			var d := absf(x - slot_x)
			if d < 26.0:
				c = lerpf(-120.0, c, smoothstep(10.0, 26.0, d))
		_ceil[i] = c


func _keys_at(keys: Array[Vector2], x: float) -> float:
	for i in keys.size() - 1:
		var a := keys[i]
		var b := keys[i + 1]
		if x <= b.x:
			var pre := keys[maxi(i - 1, 0)]
			var post := keys[mini(i + 2, keys.size() - 1)]
			return cubic_interpolate(a.y, b.y, pre.y, post.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
	return keys[keys.size() - 1].y


func _sample(samples: PackedFloat32Array, x: float) -> float:
	var f := clampf((x - paint_min_x) / SAMPLE_STEP, 0.0, samples.size() - 1.001)
	var i := int(f)
	return lerpf(samples[i], samples[i + 1], f - i)


func _line(samples: PackedFloat32Array, x0: float, x1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := x0
	while x <= x1:
		pts.append(Vector2(x, _sample(samples, x)))
		x += SAMPLE_STEP
	return pts


# --- Layers -------------------------------------------------------------------

func _add_parallax(factor: float) -> Node2D:
	var layer := DepthLayer.new()
	layer.factor = factor
	layer.anchor = Vector2(bounds.get_center().x, 640)
	add_child(layer)
	_parallax.append(layer)
	return layer


func _add_chunks(parent: Node, painter: Callable, mask: int = 1, mat: Material = null) -> void:
	var x := paint_min_x
	while x < paint_max_x:
		var chunk := PaintChunk.new()
		chunk.painter = painter
		chunk.light_mask = mask
		chunk.material = mat
		chunk.region = Rect2(x, 0, CHUNK_W, bounds.size.y)
		parent.add_child(chunk)
		_bake_queue.append(chunk)
		x += CHUNK_W


## Renders every painted chunk once into a texture and swaps it for a Sprite2D.
## Thousands of small strokes become a handful of quads: the difference
## between ~6 fps and 60 on modest GPUs. Runs under the fade-in.
func _bake() -> void:
	var s := Baker.scale()
	var jobs: Array = []
	for chunk: Node2D in _bake_queue:
		if not is_instance_valid(chunk):
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i((chunk.region.size * s).ceil())
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		vp.canvas_transform = Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
		var parent := chunk.get_parent()
		var slot := Node2D.new()
		parent.add_child(slot)
		parent.move_child(slot, chunk.get_index())
		chunk.reparent(vp, false)
		chunk.position = -chunk.region.position
		jobs.append([vp, chunk, slot])
	_bake_queue.clear()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return  # Left the room before baking finished.
	for job in jobs:
		var vp: SubViewport = job[0]
		var chunk: Node2D = job[1]
		var slot: Node2D = job[2]
		var img := vp.get_texture().get_image()
		var used := img.get_used_rect() if img != null and not img.is_empty() else Rect2i()
		if used.has_area():
			# Keep only the painted pixels: haze and foreground are mostly empty.
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = ImageTexture.create_from_image(img.get_region(used))
			sprite.position = chunk.region.position + Vector2(used.position) / s
			sprite.scale = Vector2.ONE / s
			baked_texture_bytes += used.size.x * used.size.y * 4
			sprite.light_mask = chunk.light_mask
			sprite.material = chunk.material
			slot.add_sibling(sprite)
		elif img == null or img.is_empty():
			# Could not read back: keep drawing the strokes directly.
			chunk.reparent(slot.get_parent(), false)
			chunk.position = Vector2.ZERO
			slot.get_parent().move_child(chunk, slot.get_index())
		slot.queue_free()
		vp.queue_free()
	await Baker.bake(_props_to_bake)
	is_ready_to_show = true
	baked.emit()


## Detail is generated per fixed world cell, not per chunk: neighbouring
## chunks draw the same stones where they overlap, so baked chunks (clipped to
## their own rect) meet without seams.
func _cells(rect: Rect2, margin: float) -> Array:
	return range(int(floor((rect.position.x - margin) / CELL_W)), int(ceil((rect.end.x + margin) / CELL_W)))


func _cell_rng(cell: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (cell + 1000) * 7919 + salt + (noise_seed - 4001) * 104729
	return rng


func _paint_back_wall(ci: CanvasItem, rect: Rect2) -> void:
	# Base wash for this slice of wall.
	var base := PackedVector2Array([rect.position + Vector2(0, 120), Vector2(rect.end.x, 120),
		Vector2(rect.end.x, 900), Vector2(rect.position.x, 900)])
	Painter.gradient_polygon(ci, base, 200, 860, wash_top, wash_bottom)
	# Large strata first, then stones laid loosely in uneven courses.
	for cell: int in _cells(rect, 320.0):
		var rng := _cell_rng(cell, 101)
		if rng.randf() < 0.9:
			var band := Painter.blob(Vector2(cell * CELL_W + rng.randf_range(0, CELL_W), rng.randf_range(300, 780)), rng.randf_range(160, 300), rng, 12, 0.15, 0.18)
			ci.draw_colored_polygon(band, strata)
	for cell: int in _cells(rect, 120.0):
		var rng := _cell_rng(cell, 102)
		var cx := cell * CELL_W
		var y := 160.0
		while y < 880.0:
			var x := cx + rng.randf_range(0, 40)
			while x < cx + CELL_W:
				var r := rng.randf_range(14, 58) if rng.randf() < 0.85 else rng.randf_range(60, 90)
				var c := Vector2(x, y + rng.randf_range(-10, 10))
				if c.y > ceil_y(c.x) - 90.0 and c.y < floor_y(c.x) + 50.0:
					var shade := rng.randf_range(-0.035, 0.03)
					var tint := rng.randf_range(-0.012, 0.012)
					var fill := Color(stone.r + shade + tint, stone.g + shade, stone.b + shade - tint)
					var depth := clampf((c.y - 300.0) / 500.0, 0.0, 1.0)
					fill = fill.darkened(0.35 * (1.0 - depth))
					Painter.stone(ci, c, r, rng, fill, rng.randf_range(0.45, 0.85), 1.1, wall_ink)
				x += r * rng.randf_range(1.6, 2.7)
			y += rng.randf_range(38, 50)
		for i in 3:
			var p := Vector2(cx + rng.randf_range(0, CELL_W), rng.randf_range(300, 780))
			Painter.crack(ci, p, rng, rng.randi_range(4, 9), 9.0, Color(0.03, 0.03, 0.035, 0.6), 1.1)
		for i in 2:
			var p := Vector2(cx + rng.randf_range(0, CELL_W), rng.randf_range(320, 760))
			Painter.hatch(ci, p, rng, rng.randi_range(6, 12), 16.0, 4.0, deg_to_rad(-62), Color(0.02, 0.02, 0.03, 0.28), 1.0)
		for i in 13:
			var p := Vector2(cx + rng.randf_range(0, CELL_W), rng.randf_range(300, 800))
			ci.draw_circle(p, rng.randf_range(0.6, 1.5), Color(0.55, 0.56, 0.58, rng.randf_range(0.1, 0.3)))


## Depth: the wall recedes into dark near the floor and the roof.
func _paint_haze(ci: CanvasItem, _rect: Rect2) -> void:
	var low := _line(_floor, paint_min_x, paint_max_x)
	var up := PackedVector2Array()
	for p in low:
		up.append(p + Vector2(0, -150))
	var band := up.duplicate()
	for i in range(low.size() - 1, -1, -1):
		band.append(low[i] + Vector2(0, 30))
	var cols := PackedColorArray()
	for i in band.size():
		cols.append(Color(0.02, 0.022, 0.03, 0.0 if i < up.size() else 0.55))
	ci.draw_polygon(band, cols)


func _paint_masses(ci: CanvasItem, rect: Rect2) -> void:
	var x0 := rect.position.x - SAMPLE_STEP
	var x1 := rect.end.x + SAMPLE_STEP
	# Floor.
	var floor_line := _line(_floor, x0, x1)
	var floor_poly := floor_line.duplicate()
	floor_poly.append(Vector2(x1, 1400))
	floor_poly.append(Vector2(x0, 1400))
	Painter.gradient_polygon(ci, floor_poly, 780, 1080, mass_top, mass_deep)
	for cell: int in _cells(rect, 60.0):
		var rng := _cell_rng(cell, 202)
		var cx := cell * CELL_W
		for i in 3:
			var x := cx + rng.randf_range(0, CELL_W)
			var y := floor_y(x) + rng.randf_range(20, 150)
			var fill := Color(0.13, 0.125, 0.125).darkened(clampf((y - 800.0) / 260.0, 0.0, 0.8))
			Painter.stone(ci, Vector2(x, y), rng.randf_range(10, 30), rng, fill.darkened(0.25), rng.randf_range(0.35, 0.6), 1.1, wall_ink)
		if rng.randf() < 0.6:
			var p := Vector2(cx + rng.randf_range(0, CELL_W), 0)
			p.y = floor_y(p.x) + rng.randf_range(30, 120)
			Painter.hatch(ci, p, rng, 10, 20.0, 4.5, deg_to_rad(-30), Color(0.0, 0.0, 0.0, 0.3), 1.0)
	var lip_line := PackedVector2Array()
	for p in floor_line:
		lip_line.append(p + Vector2(0, 2.5))
	ci.draw_polyline(lip_line, lip, 1.3, true)
	ci.draw_polyline(floor_line, Painter.INK, 2.4, true)
	for cell: int in _cells(rect, 20.0):
		var rng := _cell_rng(cell, 203)
		for i in 5:
			var x := cell * CELL_W + rng.randf_range(0, CELL_W)
			var r := rng.randf_range(2.5, 7.0)
			Painter.stone(ci, Vector2(x, floor_y(x) - r * 0.35), r, rng, Color(0.22, 0.21, 0.21), 0.6, 1.1)

	# Ceiling.
	var ceil_line := _line(_ceil, x0, x1)
	var ceil_poly := ceil_line.duplicate()
	ceil_poly.append(Vector2(x1, -400))
	ceil_poly.append(Vector2(x0, -400))
	Painter.gradient_polygon(ci, ceil_poly, -100, 380, mass_deep, Color(0.11, 0.105, 0.11))
	ci.draw_polyline(ceil_line, Painter.INK, 2.4, true)
	for cell: int in _cells(rect, 40.0):
		var rng := _cell_rng(cell, 204)
		var x := cell * CELL_W + rng.randf_range(0, 50)
		while x < (cell + 1) * CELL_W:
			if _spike_allowed(x):
				var w := rng.randf_range(12, 40)
				var l := rng.randf_range(16, 70) * (1.6 if rng.randf() < 0.2 else 1.0)
				Painter.spike(ci, Vector2(x, ceil_y(x) - 4), w, l, 1.0, rng, Color(0.12, 0.115, 0.12), Color(0.3, 0.29, 0.28, 0.5))
			x += rng.randf_range(50, 150)
	for h in hero_spikes:
		var hx: float = h[0]
		if hx >= rect.position.x - 40.0 and hx < rect.end.x + 40.0:
			var rng := _cell_rng(9999 + int(hx), 205)
			Painter.spike(ci, Vector2(hx, ceil_y(hx) - 6), h[1], h[2], 1.0, rng, Color(0.13, 0.125, 0.13), Color(0.36, 0.38, 0.4, 0.55))


func _spike_allowed(x: float) -> bool:
	for c in spike_clear:
		if absf(x - float(c[0])) <= float(c[1]):
			return false
	return true


## Side walls close the chamber. Painted as their own chunks, over the masses.
func _paint_side_wall(ci: CanvasItem, _rect: Rect2, side: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (303 if side < 0 else 304) + noise_seed - 4001
	var edge := PackedVector2Array()
	var base_x := left_limit + 15.0 if side < 0 else right_limit + 17.0
	var y := floor_y(base_x) + 6.0
	while y > -400.0:
		var k := clampf((floor_y(base_x) - y) / 520.0, 0.0, 1.0)
		var lean := (-90.0 if side < 0 else 40.0) * k * k
		edge.append(Vector2(base_x + lean + _noise.get_noise_1d(y * 2.0 + side * 300.0) * 14.0, y))
		y -= 16.0
	var poly := edge.duplicate()
	var far := paint_min_x if side < 0 else paint_max_x
	poly.append(Vector2(far, -400))
	poly.append(Vector2(far, floor_y(base_x) + 6.0))
	Painter.gradient_polygon(ci, poly, 300, 820, Color(0.07, 0.068, 0.075), Color(0.12, 0.115, 0.115))
	for i in 18:
		var p := Vector2(base_x + side * rng.randf_range(20, 260), rng.randf_range(300, 800))
		Painter.stone(ci, p, rng.randf_range(14, 40), rng, Color(0.12, 0.115, 0.12), rng.randf_range(0.5, 0.8), 1.5)
	ci.draw_polyline(edge, Painter.INK, 2.6, true)
	var lit := PackedVector2Array()
	for p in edge:
		lit.append(p + Vector2(-side * 2.5, 0))
	ci.draw_polyline(lit, Color(lip, 0.35), 1.2, true)


## Stalagmites standing on the floor. They catch the lantern and throw long
## shadows across the back wall.
func _add_stalagmites(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909 + noise_seed - 4001
	for s in stalagmites:
		var x: float = s[0]
		var holder := PaintChunk.new()
		holder.light_mask = MASK_NO_SHADOW
		var base := Vector2(x, floor_y(x) + 6.0)
		var width: float = s[1]
		var height: float = s[2]
		var spike_seed := rng.randi()
		var shape := PackedVector2Array()
		holder.painter = func(ci: CanvasItem, _r: Rect2) -> void:
			var r := RandomNumberGenerator.new()
			r.seed = spike_seed
			Painter.spike(ci, base, width, height, -1.0, r, Color(0.16, 0.152, 0.15), Color(0.42, 0.40, 0.37, 0.55))
		parent.add_child(holder)
		for i in 7:
			var k := float(i) / 6.0
			shape.append(base + Vector2(lerpf(-width * 0.42, 0.0, k), -height * k * 0.92))
		for i in range(5, -1, -1):
			var k := float(i) / 6.0
			shape.append(base + Vector2(lerpf(width * 0.42, 0.0, k), -height * k * 0.92))
		var occ := LightOccluder2D.new()
		occ.occluder = OccluderPolygon2D.new()
		occ.occluder.polygon = shape
		parent.add_child(occ)


func _paint_foreground(ci: CanvasItem, _rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212 + noise_seed - 4001
	for spec in fg_humps:
		var cx: float = spec[0]
		var top: float = spec[1]
		var w: float = spec[2]
		var hump := PackedVector2Array()
		for i in 17:
			var a := PI + PI * i / 16.0
			var r := 1.0 + rng.randf_range(-0.08, 0.08)
			hump.append(Vector2(cx + cos(a) * w * r, 1200.0 + sin(a) * (1200.0 - top) * r))
		ci.draw_colored_polygon(hump, silhouette)
	for spec in fg_spikes:
		Painter.spike(ci, Vector2(spec[0], -40), spec[2], spec[1], 1.0, rng, silhouette, Color(0.06, 0.06, 0.07, 0.5))


# --- Props, exits, collision ------------------------------------------------------

## An examinable thing. [param data]: {"title", "first", "repeat"} of keys.
func add_interactable(parent: Node, id: String, data: Dictionary, pos: Vector2, opts: Dictionary) -> Node2D:
	var it := Interactable.new()
	it.object_id = id
	it.title = data["title"]
	it.first_lines = data["first"]
	it.repeat_lines = data["repeat"]
	it.position = pos
	it.stand_distance = opts.get("stand", 70.0)
	it.radius = opts.get("radius", 110.0)
	it.hit_size = opts.get("hit", it.hit_size)
	it.hit_offset = opts.get("hit_offset", it.hit_offset)
	it.prompt_offset = opts.get("prompt", it.prompt_offset)
	parent.add_child(it)
	return it


## An item lying in the world. Examining it reads its lines and puts it in the
## satchel; it is never created again once collected. Returns null if taken.
func add_collectible(parent: Node, item_id: String, pos: Vector2, opts: Dictionary = {}) -> Node2D:
	if WorldManager.is_collected(item_id):
		return null
	var data: Dictionary = Items.ITEMS[item_id]
	var prop := ItemProp.new()
	prop.item_id = item_id
	prop.position = pos
	parent.add_child(prop)
	var o := {"stand": 40.0, "hit": Vector2(110, 110), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -46), "radius": 80.0}
	o.merge(opts, true)
	var it := add_interactable(parent, "item_" + item_id, {"title": data["title"], "first": data["found"], "repeat": data["found"]}, Vector2(pos.x, floor_y(pos.x)), o)
	it.prompt_offset.y += pos.y - floor_y(pos.x)
	it.hit_offset.y += pos.y - floor_y(pos.x)
	it.on_examined = func(_count: int) -> void:
		if WorldManager.collect(item_id):
			AudioManager.play("pickup", -10.0, 1.0, AudioManager.BUS_CHARACTER)
			UIManager.toast(Loc.t("TOAST_FOUND") % Loc.t(data["title"]))
			prop.vanish()
			it.queue_free()
	return prop


func _add_exits(parent: Node) -> void:
	for spec: Dictionary in exit_specs:
		var e := Exit.new()
		e.spec = spec
		e.floor_at = floor_y(clampf((float(spec["x0"]) + float(spec["x1"])) * 0.5, left_limit, right_limit))
		e.walk_x = clampf((float(spec["x0"]) + float(spec["x1"])) * 0.5, walkable_range().x, walkable_range().y)
		e.reached.connect(func(to_room: String, to_entry: String) -> void: exit_reached.emit(to_room, to_entry))
		parent.add_child(e)
		exits.append(e)


func _add_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	# A solid slab under the floor line (a segment chain would be closed into
	# a loop, putting a stray edge across the room).
	var ground := CollisionPolygon2D.new()
	var x0 := left_limit - 200.0
	var x1 := right_limit + 200.0
	var pts := _line(_floor, x0, x1)
	pts.append(Vector2(pts[pts.size() - 1].x, 1300))
	pts.append(Vector2(x0, 1300))
	ground.polygon = pts
	body.add_child(ground)
	for x in [left_limit, right_limit]:
		var wall := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = Vector2(x, -200)
		seg.b = Vector2(x, 1100)
		wall.shape = seg
		body.add_child(wall)
