extends "res://scripts/world/room_base.gd"
## A room described by a mod (validated by ModManager). It is built from the
## game's own pieces — the same painter, props and lighting — so a mod adds
## places that look like they belong. Reached through a side passage in the
## mod's anchor room; its west end leads back there.

const WallDetails := preload("res://scripts/world/props/wall_details.gd")
const GlowFeatures := preload("res://scripts/world/props/glow_features.gd")
const LightShaft := preload("res://scripts/world/props/light_shaft.gd")
const Pool := preload("res://scripts/world/props/pool.gd")
const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")

## Set by Rooms.create before the room enters the tree.
var def: Dictionary = {}
var room_id_full: String = ""


func _configure() -> void:
	room_id = room_id_full
	title_key = def["title"]
	var w: float = def["width"]
	bounds = Rect2(0, 0, w, 1100)
	left_limit = 200.0
	right_limit = w - 180.0
	spawn_x = 320.0
	noise_seed = 9000 + absi(hash(room_id_full)) % 5000
	floor_keys = _extended(def["floor"], w)
	ceil_keys = _extended(def["ceiling"], w)
	var pal: Dictionary = def["palette"]
	if pal.has("light"):
		modulate_color = pal["light"]
	if pal.has("stone"):
		stone = pal["stone"]
	if pal.has("wash"):
		wash_bottom = pal["wash"]
		wash_top = (pal["wash"] as Color).darkened(0.45)
	for o in def["objects"]:
		if o["kind"] == "shaft":
			ceiling_slots.append(float(o["x"]))
			spike_clear.append([float(o["x"]), 50.0])
		elif o["kind"] == "pool":
			spike_clear.append([float(o["x"]), 50.0])
			hero_spikes.append([float(o["x"]), 30.0, 90.0])
	fg_humps = [[150.0, 880.0, 180.0], [w * 0.55, 950.0, 130.0], [w - 100.0, 870.0, 200.0]]
	sound_space = "garden"
	entries = {"from_anchor": {"x": 320.0, "facing": 1}}
	exit_specs = [{"id": "west", "x0": 150.0, "x1": 222.0, "side": "left", "to_room": def["anchor"], "to_entry": "anchor"}]


func _light_specs() -> Array:
	var out := []
	for o in def["objects"]:
		if o["kind"] == "shaft":
			out.append([Vector2(float(o["x"]) + 30, floor_y(o["x"]) - 30), Color(0.62, 0.68, 0.8), 0.55, 2.2])
	return out


func _add_props(parent: Node) -> void:
	var mouth := TunnelMouth.new()
	mouth.inward = -1.0
	mouth.position = Vector2(left_limit, floor_y(left_limit))
	parent.add_child(mouth)
	queue_bake(mouth)
	var objects: Array = def["objects"]
	for i in objects.size():
		var o: Dictionary = objects[i]
		var x: float = o["x"]
		var fy := floor_y(x)
		var opts := {}
		match o["kind"]:
			"fossil", "marks":
				queue_bake(_detail(parent, o["kind"], Vector2(x, fy - 150)))
				opts = {"hit": Vector2(200, 150), "hit_offset": Vector2(0, -150), "prompt": Vector2(0, -230), "stand": 40.0}
			"trickle", "pillar":
				queue_bake(_detail(parent, o["kind"], Vector2(x, fy)))
				if o["kind"] == "trickle":
					opts = {"hit": Vector2(160, 260), "hit_offset": Vector2(0, -150), "prompt": Vector2(0, -250), "stand": 70.0}
				else:
					opts = {"hit": Vector2(420, 120), "hit_offset": Vector2(0, -50), "prompt": Vector2(0, -130), "stand": 230.0, "radius": 200.0}
			"moss", "veins":
				var g := GlowFeatures.new()
				g.kind = o["kind"]
				g.seed_value = i + 11
				if o["kind"] == "moss":
					g.color = Color(0.5, 0.85, 0.72)
					g.position = Vector2(x, fy + 2)
					opts = {"hit": Vector2(200, 90), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -60), "stand": 60.0}
				else:
					g.position = Vector2(x, fy - 330)
					opts = {"hit": Vector2(200, 160), "hit_offset": Vector2(0, -330), "prompt": Vector2(0, -420), "stand": 40.0}
				parent.add_child(g)
				queue_bake(g)
			"pool":
				var p := Pool.new()
				p.position = Vector2(x, fy)
				p.drop_height = fy - (ceil_y(x) + 90.0)
				parent.add_child(p)
				queue_bake(p)
				if pool == null:
					pool = p
				opts = {"stand": 125.0, "radius": 150.0, "hit": Vector2(240, 120), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -70)}
			"shaft":
				var s := LightShaft.new()
				s.position = Vector2(x, 160)
				s.length = fy - 160.0
				parent.add_child(s)
				opts = {"hit": Vector2(160, 480), "hit_offset": Vector2(0, -280), "prompt": Vector2(0, -230), "stand": 40.0}
		if o["examinable"]:
			var repeat: Array = o["repeat"] if not (o["repeat"] as Array).is_empty() else o["first"]
			add_interactable(parent, "%s:o%d" % [room_id_full, i], {"title": o["title"], "first": o["first"], "repeat": repeat}, Vector2(x, fy), opts)
	for pick in def["items"]:
		var px: float = pick["x"]
		add_collectible(parent, pick["item"], Vector2(px, floor_y(px) - 4))


## Floor and ceiling keys reaching past both ends, as the painter needs.
func _extended(points: Array, w: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	out.append(Vector2(minf(-400.0, first.x - 400.0), first.y))
	for p: Vector2 in points:
		out.append(p)
	out.append(Vector2(maxf(w + 400.0, last.x + 400.0), last.y))
	return out


func _detail(parent: Node, kind: String, pos: Vector2) -> Node2D:
	var d := WallDetails.new()
	d.kind = kind
	d.position = pos
	parent.add_child(d)
	return d
