extends Node

var normal_player = preload("res://scenes/normal_player/normal_player.tscn")
var sandbox_scene = preload("res://levels/sandbox/sandbox.tscn")
var _players_spawn_node

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
