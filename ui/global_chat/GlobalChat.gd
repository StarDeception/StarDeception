extends PanelContainer

@export var input_field: LineEdit
@export var output_field: RichTextLabel
@export var channel_selector: OptionButton
var is_visible := false

# Definition of an internal “class” for Message
class Message:
	var content: String
	var channel: int
	var author: String
	var gdh := Time.get_datetime_dict_from_system()

# List for storing messages
var messages: Array[Message] = []
var messages_waiting: Array[Message] = []

# Channel enumeration
enum ChannelE {
	GENERAL,
	DIRECT_MESSAGE,
	GROUP,
	ALLIANCE,
	REGION,
	UNSPECIFIED
}

# Forced colors in hexadecimal according to channel
var forced_colors := {
	str(ChannelE.GENERAL): "FFFFFF",
	str(ChannelE.UNSPECIFIED): "AAAAAA",
	str(ChannelE.GROUP): "27C8F5",
	str(ChannelE.ALLIANCE): "D327F5",
	str(ChannelE.REGION): "F7F3B5",
	str(ChannelE.DIRECT_MESSAGE): "79F25E"
}

# Prevents keyboard input from being sent to the game if the chat is visible
func _unhandled_input(event):
	if event is InputEventKey and event.is_pressed():
		if is_visible and input_field.has_focus():
			get_viewport().set_input_as_handled()

func _ready():
	visible = true
	is_visible = visible

	# Adding different channels to the selector
	for name in ChannelE.keys():
		channel_selector.add_item(name)
	channel_selector.selected = 0

# Boucle principale qui vérifie que l'on appuie sur F12 ou pas
func _process(delta):
	if Input.is_action_just_pressed("toggle_chat"):
		is_visible = not is_visible
		visible = is_visible

	if is_visible:
		input_field.grab_focus()
	else:
		for m in messages_waiting:
			parse_message(m)
		messages_waiting.clear()
		get_viewport().set_input_as_handled()

func _on_input_text_text_submitted(nt: String) -> void:
	if nt.strip_edges() == "":
		return
	send_message_to_server(nt)
	input_field.text = ""

# Send a message (here short-circuited locally) with the selected channel
func send_message_to_server(txt: String) -> void:
	var channel_name := channel_selector.get_item_text(channel_selector.get_selected_id())
	var channel_value : int = ChannelE[channel_name]
	receive_message_from_server(txt, "NeozSagan", channel_value)

# Receives a message from the server
func receive_message_from_server(message: String, user_nick: String, channel: int) -> void:
	var msg := Message.new()
	msg.content = message
	msg.author = user_nick
	msg.channel = channel
	messages.append(msg)
	if is_visible:
		parse_message(msg)
	else:
		messages_waiting.append(msg)
		if messages_waiting.size() > 100:
			messages_waiting = messages_waiting.slice(50, messages_waiting.size() - 50)


# Parse a message for display, and memory management
func parse_message(msg: Message) -> void:
	# If there are more than 100 messages → keep the last 50
	if messages.size() > 100:
		output_field.clear()
		messages = messages.slice(50, messages.size() - 50)
		for m in messages:
			parse_message(m)
		return

	var now := Time.get_datetime_dict_from_system()
	var gdh := "%02d:%02d:%02d" % [now.hour, now.minute, now.second]

	output_field.append_text(
		"[%s] : [color=#%s]%s [/color][color=#%s]%s%s[/color]\n" % [
			gdh,
			get_hexa_color_from_hash(msg.author),
			msg.author,
			get_hexa_color_from_hash(str(msg.channel)),
			("" if msg.channel == ChannelE.UNSPECIFIED else "(" + ChannelE.keys()[msg.channel] + ") "),
			msg.content
		]
	)


# Returns a random but constant hex color code for a given text
func get_hexa_color_from_hash(text: String) -> String:
	if forced_colors.has(text):
		return forced_colors[text]

	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var hash_bytes := ctx.finish()
	return hash_bytes.hex_encode().substr(0, 6)
