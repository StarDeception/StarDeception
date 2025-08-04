extends Label

func _ready() -> void:
	Server.set_gameserver_numberPlayers.connect(_set_gameserver_numberPlayers)
	
func _set_gameserver_numberPlayers(number_players_server_name):
	text = str(number_players_server_name)
