extends Node3D

func _ready() -> void:
	pass

func do_request(SDOServerUrl, SDOServerId):
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	print("send HTTP request free")
	$HTTPRequest.request('http://' + SDOServerUrl + '/sdo/servers/' + str(SDOServerId) + '/free', headers, HTTPClient.METHOD_POST)
