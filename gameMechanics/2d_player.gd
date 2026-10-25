extends CharacterBody2D


#const SPEED = 300.0
@export var SPEED: float = 300.0
const JUMP_VELOCITY = -400.0
var screen_size: Vector2


func ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	screen_size = get_viewport_rect().size


func _physics_process(delta: float) -> void:
	var direction = Input.get_vector("left", "right", "forward", "backward")
	if direction:
		velocity = lerp(velocity, direction * SPEED, 0.2)
	else:
		velocity = lerp(velocity, Vector2(0,0), 0.2)
	
	move_and_slide()

func die(): 
	queue_free()
