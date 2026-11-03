extends Node
## InteractionSystem — lives on the creature. Finds the nearest examinable
## thing in range, highlights it, and performs examinations.

var actor
var current: Node = null


func _physics_process(_delta: float) -> void:
	if actor == null:
		return
	var best: Node = null
	var best_d := INF
	for node in WorldManager.interactables:
		var d := absf(node.global_position.x - actor.global_position.x)
		if d <= node.radius and d < best_d:
			best_d = d
			best = node
	if best != current:
		if current != null and is_instance_valid(current):
			current.highlight = 0.0
		current = best
		if current != null:
			current.highlight = 1.0


## Examines whatever is in range. Returns false if nothing is.
func try_interact() -> bool:
	if current == null or not is_instance_valid(current):
		return false
	examine(current)
	return true


func examine(target: Node) -> void:
	if UIManager.is_text_open():
		return
	actor.face_toward(target.global_position.x)
	actor.set_examining(true)
	WorldManager.examine(target)
