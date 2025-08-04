class_name Slide extends PlayerState


func enter(_msg := {}) -> void:
	player.toggle_crouch()


func physics_update(_delta: float) -> void:
	player.velocity = player.velocity.lerp(Vector3.ZERO, .01)
	
	if player.velocity.length() > 1.0 && player.velocity.length() < 2.0:
		state_machine.transition_to(state_machine.movement_state[state_machine.CROUCH])
