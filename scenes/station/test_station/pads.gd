extends CSGCombiner3D

func _ready() -> void:
	$GravityArea.gravity_direction = -global_basis.y
