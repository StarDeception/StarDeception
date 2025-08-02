extends Node3D

func _ready() -> void:
	$HTTPRequest.request_completed.connect(_my_reponse)
	
func do_request(SDOServerUrl, SDOServerId):
	var headers = []
	print("send HTTP request to get server / zone to manage (in case changed by the SDO)")
	$HTTPRequest.request('http://' + SDOServerUrl + '/sdo/servers/' + str(SDOServerId), headers, HTTPClient.METHOD_GET)

func _my_reponse(result, reponse_code, headers, body):
	print("Get zone request finished")
	print(body.get_string_from_utf8())
	var json = JSON.parse_string(body.get_string_from_utf8())
	Server.ServerSDOInfo = json
