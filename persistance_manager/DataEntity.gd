extends DataObject

class_name  DataEntity


var parent: PhysicsBody3D # check is parent on arbo 



var position :Vector3
var parent_obj: DataObject
const SCALE := 1e6;


func serialize():
	var dict = {
		"uid": uid,
		"uuid": uuid_obj,
		"position":{
			"x": position.x*SCALE,
			"y": position.y*SCALE,
			"z": position.z*SCALE
		},
		"parent": {
			"uid": parent_obj.uid
		}, 
		"dgraph.type": "Entity",
		"type_obj": get_parent().scene_file_path
	}
	return JSON.stringify(dict)


func _enter_tree():
	check_parent()

func _ready() -> void:
	check_parent()
	PersitDataBridge.setup_persistence_manager(_on_client_ready)
	if parent.get_parent() != null && parent.get_parent().has_node("DataPlanete"):
		parent_obj = parent.get_parent().get_node("DataPlanete")
		print(parent_obj.uid)
		if parent_obj.uid.is_empty():
			push_error("parent of entity is not empty possible")
		uuid_obj = uuid.v4()
		position = position
		saved()


func check_parent():
	parent = get_parent()
	if parent and not (parent is PhysicsBody3D):
		push_error("PersitData is not children of PhysicsBody3D.")

func  _on_client_ready():
	print("🚀 Signal ClientReady Persist Physic Data !")
