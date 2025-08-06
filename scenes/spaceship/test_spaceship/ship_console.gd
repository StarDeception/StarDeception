extends Area3D

@export var label = "Interact"

func interact(player: Player):
	owner.take_control(player)
