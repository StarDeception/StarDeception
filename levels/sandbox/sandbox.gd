extends Node3D


@export var player_scene : PackedScene

func _on_ready() -> void:
	if not OS.has_feature("dedicated_server") and Globals.onlineMode:
		await Server.create_client(player_scene)
		
	#add_child(newplayer)
	#newplayer.global_position = Vector3(10.0, 10.0, 0)
