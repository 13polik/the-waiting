extends Node2D
## Offsets its children against the camera to suggest depth.
## factor < 1 recedes (back wall), factor > 1 comes forward (foreground).
## At [member anchor] the layer lines up exactly with the world, so content
## can be authored in world coordinates.

var factor: float = 1.0
var anchor: Vector2 = Vector2.ZERO
var camera: Camera2D


func _process(_delta: float) -> void:
	if camera != null:
		position = (camera.get_screen_center_position() - anchor) * (1.0 - factor)
