extends Node
class_name PersitDataBridge

@export var data: DataObject

var persistCalback: Dictionary[String, Callable]

func setup_persistence_manager():
	if OS.has_feature("dedicated_server") || true:
		var pm = PersistanceManager
		if not pm:
			push_error("PersistanceManager is null!")
			return
		# Connect all PersistanceManagerSignal
		if not pm.SaveCompleted.is_connected(_on_save_completed):
			pm.SaveCompleted.connect(_on_save_completed)
		
		if not pm.DeleteCompleted.is_connected(_on_delete_completed):
			pm.DeleteCompleted.connect(_on_delete_completed)
		
		if not pm.QueryCompleted.is_connected(_on_query_completed):
			pm.QueryCompleted.connect(_on_query_completed)
		
		if not pm.FindByIdCompleted.is_connected(_on_find_by_id_completed):
			pm.FindByIdCompleted.connect(_on_find_by_id_completed)
		
		# Démarrer les opérations si le manager est prêt
		if pm.IsReady:
			print("✅ Client Alredy start")
			_on_client_ready()
		else:
			print("⏳ En attente du signal ClientReady...")
			if not pm.ClientReady.is_connected(_on_client_ready):
				pm.ClientReady.connect(_on_client_ready)
	else :
		print("only dev for the server")

# ============ EVENT HANDLERS ============
func _on_client_ready():
	print("🚀 Signal ClientReady !")

func _on_save_completed(success: bool, uid: String, error_message: String, request_id: String):
	print("💾 Save completed - RequestID: ", request_id)
	if success:
		print("✅Object save with UID: ", uid)
		persistCalback[request_id].call(uid)
		persistCalback.erase(request_id)
	else:
		printerr("❌ Failed save: ", error_message)

func _on_delete_completed(success: bool, error_message: String, request_id: String):
	print("🗑️ Delete completed - RequestID: ", request_id)
	if success:
		print("✅ Objet deleted succès")
		persistCalback[request_id].call()
		persistCalback.erase(request_id)
	else:
		printerr("❌ Failed delete: ", error_message)

func _on_query_completed(success: bool, json_data: String, error_message: String, request_id: String):
	print("🔍 Query completed - RequestID: ", request_id)
	if success:
		print("✅ Requête Success")
		persistCalback[request_id].call(json_data)
		persistCalback.erase(request_id)
	else:
		printerr("❌ Échec requête: ", error_message)

func _on_find_by_id_completed(success: bool, json_data: String, error_message: String, request_id: String):
	print("🎯 FindById completed - RequestID: ", request_id)
	if success:
		print("✅ Serach By ID success")
		persistCalback[request_id].call(json_data)
		persistCalback.erase(request_id)
	else:
		printerr("❌ Échec recherche: ", error_message)



# ============ function for external use ============
func save_data(calback: Callable):
	var pm = PersistanceManager
	if pm and pm.IsReady:
		var rid = pm.StartSaveAsync(data.serialize())
		persistCalback[rid]=calback
	else:
		printerr("❌ PersistanceManager is not ready for save_data")

func delete_data(calback: Callable):
	if data.uid == "":
		print("❌ not uid")
		return
	
	var pm = PersistanceManager
	if pm and pm.IsReady:
		var rid = pm.StartDeleteAsync(data.uid)
		persistCalback[rid]=calback
	else:
		printerr("❌ PersistanceManager is not ready pour delete_data")

func find_data_by_id(uid: String,calback: Callable):
	var pm = PersistanceManager
	if pm and pm.IsReady:
		var rid = pm.StartFindByIdAsync(uid)
		persistCalback[rid]=calback
	else:
		printerr("❌ PersistanceManager is not ready find_data_by_id")

func execute_custom_query(query_string: String,calback: Callable):
	var pm = PersistanceManager
	if pm and pm.IsReady:
		var rid = pm.StartQueryAsync(query_string)
		persistCalback[rid]=calback
	else:
		printerr("❌ PersistanceManager is not ready execute_custom_query")

# ============ UTILITAIRES ============
func get_current_uid() -> String:
	return data.uid

func is_saved() -> bool:
	return data.uid != "" and not data.uid.begins_with("_")
