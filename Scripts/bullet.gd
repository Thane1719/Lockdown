extends Area3D

var speed : float = 32.0
var damage : int = 25

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.start(3)
	await $Timer.timeout
	destroy()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_transform.origin -= transform.basis.z.normalized() * speed * delta


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, "trap", "Cop")
	destroy()

func destroy():
	queue_free()
