@tool
extends StaticBody3D

class_name PlanetTerrain

@export_tool_button("update") var on_update = trigger_update

## Base radius of the planet
@export var radius: int

@export var min_height: float = 10000.0
@export var max_height: float

@export var terrain_settings: PlanetTerrainSettings

@export var terrain_material: Material

@onready var occluder_instance_3d: OccluderInstance3D = $OccluderInstance3D

var focus_positions = []
var players_ids = []

signal regenerate()

func _ready() -> void:
	var resolution = 100
	trigger_update()


func _process(delta: float) -> void:
	var camera: Camera3D
	if Engine.is_editor_hint():
		camera = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		players_ids = [1]
		focus_positions = [camera.global_position + -camera.global_basis.z * 1]
		return
	
	if multiplayer.is_server():
		focus_positions = []
		players_ids = []
		for player: Player in get_tree().get_nodes_in_group("player"):
			focus_positions.push_back(player.global_position)
			players_ids.push_back(player.name.to_int())
		return
	
	camera = get_viewport().get_camera_3d()
	if camera:
		players_ids = [multiplayer.get_unique_id()]
		focus_positions = [camera.global_position + -camera.global_basis.z * 1]

func trigger_update():
	var occluder = occluder_instance_3d.occluder as SphereOccluder3D
	occluder.radius = radius + 600
	
	regenerate.emit()

func norm(value: float):
	return value + 1 / 2.0

func get_height(point) -> Vector3:
	var elev = 0.0
	
	for n_param in terrain_settings.noise_params:
		if n_param.noise_type == "macro":
			elev += clamp(norm(terrain_settings.noise.get_noise_3dv(point * 400.0 * terrain_settings.noise_scale)) * n_param.amplitude, n_param.clamp_min, n_param.clamp_max)
		elif n_param.noise_type == "micro":
			elev += clamp(norm(terrain_settings.noise_micro.get_noise_3dv(point * 300 * terrain_settings.noise_scale)) * n_param.amplitude, n_param.clamp_min, n_param.clamp_max)
	
	# plateau
	#elev += clamp(norm(noise.get_noise_3dv(point * 400.0 * noise_scale)) * 300, 300, 350)
	#
	## some mountains
	#elev += clamp(norm(noise.get_noise_3dv(point * 400.0 * noise_scale)) * 270, 350, 500)
	#
	## micro detail elevations
	#elev += norm(noise_micro.get_noise_3dv(point * 300 * noise_scale)) * 10
	
	return point * (radius + (elev * terrain_settings.elev_scale))
