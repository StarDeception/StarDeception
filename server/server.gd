extends Node

signal populated_universe

const UUID_UTIL = preload("res://addons/uuid/uuid.gd")

var universe_scene: Node = null
var entities_spawn_node: Node = null
var datas_to_spawn_count: int = 0

var clients_peers_ids: Array[int] = []

var server_zone = {
	"x_start": -100000.0,
	"x_end": 100000.0,
	"y_start": -100000.0,
	"y_end": 100000.0,
	"z_start": -100000.0,
	"z_end": 100000.0
}

var max_players_allowed: int = 2
var players_list: Dictionary = {}
var players_list_last_movement: Dictionary = {}
var players_list_last_rotation: Dictionary = {}
var players_list_temp_by_id: Dictionary = {}
var players_list_currently_in_transfert: Dictionary = {}
var changing_zone: bool = false
var transfer_players: bool = false
var props_list: Dictionary = {
	"box50cm": {},
	"box4m": {},
	"ship": {},
}
var props_list_last_movement: Dictionary = {
	"box50cm": {},
	"box4m": {},
	"ship": {},
}
var props_list_last_rotation: Dictionary = {
	"box50cm": {},
	"box4m": {},
	"ship": {},
}

var servers_ticks_tasks: Dictionary = {
	"TooManyPlayersCurent": 3600,
	"TooManyPlayersReset": 3600, # all 1 minute
	"SendPlayersToMQTTCurrent": 15,
	"SendPlayersToMQTTReset": 15,
	"CheckPlayersOutOfZoneCurrent": 20,
	"CheckPlayersOutOfZoneReset": 20,
	"SendPropsToMQTTCurrent": 15,
	"SendPropsToMQTTReset": 15,
	"SendMetricsCurrent": 120,
	"SendMetricsReset": 120,
}

func _enter_tree() -> void:
	NetworkOrchestrator.load_server_config()

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	if NetworkOrchestrator.is_sdo_active == true:
		_is_server_has_too_many_players()
		_send_players_to_sdo()
		_check_player_out_of_zone()
		_send_props_to_sdo()

func start_server(receveid_universe_scene: Node, receveid_player_spawn_node: Node) -> void:
	universe_scene = receveid_universe_scene
	entities_spawn_node = receveid_player_spawn_node
	var server_peer = ENetMultiplayerPeer.new()
	if not server_peer:
		printerr("creating server_peer failed!")
		return

	var res = server_peer.create_server(NetworkOrchestrator.server_port, 150)
	if res != OK:
		printerr("creating server failed: ", error_string(res))
		return

	universe_scene.multiplayer.multiplayer_peer = server_peer
	NetworkOrchestrator.connect_chat_mqtt()
	# load SDO mqtt in NetworkOrchestrator
	NetworkOrchestrator.connect_mqtt_sdo()
	if NetworkOrchestrator.metrics_enabled == true:
		NetworkOrchestrator.connect_mqtt_metrics()
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

	# TODO manage players move to another server and players disconnect completly
	var uuid = players_list_temp_by_id[id]
	if not players_list_currently_in_transfert.has(uuid):
		var data = JSON.stringify({
			"add": [],
			"update": [],
			"delete": [{"client_uuid" : players_list_temp_by_id[id]}],
			"server_id": NetworkOrchestrator.server_sdo_id,
		})
		NetworkOrchestrator.mqtt_client_sdo.publish("sdo/playerschanges", data)
		players_list_temp_by_id.erase(multiplayer.get_remote_sender_id())
		players_list.erase(players_list_temp_by_id[id])

		# player.queue_free()
	NetworkOrchestrator.update_all_text_client()



func _is_server_has_too_many_players():
	if servers_ticks_tasks.TooManyPlayersCurent > 0:
		servers_ticks_tasks.TooManyPlayersCurent -= 1
	else:
		if players_list.size() > max_players_allowed and changing_zone == false:
			if _players_must_change_server() == false:
				var players_data = []
				for value in players_list.values():
					var position = value.global_position
					if position != Vector3.ZERO:
						# can have position zero if spawn not yet defined and it can break split of servers
						players_data.append({"x": position[0], "y": position[1], "z": position[2]})
				print("######################################################")
				print("####################### Too many players, need split #")
				changing_zone = true
				NetworkOrchestrator.mqtt_client_sdo.publish("sdo/servertooheavy", JSON.stringify({
					"id": NetworkOrchestrator.server_sdo_id,
					"players": players_data,
				}))
		servers_ticks_tasks.TooManyPlayersCurent = servers_ticks_tasks.TooManyPlayersReset

