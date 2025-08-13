extends Node3D

func _ready() -> void:
	$HTTPRequest.request_completed.connect(_my_reponse)
	

func do_request(playersDataJson, SDOServerUrl, SDOServerId):
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	print("send HTTP request HEAVY")
	$HTTPRequest.request('http://' + SDOServerUrl + '/sdo/servers/' + str(SDOServerId) + '/heavy', headers, HTTPClient.METHOD_POST, 'players=' + playersDataJson)

func _my_reponse(_result, _reponse_code, _headers, body):
	print("Heavy request finished")
	print(body.get_string_from_utf8())
	var json = JSON.parse_string(body.get_string_from_utf8())
	GameOrchestrator._game_server.httpresponse_server_heavy(json)
