@tool
extends  Node
class_name  DataObject


var uuid_obj: String
var uid: String
var type_obj: String

func serialize():
	var dict = {
		"uid": uid,
		"uuid": uuid_obj,
		"type_obj": get_parent().scene_file_path
	}
	return JSON.stringify(dict)

func deserialize(data: Dictionary):
	uid = data["uid"]
	uuid_obj = data["uuid"]
	
func saved():
	PersitDataBridge.save_data(self,on_saved)

func on_saved(uid: String):
	uid = uid
	print("uid is saved "+uid)

# ============ UTILITAIRES ============
func get_current_uid() -> String:
	return uid

func is_saved() -> bool:
	return uid != "" and not uid.begins_with("_")
