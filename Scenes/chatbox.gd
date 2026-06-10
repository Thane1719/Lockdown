extends Node2D

@onready var Message = $Message
@onready var Send = $Send
@onready var Messages = $Messages
@onready var Chatbox = self

func _ready(): #Hides the chatbox
	Chatbox.hide()
	Send.pressed.connect(_on_send_pressed)

func _process(delta):
	if Input.is_action_just_pressed("chatbox"):
		Chatbox.visible = !Chatbox.visible

		if Chatbox.visible: #Changes the mouse mode and auto focus's the chatbox.
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Message.grab_focus()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			Message.release_focus()

func _on_send_pressed() -> void:

	var text = Message.text.strip_edges()

	if text == "": # Don't send empty messages
		return

	# Sends the message to everybody
	send_message.rpc(multiplayer.get_unique_id(), text)

	Message.text = ""

# Multiplayer Fuction
@rpc("any_peer", "call_local")
func send_message(player_id, text):
	
# Creates a new label for the message
	var new_message = Label.new()
	new_message.text = str(player_id) + ": " + text

	Messages.add_child(new_message)
