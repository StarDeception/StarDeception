extends Node

var normal_player = preload("res://scenes/normal_player/normal_player.tscn")
var sandbox_scene = preload("res://levels/sandbox/sandbox.tscn")
var box_50cm = preload("res://scenes/props/testbox/box_50cm.tscn")

var _players_spawn_node
var _spawn_node_box_50cm

@onready var isInsideBox4m: bool = false

func _ready() -> void:
	
	if OS.has_feature("dedicated_server"):
		print("OS has dedicated_server")
		_start_server()
	else:
		print("OS doesn't have dedicated_server")



func _physics_process(delta: float) -> void:
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
	get_tree().change_scene_to_packed(sandbox_scene)
	await get_tree().create_timer(4.0).timeout

	_players_spawn_node = get_tree().get_current_scene().get_node("Players")
	_spawn_node_box_50cm = get_tree().get_current_scene().get_node("Boxes50cm")

	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(7051, 150)
	multiplayer.multiplayer_peer = server_peer
	print("server loaded... \\o/")
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnect)

func _on_player_connected(id):
	print("player " + str(id) + " connected, wouahou !")
	var player_to_add = normal_player.instantiate()
	player_to_add.name = str(id)
	_players_spawn_node.add_child(player_to_add, true)

func _on_player_disconnect(id):
	print("player " + str(id) + " disconnected")

	var player = _players_spawn_node.get_node_or_null(str(id))
	if player:
		player.queue_free()

@rpc("any_peer", "call_local", "reliable")
func spawn_box50cm(spawn_position) -> void:
	# server received and ths is played on all clients (rpc any_peer)
	var box50cm_instance = box_50cm.instantiate()
	_spawn_node_box_50cm = get_tree().get_current_scene().get_node("Boxes50cm")
	_spawn_node_box_50cm.add_child(box50cm_instance, true)
	box50cm_instance.global_position = spawn_position
	
	if isInsideBox4m:
		box50cm_instance.set_collision_layer_value(1, false)
		box50cm_instance.set_collision_layer_value(2, true)
		box50cm_instance.set_collision_mask_value(1, false)
		box50cm_instance.set_collision_mask_value(2, true)

#####################################################################################
## Played on the very first game server (to manage all players positions)
#####################################################################################





####################################################################################
# Played on client
####################################################################################

func create_client(player_scene):
	# create client
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 7051)
	multiplayer.multiplayer_peer = client_peer

