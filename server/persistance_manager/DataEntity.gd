extends DataObject

class_name  DataEntity


var parent: PhysicsBody3D # check is parent on arbo 

var interval := 2.0

var last_saved_position :Vector3
var parent_obj: DataObject
var uid_position: String


const SCALE := 1e6;


func serialize():
	var dict = {
		"uuid": uuid_obj,
		"position":{
			"uid": uid_position,
			"x": int(last_saved_position.x * SCALE),
			"y": int(last_saved_position.y * SCALE),
			"z": int(last_saved_position.z * SCALE),
			"dgraph.type": "Position",
		},
		"parent": {
			"uid": parent_obj.uid
		}, 
		"dgraph.type": "Entity",
		"type_obj": get_parent().scene_file_path
	}
	if not is_new_object and uid != "":
		dict["uid"] = uid
	return JSON.stringify(dict)

func deserialize(data: Dictionary):
	super.deserialize(data)
	
	if data.has("position"):
		var pos_data = data["position"]
		uid_position = pos_data["uid"]
		last_saved_position = Vector3(
			float(pos_data['x']) / SCALE,
			float(pos_data['y']) / SCALE,
			float(pos_data['z']) / SCALE
		)
		if parent:
			parent.position = last_saved_position

func _enter_tree():
	check_parent()

func _ready() -> void:
	check_parent()
	PersitDataBridge.setup_persistence_manager(_on_client_ready)
	if is_new_object:
		last_saved_position = parent.position
		if parent.get_parent() != null && parent.get_parent().has_node("DataPlanete"):
			parent_obj = parent.get_parent().get_node("DataPlanete")
			print("Parent UID: ", parent_obj.uid)
			if parent_obj.uid.is_empty():
				print("⏳ Waiting for parent to be saved...")
				# Créer un timer ou attendre le signal de sauvegarde du parent
				await_parent_save()
			else:
				initialize_and_save()
		
func start_loop():
	while true:
		await get_tree().create_timer(interval).timeout  # toutes les 2 secondes
		last_saved_position = parent.position
		if not is_new_object and uid != "":
			saved()

func await_parent_save():
	# Attendre que le parent soit sauvé
	while parent_obj.uid.is_empty():
		await get_tree().process_frame
	initialize_and_save()

func initialize_and_save():
	uuid_obj = uuid.v4()
	last_saved_position = parent.position
	saved()
	start_loop()

func load(data: Dictionary, attach_parent: DataObject):
	print("load Data Object")
	is_new_object = false
	if attach_parent != null:
		parent_obj = attach_parent
	PersitDataBridge.execute_custom_query('''
	{
	  entity(func: uid({0})) {
		uid
		uuid
	 	type_obj
		position {
			uid
			x
			y
			z
		}
	  }
	}'''.format([data["uid"]]),loaded)
	
func loaded(result: String):
	print(" Data Entity is loaded")
	var parsed = JSON.parse_string(result)
	if parsed != null:
		deserialize(parsed["entity"][0])
		start_loop()

func check_parent():
	parent = get_parent()
	if parent and not (parent is PhysicsBody3D):
		push_error("PersitData is not children of PhysicsBody3D.")

func  _on_client_ready():
	print("🚀 Signal ClientReady Persist Physic Data !")
