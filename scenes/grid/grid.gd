extends Area3D

class_name PhysicsGrid

# TODO: implement translation/rotation of nodes detected by area based on parent

#var bodies_in_area: Array[Node3D] = []
#var last_parent_transform: Transform3D
#
#func _ready():
	#body_entered.connect(_on_body_entered)
	#body_exited.connect(_on_body_exited)
	#last_parent_transform = get_parent().global_transform
#
#func _on_body_entered(body: Node) -> void:
	#if body is Node3D and body not in bodies_in_area:
		#bodies_in_area.append(body)
#
#func _on_body_exited(body: Node) -> void:
	#bodies_in_area.erase(body)
#
#func _physics_process(delta: float) -> void:
	#var parent_t = get_parent().global_transform
	#print(parent_t.basis.y)
	## Compute how the parent moved this frame
	#var delta_t = last_parent_transform.affine_inverse() * parent_t
#
	## Apply that same movement to every body inside
	#for body in bodies_in_area:
		#body.global_transform = delta_t * body.global_transform
#
	#last_parent_transform = parent_t
