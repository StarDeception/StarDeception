@tool
extends PersitDataBridge
class_name PersitDataPhysics

var parent: PhysicsBody3D

func _enter_tree():
	check_parent()

func _ready():
	check_parent()
	setup_persistence_manager()
	create_test_data()

func create_test_data():
	data = DataObject.new()
	data.position = parent.position
	data.name = "TestObject_" + str(randi() % 1000)
	data.uid = "_:temp_" + str(randi() % 10000)

func check_parent():
	parent = get_parent()
	if parent and not (parent is PhysicsBody3D):
		push_error("PersitData is not children of PhysicsBody3D.")

func  _on_client_ready():
	print("🚀 Signal ClientReady Persist Physic Data !")
	save_data(on_saved)
	
func on_saved(uid):
	print("uid is saved "+uid)
