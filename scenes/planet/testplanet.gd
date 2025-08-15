extends StaticBody3D

@onready var planet_gravity: PhysicsGrid = $PlanetGravity
@onready var planet_terrain: Planet = $PlanetTerrain

func _physics_process(delta: float) -> void:
	planet_gravity.gravity_point_unit_distance = planet_terrain.min_height
	
