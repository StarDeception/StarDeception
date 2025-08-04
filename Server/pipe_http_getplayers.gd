extends Node3D

func _ready() -> void:
	$HTTPRequest.request_completed.connect(_my_reponse)
	
func do_request(SDOServerUrl, SDOServerId):
	var headers = []
	$HTTPRequest.request('http://' + SDOServerUrl + '/sdo/players', headers, HTTPClient.METHOD_GET)

func _my_reponse(result, reponse_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	Server.updatePlayersList(json)
