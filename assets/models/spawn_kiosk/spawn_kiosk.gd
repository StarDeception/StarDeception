extends StaticBody3D

@onready var kiosk_interaction_area: Area3D = $KioskInteractionArea
@onready var spawn_area: Area3D = $SpawnArea
@onready var spawn_response_label: Label3D = $SpawnResponseLabel
@onready var spawn_response_timer: Timer = $SpawnResponseLabel/Timer

func _ready() -> void:
	kiosk_interaction_area.connect("interacted", _on_interaction_requested)
	spawn_response_timer.connect("timeout", _on_timer_timeout)

func _on_interaction_requested(interactor: Node) -> void:
	if interactor is Player and not multiplayer.is_server():
		
		if spawn_area.has_overlapping_bodies():
			spawn_response_timer.stop()
			spawn_response_label.text = "Clear the pad first"
			spawn_response_timer.start()
			return
		
		var spawn_position: Vector3 = spawn_area.global_position
		var spawn_rotation: Vector3 = spawn_area.global_rotation
		
		interactor.emit_signal("client_action_requested", {"action": "spawn", "entity": "ship", "spawn_position": spawn_position, "spawn_rotation": spawn_rotation})

func _on_timer_timeout() -> void:
	spawn_response_label.text = ""
