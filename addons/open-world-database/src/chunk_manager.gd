#chunk_manager.gd
@tool
extends RefCounted
class_name ChunkManager

var owdb: OpenWorldDatabase
var loaded_chunks: Dictionary = {}
var last_camera_position: Vector3

func _init(open_world_database: OpenWorldDatabase):
	owdb = open_world_database
	reset()

func reset():
	for size in OpenWorldDatabase.Size.values():
		loaded_chunks[size] = {}

func _get_camera() -> Node3D:

	if Engine.is_editor_hint():
		var viewport = EditorInterface.get_editor_viewport_3d(0)
		if viewport:
			return viewport.get_camera_3d()

	if owdb.camera and owdb.camera is Node3D:
		return owdb.camera


	owdb.camera = _find_visible_camera3d(owdb.get_tree().root)

	return owdb.camera

func _find_visible_camera3d(node: Node) -> Camera3D:
	if node is Camera3D and node.visible:
		return node

	for child in node.get_children():
		var found = _find_visible_camera3d(child)
		if found:
			return found
	return null

func _update_camera_chunks():
	var camera = _get_camera()
	if not camera:
		return

	var current_pos = camera.global_position
	if last_camera_position.distance_to(current_pos) < owdb.chunk_sizes[OpenWorldDatabase.Size.SMALL] * 0.1:
		return

	last_camera_position = current_pos

	# Process chunks from largest to smallest for proper hierarchy loading
	var sizes = OpenWorldDatabase.Size.values()
	sizes.reverse()

	for size in sizes:
		if size >= owdb.chunk_sizes.size():
			continue

		var chunk_size = owdb.chunk_sizes[size]
		var center_chunk = Vector2i(
			int(current_pos.x / chunk_size),
			int(current_pos.z / chunk_size)
		)

		var new_chunks = {}
		for x in range(-owdb.chunk_load_range, owdb.chunk_load_range + 1):
			for z in range(-owdb.chunk_load_range, owdb.chunk_load_range + 1):
				var chunk_pos = center_chunk + Vector2i(x, z)
				new_chunks[chunk_pos] = true

		# Find chunks that are being unloaded
		var chunks_to_unload = []
		var loaded_chunks_size = loaded_chunks[size]
		for chunk_pos in loaded_chunks_size:
			if not new_chunks.has(chunk_pos):
				chunks_to_unload.append(chunk_pos)

		# Validate nodes only in chunks that are being unloaded
		_validate_nodes_in_chunks(size, chunks_to_unload)

		# Unload chunks
		for chunk_pos in chunks_to_unload:
			_unload_chunk(size, chunk_pos)

		# Load chunks
		for chunk_pos in new_chunks:
			if not loaded_chunks_size.has(chunk_pos):
				_load_chunk(size, chunk_pos)

		loaded_chunks[size] = new_chunks

func _validate_nodes_in_chunks(size_cat: OpenWorldDatabase.Size, chunks_to_check: Array):
	if chunks_to_check.is_empty():
		return

	# Only process nodes in the specified chunks
	for chunk_pos in chunks_to_check:
		if not owdb.chunk_lookup.has(size_cat) or not owdb.chunk_lookup[size_cat].has(chunk_pos):
			continue

		# Make a copy since we might modify the array
		var node_uids = owdb.chunk_lookup[size_cat][chunk_pos].duplicate()

		for uid in node_uids:
			var node = owdb.get_node_by_uid(uid)
			if not node or not node is Node3D:
				continue

			# Check if node has moved or changed size
			var node_size = NodeUtils.calculate_node_size(node)
			var current_size_cat = owdb.get_size_category(node_size)
			var current_chunk = owdb.get_chunk_position(node.global_position, current_size_cat)

			# If node has moved to a different chunk or changed size category
			if current_size_cat != size_cat or current_chunk != chunk_pos:
				# Remove from old location
				owdb.chunk_lookup[size_cat][chunk_pos].erase(uid)
				if owdb.chunk_lookup[size_cat][chunk_pos].is_empty():
					owdb.chunk_lookup[size_cat].erase(chunk_pos)

				# Add to new location
				owdb.add_to_chunk_lookup(uid, node.global_position, node_size)

				# Update stored node info
				owdb.node_monitor.update_stored_node(node)

func _is_node_in_chunk_lookup(uid: String, size_cat: OpenWorldDatabase.Size, chunk_pos: Vector2i) -> bool:
	return owdb.chunk_lookup.has(size_cat) and \
		   owdb.chunk_lookup[size_cat].has(chunk_pos) and \
		   uid in owdb.chunk_lookup[size_cat][chunk_pos]

func _load_chunk(size: OpenWorldDatabase.Size, chunk_pos: Vector2i):
	if not owdb.chunk_lookup.has(size) or not owdb.chunk_lookup[size].has(chunk_pos):
		return

	owdb.is_loading = true

	var node_infos = owdb.node_monitor.get_nodes_for_chunk(size, chunk_pos)

	# Sort by hierarchy level (parents first)
	#node_infos.sort_custom(func(a, b): return a.parent_uid.length() < b.parent_uid.length())

	for info in node_infos:
		#if not owdb.get_node_by_uid(info.uid):
		_load_node(info)
		#else:
		#	print("node already loaded")

	owdb.is_loading = false

func _load_node(node_info: Dictionary):
	var scene = ResourceLoader.load(node_info.scene, "", ResourceLoader.CACHE_MODE_REUSE) #load(node_info.scene)
	var instance = scene.instantiate()
	instance.set_meta("_owd_uid", node_info.uid)
	instance.name = node_info.uid
	# Find parent
	var parent_node = null
	if node_info.parent_uid != "":
		parent_node = owdb.get_node_by_uid(node_info.parent_uid)

	# Add to parent or owdb
	if parent_node:
		parent_node.add_child(instance)
	else:
		owdb.add_child(instance)

	instance.owner = owdb.get_tree().get_edited_scene_root()

	# Set properties
	instance.global_position = node_info.position
	instance.global_rotation = node_info.rotation
	instance.scale = node_info.scale

	for prop_name in node_info.properties:
		if prop_name not in ["position", "rotation", "scale", "size"]:
			instance.set(prop_name, node_info.properties[prop_name])

	"""
	# Check for orphaned children and reparent them
	for child in owdb.get_children():
		if child.has_meta("_owd_uid") and child != instance:
			var child_parent_uid = owdb.node_monitor.stored_nodes.get(
				child.get_meta("_owd_uid"), {}
			).get("parent_uid", "")
			if child_parent_uid == node_info.uid:
				child.reparent(instance)
	"""

func _unload_chunk(size: OpenWorldDatabase.Size, chunk_pos: Vector2i):
	if not owdb.chunk_lookup.has(size) or not owdb.chunk_lookup[size].has(chunk_pos):
		return

	owdb.is_loading = true

	# Make a copy since we'll be modifying the array
	var uids_to_unload = owdb.chunk_lookup[size][chunk_pos].duplicate()

	for uid in uids_to_unload:
		var node = owdb.get_node_by_uid(uid)
		if node:
			# Update stored data before unloading
			owdb.node_monitor.update_stored_node(node)
			node.free()

	owdb.is_loading = false
