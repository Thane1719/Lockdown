extends Node3D

@onready var timer = $Timer
@onready var hurtArea = $HurtArea

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_damage_timer_timeout() -> void:
	var bodies = hurtArea.get_overlapping_bodies()
	for i in bodies:
		if i.has_method("take_damage"):
			i.take_damage(10, "trap", "Cop")  # Deal damage to the enemy
