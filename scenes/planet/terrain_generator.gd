@tool
extends Node3D
class_name QuadtreeNode

## Based on: https://github.com/stefsdev/ProcPlanetLOD

@export var planet: Planet

var focus_position_last: Vector3 = Vector3.ZERO
@export var focus_position: Vector3 = Vector3.ZERO
# Quadtree specific properties
@export var material: Material

var camera_dir: Vector3
var last_cam_dir: Vector3

@export var normal : Vector3

var axisA: Vector3
var axisB: Vector3

var chunks_list = {}
var chunks_list_current = {}


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

	func subdivide(lod_center: Vector3, camera_dir: Vector3):
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
			
			var h: Vector3 = planet.get_height(center_local_3d.normalized())
			var distance = planet.get_height(center_local_3d.normalized()).distance_to(lod_center)
			
			if depth < max_chunk_depth and distance <= planet.lod_levels[depth]["distance"]:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth, planet, face_origin, axisA, axisB)
				children.append(new_child)
				
				new_child.subdivide(lod_center, camera_dir)
			else:
				var child_bounds = AABB(Vector3(child_pos_2d.x, 0, child_pos_2d.y) - Vector3(quarter_size, quarter_size, quarter_size), half_extents)
				var new_child = QuadtreeChunk.new(child_bounds, depth + 1, max_chunk_depth, planet, face_origin, axisA, axisB)
				children.append(new_child)

func visualize_quadtree(chunk: QuadtreeChunk):
	# Generate a MeshInstance for each chunk
	if not chunk.children:

		chunks_list_current[chunk.identifier] = true
		#if chunk.identifier already exists leave it
		if chunks_list.has(chunk.identifier):
			return
		
		var size = chunk.bounds.size.x
		var offset = chunk.bounds.position
		var resolution: int = planet.lod_levels[chunk.depth - 1]["resolution"]
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
				var percent = Vector2(x, y) / float(resolution - 1)
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

		# Create and instance mesh
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material
		
		(material as ShaderMaterial).set_shader_parameter("h_min", planet.min_height)
		(material as ShaderMaterial).set_shader_parameter("h_max", planet.max_height)
		
		add_child(mi)

		#add this chunk to chunk list
		chunks_list[chunk.identifier] = mi
		
	# Recursively visualize children chunks
	for child in chunk.children:
		visualize_quadtree(child)

func _ready():
	planet = get_parent()
	axisA = Vector3(normal.y, normal.z, normal.x).normalized()
	axisB = normal.cross(axisA).normalized()
	
	# Clear existing children
	for child in get_children():
		remove_child(child)
		child.queue_free()
	update_chunks()
	
	planet.regenerate.connect(func():
		for chunk in chunks_list:
			chunks_list[chunk].queue_free()
		chunks_list.clear()
		update_chunks()
	)
	

func _process(delta):
	focus_position = EditorInterface.get_editor_viewport_3d(0).get_camera_3d().global_position
	camera_dir = EditorInterface.get_editor_viewport_3d(0).get_camera_3d().global_basis.z
	
	if focus_position != focus_position_last:
		
		if floor(focus_position) != focus_position_last:
			update_chunks()
			focus_position_last = floor(focus_position)
			


func update_chunks():
	var maxlod = planet.lod_levels.size() - 1
	# Initialize the quadtree by creating the root chunk
	var bounds = AABB(Vector3(0, 0, 0), Vector3(2,2,2))
	quadtree = QuadtreeChunk.new(bounds, 0, maxlod, planet, normal, axisA, axisB)
	# Start the subdivision process
	quadtree.subdivide(focus_position, camera_dir)

	chunks_list_current = {}

	# Create a visual representation
	visualize_quadtree(quadtree)

	#remove any old unused chunks
	var chunks_to_remove = []
	for chunk_id in chunks_list:
		if not chunks_list_current.has(chunk_id):
			chunks_to_remove.append(chunk_id)
	for chunk_id in chunks_to_remove:
		chunks_list[chunk_id].queue_free()
		chunks_list.erase(chunk_id)
