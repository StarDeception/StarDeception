extends PanelContainer

@export var input_field: LineEdit
@export var output_field: RichTextLabel
@export var channel_selector: OptionButton
var is_visible := false

# Définition d'une "classe" interne pour Message
class Message:
	var content: String
	var channel: int
	var author: String
	var gdh := Time.get_datetime_dict_from_system()

# Liste pour stocker les messages
var messages: Array[Message] = []

# Énumération des canaux
enum ChannelE {
	GENERAL,
	DIRECT_MESSAGE,
	GROUP,
	ALLIANCE,
	REGION,
	UNSPECIFIED
}

# Couleurs forcées en hexadécimal selon le canal
var forced_colors := {
	str(ChannelE.GENERAL): "FFFFFF",
	str(ChannelE.UNSPECIFIED): "AAAAAA",
	str(ChannelE.GROUP): "27C8F5",
	str(ChannelE.ALLIANCE): "D327F5",
	str(ChannelE.REGION): "F7F3B5",
	str(ChannelE.DIRECT_MESSAGE): "79F25E"
}

func _ready():
	visible = true

	# Si on est dans l'éditeur → affichage texte aléatoire pour démo
	if Engine.is_editor_hint() or OS.has_feature("editor"):
		var lorem := "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?"
		var text_users := ["NeozSagan", "ddurieu", "irong", "The_Moye", "Syffix", "Sangoku"]
		randomize()

		for i in range(30):
			var user : String = text_users[randi() % text_users.size()]
			# récupère un index valide dans l'enum
			var channel : int = randi() % ChannelE.keys().size()
			var start := (randi() % lorem.length()) / 2
			var length := (randi() % lorem.length()) / 6
			var snippet := lorem.substr(start, length)
			receive_message_from_server(snippet, user, channel)

	# Ajout des différents canaux dans le sélecteur
	for name in ChannelE.keys():
		channel_selector.add_item(name)
	channel_selector.selected = 0
	
func _process(delta):
	if Input.is_action_just_pressed("toggle_chat"):
		is_visible = not is_visible
		visible = is_visible

	if is_visible:
		input_field.grab_focus()
	else:
		get_viewport().set_input_as_handled()

func _on_input_text_text_submitted(nt: String) -> void:
	if nt.strip_edges() == "":
		return
	send_message_to_server(nt)
	input_field.text = ""

# Envoie un message (ici court-circuité en local) avec le canal sélectionné
func send_message_to_server(txt: String) -> void:
	var channel_name := channel_selector.get_item_text(channel_selector.get_selected_id())
	var channel_value : int = ChannelE[channel_name]
	receive_message_from_server(txt, "NeozSagan", channel_value)


# Reçoit un message du serveur
func receive_message_from_server(message: String, user_nick: String, channel: int) -> void:
	var msg := Message.new()
	msg.content = message
	msg.author = user_nick
	msg.channel = channel
	messages.append(msg)
	parse_message(msg)


# Parse un message pour affichage et gestion mémoire
func parse_message(msg: Message) -> void:
	# Si plus de 100 messages → on garde les 50 derniers
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


# Renvoie un code couleur hexa aléatoire mais constant pour un texte donné
func get_hexa_color_from_hash(text: String) -> String:
	if forced_colors.has(text):
		return forced_colors[text]

	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var hash_bytes := ctx.finish()
	return hash_bytes.hex_encode().substr(0, 6)
