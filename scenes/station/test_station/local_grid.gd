extends Node3D

var parenting = false

#func _on_body_entered(body: Node3D) -> void:
	#pass
	##prints(body.name, "entered", self)
	##if body.get_parent() == get_parent():
		##parenting = true
		##body.call_deferred("reparent", self)
#
#
#func _on_body_exited(body: Node3D) -> void:
	#pass
	#if parenting: return
	#if parenting:
		#parenting = false
		#return
	#
	#prints(body.name, "exited", self)
	#if body.get_parent() == self:
		#body.call_deferred("reparent", get_parent())
