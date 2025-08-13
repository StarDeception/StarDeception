extends Node

var SDOServerUrl = ""
var ServerName = ""
var ServerPort = ""

var ServerMQTTUrl
var ServerMQTTPort
var ServerMQTTUsername
var ServerMQTTPasword
var ServerMQTTVerboseLevel

const mqtt = preload("res://addons/mqtt/mqtt.tscn")
var MQTTClient

var network_agent: Node = null
var universe_scene: Node = null

var small_props_spawner_node: MultiplayerSpawner = null
var small_spawnable_props: Array[PackedScene] = []
var small_spawnable_props_entry_point: Node = null

var universe_datas_spawner_node: MultiplayerSpawner = null
var spawnable_planet_scene: PackedScene = null
var spawnable_station_scene: PackedScene = null

var players: Dictionary[int, Player] = {}
var player_ship: Dictionary[int, Spaceship] = {}

var isInsideBox4m: bool = false

func _enter_tree() -> void:
	loadServerConfig()

func create_server() -> void:
	network_agent = load("res://server/server.tscn").instantiate()
	call_deferred("add_child",network_agent)

func create_client() -> void:
	network_agent = load("res://server/client.tscn").instantiate()
	call_deferred("add_child",network_agent)

func start_server(changed_scene) -> Node:
	
	universe_scene = changed_scene
	
	small_props_spawner_node = universe_scene.get_node("SmallPropsMultiplayerSpawner")
	universe_datas_spawner_node = universe_scene.get_node("UniversDatasMultiplayerSpawner")
	
	var spawnable_planet_path: String = universe_datas_spawner_node.get_spawnable_scene(0)
	spawnable_planet_scene = load(spawnable_planet_path)
	var spawnable_station_path: String = universe_datas_spawner_node.get_spawnable_scene(1)
	spawnable_station_scene = load(spawnable_station_path)
	
	small_props_spawner_node.spawn_function = Callable(self, "_spawn_entity")
	
	preload_small_props(small_props_spawner_node)
	small_spawnable_props_entry_point = small_props_spawner_node.get_node(small_props_spawner_node.get_spawn_path())
	network_agent.start_server(changed_scene, small_spawnable_props_entry_point)
	return network_agent

func start_client(changed_scene) -> Node:
	universe_scene = changed_scene
	small_props_spawner_node = universe_scene.get_node("SmallPropsMultiplayerSpawner")
	
	small_props_spawner_node.spawn_function = Callable(self, "_spawn_entity")
	
	small_props_spawner_node.connect("spawned", _on_entity_spawned)
	
	preload_small_props(small_props_spawner_node)
	small_spawnable_props_entry_point = small_props_spawner_node.get_node(small_props_spawner_node.get_spawn_path())
	network_agent.start_client(changed_scene)
	return network_agent

## Load configuration from server.ini file
func loadServerConfig():
	var config = ConfigFile.new()
	config.load("server.ini")
	SDOServerUrl = config.get_value("server", "SDO")
	ServerPort = config.get_value("server", "port")
	ServerName = config.get_value("server", "name")
	# Load chat config
	ServerMQTTUrl = config.get_value("chat", "url")
	ServerMQTTPort = config.get_value("chat", "port")
	ServerMQTTUsername = config.get_value("chat", "username")
	ServerMQTTPasword = config.get_value("chat", "password")
	ServerMQTTVerboseLevel = config.get_value("chat", "verbose_level")

func preload_small_props(small_props_spawner: Node) -> void:
	var small_props_number: int = small_props_spawner.get_spawnable_scene_count()
	for i in range(small_props_number):
		small_spawnable_props.append(load(small_props_spawner.get_spawnable_scene(i)))

func _spawn_entity(datas: Dictionary) -> Node:
	var spawned_entity_instance: Node3D = null
	if datas.has("entity"):
		match datas["entity"]:
			"player":
				spawned_entity_instance = load(datas["player_scene_path"]).instantiate()
				spawned_entity_instance.name = datas["player_name"]
				spawned_entity_instance.spawn_position = datas["player_spawn_position"]
				spawned_entity_instance.spawn_up = datas["player_spawn_up"]
				spawned_entity_instance.set_multiplayer_authority(datas["authority_peer_id"])
			"ship":
				spawned_entity_instance = load(datas["ship_scene_path"]).instantiate()
				spawned_entity_instance.spawn_position = datas["ship_spawn_position"]
				spawned_entity_instance.spawn_rotation = datas["ship_spawn_rotation"]
				spawned_entity_instance.set_multiplayer_authority(1)
	
	return spawned_entity_instance

func _on_entity_spawned(entity: Node) -> void:
	if entity is Player:
		var my_unique_id = universe_scene.multiplayer.get_unique_id()
		if entity.get_multiplayer_authority() == my_unique_id:
			network_agent.complete_client_initialization(entity)

#region Chat Part

