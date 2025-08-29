extends Label

func _ready() -> void:
	NetworkOrchestrator.set_gameserver_serverzone.connect(_set_gameserver_serverzone)

func _set_gameserver_serverzone(serverzone):
	var x_start = "∞"
	var x_end = "∞"
	var y_start = "∞"
	var y_end = "∞"
	var z_start = "∞"
	var z_end = "∞"
	if serverzone.x_start != -10000000.0 and serverzone.x_start != 10000000.0:
		x_start = String.num(serverzone.x_start, 2)
	if serverzone.x_end != -10000000.0 and serverzone.x_end != 10000000.0:
		x_end = String.num(serverzone.x_end, 2)
	if serverzone.y_start != -10000000.0 and serverzone.y_start != 10000000.0:
		y_start = String.num(serverzone.y_start, 2)
	if serverzone.y_end != -10000000.0 and serverzone.y_end != 10000000.0:
		y_end = String.num(serverzone.y_end, 2)
	if serverzone.z_start != -10000000.0 and serverzone.z_start != 10000000.0:
		z_start = String.num(serverzone.z_start, 2)
	if serverzone.z_end != -10000000.0 and serverzone.z_end != 10000000.0:
		z_end = String.num(serverzone.z_end, 2)
	text = "Server zone | x " + x_start + " -> " + x_end + " | y " + y_start + " -> " + y_end + " | z " + z_start + " -> " + z_end + " |"
