extends Node2D

@onready var player_scene = preload("res://gameMechanics/2d_player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_player()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_player():
	var new_player = player_scene.instantiate()
	new_player.global_position = $SpawnPoint.global_position
	add_child(new_player)


func _on_area_2d_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body.name == "2DPlayer":
		Global.emit_signal("playerWonTask")
		get_tree().root.get_node("World").openTerminalDoors()
		get_tree().root.get_node("World").hasCompletedMiniTask = true
		get_tree().root.get_node("World").rpc("showAnnounceText", "Terminal has been breached", 3)
		await get_tree().create_timer(5).timeout
		get_tree().root.get_node("World").rpc("showAnnounceText", "Secondary door now open", 3)
