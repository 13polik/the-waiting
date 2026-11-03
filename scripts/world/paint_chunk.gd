extends Node2D
## One slice of a painted layer. Large layers are split into chunks so the
## renderer can skip slices that are off-screen (each chunk's bounds come from
## what it draws). [member painter] is called once; the result is cached.

var painter: Callable
var region: Rect2


func _draw() -> void:
	if painter.is_valid():
		painter.call(self, region)
