@tool
extends Node3D
class_name QuadtreeNode

## Based on: https://github.com/stefsdev/ProcPlanetLOD

@export var planet: Planet

var focus_positions_last = []
var focus_positions = []

# Quadtree specific properties
@export var material: Material
@export var normal : Vector3

var camera_dir: Vector3
var last_cam_dir: Vector3


var axisA: Vector3
var axisB: Vector3

var skirt_indices = 2

var chunks_list = {}
var chunks_list_current = {}
# collision shape for chunks
var chunks_col_list = {}
# chunks that do not have a meshinstance yet
var chunks_generating = {}

var update_thread: Thread
var semaphore: Semaphore
var mutex: Mutex
var should_exit = false


var run_serverside = false

# Placeholder for the quadtree structure
var quadtree: QuadtreeChunk

# Define a Quadtree chunk class
class QuadtreeChunk:
	var bounds: AABB
	var children = []
	var depth: int
	var max_chunk_depth: int
	var identifier: String
	
	var planet: Planet
	var face_origin: Vector3
	var axisA: Vector3
	var axisB: Vector3
	
	func _init(_bounds: AABB, _depth: int, _max_chunk_depth: int, _planet: Planet, _face_origin: Vector3, _axisA: Vector3, _axisB: Vector3):
		bounds = _bounds
		depth = _depth
		max_chunk_depth = _max_chunk_depth
		identifier = generate_identifier()
		planet = _planet
		face_origin = _face_origin
		axisA = _axisA
		axisB = _axisB

	func generate_identifier() -> String:
		# Generate a unique identifier for the chunk based on bounds and depth
		return "%s_%s_%d" % [bounds.position, bounds.size, depth]
	
	
	func within_lod_distance(lod_centers: Array, run_serverside: bool, center_local_3d: Vector3):
		#if run_serverside:
			#return true
			
		for pos in lod_centers:
			var distance = planet.get_height(center_local_3d.normalized()).distance_to(pos)
			if distance <= planet.lod_levels[depth]["distance"]:
				return true
		
		return false

	func subdivide(lod_centers: Array, run_serverside: bool):
		# Calculate new bounds for children
		var half_size = bounds.size.x * 0.5
		var quarter_size = bounds.size.x * 0.25
		var half_extents = Vector3(half_size, half_size, half_size)
		
		var child_offsets = [
			Vector2(-quarter_size, -quarter_size),
			Vector2(quarter_size, -quarter_size),
			Vector2(-quarter_size, quarter_size),
			Vector2(quarter_size, quarter_size)
		]
		

		for offset in child_offsets:
			var child_pos_2d = Vector2(bounds.position.x, bounds.position.z) + offset
			var center_local_3d = face_origin + child_pos_2d.x * axisA + child_pos_2d.y * axisB
			
			
			if depth < max_chunk_depth and within_lod_distance(lod_centers, run_serverside, center_local_3d):
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth, planet, face_origin, axisA, axisB)
				children.append(new_child)
				
				new_child.subdivide(lod_centers, run_serverside)
			else:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y) - Vector3(quarter_size, quarter_size, quarter_size), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth, planet, face_origin, axisA, axisB)
				children.append(new_child)

func visualize_quadtree(chunk: QuadtreeChunk):
	# Generate a MeshInstance for each chunk
	if not chunk.children:

		chunks_list_current[chunk.identifier] = true
		#if chunk.identifier already exists leave it
		if chunks_generating.has(chunk.identifier):
			return
		
		var size = chunk.bounds.size.x
		var offset = chunk.bounds.position
		var resolution: int = planet.lod_levels[chunk.depth - 1]["resolution"] + skirt_indices
		var vertex_array := PackedVector3Array()
		var normal_array := PackedVector3Array()
		var index_array := PackedInt32Array()

		# Pre-allocate indices (we know exact count)
		var num_cells = (resolution - 1)
		index_array.resize(num_cells * num_cells * 6)

		# Build vertices & normals (initialized zero)
		vertex_array.resize(resolution * resolution)
		normal_array.resize(resolution * resolution)

		var tri_idx: int = 0
		for y in range(resolution):
			for x in range(resolution):
				var i = x + y * resolution
				var percent = Vector2(x, y) / float(resolution - skirt_indices - 1)
				var local = Vector2(offset.x, offset.z) + percent * size
				var point_on_plane = normal + local.x * axisA + local.y * axisB
				# Project onto sphere and apply height
				var sphere_pos = planet.get_height(point_on_plane.normalized())
				vertex_array[i] = sphere_pos
				normal_array[i] = Vector3.ZERO

				# Track height extremes
				var length = sphere_pos.length()
				planet.min_height = min(planet.min_height, length)
				planet.max_height = max(planet.max_height, length)

				# Create two triangles per cell
				if x < resolution - 1 and y < resolution - 1:
					# Triangle 1
					index_array[tri_idx]     = i
					index_array[tri_idx + 1] = i + resolution
					index_array[tri_idx + 2] = i + resolution + 1
					# Triangle 2
					index_array[tri_idx + 3] = i
					index_array[tri_idx + 4] = i + resolution + 1
					index_array[tri_idx + 5] = i + 1
					tri_idx += 6

		# Calculate smooth normals
		for t in range(0, index_array.size(), 3):
			var a = index_array[t]
			var b = index_array[t + 1]
			var c = index_array[t + 2]
			var v0 = vertex_array[a]
			var v1 = vertex_array[b]
			var v2 = vertex_array[c]
			var face_normal = -(v1 - v0).cross(v2 - v0).normalized()
			
			normal_array[a] += face_normal
			normal_array[b] += face_normal
			normal_array[c] += face_normal
		# Normalize vertex normals
		for i in range(normal_array.size()):
			normal_array[i] = normal_array[i].normalized()

		# Prepare mesh arrays
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertex_array
		arrays[Mesh.ARRAY_NORMAL] = normal_array
		arrays[Mesh.ARRAY_INDEX] = index_array

		
		generate_mesh.call_deferred(arrays, chunk)
		chunks_generating[chunk.identifier] = true
		
		
	# Recursively visualize children chunks
	for child in chunk.children:
		visualize_quadtree(child)

