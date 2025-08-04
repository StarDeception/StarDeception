class_name Climb extends PlayerState

var ledge_position: Vector3


func enter(msg := {}) -> void:
	player.gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	ledge_position = msg["ledge_position"]
	
	if ledge_position:
		ledge_position = Vector3(ledge_position.x, ledge_position.y + 0.1, ledge_position.z)
	else:
		state_machine.transition_to(state_machine.movement_state[state_machine.IDLE])


func handle_input(event: InputEvent) -> void:
	if event.is_action_released(player.JUMP):
		player.setup_can_climb_timer()
		state_machine.transition_to(state_machine.movement_state[state_machine.IDLE])


func physics_update(delta: float) -> void:
	var direction = player.global_position.direction_to(ledge_position)
	
	player.velocity = direction * player.climb_speed
	
	if int(player.global_position.y * 10) in range(ledge_position.y * 10 - 1, ledge_position.y * 10):
		state_machine.transition_to(state_machine.movement_state[state_machine.IDLE])
