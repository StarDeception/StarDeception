@tool
extends Node3D
class_name PersitData

var parent: PhysicsBody3D
var data: DataObject
var current_uid: String = ""
var demo_step: int = 0  # Pour contrôler la progression de la démo
var demo_enabled: bool = true  # Pour désactiver la démo auto

func _enter_tree():
	check_parent()

func _ready():
	check_parent()
	setup_persistence_manager()
	create_test_data()

func setup_persistence_manager():
	var pm = PersistanceManager
	if not pm:
		push_error("PersistanceManager is null!")
		return
	
	# Connecter tous les signaux une seule fois
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
		print("✅ Client déjà prêt, démarrage des tests !")
		start_crud_demo()
	else:
		print("⏳ En attente du signal ClientReady...")
		if not pm.ClientReady.is_connected(_on_client_ready):
			pm.ClientReady.connect(_on_client_ready)

func create_test_data():
	data = DataObject.new()
	data.position = parent.position
	data.name = "TestObject_" + str(randi() % 1000)
	data.uid = "_:temp_" + str(randi() % 10000)

func check_parent():
	parent = get_parent()
	if parent and not (parent is PhysicsBody3D):
		push_error("PersitData is not children of PhysicsBody3D.")

# ============ EVENT HANDLERS ============
func _on_client_ready():
	print("🚀 Signal ClientReady reçu !")
	start_crud_demo()

func _on_save_completed(success: bool, uid: String, error_message: String, request_id: String):
	print("💾 Save completed - RequestID: ", request_id)
	if success:
		current_uid = uid
		data.uid = uid
		print("✅ Objet sauvegardé avec UID: ", uid)
		
		# Progression contrôlée de la démo
		if demo_enabled and demo_step == 1:
			demo_step = 2
			print("⏭️ Prochaine étape: FindById dans 2 secondes...")
			await get_tree().create_timer(2.0).timeout
			test_find_by_id()
	else:
		print("❌ Échec sauvegarde: ", error_message)

func _on_delete_completed(success: bool, error_message: String, request_id: String):
	print("🗑️ Delete completed - RequestID: ", request_id)
	if success:
		print("✅ Objet supprimé avec succès")
		current_uid = ""
		
		# Fin de la démo
		if demo_enabled and demo_step == 4:
			demo_step = 5
			print("\n🎉 === DÉMO CRUD TERMINÉE ===")
			print("✅ Toutes les opérations ont été testées avec succès !")
			demo_enabled = false  # Arrêter la démo
	else:
		print("❌ Échec suppression: ", error_message)

func _on_query_completed(success: bool, json_data: String, error_message: String, request_id: String):
	print("🔍 Query completed - RequestID: ", request_id)
	if success:
		print("✅ Requête exécutée avec succès")
		print("📄 Données JSON: ", json_data)
		
		# Progression contrôlée de la démo
		if demo_enabled and demo_step == 3:
			demo_step = 4
			print("⏭️ Dernière étape: Delete dans 3 secondes...")
			print("⚠️  L'objet va être supprimé définitivement !")
			await get_tree().create_timer(3.0).timeout
			test_delete()
	else:
		print("❌ Échec requête: ", error_message)

func _on_find_by_id_completed(success: bool, json_data: String, error_message: String, request_id: String):
	print("🎯 FindById completed - RequestID: ", request_id)
	if success:
		print("✅ Recherche par ID réussie")
		print("📄 Données trouvées: ", json_data)
		
		# Progression contrôlée de la démo
		if demo_enabled and demo_step == 2:
			demo_step = 3
			print("⏭️ Prochaine étape: Query dans 2 secondes...")
			await get_tree().create_timer(2.0).timeout
			test_query()
	else:
		print("❌ Échec recherche: ", error_message)

