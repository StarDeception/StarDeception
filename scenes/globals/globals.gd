extends Node

var init_scene = "res://levels/system-sandbox/system_sandbox.tscn"

var playerName: String = "I am an idiot !"
var onlineMode: bool = false

func print_rich_distinguished(message: String, extras: Array) -> void:
	var instance_color = GameOrchestrator.distinguish_instances[GameOrchestrator.current_mode]["instance_color"]
	var instance_name = GameOrchestrator.distinguish_instances[GameOrchestrator.current_mode]["instance_name"]
	var prefix = "[color=" + instance_color + "][" + instance_name + "][/color]"
	
	var formatted_message = message
	
	if not extras.is_empty():
		formatted_message = message % extras
	
	print_rich(prefix + formatted_message)

func align_with_y(xform: Transform3D, new_y: Vector3) -> Transform3D:
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform
