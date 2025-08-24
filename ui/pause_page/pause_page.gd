extends Control

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	if not visible:
		if event.is_action_pressed("pause"):
			GameOrchestrator.change_game_state(GameOrchestrator.GAME_STATES.PAUSE_MENU)
			visible = true
	else:
		if event.is_action_pressed("pause"):
			GameOrchestrator.change_game_state(GameOrchestrator.GAME_STATES.PLAYING)
			visible = false
		
		if event is InputEventMouseButton:
			GameOrchestrator.change_game_state(GameOrchestrator.GAME_STATES.PLAYING)
			visible = false
		
		get_viewport().set_input_as_handled()
