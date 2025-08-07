extends Area3D

class_name Grid

var parent: RigidBody3D

func _ready() -> void:
	parent = owner

func enter(node: Node3D):
	parent.add_collision_exception_with(node)
	node.reparent(parent)

func exit(node: Node3D):
	parent.remove_collision_exception_with(node)
