extends Node

@export var levels: Array[PackedScene]

#var home_menu_scene: PackedScene = preload("res://ui/login_page/login_page.tscn")
#var enter_universe_scene: PackedScene = preload("res://ui/main_page/main_page.tscn")

enum CHANGE_STATE_RETURNS {OK, ERROR, NO_CHANGE}

enum GAME_MODES {PLAYABLE, SERVER}
enum GAME_STATES {HOME_MENU, UNIVERSE_MENU, GAME_MENU, PAUSE_MENU, PLAYING, JUST_SERVER}
enum PLAYING_LEVELS{SYSTEM_SANDBOX}

const SCENE_TREE_EXTENDED_SCRIPT_PATH = preload("res://scenes/globals/scene_tree_extended.gd")

const GAME_STATES_SCENES_PATHS: Dictionary = {
	GAME_STATES.HOME_MENU : "res://ui/login_page/login_page.tscn",
	GAME_STATES.UNIVERSE_MENU : "res://ui/main_page/main_page.tscn",
	GAME_STATES.GAME_MENU : "",
	GAME_STATES.PAUSE_MENU : "",
	GAME_STATES.PLAYING : "res://levels/system-sandbox/system_sandbox.tscn",
	GAME_STATES.JUST_SERVER : "res://server/server.tscn",
}

var current_mode = null
var current_stat = null
var distinguish_instances: Dictionary = {
		GAME_MODES.SERVER: {"instance_name": "Serveur", "instance_color": "aquamarine"},
		GAME_MODES.PLAYABLE: {"instance_name": "Joueur", "instance_color": "salmon"},
	}

var game_server: Node = null

@onready var game_is_paused: bool = false

func _enter_tree() -> void:
	get_tree().set_script(SCENE_TREE_EXTENDED_SCRIPT_PATH)

func _ready():
	print_rich("[color=gold]Le Game Orchestrator est près[/color]")
	get_tree().connect("scene_changed",_on_scene_changed)
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
			game_server = load("res://server/server.tscn").instantiate()
			get_tree().get_root().call_deferred("add_child",game_server)
			get_tree().call_deferred("change_scene_to_file",GAME_STATES_SCENES_PATHS[GAME_STATES.HOME_MENU])
			return CHANGE_STATE_RETURNS.OK
		GAME_STATES.JUST_SERVER:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour JUST_SERVER[/color]", [])
			current_stat = new_state
			game_server = load(GAME_STATES_SCENES_PATHS[GAME_STATES.JUST_SERVER]).instantiate()
			get_tree().get_root().call_deferred("add_child",game_server)
			return CHANGE_STATE_RETURNS.OK
		GAME_STATES.UNIVERSE_MENU:
			Globals.print_rich_distinguished("[color=Darkorange] -> Changement de State pour UNIVERSE_MENU[/color]", [])
			current_stat = new_state
			get_tree().call_deferred("change_scene_to_file",GAME_STATES_SCENES_PATHS[GAME_STATES.UNIVERSE_MENU])
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
					get_tree().call_deferred("change_scene_to_file",GAME_STATES_SCENES_PATHS[GAME_STATES.PLAYING])
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

func _on_scene_changed(changed_scene: Node) -> void:
	Globals.print_rich_distinguished("[color=Darkorange]J'ai reçu le signal _on_scene_changed avec changed_scene = %s[/color]", [str(changed_scene)])
	var scene_path: String = changed_scene.scene_file_path
	
	match scene_path:
		GAME_STATES_SCENES_PATHS[GAME_STATES.PLAYING]:
			Globals.print_rich_distinguished("[color=Darkorange]Il s'agit de la scene de jeu !![/color]", [])
		_:
			print_rich("[color=Palegreen]Il s'agit d'une autre scene[/color]")
