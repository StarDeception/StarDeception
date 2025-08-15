extends Node3D

var spaceship_scene = preload("res://scenes/spaceship/test_spaceship/test_spaceship.tscn")
var station_scene = preload("res://scenes/station/test_station/test_station.tscn")
var normal_player = preload("res://scenes/normal_player/normal_player.tscn")


@export var spawn_node: Node

var spawn_points_list: Array[Vector3]

func _enter_tree() -> void:
	if not OS.has_feature("dedicated_server") and Globals.onlineMode:
		Server.create_client(self)

func _ready() -> void:
	if has_node("PlayerSpawnPointsList"):
		for child in get_node("PlayerSpawnPointsList").get_children():
			spawn_points_list.append(child.global_position)
	
	Server.player_spawned.connect(on_player_spawn)
	
	if multiplayer.is_server():
		# spawn station on the server
		spawn_station()

# this function is run on the server after a 
func on_player_spawn(id):
	# spawn station for the new connected player
	spawn_station.rpc_id(id)
	
	# spawn player on server
	spawn_player(id)
	

func spawn_player(id: int) -> void:
	var player = normal_player.instantiate()
	player.name = str(id)
	spawn_node.add_child(player, true)
	Server.players[id] = player
	
	var point = Vector3(randf_range(-.1, .1), 1.0, randf_range(-.2, .2))
	print(point)
	var planet_normal = point.normalized()
	
	var space_state = get_world_3d().direct_space_state
	Globals.log("Space state is " + str(space_state))
	var param = PhysicsRayQueryParameters3D.new()
	param.from = planet_normal * 10000
	param.to = Vector3.ZERO
	var res = space_state.intersect_ray(param)
	
	var spawn_point: Vector3 = res["position"] + planet_normal * 5
	
	# Le joueur spawn à une des positions de la liste. La liste est remplie avec les coordonnées de ses enfants de type PlayerSpawnPoint
	if spawn_points_list.size() > 0:
		spawn_point = spawn_points_list.pick_random()
	
	print_rich("[color=green]Spawn point : %.2v[/color]" % spawn_point)
	
	set_player_position.rpc(id, spawn_point, planet_normal)


@rpc("authority", "call_remote", "reliable")
func spawn_station():
	prints("spawn station from", multiplayer.get_unique_id())
	var station = station_scene.instantiate() as Node3D
	spawn_node.add_child(station, true)
	station.global_position = spawn_node.global_basis.y * 5000


@rpc("authority", "call_local", "reliable")
func set_player_position(id: int, player_position: Vector3, planet_normal: Vector3):
	var player = spawn_node.get_node(str(id)) as Node3D
	player.global_position = player_position
	player.global_transform = Globals.align_with_y(player.global_transform, planet_normal)
	
	await get_tree().create_timer(1).timeout
	player.handle_spawn()
	


func _physics_process(delta: float) -> void:
	pass
	spawn_node.rotation.y += 0.01 * delta
