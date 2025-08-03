@tool
extends Node3D
class_name  PersitData

var parent: PhysicsBody3D
var data: DataObject

func _enter_tree():
	_check_parent()

func _ready():
	_check_parent()
	data = DataObject.new()
	data.position = parent.position
	data.name="letestgd"
	data.uid="_:tempid10"
	var persistance_class = preload("res://persistance_manager/PersistanceManager.cs")
	var persistance_instance = persistance_class.new()
	persistance_instance._Ready()
	#cs_instance.SaveObj(data.serialize())
	#data.uid=persistance_instance.SaveObj(data.serialize())
	print(data.uid)
	
func _check_parent():
	parent = get_parent()
	if parent and not (parent is PhysicsBody3D):
		push_error("PersitData is not children of  PhysicsBody3D.")
