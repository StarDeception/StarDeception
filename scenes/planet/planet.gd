@tool
extends Node3D

class_name Planet

@export_tool_button("update") var on_update = _on_update

@export var radius: int
@export var lod_levels: Array[Dictionary] = [
	{ "distance": 2000, "resolution": 5 },
	{ "distance": 1000, "resolution": 10 },
	{ "distance": 500, "resolution": 20 },
]
@export var min_height: float = 10000.0
@export var max_height: float
@export var noise: FastNoiseLite
@export var noise_micro: FastNoiseLite

class NoiseGenerator extends Resource:
	@export var amplitude: float
	@export var noise: FastNoiseLite
	func init():
		pass

@export var noise_maps: Array[NoiseParam]

signal regenerate()

func _on_update():
	print("update")
	regenerate.emit()

func norm(value: float):
	return value + 1 / 2.0

func get_height(point) -> Vector3:
	var elev = 0.0
	elev += norm(noise.get_noise_3dv(point * 400.0)) * 0.3 #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	
	#for noise_map in noise_maps:
		#elev += norm(noise_map.noise.get_noise_3dv(point * 100.0)) * noise_map.amplitude
	elev = max(0.3, elev)
	elev = min(0.35, elev)
	
	elev += clamp(norm(noise.get_noise_3dv(point * 400.0)) * 0.27, 0.35, 0.5) #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	elev += norm(noise_micro.get_noise_3dv(point * 500)) * 0.01 #* (1.0 + norm(noise_micro.get_noise_3dv(point * 100.0)) * 0.05)
	
	#elev -= clamp(noise.get_noise_3dv(point * 100.0) * 0.3, 0.3, 1.0)
	
	return point * radius * (elev + 1.0)
