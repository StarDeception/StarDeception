extends Node

var normal_player = preload("res://scenes/normal_player/normal_player.tscn")
var box_50cm = preload("res://scenes/props/testbox/box_50cm.tscn")
const box_4m = preload("res://scenes/props/testbox/box_4m.tscn")
var spaceship_scene = preload("res://scenes/spaceship/test_spaceship/test_spaceship.tscn")

## triggered when a new player has spawned
signal player_spawned(id)

var entities_spawn_node: Node3D

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

var players: Dictionary[int, Player] = {}
var player_ship: Dictionary[int, Spaceship] = {}

@onready var isInsideBox4m: bool = false

func _ready() -> void:
	
	if OS.has_feature("dedicated_server"):
		print("OS has dedicated_server")
		_start_server()
	else:
		print("OS doesn't have dedicated_server")



func _physics_process(_delta: float) -> void:
	if OS.has_feature("dedicated_server"):
		pass

func _display_type_of_var(variable):
	print("TYPE OF VAR")
	print(type_string(typeof(variable)))


####################################################################################
# Played on game server
####################################################################################

func _start_server():
	print("Starting the server...")
	# change to main scene
	get_tree().call_deferred("change_scene_to_file", Globals.init_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	loadServerConfig()
	
	entities_spawn_node = get_tree().get_current_scene().get_node("Planet")

	var server_peer = ENetMultiplayerPeer.new()
	var res = server_peer.create_server(7051, 150)
	if res != OK:
		prints("creating server failed:", error_string(res))
		return
		
	multiplayer.multiplayer_peer = server_peer
	connect_chat_mqtt()
	print("server loaded... \\o/")
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnect)

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

func _on_player_connected(id):
	print("player " + str(id) + " connected, wouahou !")
	
	player_spawned.emit(id)

func _on_player_disconnect(id):
	print("player " + str(id) + " disconnected")
	var player = entities_spawn_node.get_node_or_null(str(id))
	if player:
		player.queue_free()
	
	var ship = player_ship[id]
	if ship:
		ship.queue_free()
	
	players.erase(id)
	player_ship.erase(id)


@rpc("any_peer", "call_remote", "reliable")
func spawn_box50cm() -> void:
	var senderid = multiplayer.get_remote_sender_id()
	# server received and ths is played on all clients (rpc any_peer)
	var box50cm_instance = box_50cm.instantiate()
	
	var player = players[senderid]
	
	var spawn_position = player.global_position + (-player.global_basis.z * 1.5) + player.global_basis.y * 2.0
	
	players[senderid].add_sibling(box50cm_instance, true)
	box50cm_instance.global_position = spawn_position
	
	if isInsideBox4m:
		box50cm_instance.set_collision_layer_value(1, false)
		box50cm_instance.set_collision_layer_value(2, true)
		box50cm_instance.set_collision_mask_value(1, false)
		box50cm_instance.set_collision_mask_value(2, true)

###################
# Chat part       #

func connect_chat_mqtt():
	MQTTClient = mqtt.instantiate()
	get_tree().get_current_scene().add_child(MQTTClient)

	MQTTClient.broker_connected.connect(_on_mqtt_broker_connected)
	MQTTClient.broker_connection_failed.connect(_on_mqtt_broker_connection_failed)
	MQTTClient.received_message.connect(_on_mqtt_received_message)
	MQTTClient.verbose_level = ServerMQTTVerboseLevel
	#MQTTClient.connect_to_broker("tcp://", "192.168.20.158", 1883)
	MQTTClient.connect_to_broker("ws://", ServerMQTTUrl, ServerMQTTPort)

func _on_mqtt_received_message(topic, message):
	print("[chat] received MQTT message")
	if topic == "chat/GENERAL":
		var chatData = JSON.parse_string(message)
		rpc("receive_chat_message_from_server", chatData.msg, chatData.pseudo, "GENERAL")
	else:
		print(topic)
		print(message)

func _on_mqtt_broker_connected():
	print("[chat] MQTT chat connected")
	MQTTClient.subscribe("chat/GENERAL")
	MQTTClient.publish("test", "I'm here NOW")

func _on_mqtt_broker_connection_failed():
	print("[chat] MQTT chat failed to connecte :(")

@rpc("any_peer", "call_local", "reliable")
func server_receive_chat_message(channelName, pseudo, message):
	MQTTClient.publish("chat/" + channelName, JSON.stringify({
		"pseudo": pseudo,
		"msg": message,
	}))


@rpc("any_peer", "call_remote", "reliable")
func spawn_box4m() -> void:
	var player = Server.players[multiplayer.get_remote_sender_id()]
	var box4m_instance: RigidBody3D = box_4m.instantiate()
	var spawn_position: Vector3 = player.global_position + (-player.global_basis.z * 3.0) + player.global_basis.y * 6.0
	player.add_sibling(box4m_instance, true)
	box4m_instance.global_position = spawn_position
	var to_player = (player.global_transform.origin - spawn_position)
	box4m_instance.rotate_y(atan2(to_player.x, to_player.z) + PI)

@rpc("any_peer", "call_remote", "reliable")
func spawn_ship() -> void:
	var id = multiplayer.get_remote_sender_id()
	var player = Server.players[id]
	var ship_pos = player.global_position + -player.global_basis.z * 10 + player.global_basis.y * 3
	
	var spaceship = spaceship_scene.instantiate() as Spaceship
	
	Server.player_ship[id] = spaceship
	player.add_sibling(spaceship, true)
	
	var planet_normal = get_tree().current_scene.global_position.direction_to(player.global_position)
	
	#spaceship.position_ship.rpc(ship_pos, planet_normal)
	spaceship.global_position = ship_pos
	spaceship.global_transform = Globals.align_with_y(spaceship.global_transform, planet_normal)

#####################################################################################
## Played on the very first game server (to manage all players positions)
#####################################################################################





####################################################################################
# Played on client
####################################################################################

func create_client(client_tree: Node):
	# create client
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 7051)
	client_tree.multiplayer.multiplayer_peer = client_peer

@rpc("any_peer", "call_remote", "unreliable", 0)
func receive_chat_message_from_server(message: String, pseudo: String, channel: String) -> void:
	var sceneChat = get_tree().get_current_scene().get_node("GlobalChat")
	var canvas = sceneChat.get_node("CanvasLayer")
	var chatContainer = canvas.get_node("global_chat_container")
	chatContainer.receive_message_from_server(message, pseudo, channel)
