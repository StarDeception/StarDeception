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
		x_start = str(serverzone.x_start)
	if serverzone.x_end != -10000000.0 and serverzone.x_end != 10000000.0:
		x_end = str(serverzone.x_end)
	if serverzone.y_start != -10000000.0 and serverzone.y_start != 10000000.0:
		y_start = str(serverzone.y_start)
	if serverzone.y_end != -10000000.0 and serverzone.y_end != 10000000.0:
		y_end = str(serverzone.y_end)
	if serverzone.z_start != -10000000.0 and serverzone.z_start != 10000000.0:
		z_start = str(serverzone.z_start)
	if serverzone.z_end != -10000000.0 and serverzone.z_end != 10000000.0:
		z_end = str(serverzone.z_end)
	text = "Server zone | x " + x_start + " -> " + x_end + " | y " + y_start + " -> " + y_end + " | z " + z_start + " -> " + z_end + " |"
