@tool
extends Node3D

class_name Planet

@export_tool_button("update") var on_update = update_planet

@onready var planet_gravity: PhysicsGrid = $PlanetGravity
@onready var planet_terrain: PlanetTerrain = $PlanetTerrain
@onready var atmosphere: ExtremelyFastAtmpsphere = $Atmosphere
@onready var water_surface: MeshInstance3D = $WaterSurface

@export var planet_settings: PlanetSettings

@export var sun: DirectionalLight3D


var synced = true

func _ready() -> void:
	synced = multiplayer.is_server()
	
	Server.client_connected.connect(func():
		if not multiplayer.is_server():
			sync_rotation.rpc_id(1)
	)
	$Atmosphere.sun_object = sun
	update_planet()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	planet_terrain.rotation.y += 0.001 * delta

func update_planet():
	planet_gravity.gravity_point_unit_distance = planet_settings.radius
	var shape = planet_gravity.get_node("CollisionShape3D").shape as SphereShape3D
	shape.radius = planet_settings.radius + planet_settings.atmosphere_height
	
	planet_terrain.radius = planet_settings.radius
	planet_terrain.terrain_material = planet_settings.terrain_material
	
	
	atmosphere.atmosphere_height = planet_settings.atmosphere_height
	atmosphere.planet_radius = planet_settings.radius + 600
	
	if planet_settings.has_ocean:
		var watermesh = water_surface.mesh as SphereMesh
		watermesh.radius = planet_settings.radius + planet_settings.sea_level
		watermesh.height = (planet_settings.radius + planet_settings.sea_level) * 2
		water_surface.show()
	else:
		water_surface.hide()
		
	planet_terrain.trigger_update()

@rpc("any_peer", "call_remote", "reliable")
func sync_rotation():
	var id = multiplayer.get_remote_sender_id()
	set_planet_rotation.rpc_id(id, planet_terrain.rotation)

@rpc("authority", "call_remote", "reliable")
func set_planet_rotation(rot: Vector3):
	print("set planet rotation", rot)
	planet_terrain.rotation = rot
	synced = true
