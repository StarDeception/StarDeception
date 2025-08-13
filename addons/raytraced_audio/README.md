# raytraced-audio
Adds procedural audio effects to Godot like echo, ambient outdoor sounds, and muffle.

Check out [this amazing video](https://youtu.be/u6EuAUjq92k?si=6W-sGozYBQITEgQo) by **Vercidium** for insights on how this works!

No need to create and maintain zones while creating levels, just put the `RaytracedAudioListener` node in your scene and most features will be available for you to use!

Additionally, by using `RaytracedAudioPlayer3D`s instead of regular `AudioPlayer3D`s, sounds will get automatically muffled behind walls.

### Audio buses
Right off the bat, this plugin creates 2 new audio buses for you to use across your project:
a *"Reverb"* bus, and an *"Ambient"* bus.
Note: both buses' names can be changed under `Project Settings > Raytraced Audio`.

The reverb bus controls echo / reverb.
For example, there will be a much bigger reverb in large enclosed rooms compared to small ones, or outside in the open.

The ambient bus controls the strength and pan of sounds coming from outside.
For example, in a room with a single opening leading outisde, sounds in this bus will appear to come from that opening, and will fade based on the player's distance to it.

### Performace

Because the rays need to gather different informations about the environment, the actual number of processed rays can go up to:

`rays_count * (2 + n)` where `n` is the number of enabled `RaytracedAudioPlayer3D`s in the scene.

That is:

`(rays_count: configurable) * (1 ray that bounces around + 1 echo ray + (1 muffle ray per enabled RaytracedAudioPlayer3D))`

Raytraced Audio also adds 2 performance monitors:
 - `raytraced_audio/raycast_updates`: How many raycast updates happened in the update tick
 - `raytraced_audio/enabled_players_count`: How many `RaytracedAudioPlayer3D`s are currently enabled in the scene


### Installation

#### Manual installation

- Download or clone this repository
- Copy the `addons/raytraced_audio` folder into your project's `addons/` folder
- Enable the plugin in `Project Settings > Plugins > Raytraced Audio`