func _send_players_to_sdo():
	if servers_ticks_tasks.SendPlayersToMQTTCurrent > 0:
		servers_ticks_tasks.SendPlayersToMQTTCurrent -= 1
	else:
		var players_data = []
		var position = Vector3(0.0, 0.0, 0.0)
		var rotation = Vector3(0.0, 0.0, 0.0)
		for puuid in players_list.keys():
			position = players_list[puuid].global_position
			rotation = players_list[puuid].global_rotation
			if players_list_last_movement[puuid] != position or players_list_last_rotation[puuid] != rotation:
				if not players_list_currently_in_transfert.has(puuid):
					# only the players of this server and not in transfert
					players_data.append({
						"name": players_list[puuid].name,
						"client_uuid": puuid,
						"x": position[0],
						"y": position[1],
						"z": position[2],
						"xr": rotation[0],
						"yr": rotation[1],
						"zr": rotation[2]
					})
					players_list_last_movement[puuid] = position
					players_list_last_rotation[puuid] = rotation
		if players_data.size() > 0:
			NetworkOrchestrator.mqtt_client_sdo.publish("sdo/playerschanges", JSON.stringify({
				"add": [],
				"update": players_data,
				"delete": [],
				"server_id": NetworkOrchestrator.server_sdo_id,
			}))
		servers_ticks_tasks.SendPlayersToMQTTCurrent = servers_ticks_tasks.SendPlayersToMQTTReset

func _check_player_out_of_zone():
	if servers_ticks_tasks.CheckPlayersOutOfZoneCurrent > 0:
		servers_ticks_tasks.CheckPlayersOutOfZoneCurrent -= 1
	else:
		if changing_zone == false:
			_players_must_change_server()
		servers_ticks_tasks.CheckPlayersOutOfZoneCurrent = servers_ticks_tasks.CheckPlayersOutOfZoneReset

func _players_must_change_server():
	# loop on coordinates of new server
	var some_players_transfered = false
	for puuid in players_list.keys():
		if players_list_currently_in_transfert.has(puuid):
			continue
		var position = players_list[puuid].global_position
		if position[0] < server_zone.x_start or position[0] > server_zone.x_end:
			print("Expulse player X: " + str(puuid))
			print("serverstart, server end, player: ", server_zone.x_start, " ", server_zone.x_end, " ", position[0])
			var new_server = _search_another_server_for_coordinates(position[0], position[1], position[2])
			if new_server != null:
				NetworkOrchestrator.transfert_player_to_another_server(puuid, new_server)
				some_players_transfered = true
			else:
				print("ERROR: no server found to expulse :/")
		elif position[1] < server_zone.y_start or position[1] > server_zone.y_end:
			print("Expulse player Y: " + str(puuid))
			print("serverstart, server end, player: ", server_zone.y_start, " ", server_zone.y_end, " ", position[1])
			var new_server = _search_another_server_for_coordinates(position[0], position[1], position[2])
			if new_server != null:
				NetworkOrchestrator.transfert_player_to_another_server(puuid, new_server)
				some_players_transfered = true
		elif position[2] < server_zone.z_start or position[2] > server_zone.z_end:
			print("Expulse player Z: " + str(puuid))
			print("serverstart, server end, player: ", server_zone.z_start, " ", server_zone.z_end, " ", position[2])
			var new_server = _search_another_server_for_coordinates(position[0], position[1], position[2])
			if new_server != null:
				NetworkOrchestrator.transfert_player_to_another_server(puuid, new_server)
				some_players_transfered = true
	return some_players_transfered

func _search_another_server_for_coordinates(x, y, z):
	for s in NetworkOrchestrator.servers_list.values():
		if s.id == NetworkOrchestrator.server_sdo_id:
			continue
		if float(s.x_start) <= x \
			and x < float(s.x_end) \
			and float(s.y_start) <= y \
			and y < float(s.y_end) \
			and float(s.z_start) <= z \
			and z < float(s.z_end):
			return s
	return null

# Instantiate remote server player, need to be visible for players on this server
func instantiate_player_remote(player, set_player_position = false, server_id = null):
	var playername = "Pigeon with no name"
	if player.has("name"):
		playername = player.name
	var spawn_position: Vector3 = Vector3.ZERO
	if set_player_position == true:
		spawn_position = Vector3(float(player.x), float(player.y), float(player.z))
		print("Remnote player spawn with position: ", spawn_position)

	var player_to_add = NetworkOrchestrator.small_props_spawner_node.spawn({
		"entity": "player",
		"player_scene_path": NetworkOrchestrator.player_scene_path,
		"player_name": "remoteplayer" + playername,
		"player_spawn_position": spawn_position,
		"player_spawn_up": Vector3.UP,
		"authority_peer_id": 1
	})
	player_to_add.name = playername
	player_to_add.label_player_name.text = playername
	player_to_add.global_rotation = Vector3(float(player.xr), float(player.yr), float(player.zr))
	player_to_add.set_physics_process(false)
	NetworkOrchestrator.players_list[player.client_uuid] = player_to_add
	if server_id != null:
		player_to_add.label_server_name.text = NetworkOrchestrator.servers_list[server_id].name

	print("Remnote player spawned with position: ", player_to_add.global_position)

