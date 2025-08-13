extends MeshInstance3D

@onready var m = material_override as StandardMaterial3D

func _process(delta: float) -> void:
	if $RaytracedAudioPlayer3D.playing:
		m.albedo_color = Color.RED
	else:
		m.albedo_color = Color.WHITE
