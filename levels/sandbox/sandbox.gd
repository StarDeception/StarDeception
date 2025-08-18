extends Node3D


func _on_ready() -> void:
	if not OS.has_feature("dedicated_server") and Globals.onlineMode:
		Server.create_client(self)
		
	#add_child(newplayer)
	#newplayer.global_position = Vector3(10.0, 10.0, 0)
