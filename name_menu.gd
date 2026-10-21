extends Node

@onready var name_entry: LineEdit = $CanvasLayer/MenuBackground/LineEdit
@onready var start_button: Button = $CanvasLayer/MenuBackground/Button


func _ready() -> void:
	# Disable Start if the username is empty.
	start_button.disabled = name_entry.text.strip_edges().is_empty()

	# Update the button whenever the user types.
	name_entry.text_changed.connect(_on_name_entry_text_changed)

	name_entry.grab_focus()


func _on_name_entry_text_changed(new_text: String) -> void:
	start_button.disabled = new_text.strip_edges().is_empty()
