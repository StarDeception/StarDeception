extends CharacterBody3D
class_name Player

@onready var camera: Camera3D = $CameraPivot/Camera3D

@onready var labelx: Label = $UserInterface/LabelXValue
@onready var labely: Label = $UserInterface/LabelYValue
@onready var labelz: Label = $UserInterface/LabelZValue
@onready var labelPlayerName: Label3D = %LabelPlayerName
@onready var astronaut: Node3D = $Placeholder_Collider/Astronaut
@onready var interact_ray: RayCast3D = $CameraPivot/Camera3D/InteractRay
@onready var interact_label: Label = $UserInterface/InteractLabel
@onready var camera_pivot: Node3D = $CameraPivot

@onready var box4m: PackedScene = preload("res://scenes/props/testbox/box_4m.tscn")
@onready var box50m: PackedScene = preload("res://scenes/props/testbox/box_50cm.tscn")
@onready var isInsideBox4m: bool = false

@onready var game_is_paused: bool = false

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

var input_direction: Vector2
var movement_strength: float
var mouse_motion: Vector2

@export var gravity = 0.0

var gravity_parents: Array[Area3D]

# to disable player input when piloting vehicule/ship
var active = true

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if not is_multiplayer_authority(): return
	Globals.log("player spawn")
	
	# Here: client have authority
	if Globals.playerName == "":
		labelPlayerName.text = "I'm an idiot!"
		Globals.playerName = "I'm an idiot!"
	else:
		labelPlayerName.text = Globals.playerName
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = false
	$ExtCamera3D.current = false
	# hide player name label for me only
	labelPlayerName.visible = false
	astronaut.visible = false
	connect_area_detect()
	active = false

func handle_spawn():
	active = true
	camera.current = true
	
	await get_tree().create_timer(1).timeout
	Server.spawn_ship.rpc_id(1)
	


func connect_area_detect():
	$AreaDetector.area_entered.connect(_on_area_detector_area_entered)
	$AreaDetector.area_exited.connect(_on_area_detector_area_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if !active: return
	
	if GlobalChat.is_shown: return
	
	if event.is_action_pressed(PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game_is_paused = true
	
	if game_is_paused and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		game_is_paused = false
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_motion = -event.relative * 0.001
	
	if event.is_action_pressed("spawn_50cmbox"):
		# action of client, send RPC request to server (id = 1)
		Server.spawn_box50cm.rpc_id(1)
	
	if event.is_action_pressed("spawn_4mbox"):
		Server.spawn_box4m.rpc_id(1)
	

	if Input.is_action_just_pressed("ext_cam"):
		if $ExtCamera3D.current:
			camera.make_current()
			astronaut.visible = false
		else: 
			astronaut.visible = true
			$ExtCamera3D.make_current()

func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	if !active: return
	
	_handle_camera_motion()
	
	interact_label.hide()
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider.has_method("interact"):
			interact_label.text = collider.label
			interact_label.show()
			if Input.is_action_just_pressed("interact"):
				collider.interact()
				interact_label.hide()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	if !active: return
	
	var dir_vect = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)
	if dir_vect and !GlobalChat.is_shown:
		input_direction = dir_vect
	else:
		input_direction = Vector2.ZERO

	var sprint = Input.is_action_pressed(SPRINT)
	var jump = Input.is_action_just_pressed(JUMP)
	
	var parent_gravity_area: Area3D = gravity_parents.back() if not gravity_parents.is_empty() else null
	
	if parent_gravity_area:
		
		if parent_gravity_area.gravity_point:
			up_direction = parent_gravity_area.global_position.direction_to(global_position)
		else:
			up_direction = parent_gravity_area.global_basis.y
		
		gravity = parent_gravity_area.gravity
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	else:
		# 0g movement
		gravity = 0.0
		camera_pivot.rotation.x = 0
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var dir = Vector3(input_direction.x, 0, input_direction.y)
		
		velocity += global_basis * dir * player_thruster_force * delta
		velocity *= 0.98
	
	var move_direction = (global_transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	
	if gravity > 0:
		orient_player()
	
	var speed = sprint_speed if sprint else walk_speed
	
	if is_on_floor():
		if input_direction and !GlobalChat.is_shown:
			velocity = move_direction * speed
		else:
			velocity = velocity.move_toward(Vector3.ZERO, speed)
	else:
		# "air" movement
		if input_direction:
			velocity += move_direction * speed * delta
			
	if is_on_floor() and jump and !GlobalChat.is_shown:
		velocity += up_direction * jump_height * gravity
	# Add the gravity.
	elif not is_on_floor():
		velocity -= up_direction * gravity * 2.0 * delta

	#prints("player vel", velocity, multiplayer.get_unique_id())
	
	#prints("player pos", position, rotation, multiplayer.get_unique_id())
	move_and_slide()
	
	labelx.text = str("%0.2f" % global_position[0])
	labely.text = str("%0.2f" % global_position[1])
	labelz.text = str("%0.2f" % global_position[2])

func _handle_camera_motion():
	if gravity == 0:
		camera_pivot.rotation.x = 0
		rotate_object_local(Vector3.UP, mouse_motion.x  * camera_sensitivity)
		rotate_object_local(Vector3.RIGHT, mouse_motion.y  * camera_sensitivity)
	else:
		orient_player()
		global_basis = global_basis.rotated(global_basis.y, mouse_motion.x * camera_sensitivity)
		camera_pivot.rotate_object_local(Vector3.RIGHT, mouse_motion.y  * camera_sensitivity)
		camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x, -80, 80)
	mouse_motion = Vector2.ZERO

func orient_player():
	global_transform = global_transform.interpolate_with(Globals.align_with_y(global_transform, up_direction), 0.3)

func set_player_name(player_name):
	labelPlayerName.text = str(player_name)
	
func get_player_name():
	print(labelPlayerName.text)



func _on_area_detector_area_entered(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		gravity_parents.push_back(area)
		prints("player entered gravity area", area)
		#disconnect_area_detect()
		#await call_deferred("reparent", self, area)
		#connect_area_detect()

func _on_area_detector_area_exited(area: Area3D) -> void:
	if area.is_in_group("gravity"):
		if gravity_parents.has(area):
			prints("player left gravity area", area)
			gravity_parents.erase(area)