func generate_mesh(arrays: Array, chunk: QuadtreeChunk):
	# Create and instance mesh
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# if at final LOD (highest)
	if planet.lod_levels.size() == chunk.depth and not Engine.is_editor_hint():
		if !chunks_col_list.has(chunk.identifier):
			add_staticbody(chunk.identifier, mesh)
		else:
			update_collision(chunk.identifier, mesh)
	
	if not run_serverside:
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material
		
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter("h_min", planet.min_height)
			(material as ShaderMaterial).set_shader_parameter("h_max", planet.max_height)
		
		add_child(mi)

		#add this chunk to chunk list
		chunks_list[chunk.identifier] = mi
	

func update_collision(id: String, mesh: ArrayMesh):
	var col = chunks_col_list[id].get_child(0) as CollisionShape3D
	col.disabled = false
	#prints("update shape for chunk", id)

func add_staticbody(id: String, mesh: ArrayMesh):
	var t =  Time.get_ticks_msec()
	var staticbody = StaticBody3D.new()
	#staticbody.position = mesh.get_aabb().get_center()
	var collision_shape = CollisionShape3D.new()
	collision_shape.name = "ChunkColShape"
	collision_shape.shape = mesh.create_trimesh_shape()
	staticbody.add_child(collision_shape, true)
	add_child(staticbody)
	#logmsg("duration: %d ms" % (t - Time.get_ticks_msec()))
#
	# logmsg("add static body for chunk %s faces %d" % [id, (collision_shape.shape as ConcavePolygonShape3D).get_faces().size()])

	chunks_col_list[id] = staticbody


func logmsg(msg: String):
	if Engine.is_editor_hint(): return
	Globals.log(msg)

func _enter_tree() -> void:
	update_thread = Thread.new()
	semaphore = Semaphore.new()
	mutex = Mutex.new()

func _ready():

	should_exit = false
	
	run_serverside = not Engine.is_editor_hint() and multiplayer.is_server()
	
	# Clear existing children
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	update_thread.start(update_process)
	
	
	planet = get_parent()
	axisA = Vector3(normal.y, normal.z, normal.x).normalized()
	axisB = normal.cross(axisA).normalized()
	
	update_chunks.call_deferred()
	
	planet.regenerate.connect(func():
		for chunk in chunks_list:
			chunks_list[chunk].queue_free()
			
		chunks_list.clear()
		chunks_generating.clear()
		update_chunks.call_deferred()
	)
	
func _exit_tree() -> void:
	mutex.lock()
	should_exit = true # Protect with Mutex.
	mutex.unlock()

	semaphore.post()
	update_thread.wait_to_finish()

func update_process():
	while true:
		semaphore.wait() # Wait until posted.
		
		mutex.lock()
		var must_exit = should_exit # Protect with Mutex.
		mutex.unlock()

		if must_exit:
			break

		update_chunks()
		
		mutex.lock()
		focus_positions_last = []
		for pos in focus_positions:
			focus_positions_last.push_back(floor(pos))
		mutex.unlock()
		

func positions_changed() -> bool:
	if focus_positions.size() != focus_positions_last.size():
		return true
	
	for i in focus_positions.size():
		if !focus_positions_last.has(i):
			return true
		if !focus_positions.has(i):
			return true
		
		if focus_positions[i] != focus_positions_last[i]:
			if floor(focus_positions[i]) != focus_positions_last[i]:
				return true
	
	return false

func transform_positions() -> Array:
	var transformed_positions = []
	for pos in planet.focus_positions:
		transformed_positions.push_back(global_transform.inverse() * pos)
	return transformed_positions

func _process(delta):
	mutex.lock()
	focus_positions = transform_positions()
	mutex.unlock()
	
	if focus_positions.is_empty(): return
	if positions_changed():
		semaphore.post()

func update_chunks():
	var maxlod = planet.lod_levels.size() - 1
	# Initialize the quadtree by creating the root chunk
	var bounds = AABB(Vector3(0, 0, 0), Vector3(2,2,2))
	quadtree = QuadtreeChunk.new(bounds, 0, maxlod, planet, normal, axisA, axisB)
	# Start the subdivision process
	quadtree.subdivide(focus_positions.duplicate(), run_serverside)

	chunks_list_current = {}

	# Create a visual representation
	visualize_quadtree(quadtree)

	#remove any old unused chunks
	var chunks_to_remove = []
	for chunk_id in chunks_list:
		if not chunks_list_current.has(chunk_id):
			chunks_to_remove.append(chunk_id)
	for chunk_id in chunks_to_remove:
		if chunk_id in chunks_list:
			chunks_list[chunk_id].queue_free.call_deferred()
			chunks_list.erase(chunk_id)
			chunks_generating.erase(chunk_id)
			
			disable_col.call_deferred(chunk_id)

func any_player_near(body: StaticBody3D, distance = 1000):
	for pos: Vector3 in focus_positions:
		if pos.distance_squared_to(body.global_position) < distance*distance:
			return true
	return false

func disable_col(chunk_id):
	if chunk_id in chunks_col_list:
		chunks_col_list[chunk_id].get_child(0).disabled = true
		
		#if not any_player_near(chunks_col_list[chunk_id]):
			#chunks_col_list[chunk_id].queue_free.call_deferred()
	
