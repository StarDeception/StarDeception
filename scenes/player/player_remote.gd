extends Node3D

@onready var displayName: String = $Astronaut/LabelPlayerName.text

func set_player_name(name):
	displayName = name
