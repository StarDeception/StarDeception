extends DataObject

class_name DataPlanete

var contains: Array[DataObject]
var parent
var planete_name

func serialize():
	var dict = {
		"uid": uid,
		"uuid": uuid_obj,
		"name": planete_name,
		"dgraph.type": "Planete",
		"type_obj": get_parent().scene_file_path
	}
	return JSON.stringify(dict)

func _ready():
	parent = get_parent()
	PersitDataBridge.setup_persistence_manager(_on_client_ready)
	planete_name = "TestPlanete"
	uuid_obj = uuid.v4()

func  _on_client_ready():
	print("🚀 Signal ClientReady Persist Physic Data !")
	PersitDataBridge.execute_custom_query('''
	{ 
		planet(func: eq(name, {0})) @filter(eq(dgraph.type, "Planete")) 
		{ 
			uid 
			uuid 
			name 
			contains 
			{ 
				uid 
				uuid 
				name 
			} 
		} }'''.format([planete_name]),_check_planete)
	#save_data(on_saved)
func _check_planete(result: String):
	var parsed = JSON.parse_string(result)
	if parsed != null:
		var loadplanet = parsed["planet"]
		if typeof(loadplanet) == TYPE_ARRAY:
			if(loadplanet.size() == 0):
				print("0 planet fond")
				saved() # todo bug for get uid on the first run after wipe 
			else:
				deserialize(loadplanet[0])
				query_child_data()
		else:
			print("Unexpected data")
			
func query_child_data():
	print("🚀 Query Get child !")
	PersitDataBridge.execute_custom_query('''
	{
	  entity(func: uid({0})) {
		~parent{
			uid
			type_obj
		  }
	  }
	}'''.format([uid]),_list_child_entity)

func _list_child_entity(result: String):
	print(result)
