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
		print("You Win!")
