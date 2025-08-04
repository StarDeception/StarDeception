extends RigidBody3D

@export var inside_space: World3D

func _ready() -> void:
	$Area3D.body_entered.connect(_on_holeArea_entered)

func _on_holeArea_entered(body: Node3D):
	print("Entrée avec body = " + body.name)
	if body.name == "Player" or body.name == "box_50cm":
		match body.isInsideBox4m:
			false:
				body.set_collision_layer_value(1, false)
				body.set_collision_layer_value(2, true)
				body.set_collision_mask_value(1, false)
				body.set_collision_mask_value(2, true)
				body.isInsideBox4m = true
			true:
				body.set_collision_layer_value(2, false)
				body.set_collision_layer_value(1, true)
				body.set_collision_mask_value(2, false)
				body.set_collision_mask_value(1, true)
				body.isInsideBox4m = false
