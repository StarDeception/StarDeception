extends Label

func _ready() -> void:
	pass
	#Server.set_gameserver_numberServers.connect(_set_gameserver_numberServers)
	
func _set_gameserver_numberServers(nbServers):
	text = str(nbServers)
