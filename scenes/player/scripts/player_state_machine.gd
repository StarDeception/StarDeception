class_name PlayerStateMachine extends Node

signal transitioned(state: PlayerState)

static var FROM = "from_state"
static var TO = "to_state"

# probably not the best way to store the state constants
static var IDLE = 0
static var WALK = 1
static var SPRINT = 2
static var JUMP = 3
static var FALL = 4
static var CROUCH = 5
static var CLIMB = 6
static var GRAB = 7
static var SLIDE = 8

static var movement_state = {
	IDLE: "Idle",
	WALK: "Walk",
	SPRINT: "Sprint", 
	JUMP: "Jump", 
	FALL: "Fall", 
	CROUCH: "Crouch", 
	CLIMB: "Climb",
	GRAB: "Grab",
	SLIDE: "Slide",
}

@export var initial_state := NodePath()

@onready var state: PlayerState = get_node(initial_state)


func _ready() -> void:
	await owner.ready
	for child in get_children():
		child.state_machine = self
		state.enter()


func _unhandled_input(event: InputEvent) -> void:
	state.handle_input(event)


func _process(delta: float) -> void:
	state.update(delta)


func _physics_process(delta: float) -> void:
	state.physics_update(delta)


func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	if not has_node(str(target_state_name)):
		push_error("No target node \"" + target_state_name + "\" found")
		return
	
	if state == get_node(target_state_name):
		return
	
	state.exit()
	state = get_node(target_state_name)
	state.enter(msg)
	emit_signal("transitioned", state)
