extends RigidBody3D


@export var speed = 300
@export var roll_speed = 100
@export var mouse_sensitivity = 0.01

var force_multiplier = 1000

var active = false

var gravity_area: Area3D

var pilot: Player

var pause_mode

func _ready() -> void:
	$StaticBody3D.add_collision_exception_with(self)

# make the player part of the ship
func take_control(player: Player):
	pilot = player
	player.reparent($PilotPosition)
	player.global_transform = $PilotPosition.global_transform
	player.active = false
	player.camera_pivot.rotation.x = 0


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_mode = true
		
	if pause_mode and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pause_mode = false
	
	if Input.is_action_just_pressed("exit"):
		active = false
		pilot.active = true
		pilot.reparent(get_tree().current_scene)
		pilot = null

			
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		steer_ship_mouse(event.screen_relative)

func steer_ship_mouse(dir: Vector2) -> void:
	apply_torque_impulse(-global_transform.basis.x * dir.y * mouse_sensitivity * force_multiplier)
	apply_torque_impulse(-global_transform.basis.y * dir.x * mouse_sensitivity * force_multiplier)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if pilot:
		active = true
	
	var dir = Vector3.ZERO
	var roll = Vector3.ZERO
		
	var boost = false
	
	$GravityArea.gravity_direction = -global_basis.y
	
	if active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		dir = Vector3(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("strafe_down", "strafe_up"),
			Input.get_axis("move_forward", "move_back"),
		)
		
		roll = Vector3(0, 0, -Input.get_axis("roll_left", "roll_right"))
		
		#boost = Input.is_action_pressed("boost")
	
	
	var speed_multiplier = 20.0 if boost else 1.0
	
	var force = dir.normalized() * speed * force_multiplier * speed_multiplier * delta
	
	apply_central_force(global_transform.basis * force);
	
	var roll_force = roll * roll_speed * force_multiplier * delta
	apply_torque(global_transform.basis * roll_force)

func _on_collision_area_entered(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		gravity_area = area
		print("enter planet")

func _on_collision_area_exited(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		gravity_area = null
		print("exit planet")
