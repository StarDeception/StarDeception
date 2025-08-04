class_name Jump extends PlayerState

var init_state: int
var input_dir: Vector2
var move_speed: float

var has_direction: bool


func enter(msg := {}) -> void:
	if player.is_crouched:
		player.stand_up()
	if msg:
		init_state = msg[state_machine.TO]
	
	move_speed = player.walk_back_speed
	has_direction = player.input_direction != Vector2.ZERO
	player.velocity.y = sqrt(player.jump_height * 2 * player.gravity)


func physics_update(_delta: float) -> void:
	if player.velocity.y < 0:
		state_machine.transition_to(
			state_machine.movement_state[state_machine.FALL],
			{ state_machine.TO : init_state }
		)
	
	input_dir = player.input_direction
	
	if not input_dir:
		init_state = state_machine.WALK
	
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# this gives some in-air control if jumping from standing still
	if (has_direction && player.velocity.length() < player.walk_back_speed) || !has_direction:
		if direction:
			player.velocity.x = direction.x * move_speed
			player.velocity.z = direction.z * move_speed
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, move_speed)
			player.velocity.z = move_toward(player.velocity.z, 0, move_speed)
