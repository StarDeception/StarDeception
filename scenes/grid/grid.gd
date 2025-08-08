extends Area3D

class_name PhysicsGrid

var parent_gravity: Node3D


@export var reparent_bodies = true

var reparenting = false

func _ready() -> void:
	parent_gravity = get_parent().get_parent()
	#if reparent_bodies:
		#body_entered.connect(_on_gravity_area_body_entered)
		#body_exited.connect(_on_gravity_area_body_exited)

func _process(delta: float) -> void:
	gravity_direction = -global_basis.y


#func _on_gravity_area_body_entered(body: PhysicsBody3D) -> void:
	#if body == get_parent(): return
	#if reparenting: return
	#var body_parent = body.get_parent()
	#
	## make sure the body entering the physics grid shares the same ancestor physics grid as this grid
	##prints(body, "grids", body_parent, parent_gravity)
	##if body_parent is PhysicsGrid and body_parent != parent_gravity:
		##return
	#
	#
	#prints(name, body, "entered")
	#reparenting = true
	#prints(body, "REPARENTING START")
	#var bodies = get_overlapping_bodies()
#
	#toggle_disable_bodies(bodies, true)
	#
	#await body.call_deferred("reparent", self)
	#await get_tree().physics_frame
	#await get_tree().physics_frame
	#
	#toggle_disable_bodies(bodies, false)
	#prints(body, "REPARENTING END")
	#reparenting = false
	#
#func _on_gravity_area_body_exited(body: Node3D) -> void:
	#if reparenting: return
	#if body == get_parent(): return
	#var body_parent = body.get_parent()
	#
	##
	##prints(body,"grids", body_parent, parent_gravity)
	##return
	### make sure the body entering the physics grid shares the same ancestor physics grid as this grid 
	##if body_parent is PhysicsGrid and body_parent != parent_gravity:
		##return
#
	#prints(name, body, "exited")
	#reparenting = true
	#var bodies = get_overlapping_bodies()
	#
	#toggle_disable_bodies(bodies, true)
#
	#await body.call_deferred("reparent", get_parent().get_parent())
	#await get_tree().physics_frame
	#await get_tree().physics_frame
	#toggle_disable_bodies(bodies, false)
	#reparenting = false
	#
#
#func toggle_disable_bodies(bodies: Array, disable: bool):
	#for body: PhysicsBody3D in bodies:
		#if body != get_parent():
			#prints("update body enable", body, disable)
			#body.process_mode = Node.PROCESS_MODE_DISABLED if disable else Node.PROCESS_MODE_INHERIT
