extends Node

signal populated_universe

const uuid_util = preload("res://addons/uuid/uuid.gd")

var universe_scene: Node = null
var entities_spawn_node: Node = null
var datas_to_spawn_count: int = 0

var clients_peers_ids: Array[int] = []

var ServerZone = {
	"x_start": -100000.0,
	"x_end": 100000.0,
	"y_start": -100000.0,
	"y_end": 100000.0,
	"z_start": -100000.0,
	"z_end": 100000.0
}

var MaxPlayersAllowed = 2
var PlayersList = {}
var PlayersListLastMovement = {}
var PlayersListLastRotation = {}
var PlayersListTempById = {}
var PlayersListCurrentlyInTransfert = {}
var ChangingZone = false
var TransferPlayers = false
var PropsList = {
	"box50cm": {},
	"box4m": {},
	"ship": {},
}
var PropsListLastMovement = {
	"box50cm": {},
	"box4m": {},
	"ship": {},
}
var PropsListLastRotation = {
	"box50cm": {},
	"box4m": {},
	"ship": {},
}

var ServersTicksTasks = {
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
	NetworkOrchestrator.loadServerConfig()

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	if NetworkOrchestrator.isSDOActive == true:
		_is_server_has_too_many_players()
		_send_players_to_sdo()
		_checkPlayerOutOfZone()
		_send_props_to_sdo()

func start_server(receveid_universe_scene: Node, receveid_player_spawn_node: Node) -> void:
	Engine.physics_ticks_per_second = 30
	Engine.max_fps = 30
	
	universe_scene = receveid_universe_scene
	entities_spawn_node = receveid_player_spawn_node
	var server_peer = ENetMultiplayerPeer.new()
	if not server_peer:
		printerr("creating server_peer failed!")
		return
	
	var res = server_peer.create_server(NetworkOrchestrator.ServerPort, 150)
	if res != OK:
		printerr("creating server failed: ", error_string(res))
		return
	
	universe_scene.multiplayer.multiplayer_peer = server_peer
	NetworkOrchestrator.connect_chat_mqtt()
	# load SDO mqtt in NetworkOrchestrator
	NetworkOrchestrator.connect_mqtt_sdo()
	if NetworkOrchestrator.MetricsEnabled == true:
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
	var uuid = PlayersListTempById[id]
	if not PlayersListCurrentlyInTransfert.has(uuid):
		var data = JSON.stringify({
			"add": [],
			"update": [],
			"delete": [{"client_uuid" : PlayersListTempById[id]}],
			"server_id": NetworkOrchestrator.ServerSDOId,
		})
		NetworkOrchestrator.MQTTClientSDO.publish("sdo/playerschanges", data)
		PlayersListTempById.erase(multiplayer.get_remote_sender_id())
		PlayersList.erase(PlayersListTempById[id])

		# player.queue_free()
	NetworkOrchestrator.update_all_text_client()



func _is_server_has_too_many_players():
	if ServersTicksTasks.TooManyPlayersCurent > 0:
		ServersTicksTasks.TooManyPlayersCurent -= 1
	else:
		if PlayersList.size() > MaxPlayersAllowed and ChangingZone == false:
			if _playersMustChangeServer() == false:
				var playersData = []
				for value in PlayersList.values():
					var position = value.global_position
					if position != Vector3.ZERO:
						# can have position zero if spawn not yet defined and it can break split of servers 
						playersData.append({"x": position[0], "y": position[1], "z": position[2]})
				print("######################################################")
				print("####################### Too many players, need split #")
				ChangingZone = true
				NetworkOrchestrator.MQTTClientSDO.publish("sdo/servertooheavy", JSON.stringify({
					"id": NetworkOrchestrator.ServerSDOId,
					"players": playersData,
				}))
		ServersTicksTasks.TooManyPlayersCurent = ServersTicksTasks.TooManyPlayersReset

func _send_players_to_sdo():
	if ServersTicksTasks.SendPlayersToMQTTCurrent > 0:
		ServersTicksTasks.SendPlayersToMQTTCurrent -= 1
	else:
		var playersData = []
		var position = Vector3(0.0, 0.0, 0.0)
		var rotation = Vector3(0.0, 0.0, 0.0)
		for puuid in PlayersList.keys():
			position = PlayersList[puuid].global_position
			rotation = PlayersList[puuid].global_rotation
			if PlayersListLastMovement[puuid] != position or PlayersListLastRotation[puuid] != rotation:
				if not PlayersListCurrentlyInTransfert.has(puuid):
					# only the players of this server and not in transfert
					playersData.append({
						"name": PlayersList[puuid].name,
						"client_uuid": puuid,
						"x": position[0],
						"y": position[1],
						"z": position[2],
						"xr": rotation[0],
						"yr": rotation[1],
						"zr": rotation[2]
					})
					PlayersListLastMovement[puuid] = position
					PlayersListLastRotation[puuid] = rotation
		if playersData.size() > 0:
			NetworkOrchestrator.MQTTClientSDO.publish("sdo/playerschanges", JSON.stringify({
				"add": [],
				"update": playersData,
				"delete": [],
				"server_id": NetworkOrchestrator.ServerSDOId,
			}))
		ServersTicksTasks.SendPlayersToMQTTCurrent = ServersTicksTasks.SendPlayersToMQTTReset

func _checkPlayerOutOfZone():
	if ServersTicksTasks.CheckPlayersOutOfZoneCurrent > 0:
		ServersTicksTasks.CheckPlayersOutOfZoneCurrent -= 1
	else:
		if ChangingZone == false:
			_playersMustChangeServer()
		ServersTicksTasks.CheckPlayersOutOfZoneCurrent = ServersTicksTasks.CheckPlayersOutOfZoneReset

func _playersMustChangeServer():
	# loop on coordinates of new server
	var somePlayersTransfered = false
	for puuid in PlayersList.keys():
		if PlayersListCurrentlyInTransfert.has(puuid):
			continue
		var position = PlayersList[puuid].global_position
		if position[0] < ServerZone.x_start or position[0] > ServerZone.x_end:
			print("Expulse player X: " + str(puuid))
			print("serverstart, server end, player: ", ServerZone.x_start, " ", ServerZone.x_end, " ", position[0])
			var newServer = _searchAnotherServerForCoordinates(position[0], position[1], position[2])
			if newServer != null:
				NetworkOrchestrator.transfert_player_to_another_server(puuid, newServer)
				somePlayersTransfered = true
			else:
				print("ERROR: no server found to expulse :/")
		elif position[1] < ServerZone.y_start or position[1] > ServerZone.y_end:
			print("Expulse player Y: " + str(puuid))
			print("serverstart, server end, player: ", ServerZone.y_start, " ", ServerZone.y_end, " ", position[1])
			var newServer = _searchAnotherServerForCoordinates(position[0], position[1], position[2])
			if newServer != null:
				NetworkOrchestrator.transfert_player_to_another_server(puuid, newServer)
				somePlayersTransfered = true
		elif position[2] < ServerZone.z_start or position[2] > ServerZone.z_end:
			print("Expulse player Z: " + str(puuid))
			print("serverstart, server end, player: ", ServerZone.z_start, " ", ServerZone.z_end, " ", position[2])
			var newServer = _searchAnotherServerForCoordinates(position[0], position[1], position[2])
			if newServer != null:
				NetworkOrchestrator.transfert_player_to_another_server(puuid, newServer)
				somePlayersTransfered = true
	return somePlayersTransfered

func _searchAnotherServerForCoordinates(x, y, z):
	for s in NetworkOrchestrator.ServersList.values():
		if s.id == NetworkOrchestrator.ServerSDOId:
			continue
		if float(s.x_start) <= x and x < float(s.x_end) and float(s.y_start) <= y and y < float(s.y_end) and float(s.z_start) <= z and z < float(s.z_end):
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
	player_to_add.labelPlayerName.text = playername
	player_to_add.global_rotation = Vector3(float(player.xr), float(player.yr), float(player.zr))
	player_to_add.set_physics_process(false)
	NetworkOrchestrator.PlayersList[player.client_uuid] = player_to_add
	if server_id != null:
		player_to_add.labelServerName.text = NetworkOrchestrator.ServersList[server_id].name

	print("Remnote player spawned with position: ", player_to_add.global_position)

func _sendMetrics():
	if ServersTicksTasks.SendMetricsCurrent > 0:
		ServersTicksTasks.SendMetricsCurrent -= 1
	else:
		if NetworkOrchestrator.MetricsEnabled == true:
			var allMetrics = {
				"currentplayers": PlayersList.size(),
				"memory": Performance.get_monitor(Performance.MEMORY_STATIC),
				"numberobjects": Performance.get_monitor(Performance.OBJECT_COUNT),
				"timefps": Performance.get_monitor(Performance.TIME_FPS),
			}
			for proptype in PropsList.keys():
				allMetrics["current" + proptype] = PropsList[proptype].size()
			NetworkOrchestrator.MQTTClientMetrics.publish("metrics/server/" + NetworkOrchestrator.ServerName, JSON.stringify(allMetrics))
		ServersTicksTasks.SendMetricsCurrent = ServersTicksTasks.SendMetricsReset


#########################
# Props                 #

func instantiate_props_remote_add(prop):
	_spawn_prop_remote_add(prop)

func instantiate_props_remote_update(prop):
	_spawn_prop_remote_update(prop)

func _spawn_prop_remote_add(prop):
	# print("Create prop: ", prop)
	# add prop
	if not PropsList.has(prop.type):
		return
	var uuid = uuid_util.v4()
	var prop_instance: RigidBody3D = NetworkOrchestrator.get_spawnable_props_newinstance(prop.type)
	NetworkOrchestrator.PropsList[prop.type][uuid] = prop_instance
	prop_instance.spawn_position = Vector3(float(prop.x), float(prop.y), float(prop.z))
	prop_instance.set_physics_process(false)
	NetworkOrchestrator.small_props_spawner_node.get_node(NetworkOrchestrator.small_props_spawner_node.spawn_path).call_deferred("add_child", prop_instance, true)
	NetworkOrchestrator.PropsList[prop.type][uuid] = prop_instance

func _spawn_prop_remote_update(prop):
	if not NetworkOrchestrator.PropsList[prop.type].has(prop.uuid):
		return
	# update the position
	NetworkOrchestrator.PropsList[prop.type][prop.uuid].global_position = Vector3(float(prop.x), float(prop.y), float(prop.z))
	NetworkOrchestrator.PropsList[prop.type][prop.uuid].global_rotation = Vector3(float(prop.xr), float(prop.yr), float(prop.zr))

func _send_props_to_sdo():
	if ServersTicksTasks.SendPropsToMQTTCurrent > 0:
		ServersTicksTasks.SendPropsToMQTTCurrent -= 1
	else:
		var propsData = []
		var position = Vector3(0.0, 0.0, 0.0)
		var rotation = Vector3(0.0, 0.0, 0.0)
		for proptype in PropsList.keys():
			for uuid in PropsList[proptype].keys():
				position = PropsList[proptype][uuid].global_position
				rotation = PropsList[proptype][uuid].global_rotation
				if PropsListLastMovement[proptype][uuid] != position or PropsListLastRotation[proptype][uuid] != rotation:
					propsData.append({
						"type": proptype,
						"uuid": uuid,
						"x": position[0],
						"y": position[1],
						"z": position[2],
						"xr": rotation[0],
						"yr": rotation[1],
						"zr": rotation[2]
					})
					PropsListLastMovement[proptype][uuid] = position
					PropsListLastRotation[proptype][uuid] = rotation
					# used for call save on persistance
					if PropsList[proptype][uuid].has_node("DataEntity"):
						var dataentity = PropsList[proptype][uuid].get_node("DataEntity")
						dataentity.Backgroud_save()
		if propsData.size() > 0:
			NetworkOrchestrator.MQTTClientSDO.publish("sdo/propschanges", JSON.stringify({
				"add": [],
				"update": propsData,
				"delete": [],
				"server_id": NetworkOrchestrator.ServerSDOId,
			}))
		ServersTicksTasks.SendPropsToMQTTCurrent = ServersTicksTasks.SendPropsToMQTTReset

func set_server_inactive(_newserverId):
	print("# Disable the server")
	NetworkOrchestrator.isSDOActive = false
	# TODO send props to new server id
	# unload all
	print("Clean items")
	for uuid in NetworkOrchestrator.PlayersList.keys():
		NetworkOrchestrator.PlayersList[uuid].queue_free()
		NetworkOrchestrator.PlayersList.erase(uuid)
	for proptype in NetworkOrchestrator.PropsList.keys():
		for uuid in NetworkOrchestrator.PropsList[proptype].keys():
			NetworkOrchestrator.PropsList[proptype][uuid].queue_free()
			NetworkOrchestrator.PropsList[proptype].erase(uuid)
	for proptype in PropsList.keys():
		for uuid in PropsList[proptype].keys():
			PropsList[proptype][uuid].queue_free()
			PropsList[proptype].erase(uuid)
