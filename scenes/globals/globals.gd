extends Node

var init_scene = "res://levels/system-sandbox/system_sandbox.tscn"

var playerName: String = "I am an idiot !"
var onlineMode: bool = false



func align_with_y(xform: Transform3D, new_y: Vector3) -> Transform3D:
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

func log(message: String):
	 
	var header = "[color=green][lb]client[rb][/color]"
	if multiplayer.is_server():
		header = "[color=teal][lb]server[rb][/color]: "
	print_rich(header + message)