func _send_metrics():
	if servers_ticks_tasks.SendMetricsCurrent > 0:
		servers_ticks_tasks.SendMetricsCurrent -= 1
	else:
		if NetworkOrchestrator.metrics_enabled == true:
			var all_metrics = {
				"currentplayers": players_list.size(),
				"memory": Performance.get_monitor(Performance.MEMORY_STATIC),
				"numberobjects": Performance.get_monitor(Performance.OBJECT_COUNT),
				"timefps": Performance.get_monitor(Performance.TIME_FPS),
			}
			for proptype in props_list.keys():
				all_metrics["current" + proptype] = props_list[proptype].size()
			NetworkOrchestrator.mqtt_client_metrics.publish("metrics/server/" + NetworkOrchestrator.server_name, JSON.stringify(all_metrics))
		servers_ticks_tasks.SendMetricsCurrent = servers_ticks_tasks.SendMetricsReset


#########################
# Props				 #

func instantiate_props_remote_add(prop):
	_spawn_prop_remote_add(prop)

func instantiate_props_remote_update(prop):
	_spawn_prop_remote_update(prop)

func _spawn_prop_remote_add(prop):
	# print("Create prop: ", prop)
	# add prop
	if not props_list.has(prop.type):
		return
	var uuid = UUID_UTIL.v4()
	var prop_instance: RigidBody3D = NetworkOrchestrator.get_spawnable_props_newinstance(prop.type)
	NetworkOrchestrator.props_list[prop.type][uuid] = prop_instance
	prop_instance.spawn_position = Vector3(float(prop.x), float(prop.y), float(prop.z))
	prop_instance.set_physics_process(false)
	NetworkOrchestrator.small_props_spawner_node.get_node(NetworkOrchestrator.small_props_spawner_node.spawn_path).call_deferred("add_child", prop_instance, true)
	NetworkOrchestrator.props_list[prop.type][uuid] = prop_instance

func _spawn_prop_remote_update(prop):
	if not NetworkOrchestrator.props_list[prop.type].has(prop.uuid):
		return
	# update the position
	NetworkOrchestrator.props_list[prop.type][prop.uuid].global_position = Vector3(float(prop.x), float(prop.y), float(prop.z))
	NetworkOrchestrator.props_list[prop.type][prop.uuid].global_rotation = Vector3(float(prop.xr), float(prop.yr), float(prop.zr))

func _send_props_to_sdo():
	if servers_ticks_tasks.SendPropsToMQTTCurrent > 0:
		servers_ticks_tasks.SendPropsToMQTTCurrent -= 1
	else:
		var props_data = []
		var position = Vector3(0.0, 0.0, 0.0)
		var rotation = Vector3(0.0, 0.0, 0.0)
		for proptype in props_list.keys():
			for uuid in props_list[proptype].keys():
				position = props_list[proptype][uuid].global_position
				rotation = props_list[proptype][uuid].global_rotation
				if props_list_last_movement[proptype][uuid] != position or props_list_last_rotation[proptype][uuid] != rotation:
					props_data.append({
						"type": proptype,
						"uuid": uuid,
						"x": position[0],
						"y": position[1],
						"z": position[2],
						"xr": rotation[0],
						"yr": rotation[1],
						"zr": rotation[2]
					})
					props_list_last_movement[proptype][uuid] = position
					props_list_last_rotation[proptype][uuid] = rotation
					# used for call save on persistance
					if props_list[proptype][uuid].has_node("DataEntity"):
						var dataentity = props_list[proptype][uuid].get_node("DataEntity")
						dataentity.backgroud_save()
		if props_data.size() > 0:
			NetworkOrchestrator.mqtt_client_sdo.publish("sdo/propschanges", JSON.stringify({
				"add": [],
				"update": props_data,
				"delete": [],
				"server_id": NetworkOrchestrator.server_sdo_id,
			}))
		servers_ticks_tasks.SendPropsToMQTTCurrent = servers_ticks_tasks.SendPropsToMQTTReset

func set_server_inactive(_newserver_id):
	print("# Disable the server")
	NetworkOrchestrator.is_sdo_active = false
	# TODO send props to new server id
	# unload all
	print("Clean items")
	for uuid in NetworkOrchestrator.players_list.keys():
		NetworkOrchestrator.players_list[uuid].queue_free()
		NetworkOrchestrator.players_list.erase(uuid)
	for proptype in NetworkOrchestrator.props_list.keys():
		for uuid in NetworkOrchestrator.props_list[proptype].keys():
			NetworkOrchestrator.props_list[proptype][uuid].queue_free()
			NetworkOrchestrator.props_list[proptype].erase(uuid)
	for proptype in props_list.keys():
		for uuid in props_list[proptype].keys():
			props_list[proptype][uuid].queue_free()
			props_list[proptype].erase(uuid)
