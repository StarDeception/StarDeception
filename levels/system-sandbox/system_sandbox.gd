extends Node3D

var spaceship_scene = preload("res://scenes/spaceship/test_spaceship/test_spaceship.tscn")
var station_scene = preload("res://scenes/station/test_station/test_station.tscn")
var normal_player = preload("res://scenes/normal_player/normal_player.tscn")

@export var spawn_points: Node

@export var spawn_node: Node


func _enter_tree() -> void:
	if not OS.has_feature("dedicated_server") and Globals.onlineMode:
		Server.create_client(self)

func _ready() -> void:
	
	$DirectionalLight3D.look_at($Planet.global_position)
	
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
	var player = normal_player.instantiate() as Player
	player.name = str(id)
	spawn_node.add_child(player, true)
	
	Server.players[id] = player
	
	
	#var point = Vector3(randf_range(-.1, .1), 1.0, randf_range(-.2, .2))
	#print(point)
	#var planet_normal = point.normalized()
	#
	## place the player on the server temporarily at the planet radius to trigger the collision shape generation
	#player.global_position = planet_normal * 500000 # TODO: replace hardcoded distance by the planet radius
	Globals.log("player positionned temporarily at: %s" % str(player.global_position))
	
	# wait for collision to generate
	await get_tree().create_timer(4).timeout
	
	# cast ray to planet to get a spawn position
	#var space_state = get_world_3d().direct_space_state
	#Globals.log("Space state is " + str(space_state))
	#var param = PhysicsRayQueryParameters3D.new()
	#param.from = planet_normal * 800000 # TODO: replace by offset from planet radius
	#param.to = Vector3.ZERO
	#var res = space_state.intersect_ray(param)
	#if res.is_empty():
		#print("failed to find a spawn point")
		#return
	var spawn_point: Vector3 # = res["position"] + planet_normal * 5
	
	# Le joueur spawn à une des positions de la liste. La liste est remplie avec les coordonnées de ses enfants de type PlayerSpawnPoint

	
	print_rich("[color=green]Spawn point : %.2v[/color]" % spawn_point)
	
	
	# trigger change of position on server + client
	set_player_position.rpc(id, spawn_point, Vector3.ZERO)


@rpc("authority", "call_remote", "reliable")
func spawn_station():
	prints("spawn station from", multiplayer.get_unique_id())
	var station = station_scene.instantiate() as Node3D
	spawn_node.add_child(station, true)
	station.global_position = spawn_node.global_basis.y * 6500


@rpc("authority", "call_local", "reliable")
func set_player_position(id: int, _player_position: Vector3, _planet_normal: Vector3):
	var player = spawn_node.get_node(str(id)) as Player
	var spawn_point = spawn_points.get_children().pick_random()
	
	if not multiplayer.is_server():
		player.global_position = spawn_point.global_position
		print("position at", spawn_point.global_position, spawn_point.name)
		await get_tree().create_timer(5).timeout
		#player.global_position = spawn_point.global_position
		print("position at", spawn_point.global_position)
		player.global_transform = Globals.align_with_y(player.global_transform, spawn_point.global_position.normalized())
		player.handle_spawn()
