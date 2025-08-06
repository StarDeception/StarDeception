extends Node3D

@export var player_scene : PackedScene

func _ready() -> void:
	var player_scene_object = player_scene
	var dummyPlayer = player_scene_object.instantiate()
	dummyPlayer.name = "FakeUser"
	# call_deferred("add_child", dummyPlayer)
	get_tree().current_scene.add_child(dummyPlayer)
	dummyPlayer.global_position = Vector3(4.0, 0.1, 4.0)
