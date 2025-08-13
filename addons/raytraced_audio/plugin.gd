@tool
extends EditorPlugin


func _enter_tree() -> void:
	_setup_settings()

	# For some reason, adding custom types like this fails to generate documentation sometimes??
	# add_custom_type(
	# 	"RaytracedAudioListener",
	# 	"AudioListener3D",
	# 	load("res://addons/raytraced_audio/raytraced_audio_listener.gd"),
	# 	null
	# )
	# add_custom_type(
	# 	"RaytracedAudioPlayer3D",
	# 	"AudioStreamPlayer3D",
	# 	load("res://addons/raytraced_audio/raytraced_audio_player_3d.gd"),
	# 	null
	# )

	_setup_audio_buses()


func _exit_tree() -> void:
	# remove_custom_type("RaytracedAudioListener")
	# remove_custom_type("RaytracedAudioPlayer3D")

	_clean_up_settings()
	_clean_up_audio_buses()


func _setup_settings() -> void:
	ProjectSettings.set_setting("raytraced_audio/reverb_bus", &"RaytracedReverb")
	ProjectSettings.set_setting("raytraced_audio/ambient_bus", &"RaytracedAmbient")

	if ProjectSettings.get_setting("audio/general/3d_panning_strength") < 1.0:
		print("[INFO] RaytracedAudio: I recommend setting Audio/General/3d_panning_strength in Project Settings to 1.0 or above")


func _clean_up_settings() -> void:
	ProjectSettings.set_setting("raytraced_audio/reverb_bus", null)
	ProjectSettings.set_setting("raytraced_audio/ambient_bus", null)


func _setup_audio_buses() -> void:
	print("[INFO] Raytraced Audio: setting up audio buses")
	_clean_up_audio_buses()

	# Reverb
	var i: int = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(i, ProjectSettings.get_setting("raytraced_audio/reverb_bus", &"RaytracedReverb"))
	AudioServer.set_bus_send(i, &"Master")
	var reverb: AudioEffectReverb = AudioEffectReverb.new()
	reverb.hipass = 1.0
	reverb.resource_name = "reverb"
	AudioServer.add_bus_effect(i, reverb)

	# Ambient
	i = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(i, ProjectSettings.get_setting("raytraced_audio/ambient_bus", &"RaytracedAmbient"))
	AudioServer.set_bus_send(i, &"Master")
	var panner: AudioEffectPanner = AudioEffectPanner.new()
	panner.resource_name = "pan"
	AudioServer.add_bus_effect(i, panner)

	# There's a bug in Godot that makes it so the ambient bus doesnt show properly in the editor
	# This is "fixable" by adding a temporary bus afterwards and deleting it immediately because ofc.
	# fuck you (respectfully)
	i = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.remove_bus(i)


func _clean_up_audio_buses() -> void:
	var i: int = AudioServer.get_bus_index(ProjectSettings.get_setting("raytraced_audio/reverb_bus", &"RaytracedReverb"))
	if i != -1:
		AudioServer.remove_bus(i)
	i = AudioServer.get_bus_index(ProjectSettings.get_setting("raytraced_audio/ambient_bus", &"RaytracedAmbient"))
	if i != -1:
		AudioServer.remove_bus(i)
