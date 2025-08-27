#database.gd
@tool
extends RefCounted
class_name Database

var owdb: OpenWorldDatabase

func _init(open_world_database: OpenWorldDatabase):
	owdb = open_world_database

func get_database_path() -> String:
	var scene_path: String = ""

	# Check if we're in the editor
	if Engine.is_editor_hint():
		var edited_scene = EditorInterface.get_edited_scene_root()
		if edited_scene:
			scene_path = edited_scene.scene_file_path
	else:
		# We're in-game, get the current scene
		var current_scene = owdb.get_tree().current_scene
		if current_scene:
			scene_path = current_scene.scene_file_path

	if scene_path == "":
		return ""

	return scene_path.get_basename() + ".owdb"


func save_database():
	var db_path = get_database_path()
	if db_path == "":
		print("Error: Scene must be saved before saving database")
		return

	# First, update all loaded nodes
	var all_nodes = owdb.get_all_owd_nodes()
	for node in all_nodes:
		owdb.node_monitor.update_stored_node(node)

	# Now save everything from stored_nodes
	var file = FileAccess.open(db_path, FileAccess.WRITE)
	if not file:
		print("Error: Could not create database file")
		return

	# Get top-level nodes
	var top_level_uids = []
	for uid in owdb.node_monitor.stored_nodes:
		var info = owdb.node_monitor.stored_nodes[uid]
		if info.parent_uid == "":
			top_level_uids.append(uid)

	top_level_uids.sort()

	for uid in top_level_uids:
		_write_node_recursive(file, uid, 0)

	file.close()
	if owdb.debug_enabled:
		print("Database saved successfully!")

func _write_node_recursive(file: FileAccess, uid: String, depth: int):
	var info = owdb.node_monitor.stored_nodes.get(uid, {})
	if info.is_empty():
		return

	var indent = "\t".repeat(depth)
	var props_str = "{}"
	if info.properties.size() > 0:
		props_str = JSON.stringify(info.properties)

	var line = "%s%s|\"%s\"|%s,%s,%s|%s,%s,%s|%s,%s,%s|%s|%s" % [
		indent, uid, info.scene,
		info.position.x, info.position.y, info.position.z,
		info.rotation.x, info.rotation.y, info.rotation.z,
		info.scale.x, info.scale.y, info.scale.z,
		info.size, props_str
	]

	file.store_line(line)

	# Write children
	var child_uids = []
	for child_uid in owdb.node_monitor.stored_nodes:
		var child_info = owdb.node_monitor.stored_nodes[child_uid]
		if child_info.parent_uid == uid:
			child_uids.append(child_uid)

	child_uids.sort()
	for child_uid in child_uids:
		_write_node_recursive(file, child_uid, depth + 1)

func load_database():
	var db_path = get_database_path()
	if db_path == "" or not FileAccess.file_exists(db_path):
		return

	var file = FileAccess.open(db_path, FileAccess.READ)
	if not file:
		return

	owdb.node_monitor.stored_nodes.clear()
	owdb.chunk_lookup.clear()

	var node_stack = []
	var depth_stack = []

	while not file.eof_reached():
		var line = file.get_line()
		if line == "":
			continue

		var depth = 0
		while depth < line.length() and line[depth] == "\t":
			depth += 1

		var clean_line = line.strip_edges()
		var info = _parse_line(clean_line)
		if not info:
			continue

		# Handle parent relationships
		while depth_stack.size() > 0 and depth <= depth_stack[-1]:
			node_stack.pop_back()
			depth_stack.pop_back()

		if node_stack.size() > 0:
			info.parent_uid = node_stack[-1]

		node_stack.append(info.uid)
		depth_stack.append(depth)

		# Store node info
		owdb.node_monitor.stored_nodes[info.uid] = info

		# Add to chunk lookup
		owdb.add_to_chunk_lookup(info.uid, info.position, info.size)

	file.close()
	print("Database loaded successfully!")

func _parse_line(line: String) -> Dictionary:
	var parts = line.split("|")
	if parts.size() < 6:
		return {}

	var info = {
		"uid": parts[0],
		"scene": parts[1].strip_edges().trim_prefix("\"").trim_suffix("\""),
		"parent_uid": "",
		"properties": {}
	}

	# Parse position
	var pos_parts = parts[2].split(",")
	info.position = Vector3(
		pos_parts[0].to_float(),
		pos_parts[1].to_float(),
		pos_parts[2].to_float()
	)

	# Parse rotation
	var rot_parts = parts[3].split(",")
	info.rotation = Vector3(
		rot_parts[0].to_float(),
		rot_parts[1].to_float(),
		rot_parts[2].to_float()
	)

	# Parse scale
	var scale_parts = parts[4].split(",")
	info.scale = Vector3(
		scale_parts[0].to_float(),
		scale_parts[1].to_float(),
		scale_parts[2].to_float()
	)

	info.size = parts[5].to_float()

	# Parse properties
	if parts.size() > 6 and parts[6] != "{}":
		var json = JSON.new()
		if json.parse(parts[6]) == OK:
			info.properties = json.data

	return info
