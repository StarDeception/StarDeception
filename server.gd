extends AwaitableHTTPRequest

var SDOServerUrl = ""
var SDOServerId = 0
var ServerName = ""
var ServerPort = ""
var players = {}
var otherServers = {}
var uniqidPlayer = 0

var ServerInternalPlayers = {}
var ServerFirstConnection
var ServerMaxPlayersAllowed = 32 # 32
var ServerTickGetZone = 5
var ServerTickServers = 15
var ServerTickSendPlayersToSDO = 15
var ServerTickGetAllPlayersFromSDO = 15
var ServerTickTooManyPlayers = 30
var ServerTickZeroPlayers = 30
# the data of this server, got from the SDO
var ServerSDOInfo = {}
# the liste of all active servers, got from the SDO
var ServersSDOList = []

var FirstServerPlayers = {}
var FirstServerGameServers = {}

var player_scene_object
var clientPlayers = {}
var clientId = 0

signal set_gameserver_name(server_name)
signal set_gameserver_numberPlayers(number_players_server_name)
signal set_gameserver_numberServers(nbServers)
signal set_gameserver_numberPlayersUniverse(nbPlayers)

const uuid_util = preload('res://addons/uuid/uuid.gd')

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		_start_server()



func _physics_process(delta: float) -> void:
	if OS.has_feature("dedicated_server"):
		rpc("client_receive_players", players)
		getRefreshZone()
		getServersList()
		_send_players_to_sdo()
		_get_players_from_sdo()
		_is_server_has_too_many_players()
		_is_server_has_no_players()















func _display_type_of_var(variable):
	print("TYPE OF VAR")
	print(type_string(typeof(variable)))



####################################################################################
# Played on game server
####################################################################################

func _start_server():
	print("Starting the server...")
	loadServerConfig()
	
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var resp := await async_request('http://' + SDOServerUrl + '/sdo/servers/register', headers, HTTPClient.METHOD_POST, 'name=' + ServerName + '&port=' + str(ServerPort))
	if resp.success() and resp.status_ok():
		#print(resp.status)
		var json = resp.body_as_json()
		#print(json)
		ServerSDOInfo = json
		
		SDOServerId = int(json.id)
		print('ID: ')
		print(SDOServerId)

	var peer = ENetMultiplayerPeer.new()
	peer.create_server(ServerPort, 150)
	multiplayer.multiplayer_peer = peer
	print("server loaded... \\o/")
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnect)

func loadServerConfig():
	var config = ConfigFile.new()
	config.load("server.ini")
	for conf in config.get_sections():
		SDOServerUrl = config.get_value(conf, "SDO")
		ServerPort = config.get_value(conf, "port")
		ServerName = config.get_value(conf, "name")

func _on_player_connected(id):
	print("player " + str(id) + " connected, wouahou !")
	rpc("get_server_name", ServerName)


func _on_player_disconnect(id):
	# get uniqidPlayer based on internal mapping
	var myUniqidPlayer = "";
	for puuid in ServerInternalPlayers.keys():
		if ServerInternalPlayers[puuid] == id:
			myUniqidPlayer = puuid
			break
	
	print("player " + str(myUniqidPlayer) + " disconnected")
	players.erase(myUniqidPlayer)
	print(players)



func _is_server_has_no_players():
	if ServerTickZeroPlayers > 0:
		ServerTickZeroPlayers -= 1
	else:
		var thisServerPlayers = _get_players_of_this_server()
		if thisServerPlayers.size() == 0:
			PipeHttpFree.do_request(SDOServerUrl, SDOServerId)
		ServerTickZeroPlayers = 30

func _get_players_of_this_server():
	var playersOfThisServer = {}
	for puuid in players.keys():
		if players[puuid].server_id == SDOServerId:
			playersOfThisServer[puuid] = players[puuid]
	return playersOfThisServer
	
func _is_server_has_too_many_players():
	if ServerTickTooManyPlayers > 0:
		ServerTickTooManyPlayers -= 1
	else:
		var playersOfThisServer = _get_players_of_this_server()
		if playersOfThisServer.size() > ServerMaxPlayersAllowed:
			var playersData = []
			for value in playersOfThisServer.values():
				playersData.append({"x": int(value.x), "y": int(value.y), "z": int(value.z)})
			var playersDataJson = JSON.new().stringify(playersData)
			print("Too many players, need split")
			var headers = ["Content-Type: application/x-www-form-urlencoded"]
			PipeHttpHeavy.do_request(playersDataJson, SDOServerUrl, SDOServerId)
		ServerTickTooManyPlayers = 30

