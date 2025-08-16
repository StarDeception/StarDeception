@tool
extends Node3D

class_name Planet

@export_tool_button("update") var on_update = _on_update

@export var radius: int

## list of dictionnary: [{ "distance": 100, "resolution": 3 }]
## distance is the distance to the chunk at which the lod is displayed.
## resolution is the number of faces in one axis for the chunk, ex: for a resolution of 20, there will be 20x20 faces per chunk
## at each new lod level, the number of chunk is multiplied by 4, meaning if there is 4 lod levels, there will be 4^3=64 chunks at the last lod level
var lod_levels: Array[Dictionary]



@export var min_height: float = 10000.0
@export var max_height: float
@export var noise: FastNoiseLite
@export var noise_micro: FastNoiseLite

@export var noise_maps: Array[NoiseParam]

var focus_positions = []

signal regenerate()

func _ready() -> void:
	lod_levels = [
		{ "distance": 3000, "resolution": 80 },
		{ "distance": 1500, "resolution": 80 },
		{ "distance": 800, "resolution": 60 },
		 { "distance": 500, "resolution": 60 },
		 { "distance": 300, "resolution": 60 },
		 { "distance": 100, "resolution": 60 },
	]
	print(lod_levels)
	if Engine.is_editor_hint(): return
	
	if multiplayer.is_server():
		print("Setting planet lod for server")
		lod_levels = [
			{ "distance": 3000, "resolution": 2 },
			{ "distance": 1500, "resolution": 2 },
			{ "distance": 1300, "resolution": 2 },
			{ "distance": 1200, "resolution": 2 },
			{ "distance": 1100, "resolution": 2 },
			{ "distance": 500, "resolution": 30 },
		]
	else:
		print("keep default lods for players", lod_levels)

func _process(delta: float) -> void:
	
	#$DebugFocusPos.global_position = focus_position
	
	var camera: Camera3D
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		focus_positions = [camera.global_position + -camera.global_basis.z * 1]
		return
	
	if multiplayer.is_server():
		focus_positions = []
		for player: Player in get_tree().get_nodes_in_group("player"):
			focus_positions.push_back(player.global_position)
			
		return
	
	camera = get_viewport().get_camera_3d()
	if camera:
		focus_positions = [camera.global_position + -camera.global_basis.z * 1]

func _on_update():
	print("update", lod_levels)
	regenerate.emit()

func norm(value: float):
	return value + 1 / 2.0

func get_height(point) -> Vector3:
	var elev = 0.0
	
	# plateau
	elev += clamp(norm(noise.get_noise_3dv(point * 400.0)) * 0.3, 0.3, 0.35) #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	#for noise_map in noise_maps:
		#elev += norm(noise_map.noise.get_noise_3dv(point * 100.0)) * noise_map.amplitude
	
	# some mountains
	elev += clamp(norm(noise.get_noise_3dv(point * 400.0)) * 0.27, 0.35, 0.5) #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	# micro detail elevations
	elev += norm(noise_micro.get_noise_3dv(point * 300)) * 0.01 #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	#elev -= clamp(noise.get_noise_3dv(point * 100.0) * 0.3, 0.3, 1.0)
	
	return point * radius * (elev + 1.0)
