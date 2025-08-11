extends Area3D
class_name Interactable

@export var label = "Interact"

signal interacted()

func interact():
	emit_signal("interacted")
