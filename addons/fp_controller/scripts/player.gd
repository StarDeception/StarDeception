class_name Player extends CharacterBody3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export_group("Controls map names")
@export var MOVE_FORWARD: String = "move_forward"
@export var MOVE_BACK: String = "move_back"
@export var MOVE_LEFT: String = "move_left"
@export var MOVE_RIGHT: String = "move_right"
@export var JUMP: String = "jump"
@export var CROUCH: String = "crouch"
@export var SPRINT: String = "sprint"
@export var PAUSE: String = "pause"

@export_group("Customizable player stats")
@export var walk_back_speed: float = 1.5
@export var walk_speed: float = 2.5
@export var sprint_speed: float = 5.0
@export var crouch_speed: float = 1.5
@export var jump_height: float = 1.0
@export var acceleration: float = 10.0
@export var arm_length: float = 0.5
@export var regular_climb_speed: float = 6.0
@export var fast_climb_speed: float = 8.0
@export_range(0.0, 1.0) var view_bobbing_amount: float = 1.0
@export_range(1.0, 10.0) var camera_sensitivity: float = 2.0
@export_range(0.0, 0.5) var camera_start_deadzone: float = .2
@export_range(0.0, 0.5) var camera_end_deadzone: float = .1

@export_group("Feature toggles")
@export var allow_jump: bool = true
@export var allow_crouch: bool = true
@export var allow_sprint: bool = true
@export var allow_climb: bool = true

# Player 'character' components
@onready var camera_pivot: Node3D = %CameraPivot
@onready var state_machine: PlayerStateMachine = %StateMachine
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var view_bobbing_player = %ViewBobbingPlayer

# Raycasts used for detecting if the player is touching a wall
@onready var bottom_raycast: RayCast3D = %BottomRaycast
@onready var middle_raycast: RayCast3D = %MiddleRaycast
@onready var top_raycast: RayCast3D = %TopRaycast

# Raycasts used for getting the ledge position and checking if there's enough space
@onready var surface_raycasts_root: Node3D = %SurfaceRaycasts
@onready var projected_height_raycast: RayCast3D = %ProjectedHeightRaycast
@onready var surface_raycast: RayCast3D = %SurfaceRaycast

# Raycasts used for checking if there's enough horizontal space to climb
@onready var left_climbable_raycast: RayCast3D = %LeftClimbableRaycast
@onready var right_climbable_raycast: RayCast3D = %RightClimbableRaycast

# Raycast for detecting ceiling
@onready var crouch_raycast = %CrouchRaycast

# Dynamic values used for calculation
var input_direction: Vector2
var ledge_position: Vector3 = Vector3.ZERO
var mouse_motion: Vector2
var default_view_bobbing_amount: float
var movement_strength: float

# Player state values that are set by applying state
var climb_speed: float = fast_climb_speed
var is_crouched: bool = false
var can_climb: bool
var can_climb_timer: Timer
var is_affected_by_gravity: bool = true
var is_moving: bool = false

# Values that are set 'false' if corresponding controls aren't mapped
var can_move: bool = true
var can_jump: bool = true
var can_crouch: bool = true
var can_sprint: bool = true
var can_pause: bool = true

@onready var game_is_paused: bool = false

@onready var labelx: Label = $UserInterface/LabelXValue
@onready var labely: Label = $UserInterface/LabelYValue
@onready var labelz: Label = $UserInterface/LabelZValue

func _ready() -> void:
	default_view_bobbing_amount = view_bobbing_amount
	# TODO FOR THE RELEASE
	global_position = Vector3(RandomNumberGenerator.new().randf_range(-4000.0, -200.0), 1707, RandomNumberGenerator.new().randf_range(-2000.0, 2000.0))
	check_controls()
	if can_pause:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func check_controls() -> void:
	if !InputMap.has_action(MOVE_FORWARD):
		push_error("No control mapped for 'move_forward', using default...")
		_add_input_map_event(MOVE_FORWARD, KEY_W)
	if !InputMap.has_action(MOVE_BACK):
		push_error("No control mapped for 'move_back', using default...")
		_add_input_map_event(MOVE_BACK, KEY_S)
	if !InputMap.has_action(MOVE_LEFT):
		push_error("No control mapped for 'move_left', using default...")
		_add_input_map_event(MOVE_LEFT, KEY_A)
	if !InputMap.has_action(MOVE_RIGHT):
		push_error("No control mapped for 'move_right', using default...")
		_add_input_map_event(MOVE_RIGHT, KEY_D)
	if !InputMap.has_action(JUMP):
		push_error("No control mapped for 'jump', using default...")
		_add_input_map_event(JUMP, KEY_SPACE)
	if !InputMap.has_action(CROUCH):
		push_error("No control mapped for 'crouch', using default...")
		_add_input_map_event(CROUCH, KEY_C)
	if !InputMap.has_action(SPRINT):
		push_error("No control mapped for 'sprint', using default...")
		_add_input_map_event(SPRINT, KEY_SHIFT)
	if !InputMap.has_action(PAUSE):
		push_error("No control mapped for 'pause', using default...")
		_add_input_map_event(PAUSE, KEY_ESCAPE)
	
	# Checking if controller inputs are mapped
	if InputMap.action_get_events(CROUCH).any(func(event): return event is InputEventJoypadButton) == false:
		_add_joy_button_event(CROUCH, JOY_BUTTON_B)
	if InputMap.action_get_events(JUMP).any(func(event): return event is InputEventJoypadButton) == false:
		_add_joy_button_event(JUMP, JOY_BUTTON_A)
	if InputMap.action_get_events(SPRINT).any(func(event): return event is InputEventJoypadButton) == false:
		_add_joy_button_event(SPRINT, JOY_BUTTON_LEFT_STICK)
	if InputMap.action_get_events(PAUSE).any(func(event): return event is InputEventJoypadButton) == false:
		_add_joy_button_event(PAUSE, JOY_BUTTON_START)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_motion = -event.relative * 0.001
	
	if can_pause:
		if event.is_action_pressed(PAUSE):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			game_is_paused = true
	
	if game_is_paused and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		game_is_paused = false


