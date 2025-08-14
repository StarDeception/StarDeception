extends Node
class_name TranslatorItem

@export var label = ""

func _ready():
	SetLabel()
	Translate()

func SetLabel():
	if label == "":
		if get_parent() is LineEdit:
			label = get_parent().placeholder_text
		else:
			label = get_parent().text
		print("set label " + label + " to node " + get_parent().name)

func Translate():
	if get_parent() is LineEdit:
		get_parent().placeholder_text = Translator.Get(label)
	else:
		get_parent().text = Translator.Get(label)
