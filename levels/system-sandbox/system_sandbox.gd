extends Node3D

var spaceship_scene = preload("res://scenes/spaceship/test_spaceship/test_spaceship.tscn")
var normal_player = preload("res://scenes/normal_player/normal_player.tscn")


@export var spawn_node: Node

var spawn_points_list: Array[Vector3]

func _ready() -> void:
	var initializer = SystemSandboxInitializer.new()
	add_child(initializer)
	
	if has_node("PlayerSpawnPointsList"):
		for child in get_node("PlayerSpawnPointsList").get_children():
			spawn_points_list.append(child.global_position)
	
	Server.player_spawned.connect(on_player_spawn)
	
	if not OS.has_feature("dedicated_server") and Globals.onlineMode:
		await Server.create_client()
		
	await loadServerCelestial()

func loadServerCelestial():
	print("loadServerCelestial")
	EntityManager.celestial_entity_loaded.connect(Server.spawn_celestial_entity)
	EntityManager.entity_manager_ready.connect(func ():
		EntityManager.load_celestial_entities()
	)
	await get_tree().process_frame
	await get_tree().process_frame

func on_player_spawn(id):
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
	var spawn_point: Vector3 = planet_normal * 2002.0
	
	# Le joueur spawn à une des positions de la liste. La liste est remplie avec les coordonnées de ses enfants de type PlayerSpawnPoint
	if spawn_points_list.size() > 0:
		spawn_point = spawn_points_list.pick_random()
	
	print_rich("[color=green]Spawn point : %.2v[/color]" % spawn_point)
	
	set_player_position.rpc(id, spawn_point, planet_normal)

@rpc("authority", "call_remote", "reliable")
func spawn_station():
	prints("spawn station from", multiplayer.get_unique_id())
	#var station = station_scene.instantiate() as Node3D
	#spawn_node.add_child(station, true)
	#station.global_position = spawn_node.global_basis.y * 3000


@rpc("authority", "call_local", "reliable")
func set_player_position(id: int, player_position: Vector3, planet_normal: Vector3):
	if spawn_node:
		var player = spawn_node.get_node(str(id)) as Node3D
		player.global_position = player_position
		player.global_transform = Globals.align_with_y(player.global_transform, planet_normal)


func _physics_process(delta: float) -> void:
	pass
	if spawn_node:
		spawn_node.rotation.y += 0.01 * delta
