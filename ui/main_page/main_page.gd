extends CanvasLayer

var is_ready: bool = false

func _ready() -> void:
	is_ready = true
	Globals.print_rich_distinguished("[color=gold]Chargement de la main page[/color]", [])

func _on_button_pressed() -> void:
	#get_tree().change_scene_to_file(Globals.init_scene)
	GameOrchestrator.change_game_state(GameOrchestrator.GAME_STATES.PLAYING)
