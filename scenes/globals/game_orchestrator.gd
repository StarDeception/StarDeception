extends Node

@export var levels: Array[PackedScene]

#var home_menu_scene: PackedScene = preload("res://ui/login_page/login_page.tscn")
#var enter_universe_scene: PackedScene = preload("res://ui/main_page/main_page.tscn")

enum CHANGE_STATE_RETURNS {OK, ERROR, NO_CHANGE}

enum GAME_MODES {PLAYABLE, SERVER}
enum GAME_STATES {HOME_MENU, UNIVERSE_MENU, GAME_MENU, PAUSE_MENU, PLAYING, JUST_SERVER}
enum PLAYING_LEVELS{SYSTEM_SANDBOX}

var current_mode = null
var current_stat = null
var distinguish_instances: Dictionary = {
		GAME_MODES.SERVER: {"instance_name": "Serveur", "instance_color": "aquamarine"},
		GAME_MODES.PLAYABLE: {"instance_name": "Joueur", "instance_color": "salmon"},
	}

var _game_server: Node = null

@onready var game_is_paused: bool = false

func _ready():
	print_rich("[color=gold]Le Game Orchestrator est près[/color]")
	if levels.is_empty():
		print_rich("[color=red]Aucun level n'est présent[/color]")
	else:
		print_rich("[color=green]Il y a %s levels de présents[/color]" % str(levels.size()))
	if OS.has_feature("dedicated_server"):
		change_game_mode(GAME_MODES.SERVER)
		change_game_state(GAME_STATES.JUST_SERVER)
	else:
		change_game_mode(GAME_MODES.PLAYABLE)
		change_game_state(GAME_STATES.HOME_MENU)

func change_game_mode(new_mode) -> int:
	match new_mode:
		GAME_MODES.PLAYABLE:
			print_rich("[color=" + distinguish_instances[GAME_MODES.PLAYABLE]["instance_color"] + "][" + distinguish_instances[GAME_MODES.PLAYABLE]["instance_name"] + "][/color][color=Darkorange] -> Changement de Mode pour PLAYABLE[/color]")
			current_mode = new_mode
			return CHANGE_STATE_RETURNS.OK
		GAME_MODES.SERVER:
			print_rich("[color=" + distinguish_instances[GAME_MODES.SERVER]["instance_color"] + "][" + distinguish_instances[GAME_MODES.SERVER]["instance_name"] + "][/color][color=Darkorange] -> Changement de Mode pour SERVER[/color]")
			current_mode = new_mode
			return CHANGE_STATE_RETURNS.OK
		_:
			return CHANGE_STATE_RETURNS.ERROR

func change_game_state(new_state) -> int:
	if new_state == current_stat:
		return CHANGE_STATE_RETURNS.NO_CHANGE
	
	match new_state:
		GAME_STATES.HOME_MENU:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour HOME_MENU[/color]", [])
			current_stat = new_state
			_game_server = load("res://server/server.tscn").instantiate()
			get_tree().get_root().call_deferred("add_child",_game_server)
			get_tree().call_deferred("change_scene_to_file","res://ui/login_page/login_page.tscn")
			return CHANGE_STATE_RETURNS.OK
		GAME_STATES.JUST_SERVER:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour JUST_SERVER[/color]", [])
			current_stat = new_state
			_game_server = load("res://server/server.tscn").instantiate()
			get_tree().get_root().call_deferred("add_child",_game_server)
			return CHANGE_STATE_RETURNS.OK
		GAME_STATES.UNIVERSE_MENU:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour UNIVERSE_MENU[/color]", [])
			current_stat = new_state
			get_tree().call_deferred("change_scene_to_file","res://ui/main_page/main_page.tscn")
			return CHANGE_STATE_RETURNS.OK
		GAME_STATES.PLAYING:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour PLAYING[/color]", [])
			match  current_stat:
				GAME_STATES.PAUSE_MENU:
					Globals.print_rich_distinguished("\t[color=Darkorange] -> Depuis l'état PAUSE_MENU[/color]", [])
					current_stat = new_state
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					return CHANGE_STATE_RETURNS.OK
				_:
					current_stat = new_state
					get_tree().call_deferred("change_scene_to_file",levels[0].resource_path)
					return CHANGE_STATE_RETURNS.OK
		GAME_STATES.PAUSE_MENU:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour PAUSE_MENU[/color]", [])
			match  current_stat:
				GAME_STATES.PLAYING:
					Globals.print_rich_distinguished("\t[color=Darkorange] -> Depuis l'état PLAYING[/color]", [])
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
					current_stat = new_state
					return CHANGE_STATE_RETURNS.OK
				_:
					return CHANGE_STATE_RETURNS.NO_CHANGE
		_:
			return CHANGE_STATE_RETURNS.ERROR
