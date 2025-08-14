extends SceneTree

signal scene_changed(new_scene: Node)

const MAX_WAITING_FRAME_COUNT: int = 5

func change_scene_to_packed(packed_scene: PackedScene) -> int:
	var err: int = super.change_scene_to_packed(packed_scene)
	if err == OK:
		Globals.print_rich_distinguished("[color=green]Dans le custom change_scene_to_packed, ERR = %s[/color]", [str(err)])
		var max_frames: int = MAX_WAITING_FRAME_COUNT
		while not self.current_scene and max_frames > 0:
			await self.process_frame
			max_frames -= 1
		
		var new_current_scene: Node = self.current_scene
		if new_current_scene:
			Globals.print_rich_distinguished("[color=green]Il y a une nouvelle current_scene : %s[/color]", [str(new_current_scene.scene_file_path)])
			if new_current_scene.get("is_ready"):
				Globals.print_rich_distinguished("[color=green]La nouvelle current_scene possède une variable is_ready[/color]", [])
				if not new_current_scene.is_ready:
					Globals.print_rich_distinguished("[color=red]La nouvelle current_scene n'est pas encore ready[/color]", [])
					await new_current_scene.ready
					Globals.print_rich_distinguished("[color=green]La nouvelle current_scene devient ready[/color]", [])
					emit_signal("scene_changed", new_current_scene)
				else:
					Globals.print_rich_distinguished("[color=green]La nouvelle current_scene est déjà ready[/color]", [])
					emit_signal("scene_changed", new_current_scene)
			else:
				Globals.print_rich_distinguished("[color=red]La nouvelle current_scene ne possède pas de variable is_ready[/color]", [])
		
	else:
		Globals.print_rich_distinguished("[color=red]Dans le custom change_scene_to_file, ERR = %s[/color]", [str(err)])
	
	return err

func change_scene_to_file(scene_file: String) -> int:
	var err: int = super.change_scene_to_file(scene_file)
	if err == OK:
		Globals.print_rich_distinguished("[color=green]Dans le custom change_scene_to_file, ERR = %s[/color]", [str(err)])
		var max_frames: int = MAX_WAITING_FRAME_COUNT
		while not self.current_scene and max_frames > 0:
			await self.process_frame
			max_frames -= 1
		
		var new_current_scene: Node = self.current_scene
		if new_current_scene:
			Globals.print_rich_distinguished("[color=green]Il y a une nouvelle current_scene : %s[/color]", [str(new_current_scene.scene_file_path)])
			if new_current_scene.get("is_ready"):
				Globals.print_rich_distinguished("[color=green]La nouvelle current_scene possède une variable is_ready[/color]", [])
				if not new_current_scene.is_ready:
					Globals.print_rich_distinguished("[color=red]La nouvelle current_scene n'est pas encore ready[/color]", [])
					await new_current_scene.ready
					Globals.print_rich_distinguished("[color=green]La nouvelle current_scene devient ready[/color]", [])
					emit_signal("scene_changed", new_current_scene)
				else:
					Globals.print_rich_distinguished("[color=green]La nouvelle current_scene est déjà ready[/color]", [])
					emit_signal("scene_changed", new_current_scene)
			else:
				Globals.print_rich_distinguished("[color=red]La nouvelle current_scene ne possède pas de variable is_ready[/color]", [])
		
	else:
		Globals.print_rich_distinguished("[color=red]Dans le custom change_scene_to_file, ERR = %s[/color]", [str(err)])
	
	return err
