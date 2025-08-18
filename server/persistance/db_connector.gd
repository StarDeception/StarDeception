extends Node
class_name DbConnector

signal connected_to_db()
signal query_completed(result: Dictionary)

var http_client: HTTPClient

var db_user = null
var db_pwd = null
var db_host: String
var db_port: int

var is_connected: bool = false

func configure() -> void:
	var config = ConfigFile.new()
	config.load("server.ini")
	
	db_user = config.get_value("persistence", "user")
	db_pwd = config.get_value("persistence", "passwd")
	db_host = config.get_value("persistence", "host")
	db_port = config.get_value("persistence", "port")

func connect_to_database() -> void:
	print('Try connecting to database')
	http_client = HTTPClient.new()
	print(db_host, db_port)
	var error = http_client.connect_to_host(db_host, db_port)
	if error != OK:
		print('Connecting to database failed')
	
	while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
		http_client.poll()
		await get_tree().process_frame
	
	if http_client.get_status() == HTTPClient.STATUS_CONNECTED:
		is_connected = true
		emit_signal("connected_to_db")

func disconnect_from_database() -> void:
	if http_client:
		http_client.close()
	is_connected = false

func execute_query(query: String,  parameters: Dictionary = {}) -> Dictionary:
	if not is_connected:
		return {"success": false, "error": "doesn't connected to database"}
	
	var headers = [
		"Content-Type: application/json",
	]
	if db_user && db_pwd:
		headers.push_back("Authorization: Basic " + Marshalls.utf8_to_base64(db_user + ":" + db_pwd))
	
	var body = JSON.stringify({
		"statements": [{
			"statement": query,
			"parameters": parameters
		}]
	})
	
	var error = http_client.request(HTTPClient.METHOD_POST, "/db/neo4j/tx/commit", headers, body)
	if error != OK:
		print_rich("[color=red]Query failed[/color]", error)
		return {"success": false, "error": "error with database"}
		
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await get_tree().process_frame
		
	var response_body = http_client.read_response_body_chunk()
	if http_client.get_response_code() == 200:
		var json = JSON.new()
		var parse_result = json.parse(response_body.get_string_from_utf8())
		
		print("result", json.data)
		if parse_result == OK:
			return {"success": true, "data": json.data.get("results")[0].data}
		else:
			return {"success": false, "error": "Erreur de parsing JSON"}
	else:
		print_rich("[color=red]Query failed end[/color]", http_client.get_response_code())
		return {"success": false, "error": str(http_client.get_response_code())}
