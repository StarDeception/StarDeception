@tool
extends  Node
class_name  DataObject


var uuid_obj: String
var uid: String
var type_obj: String

var is_new_object := true

func serialize():
	var dict = {
		"uuid": uuid_obj,
		"type_obj": get_parent().scene_file_path
	}
	if not is_new_object and uid != "":
		dict["uid"] = uid
	return JSON.stringify(dict)

func deserialize(data: Dictionary):
	if data.has("uid"):
		uid = data["uid"]
		is_new_object = false
	if data.has("uuid"):
		uuid_obj = data["uuid"]
	
func saved():
	PersitDataBridge.save_data(self,on_saved)

func on_saved(new_uid: String):
	if new_uid != "":
		if is_new_object:
			uid = new_uid
			is_new_object = false
			print("✅ New object created with UID: ", uid)
		else:
			if uid != new_uid:
				print("⚠️ UID changed during update: ", uid, " -> ", new_uid)
	elif uid != "":
		print("✅ Object updated")
	else:
		printerr("❌ Failed to save, no UID received")

# ============ UTILITAIRES ============
func get_current_uid() -> String:
	return uid

func is_saved() -> bool:
	return uid != "" and not uid.begins_with("_")
	
func load_obj(data: Dictionary, attach_parent: DataObject = null):
	print("load Data Object")
	PersitDataBridge.find_data_by_id(data["uid"],loaded)

func loaded(result: String):
	print(" Data Object is loaded")
	