# ============ CRUD OPERATIONS ============
func start_crud_demo():
	print("\n🎬 === DÉMARRAGE DÉMO CRUD ===")
	print("📋 Étapes prévues:")
	print("  1️⃣ Save - Sauvegarder l'objet")
	print("  2️⃣ FindById - Rechercher par ID")
	print("  3️⃣ Query - Requête générale")
	print("  4️⃣ Delete - Supprimer l'objet")
	print("⚠️  Vous pouvez appeler disable_demo() pour arrêter la démo automatique")
	
	demo_step = 1
	demo_enabled = true
	test_save()

func test_save():
	print("\n💾 === TEST SAVE ===")
	var pm = PersistanceManager
	if not pm:
		return
	
	var serialized_data = data.serialize()
	print("📝 Sauvegarde de: ", serialized_data)
	pm.StartSaveAsync(serialized_data)

func test_find_by_id():
	if current_uid == "":
		print("❌ Pas d'UID pour tester FindById")
		return
	
	print("\n🎯 === TEST FIND BY ID ===")
	var pm = PersistanceManager
	if not pm:
		return
	
	print("🔍 Recherche de l'UID: ", current_uid)
	pm.StartFindByIdAsync(current_uid)

func test_query():
	print("\n🔍 === TEST QUERY ===")
	var pm = PersistanceManager
	if not pm:
		return
	
	# Requête pour trouver tous les objets avec un nom
	var query = """
	{
		all(func: has(name)) {
			uid
			name
			position
			dgraph.type
		}
	}
	"""
	
	print("📝 Exécution de la requête...")
	pm.StartQueryAsync(query)

func test_delete():
	if current_uid == "":
		print("❌ Pas d'UID pour tester Delete")
		return
	
	print("\n🗑️ === TEST DELETE ===")
	var pm = PersistanceManager
	if not pm:
		return
	
	print("🗑️ Suppression de l'UID: ", current_uid)
	pm.StartDeleteAsync(current_uid)

# ============ CONTRÔLE DE LA DÉMO ============
func disable_demo():
	"""Désactive la démo automatique"""
	demo_enabled = false
	demo_step = 0
	print("⏹️ Démo automatique désactivée")

func enable_demo():
	"""Réactive la démo automatique"""
	demo_enabled = true
	print("▶️ Démo automatique réactivée")

func reset_demo():
	"""Remet la démo à zéro"""
	demo_step = 0
	demo_enabled = true
	print("🔄 Démo remise à zéro")

# ============ API PUBLIQUE POUR UTILISATION EXTERNE ============
func save_data():
	"""Sauvegarde les données actuelles"""
	var pm = PersistanceManager
	if pm and pm.IsReady:
		pm.StartSaveAsync(data.serialize())
	else:
		print("❌ PersistanceManager non disponible pour save_data")

func delete_data():
	"""Supprime l'objet de la base de données"""
	if current_uid == "":
		print("❌ Aucun UID à supprimer")
		return
	
	var pm = PersistanceManager
	if pm and pm.IsReady:
		pm.StartDeleteAsync(current_uid)
	else:
		print("❌ PersistanceManager non disponible pour delete_data")

func find_data_by_id(uid: String):
	"""Recherche un objet par son UID"""
	var pm = PersistanceManager
	if pm and pm.IsReady:
		pm.StartFindByIdAsync(uid)
	else:
		print("❌ PersistanceManager non disponible pour find_data_by_id")

func execute_custom_query(query_string: String):
	"""Exécute une requête personnalisée"""
	var pm = PersistanceManager
	if pm and pm.IsReady:
		pm.StartQueryAsync(query_string)
	else:
		print("❌ PersistanceManager non disponible pour execute_custom_query")

# ============ UTILITAIRES ============
func get_current_uid() -> String:
	"""Retourne l'UID actuel de l'objet"""
	return current_uid

func is_saved() -> bool:
	"""Vérifie si l'objet a été sauvegardé (a un UID valide)"""
	return current_uid != "" and not current_uid.begins_with("_:")
