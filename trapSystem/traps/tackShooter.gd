extends Node3D

@onready var timer = $Timer
@onready var animationPlayer = $AnimationPlayer
var bullet = preload("res://Scenes/Bullet.tscn")
@onready var barrel1 = $Marker3D
@onready var barrel2 = $Marker3D2
@onready var barrel3 = $Marker3D3
@onready var barrel4 = $Marker3D4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_damage_timer_timeout() -> void:
	#This is a crappy way to do this, oh well!
	var instantiatedBullet = bullet.instantiate()
	instantiatedBullet.global_transform = barrel1.global_transform
	get_tree().root.get_node("World").add_child(instantiatedBullet)
	
	var instantiatedBullet2 = bullet.instantiate()
	instantiatedBullet2.global_transform = barrel2.global_transform
	get_tree().root.get_node("World").add_child(instantiatedBullet2)

	var instantiatedBullet3 = bullet.instantiate()
	instantiatedBullet3.global_transform = barrel3.global_transform
	get_tree().root.get_node("World").add_child(instantiatedBullet3)

	var instantiatedBullet4 = bullet.instantiate()
	instantiatedBullet4.global_transform = barrel4.global_transform
	get_tree().root.get_node("World").add_child(instantiatedBullet4)
	
	animationPlayer.play("Shoot")
