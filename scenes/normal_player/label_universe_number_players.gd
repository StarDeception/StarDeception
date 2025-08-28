extends Label

func _ready() -> void:
	NetworkOrchestrator.set_gameserver_number_players_iniverse.connect(_set_gameserver_number_players_iniverse)

func _set_gameserver_number_players_iniverse(nb_players):
	text = str(nb_players)