func connect_chat_mqtt():
	MQTTClient = mqtt.instantiate()
	GameOrchestrator.get_tree().get_current_scene().add_child(MQTTClient)

	MQTTClient.broker_connected.connect(_on_mqtt_broker_connected)
	MQTTClient.broker_connection_failed.connect(_on_mqtt_broker_connection_failed)
	MQTTClient.received_message.connect(_on_mqtt_received_message)
	MQTTClient.verbose_level = ServerMQTTVerboseLevel
	#MQTTClient.connect_to_broker("tcp://", "192.168.20.158", 1883)
	MQTTClient.connect_to_broker("ws://", ServerMQTTUrl, ServerMQTTPort)

func _on_mqtt_received_message(topic, message):
	if topic == "chat/GENERAL":
		var chatData = JSON.parse_string(message)
		var chat_message = ChatMessage.new(chatData.msg, 0, chatData.pseudo, 0.0)
		var chat_message_for_rpc: Dictionary = {"content": chat_message["content"], "author": chat_message["author"], "channel": chat_message["channel"], "creation_schedule": chat_message["creation_schedule"]}
		receive_chat_message_from_server.rpc(chat_message_for_rpc)
	else:
		print(topic)
		print(message)

func _on_mqtt_broker_connected():
	print("[chat] MQTT chat connected")
	MQTTClient.subscribe("chat/GENERAL")
	MQTTClient.publish("test", "I'm here NOW")

func _on_mqtt_broker_connection_failed():
	print("[chat] MQTT chat failed to connecte :(")

@rpc("any_peer", "call_remote", "unreliable")
func send_chat_message_to_server(message: Dictionary) -> void:

	if not multiplayer.is_server():
		return
	
	####################
	# TRAITER LE MESSAGE SI BESOIN
	####################
		
	###################
	# ENVOI VIA MQTT
	var channelName: String = ""
	if message.has("channel"):
		match message["channel"]:
			0:
				channelName = "GENERAL"
				MQTTClient.publish("chat/" + channelName, JSON.stringify({
					"pseudo": message["author"],
					"msg": message["content"],
				}))
	
	###################
	# ENVOI VIA LE SERVEUR LOCAL
	#receive_chat_message_from_server.rpc(message)
	###################

# Receives a message from the server
@rpc("authority", "call_remote", "unreliable")
func receive_chat_message_from_server(message: Dictionary) -> void:
	if not multiplayer.is_server():
		var chat_message = ChatMessage.new(message["content"], message["channel"], message["author"], message["creation_schedule"])
		network_agent.receive_chat_message(chat_message)

#endregion

@rpc("any_peer", "call_remote", "reliable")
func spawn_box50cm(spawn_position: Vector3 = Vector3.ZERO) -> void:
	if not multiplayer.is_server():
		return
	
	var box50cm_instance: RigidBody3D = small_spawnable_props[2].instantiate()
	
	box50cm_instance.spawn_position = spawn_position
	small_props_spawner_node.get_node(small_props_spawner_node.spawn_path).call_deferred("add_child", box50cm_instance, true)
	
	if isInsideBox4m:
		box50cm_instance.set_collision_layer_value(1, false)
		box50cm_instance.set_collision_layer_value(2, true)
		box50cm_instance.set_collision_mask_value(1, false)
		box50cm_instance.set_collision_mask_value(2, true)

@rpc("any_peer", "call_remote", "reliable")
func spawn_box4m(spawn_position: Vector3 = Vector3.ZERO, spawn_rotation: Vector3 = Vector3.UP) -> void:
	if not multiplayer.is_server():
		return
	
	var box4m_instance: RigidBody3D = small_spawnable_props[3].instantiate()
	
	box4m_instance.spawn_position = spawn_position
	box4m_instance.spawn_rotation = spawn_rotation
	small_props_spawner_node.get_node(small_props_spawner_node.spawn_path).call_deferred("add_child", box4m_instance, true)

