extends Node

const UUID_UTIL = preload("res://addons/uuid/uuid.gd")

var player_scene_path: String = "res://scenes/normal_player/normal_player.tscn"
var ship_scene_path: String = "res://scenes/spaceship/test_spaceship/test_spaceship.tscn"

var client_peer: ENetMultiplayerPeer = null
var peer_id: int = -1

var universe_scene: Node = null
var player_instance: Node = null
var spawn_point: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	pass

func _ready() -> void:
	pass

func start_client(receveid_universe_scene: Node, ip, port) -> void:
	universe_scene = receveid_universe_scene
	var spawn_points_list: Array[Vector3] = universe_scene.spawn_points_list

	if spawn_points_list.size() > 0:
		spawn_point = spawn_points_list.pick_random()

	if Globals.player_uuid == "":
		Globals.player_uuid = UUID_UTIL.v4()
	client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(ip, port)
	universe_scene.multiplayer.multiplayer_peer = client_peer
	peer_id = universe_scene.multiplayer.multiplayer_peer.get_unique_id()

func on_connection_established() -> void:
	request_spawn()

func request_spawn() -> void:
	NetworkOrchestrator.set_player_uuid.rpc_id(
		1,
		Globals.player_uuid,
		GameOrchestrator.login_player_name,
		GameOrchestrator.requested_spawn_point
	)

func complete_client_initialization(entity) -> void:
	player_instance = entity
	player_instance.player_display_name = GameOrchestrator.login_player_name
	player_instance.label_player_name.text = player_instance.player_display_name
	player_instance.connect("client_action_requested", _on_client_action_requested)
	player_instance.direct_chat.connect("send_message", _on_message_from_player)

func receive_chat_message(message: ChatMessage) -> void:
	player_instance.direct_chat.receive_message_from_server(message)

func _on_client_action_requested(datas: Dictionary) -> void:
	if datas.has("action"):
		match datas["action"]:
			"spawn":
				if datas.has("entity"):
					match datas["entity"]:
						"ship":
							var spawn_position: Vector3 = player_instance.global_position + Vector3(10.0,10.0,10.0)
							if datas.has("spawn_position"):
								spawn_position = datas["spawn_position"]
							var spawn_rotation: Vector3 = player_instance.global_transform.basis.y.normalized()
							if datas.has("spawn_rotation"):
								spawn_rotation = datas["spawn_rotation"]
							var data = {
								"x": spawn_position.x,
								"y": spawn_position.y,
								"z": spawn_position.z,
								"rx": spawn_rotation.x,
								"ry": spawn_rotation.y,
								"rz": spawn_rotation.z,
							}
							NetworkOrchestrator.spawn_prop.rpc_id(1, "ship",data)
						"box50cm":
							var spawn_position: Vector3 = player_instance.global_position + Vector3(10.0,10.0,10.0)
							if datas.has("spawn_position"):
								spawn_position = datas["spawn_position"]
							var spawn_rotation: Vector3 = player_instance.global_transform.basis.y.normalized()
							if datas.has("spawn_rotation"):
								spawn_rotation = datas["spawn_rotation"]
							var data = {
								"x": spawn_position.x,
								"y": spawn_position.y,
								"z": spawn_position.z,
								"rx": spawn_rotation.x,
								"ry": spawn_rotation.y,
								"rz": spawn_rotation.z,
							}
							NetworkOrchestrator.spawn_prop.rpc_id(1, "box50cm", data)
						"box4m":
							var spawn_position: Vector3 = player_instance.global_position + Vector3(10.0,10.0,10.0)
							if datas.has("spawn_position"):
								spawn_position = datas["spawn_position"]
							var spawn_rotation: Vector3 = player_instance.global_transform.basis.y.normalized()
							if datas.has("spawn_rotation"):
								spawn_rotation = datas["spawn_rotation"]
							var data = {
								"x": spawn_position.x,
								"y": spawn_position.y,
								"z": spawn_position.z,
								"rx": spawn_rotation.x,
								"ry": spawn_rotation.y,
								"rz": spawn_rotation.z,
							}
							NetworkOrchestrator.spawn_prop.rpc_id(1, "box4m", data)
			"control":
				if datas.has("entity"):
					match datas["entity"]:
						"ship":
							var ship_instance_path: String = datas["entity_node"].get_path() if datas.has("entity_node") else ""
							NetworkOrchestrator.request_control.rpc_id(1, player_instance.get_path(), ship_instance_path)
			"release_control":
				if datas.has("entity"):
					match datas["entity"]:
						"ship":
							var ship_instance_path: String = datas["entity_node"].get_path() if datas.has("entity_node") else ""
							NetworkOrchestrator.request_release.rpc_id(peer_id, player_instance.get_path(), ship_instance_path)

func _on_message_from_player(message: ChatMessage) -> void:
	var dictionnary_message = {
		"content": message.content,
		"author": player_instance.player_display_name,
		"channel": message.channel,
		"creation_schedule": message.creation_schedule
	}
	NetworkOrchestrator.send_chat_message_to_server.rpc_id(1, dictionnary_message)
