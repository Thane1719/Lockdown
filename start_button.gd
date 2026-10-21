
extends Button

const LOBBY_SCENE_PATH: String = "res://Scenes/lobby.tscn"

@export var name_entry: LineEdit


func _ready() -> void:
	if name_entry == null:
		disabled = true
		push_error("Username LineEdit is not assigned!")
		return

	disabled = name_entry.text.strip_edges().is_empty()
	name_entry.text_changed.connect(_on_name_entry_text_changed)


func _on_name_entry_text_changed(new_text: String) -> void:
	disabled = new_text.strip_edges().is_empty()


func _on_pressed() -> void:
	if name_entry == null:
		return

	var entered_name: String = name_entry.text.strip_edges()

	if entered_name.is_empty():
		return

	# Save the username.
	Global.player_name = entered_name
	Global.name_entered = true

	# Tell the lobby to skip its menu.
	Global.skip_lobby_menu = true

	# Load the lobby scene.
	var error = get_tree().change_scene_to_file(LOBBY_SCENE_PATH)

	if error != OK:
		Global.name_entered = false
		Global.skip_lobby_menu = false
		push_error("Failed to load lobby: " + str(error))
