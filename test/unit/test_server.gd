extends GutTest

func before_each():
	pass

func after_each():
	pass

func before_all():
	# define players
	#Server.players = {
		#"c7b06780-7100-4c5d-8841-90985eea8b6d": {
			#"id": 4,
			#"name": "jeronimo",
			#"server_id": 5,
			#"client_uuid": "c7b06780-7100-4c5d-8841-90985eea8b6d",
			#"x": "-25.934005737305",
			#"y": "-0.014608105644584",
			#"z": "3.0809617042541"
		#},
		#"30be488b-2c60-473d-9595-b9ff551dcf80": {
			#"id": 4,
			#"name": "jeronimo",
			#"server_id": 5,
			#"client_uuid": "30be488b-2c60-473d-9595-b9ff551dcf80",
			#"x": "-25.934005737305",
			#"y": "-0.014608105644584",
			#"z": "56.0809617042541"
		#},
		#"6ebb847c-9c25-466a-989f-c1cf5ad3366f": {
			#"id": 4,
			#"name": "jeronimo",
			#"server_id": 5,
			#"client_uuid": "30be488b-2c60-473d-9595-b9ff551dcf80",
			#"x": "-25.934005737305",
			#"y": "-0.014608105644584",
			#"z": "-56.0809617042541"
		#}
	#}
	# define server information
	Server.ServerSDOInfo = {
		"id": 5,
		"name": "gameserver0101",
		"ip": "127.0.0.1",
		"port": 7050,
		"coordinate_x_start": -10000000,
		"coordinate_x_end": 10000000,
		"coordinate_y_start": -10000000,
		"coordinate_y_end": 10000000,
		"coordinate_z_start": -21,
		"coordinate_z_end": 55,
		"is_free": 0.0,
	}
	
	# servers list
	Server.ServersSDOList = [
		{
			"id": 5,
			"name": "gameserver0101",
			"ip": "127.0.0.1",
			"port": 7050,
			"coordinate_x_start": -10000000,
			"coordinate_x_end": 10000000,
			"coordinate_y_start": -10000000,
			"coordinate_y_end": 10000000,
			"coordinate_z_start": -21,
			"coordinate_z_end": 55,
			"is_free": 0.0,
		},
		{
			"id": 5,
			"name": "gameserver0102",
			"ip": "127.0.0.1",
			"port": 7051,
			"coordinate_x_start": -10000000,
			"coordinate_x_end": 10000000,
			"coordinate_y_start": -10000000,
			"coordinate_y_end": 10000000,
			"coordinate_z_start": 55,
			"coordinate_z_end": 150,
			"is_free": 0.0,
		}
	]

func after_all():
	pass

# Tests for the server part

func test_server__check_player_in_zone__player_in_zone():
	var inZone = Server._check_player_in_zone("c7b06780-7100-4c5d-8841-90985eea8b6d")
	assert_true(inZone)

func test_server__check_player_in_zone__player_not_in_zone():
	var inZone = Server._check_player_in_zone("30be488b-2c60-473d-9595-b9ff551dcf80")
	assert_false(inZone)

func test_server__check_server_have_zone_contain_server_position__have_server():
	var serverFound = Server._check_server_have_zone_contain_server_position("30be488b-2c60-473d-9595-b9ff551dcf80")
	assert_typeof(serverFound, TYPE_DICTIONARY)

func test_server__check_server_have_zone_contain_server_position__not_have_server():
	var serverFound = Server._check_server_have_zone_contain_server_position("6ebb847c-9c25-466a-989f-c1cf5ad3366f")
	assert_false(serverFound)



# Tests for the client part

#func test_client_
