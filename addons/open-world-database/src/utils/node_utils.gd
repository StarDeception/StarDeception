#utils/node_utils.gd
@tool
extends RefCounted
class_name NodeUtils

static func remove_children(node:Node):
	var children = node.get_children()
	for child in children:
		child.free()


static func generate_uid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return str(Time.get_unix_time_from_system()).replace(".", "")+ "_" + str(rng.randi_range(1000,9999))

static func get_node_aabb(node: Node, exclude_top_level_transform: bool = true) -> AABB:
	var bounds: AABB = AABB()

	if node is VisualInstance3D:
		bounds = node.get_aabb()

	for child in node.get_children():
		var child_bounds: AABB = get_node_aabb(child, false)
		if bounds.size == Vector3.ZERO:
			bounds = child_bounds
		else:
			bounds = bounds.merge(child_bounds)

	if not exclude_top_level_transform:
		bounds = node.transform * bounds

	return bounds

static func calculate_node_size(node: Node3D) -> float:
	# Check if we have cached values
	if node.has_meta("_owd_last_scale"):
		# If scale hasn't changed, return cached size
		var meta = node.get_meta("_owd_last_scale")
		if node.scale == meta:
			return node.get_meta("_owd_last_size")

	# Calculate new size
	var aabb = get_node_aabb(node, false)
	var size = aabb.size
	var max_size = max(size.x, max(size.y, size.z))

	# Cache the scale and size
	node.set_meta("_owd_last_scale", node.scale)
	node.set_meta("_owd_last_size", max_size)

	return max_size


static func is_top_level_node(node: Node) -> bool:
	var parent_node = node.get_parent()
	return not (parent_node and parent_node.has_meta("_owd_uid"))
