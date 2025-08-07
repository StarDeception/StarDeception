extends CharacterBody3D
class_name Player

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
@export var player_thruster_force = 10
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

var mouse_motion: Vector2
var input_direction: Vector2
var movement_strength: float
var gravity = 0.0

var gravity_parents: Array[Area3D]

# to disable player input when piloting vehicule/ship
var active = true

@onready var game_is_paused: bool = false
@onready var camera_pivot: Node3D = %CameraPivot

@onready var labelx: Label = $UserInterface/LabelXValue
@onready var labely: Label = $UserInterface/LabelYValue
@onready var labelz: Label = $UserInterface/LabelZValue

@onready var interact_ray: RayCast3D = $CameraPivot/SmoothCamera/InteractRay
@onready var interact_label: Label = $UserInterface/InteractLabel

@onready var box4m: PackedScene = preload("res://scenes/props/testbox/box_4m.tscn")
@onready var box50m: PackedScene = preload("res://scenes/props/testbox/box_50cm.tscn")
@onready var isInsideBox4m: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if !active: return
	
	if event is InputEventMouseMotion:
		mouse_motion = -event.relative * 0.001
	
	if event.is_action_pressed(PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game_is_paused = true
	
	if game_is_paused and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		game_is_paused = false
	
	if event.is_action_pressed("spawn_4mbox"):
		call_deferred("spawn_box4m")
	
	if event.is_action_pressed("spawn_50cmbox"):
		call_deferred("spawn_box50cm")
	
	
	if Input.is_action_just_pressed("ext_cam"):
		if $ExtCamera3D.current:
			$CameraPivot/SmoothCamera.make_current()
		else: 
			$ExtCamera3D.make_current()

func _physics_process(delta: float) -> void:
	if !active: return
	
	if Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK):
		input_direction = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)
	elif Input.get_connected_joypads().size() != 0:
		input_direction = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		var x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		movement_strength = Vector2(x, y).length()
	else:
		input_direction = Vector2.ZERO
		
	var parent_gravity_area: Area3D = gravity_parents.back() if not gravity_parents.is_empty() else null
	
	if parent_gravity_area:
		if parent_gravity_area.gravity_point:
			var space_state = get_world_3d().direct_space_state
			var param = PhysicsRayQueryParameters3D.new()
			param.from = global_position
			param.to = parent_gravity_area.global_position
			var result = space_state.intersect_ray(param)
			if result:
				up_direction = result.normal
		else:
			up_direction = parent_gravity_area.global_basis.y
		
		gravity = parent_gravity_area.gravity
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	else:
		gravity = 0.0
		camera_pivot.rotation.x = 0
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var dir = Vector3(input_direction.x, 0, input_direction.y)
		
		velocity += global_basis * dir * player_thruster_force * delta
		velocity *= 0.98
	
	var move_direction = (global_transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	
	if gravity > 0:
		orient_player(delta)
	
	var is_sprinting = Input.is_action_pressed(SPRINT)
	var speed = sprint_speed if is_sprinting else walk_speed
	
	if is_on_floor():
		if input_direction:
			velocity = move_direction * speed
		else:
			velocity = velocity.move_toward(Vector3.ZERO, speed)
	
	if is_on_floor() and Input.is_action_just_pressed(JUMP):
		velocity += up_direction * jump_height * gravity
	# Add the gravity.
	elif not is_on_floor():
		velocity -= up_direction * gravity * 2.0 * delta

	move_and_slide()
	#print(global_position)
	if Globals.onlineMode:
		Server.send_to_server_position(global_position)
	
	labelx.text = str("%0.2f" % global_position[0])
	labely.text = str("%0.2f" % global_position[1])
	labelz.text = str("%0.2f" % global_position[2])



func _process(_delta: float):
	if !active: return
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handling camera in '_process' so that camera movement is framerate independent
		_handle_camera_motion()
	
	if Input.get_connected_joypads().size() != 0:
		_handle_joy_camera_motion()
	
	
	interact_label.hide()
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider.has_method("interact"):
			interact_label.text = collider.label
			interact_label.show()
			if Input.is_action_just_pressed("interact"):
				collider.interact(self)
				interact_label.hide()
		

func orient_player(delta: float):
	global_transform = global_transform.interpolate_with(Globals.align_with_y(global_transform, up_direction), 0.3)


func spawn_box4m() -> void:
	var box4m_instance: RigidBody3D = box4m.instantiate()
	var spawn_position: Vector3 = global_position + (-global_basis.z * 3.0) + global_basis.y * 6.0
	get_tree().current_scene.add_child(box4m_instance)
	box4m_instance.global_position = spawn_position
	var to_player = (global_transform.origin - spawn_position)
	box4m_instance.rotate_y(atan2(to_player.x, to_player.z) + PI)
	
func spawn_box50cm() -> void:
	var box50cm_instance: RigidBody3D = box50m.instantiate()
	var spawn_position: Vector3 = global_position + (-global_basis.z * 1.5) + global_basis.y * 2.0
	get_tree().current_scene.add_child(box50cm_instance)
	box50cm_instance.global_position = spawn_position
	
	if isInsideBox4m:
		box50cm_instance.set_collision_layer_value(1, false)
		box50cm_instance.set_collision_layer_value(2, true)
		box50cm_instance.set_collision_mask_value(1, false)
		box50cm_instance.set_collision_mask_value(2, true)

func _handle_camera_motion() -> void:
	if gravity == 0:
		rotate_object_local(Vector3.UP, mouse_motion.x  * camera_sensitivity)
		rotate_object_local(Vector3.RIGHT, mouse_motion.y  * camera_sensitivity)
	else:
		global_rotate(global_basis.y, mouse_motion.x * camera_sensitivity)
		camera_pivot.global_rotate(global_basis.x, mouse_motion.y  * camera_sensitivity)
	
	
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
	global_rotate(global_basis.y, -deg_to_rad(camera_sensitivity * normalized_resulting_vector.x * action_strength))
	camera_pivot.global_rotate(global_basis.x, -deg_to_rad(camera_sensitivity * normalized_resulting_vector.y * action_strength))
	
	camera_pivot.rotation_degrees.x = clampf(
		camera_pivot.rotation_degrees.x , -89.0, 89.0
	)


func _on_area_detector_area_entered(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		gravity_parents.push_back(area)
		prints("player entered gravity area", area)
		
		if area is Grid:
			area.enter(self)


func _on_area_detector_area_exited(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		if gravity_parents.has(area):
			prints("player left gravity area", area)
			gravity_parents.erase(area)
			if area is Grid:
				area.exit(self)
				call_deferred("reparent", get_tree().current_scene)
