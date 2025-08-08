extends Node3D

var player_scene = preload("res://scenes/player/test_player.tscn")
var spaceship_scene = preload("res://scenes/spaceship/test_spaceship/test_spaceship.tscn")
var station_scene = preload("res://scenes/station/test_station/test_station.tscn")

func _ready() -> void:
	var player = player_scene.instantiate() as CharacterBody3D
	var point = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	var planet_normal = point.normalized()
	var spawn_point: Vector3 = planet_normal * 2002.0
	$Planet.add_child(player)
	player.global_position = spawn_point
	player.global_transform = Globals.align_with_y(player.global_transform, planet_normal)
	
	
	var spaceship = spaceship_scene.instantiate() as RigidBody3D
	$Planet.add_child(spaceship)
	spaceship.global_position = spawn_point + player.global_basis.x * 10 + player.global_basis.y * 3
	spaceship.global_transform = Globals.align_with_y(spaceship.global_transform, planet_normal)

	var station = station_scene.instantiate() as Node3D
	$Planet.add_child(station)
	station.global_position = player.global_position + player.global_basis.y * 1000

func _physics_process(delta: float) -> void:
	#pass
	$Planet.rotation.y += 0.01 * delta
