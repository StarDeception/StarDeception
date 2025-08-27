#open_world_database.gd
@tool
extends Node
class_name OpenWorldDatabase

enum Size { SMALL, MEDIUM, LARGE, HUGE }

@export_tool_button("Save World Database", "save") var save_action = save_database

@export var size_thresholds: Array[float] = [0.5, 2.0, 8.0]
@export var chunk_sizes: Array[float] = [8.0, 16.0, 64.0]
@export var chunk_load_range: int = 3
@export var debug_enabled: bool = false
@export var camera: Node

"""
@export_tool_button("Load Database", "load") var load_action = load_database
@export_tool_button("Reset", "save") var reset_action = reset
#@export_tool_button("TEST", "save") var test_action = test
"""
var chunk_lookup: Dictionary = {} # [Size][Vector2i] -> Array[String] (UIDs)
var database: Database
var chunk_manager: ChunkManager
var node_monitor: NodeMonitor
var is_loading: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		get_tree().auto_accept_quit = false

	reset()
	is_loading = true
	database.load_database()
	chunk_manager._update_camera_chunks()
	is_loading = false

func reset():
	is_loading = true
	NodeUtils.remove_children(self)
	chunk_manager = ChunkManager.new(self)
	node_monitor = NodeMonitor.new(self)
	database = Database.new(self)
	setup_listeners(self)
	is_loading = false

func setup_listeners(node: Node):
	if not node.child_entered_tree.is_connected(_on_child_entered_tree):
		node.child_entered_tree.connect(_on_child_entered_tree)

	if not node.child_exiting_tree.is_connected(_on_child_exiting_tree):
		node.child_exiting_tree.connect(_on_child_exiting_tree)


func _on_child_entered_tree(node: Node):
	call_deferred("setup_listeners", node)

	if is_loading or node.scene_file_path == "" or !self.is_ancestor_of(node):
		return

	# Only set UID if node doesn't have one
	if not node.has_meta("_owd_uid"):
		var uid = node.name + '-' + NodeUtils.generate_uid()
		node.set_meta("_owd_uid", uid)
		node.name = uid

	var uid = node.get_meta("_owd_uid")

	# Check if another node exists anywhere under self with this UID as its name
	var existing_node = find_node_with_uid(uid, node)
	if existing_node != null:
		# Generate a new UID for this node
		var new_uid = node.name.split('-')[0] + '-' + NodeUtils.generate_uid()
		node.set_meta("_owd_uid", new_uid)
		node.name = new_uid


	if node is Node3D:
		# Update node monitor
		node_monitor.update_stored_node(node)

		# Add to chunk lookup
		var node_size = NodeUtils.calculate_node_size(node)
		add_to_chunk_lookup(uid, node.global_position, node_size)

# Helper function to find if a node with the given UID exists (excluding the current node)
func find_node_with_uid(uid: String, exclude_node: Node) -> Node:
	return _search_for_uid_recursive(self, uid, exclude_node)

func _search_for_uid_recursive(parent: Node, uid: String, exclude_node: Node) -> Node:
	for child in parent.get_children():
		if child != exclude_node and child.name == uid:
			return child

		var found = _search_for_uid_recursive(child, uid, exclude_node)
		if found != null:
			return found

	return null

func _on_child_exiting_tree(node: Node):
	if is_loading or node.scene_file_path == "":
		return

	# Just mark for later processing
	if node.has_meta("_owd_uid"):
		call_deferred("_check_node_removal", node)

func _check_node_removal(node):
	# If node is still valid and in tree, it was reparented
	if is_instance_valid(node) and node.is_inside_tree():
		return

func get_all_owd_nodes(parent: Node = self) -> Array[Node]:
	var nodes: Array[Node] = []
	for child in parent.get_children():
		if child.has_meta("_owd_uid"):
		#if parent.is_editable_instance(child):
			nodes.append(child)
		nodes.append_array(get_all_owd_nodes(child))
	return nodes

func get_node_by_uid(uid: String) -> Node:
	var found = get_node(uid)
	if found:
		return found
	else:
		return find_child("*" + uid, true, false)

func add_to_chunk_lookup(uid: String, position: Vector3, size: float):
	var size_cat = get_size_category(size)
	var chunk_pos = get_chunk_position(position, size_cat)

	if not chunk_lookup.has(size_cat):
		chunk_lookup[size_cat] = {}
	if not chunk_lookup[size_cat].has(chunk_pos):
		chunk_lookup[size_cat][chunk_pos] = []

	if uid not in chunk_lookup[size_cat][chunk_pos]:
		chunk_lookup[size_cat][chunk_pos].append(uid)

func remove_from_chunk_lookup(uid: String, position: Vector3, size: float):
	var size_cat = get_size_category(size)
	var chunk_pos = get_chunk_position(position, size_cat)

	if chunk_lookup.has(size_cat) and chunk_lookup[size_cat].has(chunk_pos):
		chunk_lookup[size_cat][chunk_pos].erase(uid)
		if chunk_lookup[size_cat][chunk_pos].is_empty():
			chunk_lookup[size_cat].erase(chunk_pos)

func get_size_category(node_size: float) -> Size:
	for i in range(size_thresholds.size()):
		if node_size <= size_thresholds[i]:
			return i
	return Size.HUGE

func get_chunk_position(position: Vector3, size_category: Size) -> Vector2i:
	var chunk_size = 9999999999999
	if size_category < 3:
		chunk_size = chunk_sizes[size_category]
	return Vector2i(int(position.x / chunk_size), int(position.z / chunk_size))

func _process(_delta: float) -> void:
	if chunk_manager and not is_loading:
		chunk_manager._update_camera_chunks()

func save_database():
	database.save_database()

func load_database():
	reset()
	is_loading = true
	database.load_database()
	is_loading = false

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		#if what == NOTIFICATION_WM_CLOSE_REQUEST:
		#	save_database()
		#	get_tree().quit()
		if what == NOTIFICATION_EDITOR_PRE_SAVE:
			save_database()
