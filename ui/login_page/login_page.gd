extends Control

func _on_ready() -> void:
	BackgroundMusic.play_music_level()
	pass


func _on_button_pressed(button_id: String) -> void:
#	TODO Call HTTP request to auth server to authenticate
	Globals.playerName = $FormPlacer/FormContainer/UserName.get_text()
	match button_id:
		"Online":
			Globals.onlineMode = true
			get_tree().change_scene_to_file("res://ui/main_page/main_page.tscn")
		"Local":
			Globals.onlineMode = false
			get_tree().change_scene_to_file("res://ui/main_page/main_page.tscn")
