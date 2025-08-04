class_name PlayerState extends Node

var state_machine: PlayerStateMachine = null
var player: Player

func _ready() -> void:
	await owner.ready
	player = owner as Player
	assert(player != null)


func handle_input(_event: InputEvent) -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func enter(_msg := {}) -> void:
	pass


func exit() -> void:
	pass
