extends Node

signal entity_manager_ready()
signal celestial_entity_loaded(entities: Dictionary)
signal entity_loaded(entity_id: String, entity_data: Dictionary)
signal entity_created(entity_id: String, entity_data: Dictionary)
signal entity_updated(entity_id: String, entity_data: Dictionary)
signal entity_deleted(entity_id: String)

var celestial_entities: Dictionary = {}
var entities: Dictionary = {}

var db_connector: DbConnector
var entity_serializer: EntitySerializer

func _ready() -> void:
	print('Entity manager: initialise')
	await _initialize_database()

func load_celestial_entities() -> void:
	# skip solar for the moment
	var query = """
	MATCH (planet:CelestialBody:Planet) 
	OPTIONAL MATCH (planet)<-[:ORBITS]-(child)
	WITH planet, collect(child) AS children
	RETURN planet {.*, children: [child in children | child {.*} ] }
	"""
	
	var result = await db_connector.execute_query(query, {})
	if result.success:
		var rows = result.data[0].get("row")
		for row in rows:
			celestial_entities.set(row.get("id"), row)
		
		emit_signal("celestial_entity_loaded", celestial_entities)

func load_entity_arround_player(player: Node3D) -> void:
	var query ="""
	MATCH (e:Entity)
	WHERE e.position IS NOT NULL
	WITH e, point.distance(e.position, point({x: $center_x, y: $center_y, z: $center_z})) as distance
	WHERE distance <= $radius
	RETURN e, distance
	ORDER BY distance ASC
	"""
		
	var params = {
		"center_x": player.global_position.x,
		"center_y": player.global_position.y,
		"center_z": player.global_position.z,
		"radius": 10
	}
	print_rich("[color=green]Load entities : %s[/color]" % query)
	
	var result = await db_connector.execute_query(query, params)
	if result.success:
		for record in result.data:
			var node = record.get("e", {})
			
			if node.has("id"):
				entities[node["id"]]
				emit_signal("entity_loaded", node["id"], node)
		
		print("EntityManager: %d entités chargées" % entities.size())

func store_entity(entity: Node3D) -> String:
	var id = uuid.v4()
	
	var data = {
		"id": id,
		"scene": entity.scene_file_path,
		"position": entity.global_position,
		"rotation": entity.rotation,
		"scale": entity.scale,
		"created_at": Time.get_unix_time_from_system(),
		"updated_at": Time.get_unix_time_from_system()
	}
	
	entities[id] = data
	
	await _persist_entity(id, data)
	emit_signal("entity_created", id, data)
	
	return id

func _persist_entity(id: String, data: Dictionary) -> void:
	var query = """
	MERGE (e:Entity {id: $id, position: point({x: $properties.position_x, y: $properties.position_y, z: $properties.position_z, crs: 'cartesian-3d'})})
	SET e += $properties
	SET e.updated_at = timestamp()
	"""
	
	var params = {
		"id": id,
		"properties": entity_serializer.serialize(data)
	}
	print_rich("[color=green]Persist entity : %s[/color]" % query)
	
	await db_connector.execute_query(query, params)

func _on_db_connected() -> void:
	emit_signal("entity_manager_ready")

func _initialize_database() -> void:
	db_connector = DbConnector.new()
	entity_serializer = EntitySerializer.new()
	add_child(db_connector)
	add_child(entity_serializer)
	
	db_connector.configure()
	db_connector.connected_to_db.connect(_on_db_connected)
	
	await db_connector.connect_to_database()
