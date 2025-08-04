class_name Crouch extends PlayerState

var input_dir: Vector2
var move_speed: float


func enter(_msg := {}) -> void:
	if !player.is_crouched:
		player.toggle_crouch()


func handle_input(event: InputEvent) -> void:
	
	if event.is_action_pressed(player.CROUCH) && player.is_on_floor() && player.allow_crouch:
		player.toggle_crouch()
		state_machine.transition_to(state_machine.movement_state[state_machine.IDLE])
	
	if event.is_action_pressed(player.SPRINT) && player.allow_sprint:
		player.toggle_crouch()
		state_machine.transition_to(state_machine.movement_state[state_machine.SPRINT])
	
	if event.is_action_pressed(player.JUMP) && player.allow_jump:
		player.toggle_crouch()
		state_machine.transition_to(state_machine.movement_state[state_machine.JUMP])


func physics_update(_delta: float) -> void:
	input_dir = player.input_direction
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if Input.is_action_pressed(player.MOVE_BACK):
		move_speed = player.crouch_speed * .6
	else:
		move_speed = player.crouch_speed
	
	if direction:
		player.velocity.x = direction.x * move_speed
		player.velocity.z = direction.z * move_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, move_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, move_speed)
	
	if player.velocity.y < 0:
		state_machine.transition_to(
			state_machine.movement_state[state_machine.FALL],
			{ state_machine.TO : state_machine.CROUCH }
		)
