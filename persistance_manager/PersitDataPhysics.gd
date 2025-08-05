@tool
extends PersitDataBridge
class_name PersitDataPhysics

var parent: PhysicsBody3D

func _enter_tree():
	check_parent()

func _ready():
	check_parent()
	setup_persistence_manager()
	data = DataObject.new()

func check_parent():
	parent = get_parent()
	if parent and not (parent is PhysicsBody3D):
		push_error("PersitData is not children of PhysicsBody3D.")

func  _on_client_ready():
	print("🚀 Signal ClientReady Persist Physic Data !")
	save_data(on_saved)
	
func on_saved(uid):
	print("uid is saved "+uid)
