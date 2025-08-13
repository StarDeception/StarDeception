extends Control

var is_ready: bool = false

func _on_ready() -> void:
	is_ready = true
	BackgroundMusic.play_music_level()

func _on_button_pressed(button_id: String) -> void:
	# TODO Call HTTP request to auth server to authenticate
	if $FormPlacer/FormContainer/UserName.get_text():
		GameOrchestrator.login_player_name = $FormPlacer/FormContainer/UserName.get_text()
	match button_id:
		"Online":
			Globals.onlineMode = true
			GameOrchestrator.change_game_state(GameOrchestrator.GAME_STATES.UNIVERSE_MENU)
		"Local":
			Globals.onlineMode = false
			GameOrchestrator.change_game_state(GameOrchestrator.GAME_STATES.TROLL)
