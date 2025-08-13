class_name ChatMessage

var content: String = ""
var channel: int = 0
var author: String = ""
var creation_schedule: float = 0.0

func _init(from_content: String = "", from_channel : int = 0, from_author: String = "", at_time: float = 0.0) -> void:
	creation_schedule = Time.get_unix_time_from_system() if at_time == 0.0 else at_time
	content = from_content
	channel = from_channel
	author = from_author
