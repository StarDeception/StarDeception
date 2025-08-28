extends StaticBody3D

@export_file("*.tres", "*.material") var material_path : String

var spawn_position: Vector3 = Vector3.ZERO

@onready var planet_meshinstance: MeshInstance3D = $Planet

func _enter_tree() -> void:
	pass

func _ready() -> void:
	global_position = spawn_position
	planet_meshinstance.material_override = load(material_path)
