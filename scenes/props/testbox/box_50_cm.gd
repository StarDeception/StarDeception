extends RigidBody3D

@onready var isInsideBox4m: bool = false

var spawn_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	global_position = spawn_position