@rpc("authority", "call_remote", "reliable")
func spawn_planet(planet_datas: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var spawnable_planet_instance: Node3D = spawnable_planet_scene.instantiate()
	spawnable_planet_instance.spawn_position = planet_datas["coordinates"]
	spawnable_planet_instance.name = planet_datas["name"]
	universe_datas_spawner_node.get_node(universe_datas_spawner_node.spawn_path).call_deferred("add_child", spawnable_planet_instance, true)
	network_agent.spawn_data_processed(spawnable_planet_instance)

@rpc("authority", "call_remote", "reliable")
func spawn_station(station_datas: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	
	var spawnable_station_instance: Node3D = spawnable_station_scene.instantiate()
	spawnable_station_instance.spawn_position = station_datas["coordinates"]
	spawnable_station_instance.name = station_datas["name"]
	universe_datas_spawner_node.get_node(universe_datas_spawner_node.spawn_path).call_deferred("add_child", spawnable_station_instance, true)
	network_agent.spawn_data_processed(spawnable_station_instance)

@rpc("any_peer", "call_remote", "reliable")
func spawn_ship(ship_scene_path: String = "", spawn_position: Vector3 = Vector3.ZERO, spawn_rotation: Vector3 = Vector3.ZERO):
	var senderid = universe_scene.multiplayer.get_remote_sender_id()
	
	if not multiplayer.is_server():
		return
	
	small_props_spawner_node.spawn({"entity": "ship", "ship_scene_path": ship_scene_path, "ship_spawn_position": spawn_position, "ship_spawn_rotation": spawn_rotation, "authority_peer_id": senderid})

@rpc("any_peer", "call_remote", "reliable")
func spawn_player(player_scene_path: String = "", spawn_point: int = 0):
	var senderid = universe_scene.multiplayer.get_remote_sender_id()
	
	if not multiplayer.is_server():
		return
	
	var spawn_position: Vector3 = Vector3.ZERO
	var spawn_up: Vector3 = Vector3.UP
	if spawn_point >= 0 and spawn_point < GameOrchestrator.SPAWN_POINTS_LIST.size():
		var spawn_point_node_path: String = GameOrchestrator.SPAWN_POINTS_LIST[spawn_point]["node_path"]
		if spawn_point_node_path == "":
			var parent_entity_spawn_position: Vector3 = universe_scene.get_node("PlanetA").global_position if randf() < 0.5 else universe_scene.get_node("PlanetB").global_position
			spawn_position = random_spawn_on_planet(parent_entity_spawn_position, 2000.0)
			spawn_up = (spawn_position - parent_entity_spawn_position).normalized()
		elif spawn_point_node_path.contains("PlayerSpawnPointsList"):
			spawn_position = universe_scene.get_node(spawn_point_node_path).global_position
			if spawn_point_node_path.contains("PlanetA"):
				spawn_up = (spawn_position - universe_scene.get_node("PlanetA").global_position).normalized()
			elif spawn_point_node_path.contains("PlanetB"):
				spawn_up = (spawn_position - universe_scene.get_node("PlanetB").global_position).normalized()
			elif spawn_point_node_path.contains("StationA"):
				spawn_up = universe_scene.get_node(spawn_point_node_path).transform.basis.y.normalized()
		else:
			var parent_entity_spawn_position: Vector3 = universe_scene.get_node(spawn_point_node_path).global_position
			spawn_position = random_spawn_on_planet(parent_entity_spawn_position, 2000.0)
			spawn_up = (spawn_position - parent_entity_spawn_position).normalized()
	
	small_props_spawner_node.spawn({"entity": "player", "player_scene_path": player_scene_path, "player_name": "Player_" + str(senderid), "player_spawn_position": spawn_position, "player_spawn_up": spawn_up, "authority_peer_id": senderid})

func random_spawn_on_planet(planet_position: Vector3, radius: float) -> Vector3:
	var theta = randf() * TAU					# Angle azimutal
	var phi = acos(1.0 - 2.0 * randf())			# Angle polaire
	
	var random_point_on_unit_sphere = Vector3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi))
	
	return planet_position + random_point_on_unit_sphere * (radius + 1.0)

## Request the control of the ship to the server
@rpc("any_peer", "call_remote", "reliable")
func request_control(player_instance_path: String = "", ship_instance_path: String =""):
	if not multiplayer.is_server():
		return
	
	var senderid = universe_scene.multiplayer.get_remote_sender_id()
	var player_instance = get_node(player_instance_path)
	if player_instance:
		var ship_instance = get_node(ship_instance_path)
		if ship_instance:
			give_control.rpc(senderid, player_instance_path, ship_instance_path)

@rpc("authority", "call_local", "reliable")
func give_control(id, player_instance_path, ship_instance_path):
	var player_instance = get_node(player_instance_path)
	if player_instance:
		var ship_instance = get_node(ship_instance_path)
		if ship_instance:
			ship_instance.pilot = player_instance
			ship_instance.pilot.active = false
			ship_instance.pilot.camera_pivot.rotation.x = 0
			ship_instance.pilot_seat.remote_path = player_instance.get_path()
			
			ship_instance.set_multiplayer_authority(id)

@rpc("authority", "call_local", "reliable")
func request_release(player_instance_path, ship_instance_path):
	var player_instance = get_node(player_instance_path)
	if player_instance:
		var ship_instance = get_node(ship_instance_path)
		if ship_instance:
			release_control.rpc(player_instance_path, ship_instance_path)

@rpc("any_peer", "call_local", "reliable")
func release_control(player_instance_path, ship_instance_path):
	var player_instance = get_node(player_instance_path)
	if player_instance:
		var ship_instance = get_node(ship_instance_path)
		if ship_instance:
			ship_instance.pilot.active = true
			ship_instance.pilot = null
			ship_instance.pilot_seat.remote_path = NodePath("")
			ship_instance.active = false
			ship_instance.set_multiplayer_authority(1)

@rpc("authority", "call_remote", "reliable")
func notify_client_connected():
	if not multiplayer.is_server():
		network_agent.on_connection_established()
