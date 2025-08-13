extends Node

signal populated_universe

var universe_scene: Node = null
var entities_spawn_node: Node = null
var datas_to_spawn_count: int = 0

var clients_peers_ids: Array[int] = []

func _enter_tree() -> void:
	pass

func _ready() -> void:
	pass

func start_server(receveid_universe_scene: Node, receveid_player_spawn_node: Node) -> void:
	universe_scene = receveid_universe_scene
	entities_spawn_node = receveid_player_spawn_node
	var server_peer = ENetMultiplayerPeer.new()
	if not server_peer:
		printerr("creating server_peer failed!")
		return
	
	var res = server_peer.create_server(7051, 150)
	if res != OK:
		printerr("creating server failed: ", error_string(res))
		return
	
	universe_scene.multiplayer.multiplayer_peer = server_peer
	NetworkOrchestrator.connect_chat_mqtt()
	print("server loaded... \\o/")
	universe_scene.multiplayer.peer_connected.connect(_on_client_peer_connected)
	universe_scene.multiplayer.peer_disconnected.connect(_on_client_peer_disconnect)

func populate_universe(datas: Dictionary) -> void:
	
	if datas.has("datas_count"):
		datas_to_spawn_count = datas["datas_count"]
	
	for data_key in datas:
		match data_key:
			"planets":
				for planet in range(datas[data_key].size()):
					NetworkOrchestrator.spawn_planet(datas[data_key][planet])
			"stations":
				for station in range(datas[data_key].size()):
					NetworkOrchestrator.spawn_station(datas[data_key][station])

func spawn_data_processed(spawned_entity: Node) -> void:
	await spawned_entity.ready
	datas_to_spawn_count -= 1
	if datas_to_spawn_count == 0:
		emit_signal("populated_universe", universe_scene)

func _on_client_peer_connected(peer_id: int):
	clients_peers_ids.append(peer_id)
	NetworkOrchestrator.notify_client_connected.rpc_id(peer_id)

func _on_client_peer_disconnect(id):
	print("player " + str(id) + " disconnected")
	var player = entities_spawn_node.get_node_or_null("Player_" + str(id))
	if player:
		player.queue_free()
	
	if NetworkOrchestrator.player_ship.has(id):
		var ship = NetworkOrchestrator.player_ship[id]
		if ship:
			ship.queue_free()
	
	NetworkOrchestrator.players.erase(id)
	NetworkOrchestrator.player_ship.erase(id)
