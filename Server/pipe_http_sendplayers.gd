extends Node3D

func _ready() -> void:
	pass
	
func do_request(playersDataJson, SDOServerUrl, SDOServerId):
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	$HTTPRequest.request('http://' + SDOServerUrl + '/sdo/servers/' + str(SDOServerId) + '/players', headers, HTTPClient.METHOD_POST, 'players=' + playersDataJson)
