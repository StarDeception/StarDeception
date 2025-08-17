@tool
extends Node3D

class_name Planet

@export_tool_button("update") var on_update = _on_update

@export var radius: int

## List of dictionnary: [{ "distance": 100, "resolution": 3 }].
## Distance is the distance to the chunk at which the lod is displayed.
## Resolution is the number of faces in one axis for the chunk, ex: for a resolution of 20, there will be 20x20 faces per chunk.
## At each new lod level, the number of chunk is multiplied by 4, meaning if there is 4 lod levels, there will be 4^3=64 chunks at the last lod level
var lod_levels: Array[Dictionary]


@export var elev_scale: float = 100.0
@export var min_height: float = 10000.0
@export var max_height: float
@export var noise_scale: float = 1.0
@export var noise: FastNoiseLite
@export var noise_micro: FastNoiseLite

@export var noise_maps: Array[NoiseParam]

var focus_positions = []

signal regenerate()

func _ready() -> void:
	var resolution = 100
	lod_levels = [
		{ "distance": 500000, "resolution": resolution },
		{ "distance": 300000, "resolution": resolution },
		{ "distance": 100000, "resolution": resolution },
		 { "distance": 50000, "resolution": resolution },
		 { "distance": 10000, "resolution": resolution },
		 { "distance": 8000, "resolution": resolution },
		 { "distance": 5000, "resolution": resolution },
		 { "distance": 3000, "resolution": resolution },
		 { "distance": 2000, "resolution": resolution },
		 { "distance": 1000, "resolution": resolution },
		
		# { "distance": 3.0, "resolution": 0.01 },
		# { "distance": 2.0, "resolution": 0.01 },
		# { "distance": 1.0, "resolution": 0.01 },
		#  { "distance": 0.2, "resolution": 0.01 },
		#  { "distance": 0.1, "resolution": 0.01 },
		#  { "distance": 0.05, "resolution": 0.01 },
	]
	
	print(lod_levels)
	if Engine.is_editor_hint(): return
	
	if multiplayer.is_server():
		print("Setting planet lod for server")
		lod_levels = [
			{ "distance": 500000, "resolution": 2 },
			{ "distance": 300000, "resolution": 2 },
			{ "distance": 100000, "resolution": 2 },
			{ "distance": 50000, "resolution": 2 },
			{ "distance": 20000, "resolution": 2 },
			{ "distance": 10000, "resolution": 2 },
			{ "distance": 5000, "resolution": 2 },
			{ "distance": 3000, "resolution": 2 },
			{ "distance": 2000, "resolution": 2 },
		 	{ "distance": 1000, "resolution": floor(resolution * 0.4) },
		]
	else:
		print("keep default lods for players", lod_levels)

func get_adapted_lod(depth: int) -> Dictionary:
	var lod = lod_levels[depth]
	return lod
	# return { "distance": lod["distance"] * radius, "resolution": floor(lod["resolution"] * radius) }

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
	elev += clamp(norm(noise.get_noise_3dv(point * 400.0 * noise_scale)) * 0.3, 0.3, 0.35) #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	#for noise_map in noise_maps:
		#elev += norm(noise_map.noise.get_noise_3dv(point * 100.0)) * noise_map.amplitude
	
	# some mountains
	elev += clamp(norm(noise.get_noise_3dv(point * 400.0 * noise_scale)) * 0.27, 0.35, 0.5) #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	# micro detail elevations
	elev += norm(noise_micro.get_noise_3dv(point * 300 * noise_scale)) * 0.01 #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	#elev -= clamp(noise.get_noise_3dv(point * 100.0) * 0.3, 0.3, 1.0)
	
	return point * (radius + (elev * elev_scale))
