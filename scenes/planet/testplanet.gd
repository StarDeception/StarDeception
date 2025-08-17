extends Node3D

@onready var planet_gravity: PhysicsGrid = $PlanetGravity
@onready var planet_terrain: Planet = $PlanetTerrain

@export var sun: DirectionalLight3D

func _ready() -> void:
	$Atmosphere.sun_object = sun

func _physics_process(delta: float) -> void:
	planet_terrain.rotation.y += 0.001 * delta
	#planet_gravity.gravity_point_unit_distance = planet_terrain.min_height
	
