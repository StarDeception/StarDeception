extends Node3D

var spawn_position: Vector3 = Vector3.ZERO
@onready var planet_meshinstance: MeshInstance3D = $Planet
@export_file("*.tres", "*.material") var material_path : String

@onready var planet_gravity: PhysicsGrid = $PlanetGravity
@onready var planet_terrain: Planet = $PlanetTerrain


func _enter_tree() -> void:
	pass

func _ready() -> void:
	global_position = spawn_position
	planet_meshinstance.material_override = load(material_path)
	

func _physics_process(delta: float) -> void:
	planet_terrain.rotation.y += 0.001 * delta
	#planet_gravity.gravity_point_unit_distance = planet_terrain.min_height
	
