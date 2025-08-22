extends Label

func _ready() -> void:
	NetworkOrchestrator.set_gameserver_numberPlayersUniverse.connect(_set_gameserver_numberPlayersUniverse)
	
func _set_gameserver_numberPlayersUniverse(nbPlayers):
	text = str(nbPlayers)
