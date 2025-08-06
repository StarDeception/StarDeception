extends Node3D

@onready var displayName: String = $Astronaut/LabelPlayerName.text

func _ready() -> void:
	$Astronaut._show_remote_player_elements()

func set_player_name(name):
	displayName = name
