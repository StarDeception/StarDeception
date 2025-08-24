@tool
extends Node3D


@export var planet_terrain: PlanetTerrain
@export var min_rock_cell = 3
@export var max_rock_cell = 7
@export_range(0.1, 10, 0.01) var cell_size = 1.0
@export var spawn_distance = 300
@export var asset_scene: PackedScene

var rnd := RandomNumberGenerator.new()

var planet: Planet
var chunks: Dictionary[String, Node3D]

var focus_positions_last = []

var current_seed = 123

func _ready() -> void:
	planet = owner

func get_local_focus_positions():
	var local_positions = []
	for pos: Vector3 in planet_terrain.focus_positions:
		local_positions.push_back(planet_terrain.to_local(pos))
	return local_positions

func _process(delta: float) -> void:
	if not planet.synced: return
	var positions = get_local_focus_positions()
	if not positions_changed(positions): return
	focus_positions_last = positions

	for asset: Node3D in get_children():
		if not any_near(asset.global_position, spawn_distance):
			asset.queue_free()
			chunks.erase(asset.name)
				
	
	for pos: Vector3 in planet_terrain.focus_positions:
		if pos.distance_to(planet_terrain.global_position) < (spawn_distance + planet_terrain.radius):
			var local_pos = planet_terrain.to_local(pos)
			#print(rounded_pos)
			spawn(local_pos)

func any_near(target_pos: Vector3, distance: float) -> bool:
	var near = false
	for pos: Vector3 in planet_terrain.focus_positions:
		if pos.distance_to(target_pos) < 300:
			near = true
	
	return near
	

func positions_changed(positions: Array) -> bool:
	if positions.size() != focus_positions_last.size():
		return true
	
	for i in positions.size():
		if positions[i] != focus_positions_last[i]:
			if floor(positions[i]) != focus_positions_last[i]:
				return true
	
	return false

func get_cell_from_position(pos: Vector3, cell_size_deg: float) -> Vector2i:
	var dir = pos.normalized()
	var lat = asin(dir.y) * 180.0 / PI
	var lon = atan2(dir.x, dir.z) * 180.0 / PI
	return Vector2i(int(lon / cell_size_deg), int(lat / cell_size_deg))

func get_seed_from_cell(cell_coords: Vector2i) -> int:
	return int(cell_coords.x * 73856093 ^ cell_coords.y * 19349663)

func generate_rocks_in_cell(cell: Vector2i, planet_radius: float, rng: RandomNumberGenerator, cell_size_deg: float):
	var seed = get_seed_from_cell(cell)
	rng.seed = seed
	
	var count = rng.randi_range(min_rock_cell, max_rock_cell) # Number of rocks in this cell
	for i in count:
		var key = str(seed) + "_" + str(i)
		if key in chunks:
			continue
		
		var lat = (cell.y + rng.randf()) * cell_size_deg
		var lon = (cell.x + rng.randf()) * cell_size_deg

		# Convert spherical coords back to 3D
		var x = cos(deg_to_rad(lat)) * sin(deg_to_rad(lon))
		var y = sin(deg_to_rad(lat))
		var z = cos(deg_to_rad(lat)) * cos(deg_to_rad(lon))

		var dir = Vector3(x, y, z).normalized()
		var pos = planet_terrain.get_height(dir)
		
		var asset = asset_scene.instantiate()
		asset.name = key
		add_child(asset, true)
		asset.global_position = planet_terrain.transform * pos
		
		asset.rotation = Vector3(
			rng.randf(),
			rng.randf(),
			rng.randf()
		)
		
		chunks[key] = asset


func spawn(pos: Vector3):
	var cell = get_cell_from_position(pos, cell_size)
	generate_rocks_in_cell(cell, 1, rnd, cell_size)
