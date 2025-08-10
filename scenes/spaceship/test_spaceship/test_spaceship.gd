extends RigidBody3D
class_name Spaceship

@onready var pilot_seat: RemoteTransform3D = $PilotSeat
@onready var ship_console: Interactable = $ShipConsole

@export var speed = 300
@export var roll_speed = 100
@export var mouse_sensitivity = 0.01

var active = false

var force_multiplier = 1000
var gravity_area: Area3D
var pilot: Player
var pause_mode = false

func _ready() -> void:
	$StaticBody3D.add_collision_exception_with(self)
	ship_console.interacted.connect(on_ship_console_interact)

func on_ship_console_interact():
	request_control.rpc_id(1)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_mode = true
		
	if pause_mode and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pause_mode = false
	
	if not is_multiplayer_authority(): return
	
	if Input.is_action_just_pressed("exit"):
		release_control.rpc()
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		steer_ship_mouse(event.screen_relative)

func steer_ship_mouse(dir: Vector2) -> void:
	apply_torque_impulse(-global_transform.basis.x * dir.y * mouse_sensitivity * force_multiplier)
	apply_torque_impulse(-global_transform.basis.y * dir.x * mouse_sensitivity * force_multiplier)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	if pilot:
		active = true
	
	var dir = Vector3.ZERO
	var roll = Vector3.ZERO
		
	var boost = false
	
	$ShipPhysicsGrid.gravity_direction = -global_basis.y
	
	if active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		dir = Vector3(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("strafe_down", "strafe_up"),
			Input.get_axis("move_forward", "move_back"),
		)
		
		roll = Vector3(0, 0, -Input.get_axis("roll_left", "roll_right"))


	var speed_multiplier = 20.0 if boost else 1.0
	
	var force = dir.normalized() * speed * force_multiplier * speed_multiplier * delta
	
	apply_central_force(global_transform.basis * force);
	
	var roll_force = roll * roll_speed * force_multiplier * delta
	apply_torque(global_transform.basis * roll_force)

## Set the position of the ship after the spawn
@rpc("authority", "call_local", "reliable")
func position_ship(new_pos: Vector3, planet_normal: Vector3):
	global_position = new_pos
	global_transform = Globals.align_with_y(global_transform, planet_normal)

## Request the control of the ship to the server
@rpc("any_peer", "call_remote", "reliable")
func request_control():
	var peerid = multiplayer.get_remote_sender_id()
	var player = Server.players[peerid]
	prints("player", player, "take control of ship", name)
	if not pilot_seat.remote_path.is_empty():
		print("pilot is already controlling ship")
		return
		
	take_control.rpc(peerid)

## Notifies the pilot to take the control of the ship and become the authority
@rpc("authority", "call_local", "reliable")
func take_control(id):
	pilot = get_tree().current_scene.spawn_node.get_node(str(id))
	pilot.active = false
	pilot.camera_pivot.rotation.x = 0
	pilot_seat.remote_path = pilot.get_path()
	
	set_multiplayer_authority(id)

## Release the control of ship from the pilot
@rpc("authority", "call_local", "reliable")
func release_control():
	pilot.active = true
	pilot = null
	pilot_seat.remote_path = NodePath("")
	active = false
	set_multiplayer_authority(1)

func _on_collision_area_entered(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		gravity_area = area
		print("enter planet")

func _on_collision_area_exited(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		gravity_area = null
		print("exit planet")

func _on_gravity_area_body_entered(body: PhysicsBody3D) -> void:
	add_collision_exception_with(body)

	
func _on_gravity_area_body_exited(body: Node3D) -> void:
	if pilot and body == pilot: return
	remove_collision_exception_with(body)
	