func _physics_process(delta: float) -> void:
	if can_move:
		if Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK):
			input_direction = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)
		elif Input.get_connected_joypads().size() != 0:
			input_direction = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
			var x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
			var y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
			movement_strength = Vector2(x, y).length()
		else:
			input_direction = Vector2.ZERO
	
	# Add the gravity.
	if not is_on_floor() && is_affected_by_gravity:
		velocity.y -= gravity * delta
	
	# Resetting climb ability when on ground
	if is_on_floor() && !can_climb:
		if can_climb_timer != null:
			can_climb_timer.queue_free()
		can_climb = true
	
	move_and_slide()
	#print(global_position)
	Server.send_to_server_position(global_position)
	labelx.text = str(global_position[0])
	labely.text = str(global_position[1])
	labelz.text = str(global_position[2])

func _process(_delta: float):
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handling camera in '_process' so that camera movement is framerate independent
		_handle_camera_motion()
	
	if Input.get_connected_joypads().size() != 0:
		_handle_joy_camera_motion()


func _handle_camera_motion() -> void:
	rotate_y(mouse_motion.x * camera_sensitivity)
	camera_pivot.rotate_x(mouse_motion.y  * camera_sensitivity)
	
	camera_pivot.rotation_degrees.x = clampf(
		camera_pivot.rotation_degrees.x , -89.0, 89.0
	)
	
	mouse_motion = Vector2.ZERO


func _handle_joy_camera_motion() -> void:
	var x_axis = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	
	if abs(x_axis) < camera_start_deadzone:
		x_axis = 0
	if abs(x_axis) > 1 - camera_end_deadzone:
		if x_axis < 0:
			x_axis = camera_end_deadzone - 1
		else:
			x_axis = 1 - camera_end_deadzone
	
	var y_axis = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	if abs(y_axis) < camera_start_deadzone:
		y_axis = 0
	if abs(y_axis) > 1 - camera_end_deadzone:
		if y_axis < 0:
			y_axis = camera_end_deadzone - 1
		else:
			y_axis = 1 - camera_end_deadzone
	
	var resulting_vector = Vector2(x_axis, y_axis)
	var normalized_resulting_vector = resulting_vector.normalized()
	var action_strength = resulting_vector.length()
	print(camera_sensitivity)
	rotate_y(-deg_to_rad(camera_sensitivity * normalized_resulting_vector.x * action_strength))
	camera_pivot.rotate_x(-deg_to_rad(camera_sensitivity * normalized_resulting_vector.y * action_strength))
	
	camera_pivot.rotation_degrees.x = clampf(
		camera_pivot.rotation_degrees.x , -89.0, 89.0
	)


func check_climbable() -> bool:
	if crouch_raycast.is_colliding():
		return false
	
	if not bottom_raycast.is_colliding() && not middle_raycast.is_colliding() && not top_raycast.is_colliding():
		return false
	
	var climb_point = surface_raycast.get_collision_point()
	var climb_height = climb_point.y - global_position.y
	
	left_climbable_raycast.global_position.y = climb_point.y + 0.1
	right_climbable_raycast.global_position.y = climb_point.y + 0.1
	
	if left_climbable_raycast.is_colliding() || right_climbable_raycast.is_colliding():
		return false
	
	projected_height_raycast.target_position = Vector3(0, climb_height - 0.1, 0)
	
	if projected_height_raycast.is_colliding():
		return false
	
	ledge_position = climb_point
	return true


func check_small_ledge() -> bool:
	return bottom_raycast.is_colliding() && not middle_raycast.is_colliding() && not top_raycast.is_colliding()


func set_climb_speed(is_small_ledge) -> void:
	if is_small_ledge:
		climb_speed = fast_climb_speed
	else:
		climb_speed = regular_climb_speed


func toggle_crouch() -> void:
	is_crouched = !is_crouched
	
	if is_crouched:
		animation_player.play("crouch")
	else:
		animation_player.play_backwards("crouch")


func setup_can_climb_timer(callback: Callable = _on_grab_available_timeout) -> void:
	if can_climb_timer != null:
		return
	
	can_climb = false
	
	can_climb_timer = Timer.new()
	add_child(can_climb_timer)
	can_climb_timer.wait_time = 1.0
	can_climb_timer.one_shot = true
	can_climb_timer.connect("timeout", callback)
	can_climb_timer.start()


func _on_grab_available_timeout() -> void:
	can_climb = true
	
	if can_climb_timer != null:
		can_climb_timer.queue_free()


## Triggers on every state transition. Could be useful for side effects and debugging
## Note that it's triggered after the 'state' "enter" method
func _on_state_machine_transitioned(state: PlayerState) -> void:
	is_moving = state is Walk || state is Sprint
	
	if is_moving:
		view_bobbing_player.play("view_bobbing", .5, view_bobbing_amount, false)
	else:
		view_bobbing_player.play("RESET", .5)


func _add_input_map_event(action_name: String, keycode: int) -> void:
	var event = InputEventKey.new()
	event.keycode = keycode
	InputMap.add_action(action_name)
	InputMap.action_add_event(action_name, event)


func _add_joy_button_event(action_name: String, joy_button: JoyButton = 100) -> void:
	var joy_button_event = InputEventJoypadButton.new()
	joy_button_event.button_index = joy_button
	InputMap.action_add_event(action_name, joy_button_event)
