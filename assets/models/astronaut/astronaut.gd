extends Node3D

@onready var local_helmet: MeshInstance3D = $rig/Skeleton3D/Helmet
@onready var local_pigeonhead: MeshInstance3D = $PigeonHead

func _show_remote_player_elements() -> void:
	print("Un joueur multi")
	# local_helmet.show()			# Ne pas afficher le casque car on affiche la tête de pigeon
	local_pigeonhead.show()
