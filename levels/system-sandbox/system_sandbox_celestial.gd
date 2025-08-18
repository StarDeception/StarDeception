extends Node
class_name SystemSandboxInitializer

var db_connector: DbConnector
var entity_serializer: EntitySerializer

var sandbox_config = {
	"star": {
		"id": "dying_star",
		"name": "Dying Star",
		"radius": 696340,
		"temperature": 5800,
		"luminosity": 3.828e12,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"rotation": {
			"angle": 0.0,
			"speed": 0.000115,
			"axis": {"x": 0.0, "y": 1.0, "z": 0.0}
		},
		"children": [
			{
				"id": "planet",
				"name": "Planet",
				"scene": "res://scenes/planet/testplanet.tscn",
				"radius": 6371,
				"position": {"x": 15000.0, "y": 0.0, "z": 0.0},
				"rotation": {
					"angle": 0.0,
					"speed": 0.0000729,
					"axis": {"x": 0.0, "y": 1.0, "z": 0.0}
				},
				"orbit": {
					"type": "circular",
					"velocity": {"x": 0.0, "y": 0.0, "z": 0.0}
				},
				"children": [
					{
						"id": "station",
						"name": "Station",
						"scene": "res://scenes/station/test_station/test_station.tscn",
						"position": {"x": 0.0, "y": 0.0, "z": 500.0},
						"rotation": {
							"angle": 0.0,
							"speed": 0.000873, 
							"axis": {"x": 0.0, "y": 0.0, "z": 1.0}
						},
						"orbit": {
							"type": "circular",
							"velocity": {"x": 0.0, "y": 0.0, "z": 0.0}
						}
					}
				]
			}
		]
	}
}

func _ready() -> void:
	db_connector = DbConnector.new()
	entity_serializer = EntitySerializer.new()
	add_child(db_connector)
	add_child(entity_serializer)
	
	db_connector.configure()
	db_connector.connected_to_db.connect(initialize_sandbox_system)
	
	await db_connector.connect_to_database()

func initialize_sandbox_system() -> void:
	var exist = await _check_already_exist()
	
	print(entity_serializer.serialize(sandbox_config.star))
	if exist:
		print("Sandbox status: initialize !")
		return
	
	await _create_star()
	
	print('Sandbox status: created ! ')

func _check_already_exist() -> bool:
	var query = """
	MATCH (s:Entity:CelestialBody:Star {id: $star_id})
	RETURN s
	"""
	
	var result = await db_connector.execute_query(query, { "star_id": sandbox_config.star.id })
	return result.success and result.data.size() > 0

###############################################
#  CREATE SANDBOX ENTITIES
###############################################

func _create_star() -> void:
	var query = """
	CREATE (s:Entity:CelestialBody:Star $properties)
	RETURN s.id
	"""
	
	var result = await db_connector.execute_query(query, { "properties": entity_serializer.serialize(sandbox_config.star) })
	print("success _create_star", result)
	if result.success:
		for planet in sandbox_config.star.children:
			await _create_planet_and_link_start(sandbox_config.star.id, planet)

func _create_planet_and_link_start(star_id: String, planet: Dictionary) -> void:
	var query = """
	MATCH (star:Entity:CelestialBody:Star {id: $star_id})
	CREATE (p:Entity:CelestialBody:Planet $properties)-[:ORBITS {
		 relationship_type: "planetary_orbit",
		created_at: timestamp()
	}]->(star)
	RETURN p.id
	"""
	
	var result = await db_connector.execute_query(query, {
		"star_id": star_id,
		"properties": entity_serializer.serialize(planet)
	 })
	print("success _create_planet_and_link_start", result.success)
	if result.success:
		for child in planet.children:
			await _create_station_and_link_planet(planet.id, child)

func _create_station_and_link_planet(planet_id: String, station: Dictionary) -> void:
	var query = """
	MATCH (planet:Entity:CelestialBody:Planet {id: $planet_id})
	CREATE (station:Entity:CelestialBody:Station $properties)-[:ORBITS {
		 relationship_type: "station_orbit",
		created_at: timestamp()
	}]->(planet)
	RETURN station.id
	"""
	
	var result = await db_connector.execute_query(query, {
		"planet_id": planet_id,
		"properties": entity_serializer.serialize(station)
	 })
	print("success _create_station_and_link_planet", result.success)
