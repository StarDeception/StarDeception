extends CharacterBody3D

@onready var camera = $Camera3D

@onready var labelx: Label = $UserInterface/LabelXValue
@onready var labely: Label = $UserInterface/LabelYValue
@onready var labelz: Label = $UserInterface/LabelZValue
@onready var labelPlayerName: Label3D = %LabelPlayerName
@onready var astronaut: Node3D = $Placeholder_Collider/Astronaut

@onready var box4m: PackedScene = preload("res://scenes/props/testbox/box_4m.tscn")
@onready var box50m: PackedScene = preload("res://scenes/props/testbox/box_50cm.tscn")
@onready var isInsideBox4m: bool = false

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if not is_multiplayer_authority(): return
	
	# Here: client have authority
	if Globals.playerName == "":
		labelPlayerName.text = "I'm an idiot!"
		Globals.playerName = "I'm an idiot!"
	else:
		labelPlayerName.text = Globals.playerName
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	# hide player name label for me only
	labelPlayerName.visible = false
	astronaut.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	if event.is_action_pressed("spawn_4mbox"):
		call_deferred("spawn_box4m")
	
	if event.is_action_pressed("spawn_50cmbox"):
		# action of client, send RPC request to server (id = 1)
		Server.spawn_box50cm.rpc_id(1, global_position + (-transform.basis.z * 1.5) + Vector3.UP * 2.0)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not GlobalChat.is_focused:
		velocity.y = JUMP_VELOCITY

	if GlobalChat.is_focused:
		velocity.x = 0
		velocity.z = 0
	else:
		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	labelx.text = str("%0.2f" % global_position[0])
	labely.text = str("%0.2f" % global_position[1])
	labelz.text = str("%0.2f" % global_position[2])

func set_player_name(name):
	labelPlayerName.text = str(name)
	
func get_player_name():
	print(labelPlayerName.text)

func spawn_box4m() -> void:
	var box4m_instance: RigidBody3D = box4m.instantiate()
	var spawn_position: Vector3 = global_position + (-transform.basis.z * 3.0) + Vector3.UP * 6.0
	get_tree().current_scene.add_child(box4m_instance)
	box4m_instance.global_position = spawn_position
	var to_player = (global_transform.origin - spawn_position)
	box4m_instance.rotate_y(atan2(to_player.x, to_player.z) + PI)
