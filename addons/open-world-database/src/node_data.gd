#node_data.gd
@tool
extends Node
class_name NodeData

@export var uid: String
@export var scene: String
@export var position: Vector3
@export var rotation: Vector3
@export var scale: Vector3
@export var size: float
@export var properties: Dictionary
@export var children: Array[NodeData] = []
@export var parent_uid: String = "" #if the parent does not exist, don't load this #if a node exists at this path when loading, add this node as a child of it

@export var loaded : bool = false
@export var loaded_instance : Node

func node_data_to_string(node_data: NodeData) -> String:
	if node_data == null:
		return "null"

	var result = "NodeData {\n"
	result += "  uid: \"" + str(node_data.uid) + "\"\n"
	result += "  scene: \"" + str(node_data.scene) + "\"\n"
	result += "  position: " + str(node_data.position) + "\n"
	result += "  rotation: " + str(node_data.rotation) + "\n"
	result += "  scale: " + str(node_data.scale) + "\n"
	result += "  size: " + str(node_data.size) + "\n"
	result += "  properties: " + str(node_data.properties) + "\n"
	result += "  children: [" + str(node_data.children.size()) + " items]\n"
	result += "  parent_uid: \"" + str(node_data.parent_uid) + "\"\n"
	result += "  loaded: " + str(node_data.loaded) + "\n"
	result += "  loaded_instance: " + str(node_data.loaded_instance) + "\n"
	result += "}"

	return result