func httpresponse_server_heavy(json):
	# loop on coordinates of new server
	var xStart = json['coordinate_x_start']
	var xEnd = json['coordinate_x_end']
	var yStart = json['coordinate_y_start']
	var yEnd = json['coordinate_y_end']
	var zStart = json['coordinate_z_start']
	var zEnd = json['coordinate_z_end']
	print("x: " + str(xStart) + " " + str(xEnd))
	print("y: " + str(yStart) + " " + str(yEnd))
	print("z: " + str(zStart) + " " + str(zEnd))
	for puuid in players.keys():
		print("player position: ")
		print(players[puuid])
		if players[puuid].x < xStart or players[puuid].x > xEnd:
			print("Expulse player X: " + str(puuid))
			rpc_id(ServerInternalPlayers[puuid], "change_server", [json['ip'], json['port']])
			return
		if players[puuid].y < yStart or players[puuid].y > yEnd:
			print("Expulse player Y: " + str(puuid))
			rpc_id(ServerInternalPlayers[puuid], "change_server", [json['ip'], json['port']])
			return
		if players[puuid].z < zStart or players[puuid].z > zEnd:
			print("Expulse player Z: " + str(puuid))
			rpc_id(ServerInternalPlayers[puuid], "change_server", [json['ip'], json['port']])
			return


func getRefreshZone():
	if ServerTickGetZone > 0:
		ServerTickGetZone -= 1
	else:
		PipeHttpGetzone.do_request(SDOServerUrl, SDOServerId)
		ServerTickGetZone = 30

func getServersList():
	if ServerTickServers > 0:
		ServerTickServers -= 1
	else:
		PipeHttpGetservers.do_request(SDOServerUrl, SDOServerId)
		ServerTickServers = 30

func updateServersList(servers):
	print("List of all servers")
	ServersSDOList = servers
	rpc("client_receive_nbservers", servers.size())
	

func _send_players_to_sdo():
	if ServerTickSendPlayersToSDO > 0:
		ServerTickSendPlayersToSDO -= 1
	else:
		var playersData = []
		for puuid in players.keys():
			var value = players[puuid]
			# only the players of this server
			if value.server_id == SDOServerId:
				playersData.append({"client_uuid": puuid, "name": value.name, "x": value.x, "y": value.y, "z": value.z})
		var playersDataJson = JSON.new().stringify(playersData)
		PipeHttpSendplayers.do_request(playersDataJson, SDOServerUrl, SDOServerId)
		ServerTickSendPlayersToSDO = 15

func _get_players_from_sdo():
	if ServerTickGetAllPlayersFromSDO > 0:
		ServerTickGetAllPlayersFromSDO -= 1
	else:
		PipeHttpGetplayers.do_request(SDOServerUrl, SDOServerId)
		ServerTickGetAllPlayersFromSDO = 16

func updatePlayersList(json):
	rpc("client_receive_nbplayers", json.size())
	_dispatch_all_players_of_sdo(json)

func _dispatch_all_players_of_sdo(playerList):
	# we receive all players of all the universe (each 15 tickrates)
	# we displatch into variable players
	set_gameserver_numberPlayers.emit(playerList.size())
	# we generate a list of player in another format to be more quickly to delete
	var playerListForDelete = {}
	for player in playerList:
		playerListForDelete[player["client_uuid"]] = 1
	# We loop to update the variable players
	for myplayer in playerList:
		if myplayer.server_id == SDOServerId:
			# case for players of this server
			pass
		else:
			# case for players of other servers
			players[myplayer.client_uuid] = myplayer

	# delete players no more here
	for puuid in players.keys():
		if players[puuid].server_id != SDOServerId:
			if not playerListForDelete.has(puuid):
				players.erase(puuid)



func _check_player_must_change_server(playerUniqId):
	if _check_player_in_zone(playerUniqId) == false:
		print("1 joueur en dehors")
		var serverFound = _check_server_have_zone_contain_server_position(playerUniqId)
		if serverFound == false:
			print("Pas de serveurs trouve, anormal :/")
		else:
			print("Expulse player: " + str(playerUniqId))
			rpc_id(ServerInternalPlayers[playerUniqId], "change_server", [serverFound.ip, serverFound.port])	



func _check_player_in_zone(playerUniqId):
	if int(players[playerUniqId].x) < int(ServerSDOInfo.coordinate_x_start):
		return false
	if int(players[playerUniqId].x) > int(ServerSDOInfo.coordinate_x_end):
		return false
	if int(players[playerUniqId].y) < int(ServerSDOInfo.coordinate_y_start):
		return false
	if int(players[playerUniqId].y) > int(ServerSDOInfo.coordinate_y_end):
		return false
	if int(players[playerUniqId].z) < int(ServerSDOInfo.coordinate_z_start):
		return false
	if int(players[playerUniqId].z) > int(ServerSDOInfo.coordinate_z_end):
		return false
	return true

