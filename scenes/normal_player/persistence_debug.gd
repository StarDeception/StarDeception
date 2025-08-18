extends Node3D

func _ready() -> void:
	_add_debug_sphere(20.0, Color.GREEN, "Loading zone")
	
func _add_debug_sphere(radius: float, color: Color, label: String):
	print("Add debug zone ", label)
	
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.wireframe = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.3
	material.no_depth_test = true
	
	var sphere = CSGSphere3D.new()
	sphere.radius = radius
	sphere.material_override = material
	
	add_child(sphere)
