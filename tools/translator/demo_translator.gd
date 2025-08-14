extends Node

@export var dropdown: OptionButton
@export var trans_instance: Translator

func _ready() -> void:
	if OS.get_locale_language() == "en":
		dropdown.select(0)
	else:
		dropdown.select(1)
	print(Translator.Get("this_will_be_translated"))

func _on_option_button_item_selected(index: int) -> void:
	Translator.LANGUAGE = dropdown.get_item_text(index)
	print("language set to " + dropdown.get_item_text(index))
	trans_instance.TranslateAllTexts()
