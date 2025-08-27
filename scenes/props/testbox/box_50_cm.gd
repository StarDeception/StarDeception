class_name box50cm

extends RigidBody3D

var type_name = "box50cm"

var spawn_position: Vector3 = Vector3.ZERO
var spawn_rotation: Vector3 = Vector3.UP

@onready var is_inside_box4m: bool = false

func _ready() -> void:
	global_position = spawn_position
