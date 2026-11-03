extends RefCounted
## Turns a prop's static drawing into a texture, once.
##
## A baked prop must have `var baked: bool` (its _draw skips the static part
## while true) and `func bake_rect() -> Rect2` (local bounds of that part).
## The prop is rendered alone in a SubViewport (its children hidden), then
## gets a child Sprite2D drawn behind its own remaining, animated drawing and
## inheriting its material and modulate. Call [method rebake] when what the
## prop shows changes (a new tally mark, more caps).
## Headless runs skip baking and keep drawing directly.
##
## Resolution: the_waiting/rendering/bake_scale (default 1.0 = one texel per
## world unit). On high-density screens a higher scale is sharper but costs
## scale² memory; `-- --bake-scale=<n>` overrides it for measurement.


static func scale() -> float:
	var s := float(ProjectSettings.get_setting("the_waiting/rendering/bake_scale", 1.0))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bake-scale="):
			s = arg.get_slice("=", 1).to_float()
	return clampf(s, 0.5, 2.0)


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not "--no-bake" in OS.get_cmdline_user_args()


static func bake(props: Array) -> void:
	if not enabled() or props.is_empty():
		return
	var s := scale()
	var jobs: Array = []
	for prop: Node2D in props:
		if not is_instance_valid(prop) or not prop.is_inside_tree():
			continue
		var rect: Rect2 = prop.bake_rect()
		var parent := prop.get_parent()
		var vp := SubViewport.new()
		vp.size = Vector2i((rect.size * s).ceil())
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		parent.add_child(vp)
		vp.canvas_transform = Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO)
		var hidden: Array = []
		for c in prop.get_children():
			if c is CanvasItem and c.visible:
				c.visible = false
				hidden.append(c)
		var slot := Node2D.new()
		parent.add_child(slot)
		parent.move_child(slot, prop.get_index())
		var home := prop.position
		var home_scale := prop.scale
		prop.reparent(vp, false)
		prop.position = -rect.position
		prop.scale = Vector2.ONE
		jobs.append([prop, vp, slot, home, home_scale, hidden, rect])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for j in jobs:
		var prop: Node2D = j[0]
		var vp: SubViewport = j[1]
		var slot: Node2D = j[2]
		var img := vp.get_texture().get_image()
		prop.reparent(slot.get_parent(), false)
		slot.get_parent().move_child(prop, slot.get_index())
		prop.position = j[3]
		prop.scale = j[4]
		for c in j[5]:
			c.visible = true
		if img != null and not img.is_empty():
			var sprite := Sprite2D.new()
			sprite.name = "Baked"
			sprite.centered = false
			sprite.position = j[6].position
			sprite.scale = Vector2.ONE / s
			sprite.texture = ImageTexture.create_from_image(img)
			sprite.show_behind_parent = true
			sprite.use_parent_material = true
			sprite.light_mask = prop.light_mask
			prop.add_child(sprite)
			prop.baked = true
			prop.queue_redraw()
		slot.queue_free()
		vp.queue_free()


static func rebake(prop: Node2D) -> void:
	var old := prop.get_node_or_null("Baked")
	if old != null:
		old.free()
	prop.baked = false
	prop.queue_redraw()
	await bake([prop])
