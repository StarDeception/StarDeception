extends Area3D

class_name PhysicsGrid

var reparenting = false

func _ready() -> void:
	body_entered.connect(_on_gravity_area_body_entered)
	body_exited.connect(_on_gravity_area_body_exited)
	
	
func _process(delta: float) -> void:
	gravity_direction = -global_basis.y


func _on_gravity_area_body_entered(body: PhysicsBody3D) -> void:
	if body == get_parent(): return
	if reparenting: return
	var body_parent = body.get_parent()
	if body_parent is PhysicsGrid and body_parent.get_parent().get_parent() != get_parent().get_parent(): return
	
	prints(body, "entered")
	reparenting = true
	await body.call_deferred("reparent", self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	reparenting = false
	
func _on_gravity_area_body_exited(body: Node3D) -> void:
	if reparenting: return
	if body == get_parent(): return
	var body_parent = body.get_parent()
	if body_parent is PhysicsGrid and body_parent.get_parent().get_parent() != get_parent().get_parent(): return

	prints(body, "exited")
	reparenting = true
	await body.call_deferred("reparent", get_parent().get_parent())
	await get_tree().physics_frame
	await get_tree().physics_frame
	reparenting = false
	