func _check_server_have_zone_contain_server_position(playerUniqId):
	for server in ServersSDOList:
		if int(players[playerUniqId].x) > int(server.coordinate_x_start):
			if int(players[playerUniqId].x) < int(server.coordinate_x_end):
				if int(players[playerUniqId].y) > int(server.coordinate_y_start):
					if int(players[playerUniqId].y) < int(server.coordinate_y_end):
						if int(players[playerUniqId].z) > int(server.coordinate_z_start):
							if int(players[playerUniqId].z) < int(server.coordinate_z_end):
								return server
	return false




# server send RPC functions


# server receiver RPC functions

@rpc("any_peer", "call_remote", "unreliable", 0)
func send_my_playerName(playerName, puuid):
	players[puuid].name = playerName

@rpc("any_peer", "call_remote", "unreliable", 0)
func server_receive_client_uuid(puuid):
	pass

@rpc("any_peer", "call_remote", "unreliable", 0)
func remote_set_position(position, playerUniqId):
	ServerInternalPlayers[playerUniqId] = multiplayer.get_remote_sender_id()
	if players.has(playerUniqId):
		players[playerUniqId].x = position[0]
		players[playerUniqId].y = position[1]
		players[playerUniqId].z = position[2]
	else:
		players[playerUniqId] = {
			"name": "",
			"server_id": SDOServerId,
			"client_uuid": playerUniqId,
			"x": position[0],
			"y": position[1],
			"z": position[2],
		}
	# check if position in the serve zone, otherwise find the server and expulse it
	_check_player_must_change_server(playerUniqId)

####################################################################################
# Played on the very first game server (to manage all players positions)
####################################################################################

func am_I_first_server():
	if SDOServerId == 1:
		return true
	return false







####################################################################################
# Played on client
####################################################################################

func create_client(player_scene):
	# create client
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("87.90.5.157", 7050)
	multiplayer.multiplayer_peer = peer
	clientId = peer.get_unique_id()
	# Load player scene, used for display other remote players
	player_scene_object = player_scene
	uniqidPlayer = uuid_util.v4()
	rpc_id(1, "server_receive_client_uuid", uniqidPlayer)

# client send RPC functions

func send_to_server_position(text):
	rpc_id(1, "remote_set_position", text, uniqidPlayer)
	rpc_id(1, "send_my_playerName",Globals.playerName, uniqidPlayer)


# client receiver RPC functions

@rpc("any_peer", "call_remote", "unreliable", 0)
func change_server(position):
	print("I am expulsed :/")
	_changeServer(position)

#@rpc("any_peer", "call_remote", "unreliable", 0)
#func from_server_playersNames(PlayersNames):
	#for playerId in PlayersNames:
		#if clientPlayers.has(playerId):
			#clientPlayers[playerId].set_player_name(PlayersNames[playerId])

@rpc("any_peer", "call_remote", "unreliable", 0)
func client_receive_players(playerList):
	# we receive all players of this game server only (each 1 tickrate)
	set_gameserver_numberPlayers.emit(playerList.size())
	for playerId in playerList.keys():
		var pvalue = playerList[playerId]
		if clientPlayers.has(playerId) and playerId != uniqidPlayer:
			clientPlayers[playerId].global_position = Vector3(float(pvalue.x), float(pvalue.y), float(pvalue.z))
			clientPlayers[playerId].set_player_name(pvalue.name)
		elif playerId != uniqidPlayer:
			var newPlayer = player_scene_object.instantiate()
			newPlayer.name = pvalue.name
			call_deferred("add_child", newPlayer)
			newPlayer.global_position = Vector3(float(pvalue.x), float(pvalue.y), float(pvalue.z))
			clientPlayers[playerId] = newPlayer
			clientPlayers[playerId].set_player_name(pvalue.name)
	# delete players no more here
	for playerId in clientPlayers.keys():
		if not playerList.has(playerId):
			call_deferred("remove_child", clientPlayers[playerId])
			clientPlayers.erase(playerId)

@rpc("any_peer", "call_remote", "unreliable", 0)
func client_receive_nbservers(nbServers):
	set_gameserver_numberServers.emit(nbServers)

@rpc("any_peer", "call_remote", "unreliable", 0)
func client_receive_nbplayers(nbPlayers):
	set_gameserver_numberPlayersUniverse.emit(nbPlayers)

@rpc("any_peer", "call_local", "unreliable")
func get_server_name(remoteServerName):
	set_gameserver_name.emit(remoteServerName)

# All internal functions

func _changeServer(newServerInfo):
	multiplayer.multiplayer_peer.close()
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(newServerInfo[0], int(newServerInfo[1]))
	multiplayer.multiplayer_peer = peer
