extends Area3D
class_name Interactable

@export var label = "Interact"

signal interacted()

func interact(interactor: Node = null):
	emit_signal("interacted", interactor)
