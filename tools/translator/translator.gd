extends Node
class_name Translator

static var LANGUAGE = ""
static var init = false

static var words: Dictionary

func get_all_text_nodes(root: Node) -> Array:
	var found := []
	
	for child in root.get_children():
		# Vérifie si l'objet est bien un Node (par sécurité)
		if child is TranslatorItem:
			found.append(child)
		
		# Parcours récursif pour chercher aussi dans les enfants
		found += get_all_text_nodes(child)
	
	return found

static func Init():
	if init :
		return
	if FileAccess.file_exists("res://wordlist.json"):
		var file := FileAccess.open("res://wordlist.json", FileAccess.READ)
		var content := file.get_as_text()
		file.close()
		words = JSON.parse_string(content)
		if typeof(words) != TYPE_DICTIONARY:
			print("Fichier JSON invalide")
			return
	init = true
	LANGUAGE = OS.get_locale_language()
	print("Init ok, set language to " + LANGUAGE)

func TranslateAllTexts():
	for node in get_all_text_nodes(get_tree().current_scene):
		print("translate " + node.name)
		(node as TranslatorItem).Translate()

static func Get(label: String) -> String:
	if label == "":
		return ""
	Init()
	print("GET " + label + " IN " + LANGUAGE)
	
	if words.has(label):
		if words[label].has(LANGUAGE):
			return words[label][LANGUAGE]
		if words[label].has("en"):
			return words[label]["en"]
		return label.replace("_", " ")
		
	if Engine.is_editor_hint() or OS.has_feature("editor"):
		words.set(label, {"en" : label.replace("_", " "), "fr" : ""})
		SaveWords()
	return label.replace("_", " ")

static func SaveWords():
	print("saving words !")
	var json := JSON.stringify(words, "\t")
	var file := FileAccess.open("res://wordlist.json", FileAccess.WRITE)
	file.store_string(json)
	file.close()
